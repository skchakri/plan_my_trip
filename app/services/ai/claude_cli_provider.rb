require "open3"
require "json"
require "shellwords"

module Ai
  # Text generation via the local `claude` CLI (Claude Code) — uses the
  # operator's logged-in subscription (Pro/Max) instead of a pay-per-token
  # API key. Useful for local dev and bulk seeding where API balance
  # exhaustion is the bottleneck.
  #
  # Mechanics:
  #   1. Pipes the rendered user prompt on stdin to:
  #        claude -p --model <model> --system-prompt <sys> --output-format json
  #   2. Parses the result JSON, returns `.result` as the text.
  #
  # Caveats:
  #   - Requires `claude` CLI on PATH and an authenticated session
  #     (`claude login` once). Won't work from inside Docker unless the
  #     CLI + auth dir are mounted in.
  #   - Default system prompt of Claude Code is huge (~28k tokens of
  #     hooks/MCP context). Cached at Anthropic for 5min so consecutive
  #     calls amortize. For subscription users, none of that bills.
  #   - `--bare` would skip the overhead BUT also disables OAuth/keychain
  #     auth — we explicitly DON'T pass it so the subscription is used.
  class ClaudeCliProvider
    # 60 minutes. The trip_structure.v1 prompt is the long-pole (20+
    # activities × narration scripts × web-search-augmented details).
    # Has hit 25min in production; 60min buys runway without leaving
    # zombies if the CLI truly hangs.
    DEFAULT_TIMEOUT_SECONDS = 3600

    def initialize(prompt)
      @prompt = prompt
    end

    def available?
      path = ENV["CLAUDE_CLI_PATH"].presence || `which claude 2>/dev/null`.strip
      !path.empty? && File.executable?(path)
    end

    # rendered: { system: "...", user: "..." }
    # Returns [text, usage_hash, error_or_nil]
    def call(rendered)
      return [ nil, {}, "claude CLI not installed or not on PATH" ] unless available?

      cli = ENV["CLAUDE_CLI_PATH"].presence || "claude"
      args = [
        cli, "-p",
        "--model", model_alias(@prompt.model),
        # Stream-json over plain json so we don't lose huge responses to
        # the CLI's `result`-field truncation. Verified case: trip_structure
        # generated 35k output_tokens but `--output-format json` only kept
        # ~3k tokens worth of `result`. Stream-json delivers each assistant
        # message as its own NDJSON line; we accumulate the text ourselves.
        # --verbose is required by the CLI when pairing -p with stream-json.
        "--output-format", "stream-json",
        "--verbose",
        # Web tools — let the model look up niche / locally-known spots
        # (canyoneering blogs, Reddit, AllTrails trip reports) that aren't
        # in its training data. Surfacing things like Hanksville's
        # "Moonscape Overlook" or "Bentonite Hills Viewpoint" requires
        # live search — Wikipedia/training doesn't have them. Using
        # --settings to pre-grant the tools rather than --permission-mode
        # bypassPermissions, because the latter is refused when the CLI
        # runs as root (which Puma does in our docker container).
        "--allowed-tools", "WebSearch,WebFetch",
        "--settings", '{"permissions":{"allow":["WebSearch","WebFetch"]}}'
      ]
      if rendered[:system].to_s.strip.present?
        args.push("--system-prompt", rendered[:system].to_s)
      end

      env = ENV.to_h.merge(
        # Don't let any caller-provided ANTHROPIC_API_KEY override OAuth —
        # if a key is present, Claude Code prefers it. We want subscription.
        "ANTHROPIC_API_KEY" => nil,
        "CLAUDE_CODE_USE_OAUTH" => "1"
      )

      stdin, stdout, stderr, thr = Open3.popen3(env, *args)
      stdin.write(rendered[:user].to_s)
      stdin.close

      out = +""
      err = +""
      reader_out = Thread.new { out << stdout.read }
      reader_err = Thread.new { err << stderr.read }

      unless thr.join(DEFAULT_TIMEOUT_SECONDS)
        Process.kill("TERM", thr.pid) rescue nil
        thr.join(2)
        return [ nil, {}, "claude CLI timed out after #{DEFAULT_TIMEOUT_SECONDS}s" ]
      end
      reader_out.join
      reader_err.join

      unless thr.value.success?
        return [ nil, {}, "claude CLI exit #{thr.value.exitstatus}: #{err.to_s.truncate(400).presence || out.to_s.truncate(400)}" ]
      end

      # Parse stream-json NDJSON. Each line is a CLI event. The model can
      # emit MULTIPLE `assistant` events for one prompt (think-then-output
      # or tool-use turns), and concatenating them produces duplicated
      # content — we hit this on trip_structure where two assistant turns
      # both contained the full JSON object, yielding a corrupted blob.
      # So we keep only the LAST assistant message's text (final answer)
      # and pull usage from the `result` event.
      last_assistant_text = nil
      usage = {}
      final_error = nil
      out.each_line do |line|
        line = line.strip
        next if line.empty?
        begin
          ev = JSON.parse(line)
        rescue JSON::ParserError
          next
        end
        case ev["type"]
        when "assistant"
          chunks = Array(ev.dig("message", "content")).select { |c| c.is_a?(Hash) && c["type"] == "text" }
          combined = chunks.map { |c| c["text"].to_s }.join
          last_assistant_text = combined unless combined.empty?
        when "result"
          if ev["is_error"]
            final_error = "claude CLI error: #{ev["api_error_status"] || ev["result"]}"
          end
          usage = {
            input_tokens: ev.dig("usage", "input_tokens"),
            output_tokens: ev.dig("usage", "output_tokens")
          }
          # Prefer the explicit `result` field when it's substantial — the
          # CLI's final summary is usually the cleanest version. Fall back
          # to the streamed assistant text when `result` is empty.
          result_text = ev["result"].to_s
          last_assistant_text = result_text if result_text.length > last_assistant_text.to_s.length
        end
      end
      text = last_assistant_text.to_s

      return [ nil, usage, final_error ] if final_error
      return [ nil, usage, "claude CLI returned no text (raw stderr=#{err.to_s.truncate(300)})" ] if text.empty?
      [ text, usage, nil ]
    rescue JSON::ParserError => e
      [ nil, {}, "JSON parse: #{e.message}; raw=#{out.to_s.truncate(300)}" ]
    rescue StandardError => e
      [ nil, {}, "#{e.class}: #{e.message}" ]
    end

    private

    # The CLI accepts "sonnet"/"opus"/"haiku" aliases for the latest model
    # of each tier. Translate full names so admin-edited prompts stay
    # readable but the CLI resolves correctly.
    def model_alias(model)
      case model.to_s
      when /opus/   then "opus"
      when /haiku/  then "haiku"
      else "sonnet"
      end
    end
  end
end
