module Ai
  # Unified entry point for every AI call in the app.
  #
  #   Ai::Caller.call(slug: "highlight_detail.v1",
  #                   variables: { destination: "Hanksville", name: "Goblin Valley" },
  #                   user: current_user, trip: @trip)
  #
  # - Looks up the AiPrompt by slug (must exist & be active)
  # - Renders the system + user templates with the given variables
  # - Dispatches to the configured provider (anthropic or openai)
  # - Records an AiCall row with status / timings / tokens / rendered prompts
  # - Returns an Ai::Result the caller can introspect (text, json, image_url)
  class Caller
    class PromptNotFoundError < StandardError; end

    def self.call(...)
      new(...).call
    end

    def initialize(slug:, variables: {}, user: nil, trip: nil)
      @slug = slug.to_s
      @variables = variables || {}
      @user = user
      @trip = trip
    end

    def call
      prompt = AiPrompt.active.find_by(slug: @slug)
      unless prompt
        Rails.logger.warn("[Ai::Caller] no active prompt for slug=#{@slug}")
        return Result.new(text: nil, error: "prompt missing: #{@slug}")
      end

      rendered = prompt.render(@variables)
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

      Result.new(text: prompt.kind == "image" ? nil : text_or_url, image_url: prompt.kind == "image" ? text_or_url : nil, call: audit)
    rescue => e
      Rails.logger.warn("[Ai::Caller] #{@slug}: #{e.class}: #{e.message}")
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

    def create_audit!(prompt, rendered)
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
        rendered_user: rendered[:user]
      )
    end

    # Strip ActiveRecord objects / Procs / unserializable junk before saving
    # the input_variables jsonb column.
    def serialize_variables(vars)
      vars.transform_values do |v|
        case v
        when String, Integer, Float, TrueClass, FalseClass, NilClass then v
        when Array, Hash then JSON.parse(v.to_json) rescue v.to_s.truncate(500)
        else v.to_s.truncate(500)
        end
      end
    end
  end
end
