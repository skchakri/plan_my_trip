require "test_helper"

# Anthropic prompt caching: a large, static system prompt is sent as a
# cache_control content block (so later calls read it from cache) while short
# systems stay a plain string. Usage extraction surfaces the cache counters.
class Ai::AnthropicProviderCachingTest < ActiveSupport::TestCase
  BIG_SYSTEM   = ("You are a meticulous trip planner. " * 200).freeze # ≫ 4000 chars
  SMALL_SYSTEM = "You are a concise concierge.".freeze                # ≪ 4000 chars

  def body_for(system:, output_schema: nil)
    prompt = AiPrompt.new(slug: "t", name: "t", provider: "anthropic", model: "claude-sonnet-4-6",
                          user_template: "hi", max_tokens: 256, output_schema: output_schema)
    Ai::AnthropicProvider.new(prompt).send(:build_body, { system: system, user: "hi" })
  end

  test "large system is sent as a cache_control content block" do
    assert_operator BIG_SYSTEM.length, :>=, Ai::AnthropicProvider::CACHE_MIN_SYSTEM_CHARS
    body = body_for(system: BIG_SYSTEM)

    assert_kind_of Array, body[:system]
    block = body[:system].first
    assert_equal "text", block[:type]
    assert_equal BIG_SYSTEM, block[:text]
    assert_equal({ type: "ephemeral", ttl: "1h" }, block[:cache_control])
  end

  test "small system stays a plain string with no cache marker" do
    body = body_for(system: SMALL_SYSTEM)
    assert_equal SMALL_SYSTEM, body[:system]
  end

  test "blank system is omitted from the body" do
    refute body_for(system: nil).key?(:system)
    refute body_for(system: "").key?(:system)
  end

  test "caching coexists with structured outputs on the same call" do
    schema = { "type" => "object", "additionalProperties" => false,
               "required" => [ "x" ], "properties" => { "x" => { "type" => "string" } } }
    body = body_for(system: BIG_SYSTEM, output_schema: schema)

    assert_kind_of Array, body[:system]
    assert_equal({ type: "ephemeral", ttl: "1h" }, body[:system].first[:cache_control])
    assert_equal "json_schema", body.dig(:output_config, :format, :type)
  end

  test "usage_from surfaces token counts including cache counters" do
    provider = Ai::AnthropicProvider.new(AiPrompt.new(slug: "t", name: "t", provider: "anthropic",
                                                      model: "claude-sonnet-4-6", user_template: "hi"))
    usage = provider.send(:usage_from, {
      "usage" => {
        "input_tokens" => 12, "output_tokens" => 34,
        "cache_creation_input_tokens" => 1300, "cache_read_input_tokens" => 1290
      }
    })

    assert_equal 12, usage[:input_tokens]
    assert_equal 34, usage[:output_tokens]
    assert_equal 1300, usage[:cache_creation_input_tokens]
    assert_equal 1290, usage[:cache_read_input_tokens]
  end

  test "usage_from leaves cache counters nil when the response omits them" do
    provider = Ai::AnthropicProvider.new(AiPrompt.new(slug: "t", name: "t", provider: "anthropic",
                                                      model: "claude-sonnet-4-6", user_template: "hi"))
    usage = provider.send(:usage_from, { "usage" => { "input_tokens" => 5, "output_tokens" => 6 } })

    assert_nil usage[:cache_creation_input_tokens]
    assert_nil usage[:cache_read_input_tokens]
  end
end
