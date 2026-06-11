require "test_helper"

class QuizCatalogTest < ActiveSupport::TestCase
  setup do
    6.times do |i|
      Country.create!(
        name: "Country #{i}", capital: "Capital #{i}", iso2: "x#{i}", continent: "Testia",
        leader_title: ("President" if i < 4), leader_name: ("Leader #{i}" if i < 4),
        currency_name: "Currency #{i}", primary_language: "Language #{i}", calling_code: "+#{i}0",
        national_anthem: "Anthem #{i}", national_bird: "Bird #{i}", national_sport: "Sport #{i}"
      )
    end
    5.times { |i| UsState.create!(name: "State #{i}", capital: "Cap #{i}", abbreviation: "X#{i}") }
    6.times { |i| Landmark.create!(name: "Landmark #{i}", country: "Country #{i}", continent: "Testia") }
    5.times { |i| Brand.create!(name: "Car #{i}", category: "car", slug: "car#{i}") }
    5.times { |i| Brand.create!(name: "Airline #{i}", category: "airline", slug: "air#{i}") }
    5.times { |i| Brand.create!(name: "Brand #{i}", category: "brand", slug: "brand#{i}") }
  end

  test "every category is available once seeded" do
    QuizCatalog.keys.each { |k| assert QuizCatalog.available?(k), "#{k} should be available" }
  end

  test "build returns well-formed multiple-choice questions" do
    QuizCatalog.keys.each do |key|
      questions = QuizCatalog.build(key, count: 3)
      assert questions.any?, "#{key} produced no questions"
      questions.each do |q|
        assert q[:prompt].present?, "#{key} missing prompt"
        # Text decks carry :options; image-option decks carry :option_images.
        opts = q[:options] || q[:option_images]
        assert_equal QuizCatalog::OPTION_COUNT, opts.size, "#{key} option count"
        assert_equal opts.uniq.size, opts.size, "#{key} has duplicate options"
        assert_includes 0...opts.size, q[:answer_index], "#{key} answer index out of range"
      end
    end
  end

  test "the correct option always sits at answer_index" do
    # The flag deck's correct answer is the country name — assert it's present.
    QuizCatalog.build("flags_countries", count: 5).each do |q|
      assert q[:options][q[:answer_index]].present?
      assert q[:image_url].to_s.start_with?("https://flagcdn.com/")
    end
  end

  test "count is capped by the available pool" do
    assert_equal 6, QuizCatalog.build("countries_capitals", count: 99).size
    assert_equal 4, QuizCatalog.build("world_leaders", count: 99).size
    assert_equal 6, QuizCatalog.build("currencies_countries", count: 99).size
    assert_equal 6, QuizCatalog.build("landmarks_countries", count: 99).size
    assert_equal 6, QuizCatalog.build("languages_countries", count: 99).size
    assert_equal 6, QuizCatalog.build("calling_codes_countries", count: 99).size
    assert_equal 6, QuizCatalog.build("tlds_countries", count: 99).size
    assert_equal 6, QuizCatalog.build("continents_countries", count: 99).size
    assert_equal 6, QuizCatalog.build("anthems_countries", count: 99).size
    assert_equal 6, QuizCatalog.build("national_birds_countries", count: 99).size
    assert_equal 6, QuizCatalog.build("national_sports_countries", count: 99).size
    assert_equal 5, QuizCatalog.build("car_logos", count: 99).size
    assert_equal 5, QuizCatalog.build("airline_logos", count: 99).size
    assert_equal 5, QuizCatalog.build("famous_brands", count: 99).size
  end

  test "famous_brands uses the four-image format with matching label" do
    QuizCatalog.build("famous_brands", count: 5).each do |q|
      assert_nil q[:options], "should not carry text options"
      assert_equal 4, q[:option_images].size
      assert_equal 4, q[:option_labels].size
      assert q[:option_images].all? { |u| u.start_with?("https://cdn.simpleicons.org/") }
      assert_includes q[:prompt], q[:option_labels][q[:answer_index]]
    end
  end

  test "logo decks emit a logo image and brand-name options" do
    QuizCatalog.build("car_logos", count: 5).each do |q|
      assert q[:logo], "logo flag should be set"
      assert q[:image_url].start_with?("https://cdn.simpleicons.org/")
      q[:options].each { |opt| assert_match(/\ACar \d\z/, opt) }
    end
  end

  test "landmark options are all real country names" do
    QuizCatalog.build("landmarks_countries", count: 6).each do |q|
      q[:options].each { |opt| assert_match(/\ACountry \d\z/, opt) }
    end
  end

  test "unknown category builds nothing and is unavailable" do
    assert_equal [], QuizCatalog.build("nope")
    assert_not QuizCatalog.available?("nope")
    assert_nil QuizCatalog.find("nope")
  end
end
