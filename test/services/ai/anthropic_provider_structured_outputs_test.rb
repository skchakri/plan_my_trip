require "test_helper"

# Opt-in structured outputs: a prompt with an output_schema adds
# output_config.format.json_schema to the request body; one without is
# byte-for-byte unchanged.
class Ai::AnthropicProviderStructuredOutputsTest < ActiveSupport::TestCase
  SCHEMA = {
    "type" => "object",
    "additionalProperties" => false,
    "required" => [ "x" ],
    "properties" => { "x" => { "type" => "string" } }
  }.freeze

  def body_for(output_schema:)
    prompt = AiPrompt.new(slug: "t", name: "t", provider: "anthropic", model: "claude-sonnet-4-6",
                          user_template: "hi", max_tokens: 256, output_schema: output_schema)
    Ai::AnthropicProvider.new(prompt).send(:build_body, { system: nil, user: "hi" })
  end

  test "adds output_config.format json_schema when the prompt declares an output_schema" do
    body = body_for(output_schema: SCHEMA)
    assert_equal "json_schema", body.dig(:output_config, :format, :type)
    assert_equal SCHEMA, body.dig(:output_config, :format, :schema)
  end

  test "omits output_config entirely when the prompt has no output_schema" do
    refute body_for(output_schema: nil).key?(:output_config)
  end

  test "base body still carries model, max_tokens and the user message" do
    body = body_for(output_schema: nil)
    assert_equal "claude-sonnet-4-6", body[:model]
    assert_equal 256, body[:max_tokens]
    assert_equal "hi", body.dig(:messages, 0, :content)
  end
end
