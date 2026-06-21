require "net/http"
require "uri"
require "json"

module Ai
  # Text generation via the Anthropic Messages API.
  class AnthropicProvider
    API_URL = URI("https://api.anthropic.com/v1/messages").freeze
    ANTHROPIC_VERSION = "2023-06-01".freeze
    DEFAULT_READ_TIMEOUT = 300

    def initialize(prompt)
      @prompt = prompt
    end

    def api_key
      AppSetting.get("ANTHROPIC_API_KEY").presence ||
        (Rails.application.credentials.respond_to?(:anthropic) && Rails.application.credentials.anthropic&.dig(:api_key))
    end

    # rendered: { system: "...", user: "..." }
    # Returns [text, usage_hash, error_or_nil]
    def call(rendered)
      return [ nil, {}, "ANTHROPIC_API_KEY missing" ] if api_key.blank?

      req = Net::HTTP::Post.new(API_URL)
      req["x-api-key"] = api_key
      req["anthropic-version"] = ANTHROPIC_VERSION
      req["content-type"] = "application/json"
      req.body = build_body(rendered).to_json

      res = Net::HTTP.start(API_URL.hostname, API_URL.port, use_ssl: true, read_timeout: DEFAULT_READ_TIMEOUT, open_timeout: 10) do |http|
        http.request(req)
      end

      unless res.is_a?(Net::HTTPSuccess)
        return [ nil, {}, "HTTP #{res.code}: #{res.body.to_s.truncate(200)}" ]
      end

      json = JSON.parse(res.body)
      text = Array(json["content"]).filter_map { |c| c["text"] if c["type"] == "text" }.join("\n").strip
      usage = {
        input_tokens: json.dig("usage", "input_tokens"),
        output_tokens: json.dig("usage", "output_tokens")
      }
      [ text, usage, nil ]
    rescue StandardError => e
      ErrorTracker.report(e, source: "Ai::AnthropicProvider", context: { model: @prompt&.model })
      [ nil, {}, "#{e.class}: #{e.message}" ]
    end

    private

    # Builds the Messages API request body for `rendered` ({ system:, user: }).
    def build_body(rendered)
      body = {
        model: @prompt.model,
        max_tokens: @prompt.max_tokens || 1024,
        system: rendered[:system].presence,
        messages: [ { role: "user", content: rendered[:user].to_s } ]
      }
      body[:temperature] = @prompt.temperature.to_f if @prompt.temperature

      # Structured Outputs (opt-in). When a prompt declares an `output_schema`,
      # constrain the response to that JSON schema at decode time so JSON-shaped
      # prompts (trip_structure.v1 etc.) can't return malformed JSON or stray
      # prose. GA on claude-sonnet-4-6 + the Opus 4.x family. The schema must set
      # `additionalProperties: false` and avoid min/max/length constraints
      # (unsupported). Incompatible with prefilling/citations — neither of which
      # this provider uses. Off unless a prompt opts in, so existing calls are
      # byte-for-byte unchanged.
      if @prompt.respond_to?(:output_schema) && @prompt.output_schema.present?
        body[:output_config] = { format: { type: "json_schema", schema: @prompt.output_schema } }
      end

      body.compact
    end
  end
end
