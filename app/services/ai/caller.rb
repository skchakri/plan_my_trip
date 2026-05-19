require "digest"

module Ai
  # Unified entry point for every AI call in the app.
  #
  #   Ai::Caller.call(slug: "highlight_detail.v1",
  #                   variables: { destination: "Hanksville", name: "Goblin Valley" },
  #                   user: current_user, trip: @trip)
  #
  # - Looks up the AiPrompt by slug (must exist & be active)
  # - Renders the system + user templates with the given variables
  # - Returns a 30-day cached response if the rendered prompts hash matches
  #   a prior successful call (same provider/model/params)
  # - Otherwise dispatches to the configured provider, then caches the result
  # - Records an AiCall row with status / timings / tokens / rendered prompts
  #   (cache hits get latency_ms=0, tokens=0, meta.cached=true)
  # - Returns an Ai::Result the caller can introspect (text, json, image_url)
  class Caller
    class PromptNotFoundError < StandardError; end

    CACHE_TTL = 30.days
    CACHE_NAMESPACE = "ai_call/v1".freeze

    def self.call(...)
      new(...).call
    end

    def initialize(slug:, variables: {}, user: nil, trip: nil, cache: true)
      @slug = slug.to_s
      @variables = variables || {}
      @user = user
      @trip = trip
      @cache = cache
    end

    def call
      prompt = AiPrompt.active.find_by(slug: @slug)
      unless prompt
        Rails.logger.warn("[Ai::Caller] no active prompt for slug=#{@slug}")
        return Result.new(text: nil, error: "prompt missing: #{@slug}")
      end

      rendered = prompt.render(@variables)
      use_cache = @cache && cacheable?(prompt)
      key = cache_key_for(prompt, rendered)
      if use_cache
        cached = Rails.cache.read(key)
        return cache_hit_result(prompt, rendered, cached) if cached
      end

      audit = create_audit!(prompt, rendered)

      provider = provider_for(prompt)
      started = Time.current
      text_or_url, usage, error = provider.call(rendered)
      latency_ms = ((Time.current - started) * 1000).round

      if error
        audit.update!(status: "failure", error: error.to_s.truncate(2000), latency_ms: latency_ms)
        return Result.new(text: nil, call: audit, error: error)
      end

      attrs = {
        status: "success",
        latency_ms: latency_ms,
        input_tokens: usage[:input_tokens],
        output_tokens: usage[:output_tokens]
      }
      if prompt.kind == "image"
        attrs[:image_url] = text_or_url
      else
        attrs[:response_text] = text_or_url
      end
      audit.update!(attrs)

      write_cache(key, prompt, text_or_url) if use_cache

      Result.new(text: prompt.kind == "image" ? nil : text_or_url, image_url: prompt.kind == "image" ? text_or_url : nil, call: audit)
    rescue StandardError => e
      ErrorTracker.report(e, source: "Ai::Caller", context: { slug: @slug })
      Result.new(text: nil, error: "#{e.class}: #{e.message}")
    end

    private

    def provider_for(prompt)
      case prompt.provider
      when "anthropic"  then AnthropicProvider.new(prompt)
      when "openai"     then OpenaiProvider.new(prompt)
      when "claude_cli" then ClaudeCliProvider.new(prompt)
      else raise "Unknown provider #{prompt.provider}"
      end
    end

    def create_audit!(prompt, rendered, meta: {})
      AiCall.create!(
        ai_prompt: prompt,
        prompt_slug: prompt.slug,
        provider: prompt.provider,
        model: prompt.model,
        status: "pending",
        user: @user,
        trip: @trip,
        input_variables: serialize_variables(@variables),
        rendered_system: rendered[:system],
        rendered_user: rendered[:user],
        meta: meta
      )
    end

    # Build a stable cache key from prompt identity + rendered inputs.
    # prompt.updated_at busts the cache whenever an admin edits the prompt;
    # model/temperature/max_tokens busts it when generation params change.
    def cache_key_for(prompt, rendered)
      payload = [
        prompt.slug,
        prompt.updated_at&.to_i,
        prompt.provider,
        prompt.model,
        prompt.kind,
        prompt.max_tokens,
        prompt.temperature&.to_s,
        rendered[:system].to_s,
        rendered[:user].to_s
      ].join("\x1F")
      "#{CACHE_NAMESPACE}/#{Digest::SHA256.hexdigest(payload)}"
    end

    def write_cache(key, prompt, text_or_url)
      return if text_or_url.blank?
      payload =
        if prompt.kind == "image"
          { image_url: text_or_url }
        else
          { text: text_or_url }
        end
      Rails.cache.write(key, payload, expires_in: ttl_for(prompt))
    end

    def cacheable?(prompt)
      # New columns default to (cacheable: true, cache_ttl_seconds: nil) so
      # prompts created before this migration keep the prior 30-day behavior.
      prompt.respond_to?(:cacheable) ? prompt.cacheable != false : true
    end

    def ttl_for(prompt)
      seconds = prompt.respond_to?(:cache_ttl_seconds) ? prompt.cache_ttl_seconds : nil
      seconds.to_i.positive? ? seconds.seconds : CACHE_TTL
    end

    def cache_hit_result(prompt, rendered, cached)
      audit = create_audit!(prompt, rendered, meta: { "cached" => true })
      attrs = {
        status: "success",
        latency_ms: 0,
        input_tokens: 0,
        output_tokens: 0
      }
      if prompt.kind == "image"
        attrs[:image_url] = cached[:image_url] || cached["image_url"]
      else
        attrs[:response_text] = cached[:text] || cached["text"]
      end
      audit.update!(attrs)
      Result.new(
        text: prompt.kind == "image" ? nil : (cached[:text] || cached["text"]),
        image_url: prompt.kind == "image" ? (cached[:image_url] || cached["image_url"]) : nil,
        call: audit
      )
    end

    # Strip ActiveRecord objects / Procs / unserializable junk before saving
    # the input_variables jsonb column.
    def serialize_variables(vars)
      vars.transform_values do |v|
        case v
        when String, Integer, Float, TrueClass, FalseClass, NilClass then v
        when Array, Hash
          begin
            JSON.parse(v.to_json)
          rescue StandardError
            v.to_s.truncate(500)
          end
        else v.to_s.truncate(500)
        end
      end
    end
  end
end
