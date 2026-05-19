require "test_helper"

class Ai::CallerTest < ActiveSupport::TestCase
  setup do
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    @prompt = AiPrompt.create!(
      slug: "test.cache.v1",
      name: "Test cache prompt",
      provider: "anthropic",
      model: "claude-3-5-sonnet-latest",
      kind: "text",
      max_tokens: 256,
      temperature: 0.4,
      user_template: "Hello <%= name %>"
    )
  end

  teardown do
    Rails.cache = @original_cache
  end

  test "returns cached response without invoking the provider" do
    rendered_user = @prompt.render(name: "Goblin Valley")[:user]
    key = build_cache_key(rendered_user)
    Rails.cache.write(key, { text: "cached hello" }, expires_in: 30.days)

    result = Ai::Caller.call(slug: @prompt.slug, variables: { name: "Goblin Valley" })

    assert result.success?, "expected success, got error=#{result.error.inspect}"
    assert_equal "cached hello", result.text
    assert_equal 0, result.call.latency_ms
    assert_equal 0, result.call.input_tokens
    assert_equal 0, result.call.output_tokens
    assert_equal true, result.call.meta["cached"]
    assert_equal "cached hello", result.call.response_text
  end

  test "different variables produce different cache keys" do
    key_a = Ai::Caller.send(:new, slug: @prompt.slug, variables: { name: "A" })
      .send(:cache_key_for, @prompt, @prompt.render(name: "A"))
    key_b = Ai::Caller.send(:new, slug: @prompt.slug, variables: { name: "B" })
      .send(:cache_key_for, @prompt, @prompt.render(name: "B"))

    refute_equal key_a, key_b
  end

  test "editing the prompt busts the cache key" do
    rendered = @prompt.render(name: "X")
    key_before = Ai::Caller.send(:new, slug: @prompt.slug).send(:cache_key_for, @prompt, rendered)
    @prompt.update!(updated_at: 1.hour.from_now)
    key_after = Ai::Caller.send(:new, slug: @prompt.slug).send(:cache_key_for, @prompt, rendered)

    refute_equal key_before, key_after
  end

  test "failed provider calls are not cached" do
    # No ANTHROPIC_API_KEY in the test env, so the provider returns an error.
    original_key = ENV.delete("ANTHROPIC_API_KEY")
    rendered_user = @prompt.render(name: "Skip")[:user]
    key = build_cache_key(rendered_user)

    result = Ai::Caller.call(slug: @prompt.slug, variables: { name: "Skip" })

    assert_not result.success?
    assert_nil Rails.cache.read(key)
  ensure
    ENV["ANTHROPIC_API_KEY"] = original_key if original_key
  end

  private

  def build_cache_key(rendered_user)
    payload = [
      @prompt.slug,
      @prompt.updated_at&.to_i,
      @prompt.provider,
      @prompt.model,
      @prompt.kind,
      @prompt.max_tokens,
      @prompt.temperature&.to_s,
      "",
      rendered_user.to_s
    ].join("\x1F")
    "#{Ai::Caller::CACHE_NAMESPACE}/#{Digest::SHA256.hexdigest(payload)}"
  end
end
