require "net/http"
require "uri"
require "json"

module Ai
  # OpenAI provider. Used for image generation (gpt-image-2; gpt-image-1 retires
  # 2026-12-01 and dall-e-* were removed 2026-05-12 — set the model per-prompt).
  # Text mode is also supported via the Chat Completions API for parity with
  # Anthropic — admin can swap providers per-prompt without code changes.
  class OpenaiProvider
    IMAGE_URL = URI("https://api.openai.com/v1/images/generations").freeze
    CHAT_URL  = URI("https://api.openai.com/v1/chat/completions").freeze
    DEFAULT_READ_TIMEOUT = 120

    def initialize(prompt)
      @prompt = prompt
    end

    def api_key
      AppSetting.get("OPENAI_API_KEY").presence ||
        (Rails.application.credentials.respond_to?(:openai) && Rails.application.credentials.openai&.dig(:api_key))
    end

    def call(rendered)
      return [ nil, {}, "OPENAI_API_KEY missing" ] if api_key.blank?
      @prompt.kind == "image" ? call_image(rendered) : call_text(rendered)
    rescue StandardError => e
      ErrorTracker.report(e, source: "Ai::OpenaiProvider", context: { model: @prompt&.model, kind: @prompt&.kind })
      [ nil, {}, "#{e.class}: #{e.message}" ]
    end

    private

    def call_image(rendered)
      req = Net::HTTP::Post.new(IMAGE_URL)
      req["Authorization"] = "Bearer #{api_key}"
      req["Content-Type"] = "application/json"
      req.body = {
        model: @prompt.model,
        prompt: rendered[:user].to_s,
        n: 1,
        size: "1024x1024"
      }.to_json

      res = http_request(IMAGE_URL, req)
      return res if res[2] # error
      json = JSON.parse(res[3])
      url = json.dig("data", 0, "url") || json.dig("data", 0, "b64_json")
      [ url, {}, nil ]
    end

    def call_text(rendered)
      req = Net::HTTP::Post.new(CHAT_URL)
      req["Authorization"] = "Bearer #{api_key}"
      req["Content-Type"] = "application/json"
      messages = []
      messages << { role: "system", content: rendered[:system] } if rendered[:system].present?
      messages << { role: "user", content: rendered[:user].to_s }
      body = { model: @prompt.model, max_tokens: @prompt.max_tokens || 1024, messages: messages }
      body[:temperature] = @prompt.temperature.to_f if @prompt.temperature
      req.body = body.to_json

      res = http_request(CHAT_URL, req)
      return res if res[2] # error
      json = JSON.parse(res[3])
      text = json.dig("choices", 0, "message", "content").to_s.strip
      usage = {
        input_tokens: json.dig("usage", "prompt_tokens"),
        output_tokens: json.dig("usage", "completion_tokens")
      }
      [ text, usage, nil ]
    end

    # Returns [nil, {}, error, body] tuple — body for the success branches to parse.
    def http_request(url, req)
      res = Net::HTTP.start(url.hostname, url.port, use_ssl: true, read_timeout: DEFAULT_READ_TIMEOUT, open_timeout: 10) do |http|
        http.request(req)
      end
      unless res.is_a?(Net::HTTPSuccess)
        return [ nil, {}, "HTTP #{res.code}: #{res.body.to_s.truncate(200)}", nil ]
      end
      [ nil, {}, nil, res.body ]
    end
  end
end
