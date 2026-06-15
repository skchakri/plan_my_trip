require "test_helper"

class CopilotTest < ActionDispatch::IntegrationTest
  setup do
    @owner = User.create!(email: "o-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Olive")
    @trip = @owner.owned_trips.create!(title: "T", destination: "Zion", start_date: Date.current, end_date: Date.current + 1)
    @person = @trip.people.create!(name: "Sam", interests: [ "space" ], position: 0)
    @q = TriviaQuestion.create!(tag: "space", question: "How many moons does Mars have?",
                                options: [ "1", "2", "3", "4" ], answer_index: 1, source: "seed")
    sign_in_as(@owner)
  end

  test "copilot page renders for a trip with travelers" do
    get copilot_trip_path(@trip)
    assert_response :success
  end

  test "copilot_question serves a question for a person" do
    get copilot_question_trip_path(@trip), params: { person_id: @person.id }
    assert_response :success
  end

  test "copilot_response records an answer and is idempotent" do
    assert_difference -> { TriviaResponse.count }, 1 do
      post copilot_response_trip_path(@trip), params: { person_id: @person.id, question_id: @q.id, correct: "true" }
    end
    assert_response :no_content

    # second answer to the same question updates, doesn't duplicate
    assert_no_difference -> { TriviaResponse.count } do
      post copilot_response_trip_path(@trip), params: { person_id: @person.id, question_id: @q.id, correct: "false" }
    end
    resp = TriviaResponse.find_by(person: @person, trivia_question: @q)
    assert_equal false, resp.correct
  end

  test "copilot_response with an unknown question is a no-op (no crash)" do
    assert_no_difference -> { TriviaResponse.count } do
      post copilot_response_trip_path(@trip), params: { person_id: @person.id, question_id: SecureRandom.uuid, correct: "true" }
    end
    assert_response :no_content
  end

  private

  def sign_in_as(user)
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
  end
end
