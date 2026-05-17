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
    DEFAULT_TIMEOUT_SECONDS = 1500

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
        "--output-format", "json"
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

      payload = JSON.parse(out)
      if payload["is_error"]
        return [ nil, {}, "claude CLI error: #{payload["api_error_status"] || payload["result"]}" ]
      end

      text = payload["result"].to_s
      usage = {
        input_tokens: payload.dig("usage", "input_tokens"),
        output_tokens: payload.dig("usage", "output_tokens")
      }
      [ text, usage, nil ]
    rescue JSON::ParserError => e
      [ nil, {}, "JSON parse: #{e.message}; raw=#{out.to_s.truncate(300)}" ]
    rescue => e
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
