require "test_helper"

class QuizzesControllerTest < ActionDispatch::IntegrationTest
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
  end

  test "requires authentication" do
    get quizzes_path
    assert_redirected_to new_user_session_path
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
