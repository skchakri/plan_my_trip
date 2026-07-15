require "test_helper"

class QuizzesControllerTest < ActionDispatch::IntegrationTest
  include QuizzesHelper # for the quiz_seo_* SEO assertions below

  setup do
    @user = User.create!(email: "quiz-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Quinn")
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
    QuizQuestion.rebuild! # questions are served from the stored bank
  end

  # Playing is public on purpose — the decks are the app's organic front door,
  # and a login wall would hide them from crawlers and first-time visitors.
  test "guests can browse the deck index" do
    get quizzes_path
    assert_response :success
    QuizCatalog.all.each { |c| assert_includes response.body, c.title }
  end

  test "guests can play any deck" do
    QuizCatalog.keys.each do |key|
      get quiz_path(key)
      assert_response :success, "#{key} should be playable logged-out"
      assert_includes response.body, 'data-controller="quiz"'
    end
  end

  test "guests can use the country explorer and the offline manifest" do
    get quiz_explore_path
    assert_response :success

    get quiz_offline_path
    assert_response :success
  end

  test "a deck page carries its own title, description, canonical, and Quiz schema" do
    get quiz_path("countries_capitals")
    category = QuizCatalog.find("countries_capitals")

    assert_includes response.body, quiz_url("countries_capitals")           # canonical
    assert_includes response.body, "application/ld+json"                    # Quiz schema
    assert_includes response.body, %(<meta name="description")
    # The <title> must lead with the deck name, not the brand — that's the query.
    assert_match %r{<title>#{Regexp.escape(category.title)} Quiz}, response.body
  end

  test "deck titles and descriptions are unique across decks so they aren't duplicate pages" do
    titles = QuizCatalog.all.map { |c| quiz_seo_title(c) }
    descriptions = QuizCatalog.all.map { |c| quiz_seo_description(c) }

    assert_equal titles.uniq.size, titles.size, "deck <title>s must be unique"
    assert_equal descriptions.uniq.size, descriptions.size, "deck descriptions must be unique"
  end

  test "a guest finishing a deck is offered a sign-up instead of a failed save" do
    assert_no_difference -> { QuizAttempt.count } do
      post quiz_attempts_path("countries_capitals"), params: { score: 8, total: 10 }, as: :json
    end
    assert_response :success   # NOT a 401/redirect — the player must not read it as an error
    body = JSON.parse(response.body)
    assert_equal false, body["ok"]
    assert_equal true,  body["guest"]
    assert_equal new_user_registration_path, body["sign_up_url"]
  end

  test "index lists every deck" do
    sign_in_as(@user)
    get quizzes_path
    assert_response :success
    QuizCatalog.all.each { |c| assert_includes response.body, c.title }
  end

  test "show renders a playable deck with embedded questions" do
    sign_in_as(@user)
    get quiz_path("countries_capitals")
    assert_response :success
    assert_includes response.body, 'data-controller="quiz"'
    assert_includes response.body, "data-quiz-questions-value"
  end

  test "every deck renders a playable player" do
    sign_in_as(@user)
    QuizCatalog.keys.each do |key|
      get quiz_path(key)
      assert_response :success, "#{key} should render"
      assert_includes response.body, 'data-controller="quiz"'
    end
  end

  test "unknown deck redirects back to the index" do
    sign_in_as(@user)
    get quiz_path("not_a_real_deck")
    assert_redirected_to quizzes_path
  end

  test "offline manifest lists deck pages and image URLs" do
    sign_in_as(@user)
    get quiz_offline_path
    assert_response :success
    body = JSON.parse(response.body)
    assert_includes body["pages"], quiz_path("countries_capitals")
    assert body["images"].any? { |u| u.start_with?("https://flagcdn.com/") }
    assert body["images"].any? { |u| u.start_with?("https://cdn.simpleicons.org/") }
  end

  test "explore renders a country fact-sheet for the chosen country" do
    sign_in_as(@user)
    get quiz_explore_path(c: "x2")
    assert_response :success
    assert_includes response.body, "Country 2"
    assert_includes response.body, "Capital 2"   # capital fact row
    assert_includes response.body, "Anthem 2"    # national fact row
  end

  test "explore falls back gracefully when no country is given" do
    sign_in_as(@user)
    get quiz_explore_path
    assert_response :success
  end

  test "explore is reachable without colliding with the :category route" do
    sign_in_as(@user)
    get quiz_explore_path
    assert_equal "/quizzes/explore", path
  end

  test "record persists an attempt and returns the new best percentage" do
    sign_in_as(@user)
    assert_difference -> { @user.quiz_attempts.count }, 1 do
      post quiz_attempts_path("countries_capitals"), params: { score: 8, total: 10 }, as: :json
    end
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal true, body["ok"]
    assert_equal 80, body["best"]
    assert_equal 1, body["plays"]
  end

  test "record clamps an impossible score down to the total" do
    sign_in_as(@user)
    post quiz_attempts_path("us_states_capitals"), params: { score: 99, total: 10 }, as: :json
    assert_response :success
    assert_equal 10, @user.quiz_attempts.last.score
  end

  test "record on an unknown deck is a 404" do
    sign_in_as(@user)
    post quiz_attempts_path("not_a_real_deck"), params: { score: 1, total: 1 }, as: :json
    assert_response :not_found
  end

  private

  def sign_in_as(user)
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
  end
end
