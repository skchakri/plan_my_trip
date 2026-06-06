require "test_helper"

class Ai::PerplexityProviderTest < ActiveSupport::TestCase
  def prompt(model: "sonar")
    AiPrompt.new(
      slug: "nearby_ideas.test", name: "t", provider: "perplexity",
      model: model, kind: "text", max_tokens: 256, temperature: 0.4,
      user_template: "hi"
    )
  end

  # Subclass seam (no Object#stub in Minitest 6) — force a missing key so we
  # exercise the early-return without depending on the host's ENV.
  class KeylessPerplexity < Ai::PerplexityProvider
    def api_key = nil
  end

  test "missing key returns a clean error tuple, not an exception" do
    text, usage, error = KeylessPerplexity.new(prompt).call(system: "s", user: "u")
    assert_nil text
    assert_equal({}, usage)
    assert_match(/PERPLEXITY_API_KEY missing/, error)
  end

  test "model_name maps non-Sonar names to a sane default and passes Sonar through" do
    provider = Ai::PerplexityProvider.new(prompt)
    assert_equal "sonar", provider.send(:model_name, "claude-sonnet-4-6")
    assert_equal "sonar-pro", provider.send(:model_name, "sonar-pro")
    assert_equal "sonar", provider.send(:model_name, "Sonar")
  end

  test "perplexity is a registered provider the Caller can dispatch" do
    assert_includes AiPrompt::PROVIDERS, "perplexity"
  end
end
