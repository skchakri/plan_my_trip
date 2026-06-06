require "net/http"
require "uri"
require "json"

module Ai
  # Text generation via Perplexity's Sonar models — a search-augmented LLM
  # with its own live web index. Unlike AnthropicProvider/OpenaiProvider
  # (training-data only) and ClaudeCliProvider (agentic web search, but slow
  # and tied to a local logged-in CLI), Perplexity answers from a fresh web
  # search in a *single, fast* API call and returns source citations.
  #
  # Why it exists: the day-trip / nearby-ideas research path needs CURRENT
  # data (seasonal closures, "events this weekend", newly-opened trails).
  # The claude_cli provider gets that but takes minutes and can't scale to
  # concurrent web requests. Perplexity gets it in seconds over a real API,
  # so an admin can flip `nearby_ideas.v1`'s provider to "perplexity" and
  # benchmark latency/quality with no redeploy.
  #
  # API is OpenAI-compatible: POST /chat/completions with a Bearer key.
  # Models: "sonar" (cheap, fast), "sonar-pro" (stronger reasoning + more
  # citations). Set the model on the AiPrompt row.
  class PerplexityProvider
    API_URL = URI("https://api.perplexity.ai/chat/completions").freeze
    # Sonar is search-augmented, so a call does real retrieval before
    # answering — slower than a bare completion but far faster than the
    # agentic CLI. 120s is generous headroom; typical calls finish in <15s.
    DEFAULT_READ_TIMEOUT = 120

    def initialize(prompt)
      @prompt = prompt
    end

    def api_key
      AppSetting.get("PERPLEXITY_API_KEY").presence ||
        (Rails.application.credentials.respond_to?(:perplexity) && Rails.application.credentials.perplexity&.dig(:api_key))
    end

    # rendered: { system: "...", user: "..." }
    # Returns [text, usage_hash, error_or_nil]
    def call(rendered)
      return [ nil, {}, "PERPLEXITY_API_KEY missing" ] if api_key.blank?

      req = Net::HTTP::Post.new(API_URL)
      req["Authorization"] = "Bearer #{api_key}"
      req["Content-Type"] = "application/json"

      messages = []
      messages << { role: "system", content: rendered[:system] } if rendered[:system].present?
      messages << { role: "user", content: rendered[:user].to_s }

      body = {
        model: model_name(@prompt.model),
        max_tokens: @prompt.max_tokens || 1024,
        messages: messages
      }
      body[:temperature] = @prompt.temperature.to_f if @prompt.temperature
      req.body = body.to_json

      res = Net::HTTP.start(API_URL.hostname, API_URL.port, use_ssl: true, read_timeout: DEFAULT_READ_TIMEOUT, open_timeout: 10) do |http|
        http.request(req)
      end

      unless res.is_a?(Net::HTTPSuccess)
        return [ nil, {}, "HTTP #{res.code}: #{res.body.to_s.truncate(200)}" ]
      end

      json = JSON.parse(res.body)
      text = json.dig("choices", 0, "message", "content").to_s.strip
      usage = {
        input_tokens: json.dig("usage", "prompt_tokens"),
        output_tokens: json.dig("usage", "completion_tokens"),
        # Perplexity returns the sources it consulted. The Caller contract
        # only persists token counts, but we surface citations here so a
        # future change can store them on the AiCall / Place for provenance.
        citations: Array(json["citations"]).presence || Array(json["search_results"]).filter_map { |s| s["url"] if s.is_a?(Hash) }
      }
      [ text, usage, nil ]
    rescue StandardError => e
      ErrorTracker.report(e, source: "Ai::PerplexityProvider", context: { model: @prompt&.model })
      [ nil, {}, "#{e.class}: #{e.message}" ]
    end

    private

    # Admins may leave a Claude/GPT model name on a prompt they flip to
    # Perplexity. Map obvious mismatches to a sane Sonar default so the
    # call still works; pass through anything that already looks like a
    # Perplexity model.
    def model_name(model)
      m = model.to_s.strip.downcase
      return m if m.start_with?("sonar") || m.start_with?("r1") || m.include?("perplexity")
      "sonar"
    end
  end
end
