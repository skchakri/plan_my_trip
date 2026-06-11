require "test_helper"

class QuizQuestionTest < ActiveSupport::TestCase
  setup do
    6.times do |i|
      Country.create!(name: "Country #{i}", capital: "Capital #{i}", iso2: "x#{i}", continent: "Testia")
    end
    5.times { |i| Brand.create!(name: "Brand #{i}", category: "brand", slug: "brand#{i}") }
  end

  test "rebuild! stores one question per source entity" do
    QuizQuestion.rebuild!(categories: [ "countries_capitals" ])
    assert_equal 6, QuizQuestion.for_category("countries_capitals").count
  end

  test "rebuild! is idempotent (clears then repopulates)" do
    2.times { QuizQuestion.rebuild!(categories: [ "countries_capitals" ]) }
    assert_equal 6, QuizQuestion.for_category("countries_capitals").count
  end

  test "stored text payloads round-trip the question shape" do
    QuizQuestion.rebuild!(categories: [ "countries_capitals" ])
    payload = QuizQuestion.for_category("countries_capitals").first.payload
    assert_kind_of Hash, payload
    assert payload["prompt"].present?
    assert_equal 4, payload["options"].size
    assert_includes 0..3, payload["answer_index"]
  end

  test "image-option payloads store option_images and labels" do
    QuizQuestion.rebuild!(categories: [ "famous_brands" ])
    payload = QuizQuestion.for_category("famous_brands").first.payload
    assert_equal 4, payload["option_images"].size
    assert_equal 4, payload["option_labels"].size
    assert_nil payload["options"]
  end

  test "sample_for_play returns up to N payload hashes" do
    QuizQuestion.rebuild!(categories: [ "countries_capitals" ])
    sample = QuizQuestion.sample_for_play("countries_capitals", 4)
    assert_equal 4, sample.size
    assert sample.all? { |p| p.is_a?(Hash) && p["prompt"].present? }
  end
end
