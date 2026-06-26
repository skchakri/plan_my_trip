ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)

    # Runs the block with Ai::Caller.call replaced by a fake that returns a
    # canned Ai::Result — no network, no provider. Mirrors the suite's no-mock
    # fake-AI seam (Minitest 6 dropped minitest/mock's #stub). Safe under
    # process-parallel tests: redefine + restore is sequential within a worker.
    def with_fake_ai(body)
      text = body.is_a?(String) ? body : body.to_json
      original = Ai::Caller.method(:call)
      Ai::Caller.singleton_class.send(:define_method, :call) { |*_a, **_k| Ai::Result.new(text: text) }
      yield
    ensure
      Ai::Caller.singleton_class.send(:define_method, :call, original)
    end
  end
end
