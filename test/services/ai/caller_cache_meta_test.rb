require "test_helper"

# Ai::Caller persists the Anthropic prompt-cache counters returned in the
# provider usage hash into AiCall.meta (no migration — meta is jsonb), so the
# admin call log can show the cache savings.
class Ai::CallerCacheMetaTest < ActiveSupport::TestCase
  # Stands in for a provider; its #call returns the [text, usage, error] tuple.
  class FakeProvider
    def initialize(usage)
      @usage = usage
    end

    def call(_rendered)
      [ "ok", @usage, nil ]
    end
  end

  setup do
    @prompt = AiPrompt.create!(slug: "test.cachemeta.v1", name: "x", provider: "anthropic",
                               model: "claude-sonnet-4-6", kind: "text", max_tokens: 256,
                               user_template: "Hello <%= name %>")
  end

  # Swap AnthropicProvider.new for one that yields `fake`, then restore the
  # inherited Class#new (Minitest 6 ships no minitest/mock, so no #stub).
  def with_anthropic_provider(usage)
    fake = FakeProvider.new(usage)
    Ai::AnthropicProvider.define_singleton_method(:new) { |*| fake }
    yield
  ensure
    Ai::AnthropicProvider.singleton_class.send(:remove_method, :new)
  end

  test "persists anthropic cache counters into AiCall.meta" do
    usage = { input_tokens: 20, output_tokens: 40,
              cache_creation_input_tokens: 0, cache_read_input_tokens: 1290 }
    with_anthropic_provider(usage) do
      result = Ai::Caller.call(slug: @prompt.slug, variables: { name: "Z" }, cache: false)
      assert result.success?, "expected success, got #{result.error.inspect}"
      assert_equal 1290, result.call.meta["cache_read_input_tokens"]
      assert_equal 0, result.call.meta["cache_creation_input_tokens"]
    end
  end

  test "meta stays empty when the provider reports no cache counters" do
    usage = { input_tokens: 20, output_tokens: 40 }
    with_anthropic_provider(usage) do
      result = Ai::Caller.call(slug: @prompt.slug, variables: { name: "Z" }, cache: false)
      assert result.success?, "expected success, got #{result.error.inspect}"
      assert_equal({}, result.call.meta)
    end
  end
end
