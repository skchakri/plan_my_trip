require "test_helper"

# Retry-with-backoff on transient Messages API failures (429 / 5xx / 520 /
# network timeouts). Non-retryable client errors (400/401/403/404) and the
# final exhausted attempt return the error string unchanged.
class Ai::AnthropicProviderRetryTest < ActiveSupport::TestCase
  def provider
    prompt = AiPrompt.new(slug: "t", name: "t", provider: "anthropic",
                          model: "claude-sonnet-4-6", user_template: "hi", max_tokens: 64)
    p = Ai::AnthropicProvider.new(prompt)
    p.define_singleton_method(:api_key) { "sk-test" }
    p.define_singleton_method(:sleep) { |*| nil } # no real backoff sleeps in tests
    p
  end

  # Build a fake Net::HTTPResponse-ish double for a given status code.
  def http_response(code, body: "{}", headers: {})
    klass = code.to_i == 200 ? Net::HTTPOK : Net::HTTPServerError
    res = klass.new("1.1", code.to_s, "msg")
    res.instance_variable_set(:@fake_body, body)
    res.define_singleton_method(:body) { @fake_body }
    headers.each { |k, v| res[k] = v }
    res
  end

  def success_body
    { "content" => [ { "type" => "text", "text" => "ok" } ],
      "usage" => { "input_tokens" => 1, "output_tokens" => 1 } }.to_json
  end

  test "retries a 429 then succeeds" do
    p = provider
    responses = [ http_response(429, body: "rate limited"), http_response(200, body: success_body) ]
    p.define_singleton_method(:post) { |_body| responses.shift }

    text, _usage, error = p.call({ system: nil, user: "hi" })
    assert_nil error
    assert_equal "ok", text
    assert_empty responses, "should have consumed both responses (1 retry)"
  end

  test "gives up after MAX_ATTEMPTS on persistent 529" do
    p = provider
    res = http_response(529, body: "overloaded")
    calls = 0
    p.define_singleton_method(:post) { |_body| calls += 1; res }

    text, _usage, error = p.call({ system: nil, user: "hi" })
    assert_nil text
    assert_match(/HTTP 529/, error)
    assert_equal Ai::AnthropicProvider::MAX_ATTEMPTS, calls
  end

  test "does NOT retry a 400 (e.g. credit balance too low)" do
    p = provider
    res = http_response(400, body: '{"error":{"message":"credit balance too low"}}')
    calls = 0
    p.define_singleton_method(:post) { |_body| calls += 1; res }

    _text, _usage, error = p.call({ system: nil, user: "hi" })
    assert_match(/HTTP 400/, error)
    assert_equal 1, calls, "client errors must not be retried"
  end

  test "retries a network timeout then succeeds" do
    p = provider
    ok = http_response(200, body: success_body)
    seq = [ :raise, :ok ]
    p.define_singleton_method(:post) do |_body|
      case seq.shift
      when :raise then raise Net::ReadTimeout
      else ok
      end
    end

    text, _usage, error = p.call({ system: nil, user: "hi" })
    assert_nil error
    assert_equal "ok", text
  end

  test "a persistent network error is reported as an error string, not raised" do
    p = provider
    p.define_singleton_method(:post) { |_body| raise Net::OpenTimeout }
    _text, _usage, error = p.call({ system: nil, user: "hi" })
    assert_match(/Net::OpenTimeout/, error)
  end

  test "backoff honors a sane retry-after header, else exponential capped" do
    p = provider
    res = http_response(429, headers: { "retry-after" => "3" })
    assert_equal 3.0, p.send(:backoff_seconds, 1, res)

    # No header → exponential: 0.5, 1, 2, … capped at BACKOFF_MAX
    assert_equal 0.5, p.send(:backoff_seconds, 1, nil)
    assert_equal 1.0, p.send(:backoff_seconds, 2, nil)
    assert_equal Ai::AnthropicProvider::BACKOFF_MAX, p.send(:backoff_seconds, 20, nil)
  end

  test "retryable_status? classifies transient vs client errors" do
    p = provider
    [ 429, 500, 502, 503, 520, 529 ].each { |c| assert p.send(:retryable_status?, c), "#{c} should retry" }
    [ 400, 401, 403, 404, 200 ].each { |c| refute p.send(:retryable_status?, c), "#{c} should not retry" }
  end
end
