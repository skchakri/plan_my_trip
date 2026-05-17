module Ai
  # Wraps a single AI call's outcome — the raw text (or image URL) plus the
  # AiCall audit row so callers can introspect tokens / latency / failure.
  Result = Struct.new(:text, :image_url, :call, :error, keyword_init: true) do
    def success?
      error.nil?
    end

    def json
      return nil if text.blank?
      cleaned = text.to_s.sub(/\A\s*```(?:json)?\s*/, "").sub(/\s*```\s*\z/, "").strip
      brace = cleaned.index("{")
      bracket = cleaned.index("[")
      # Pick whichever delimiter the JSON value *starts* with — otherwise an
      # array of objects gets sliced as `{...},{...}` (the inner brace beats
      # the outer bracket) and fails to parse.
      pair = [ [ brace, "{", "}" ], [ bracket, "[", "]" ] ].reject { |i, _, _| i.nil? }.min_by { |i, _, _| i }
      return nil unless pair
      s, _, close_char = pair
      e = cleaned.rindex(close_char)
      return nil unless e && e > s
      JSON.parse(cleaned[s..e])
    rescue JSON::ParserError
      nil
    end
  end
end
