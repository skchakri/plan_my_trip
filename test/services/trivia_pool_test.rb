require "test_helper"

class TriviaPoolTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "o-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Olive")
    @trip = @user.owned_trips.create!(title: "T", destination: "Zion", start_date: Date.current, end_date: Date.current + 1)
    @person = @trip.people.create!(name: "Sam", interests: [ "space" ], position: 0)
  end

  def make_question(tag: "space", question: "How many moons does Mars have?", trip_id: nil)
    TriviaQuestion.create!(
      tag: tag, question: question, options: [ "1", "2", "3", "4" ],
      answer_index: 1, trip_id: trip_id, source: "seed"
    )
  end

  test "pick_for returns an interest-matched question as a hash" do
    q = make_question
    picked = TriviaPool.pick_for(@person)
    assert_equal q.id, picked[:id]
    assert_equal "How many moons does Mars have?", picked[:q]
    assert_equal 1, picked[:answer]
  end

  test "pick_for excludes questions the person already answered" do
    q = make_question
    TriviaResponse.create!(person: @person, trivia_question: q, correct: true, answered_at: Time.current)
    picked = TriviaPool.pick_for(@person)
    # only question is answered -> falls back to a GENERIC seed (different id)
    assert_not_equal q.id, picked[:id]
  end

  test "pick_for never repeats a question by text across chains" do
    make_question(question: "Repeated fact?")
    dupe = make_question(question: "Repeated fact?")
    TriviaResponse.create!(person: @person, trivia_question: dupe, correct: true, answered_at: Time.current)
    picked = TriviaPool.pick_for(@person)
    assert_not_equal "Repeated fact?", picked[:q]
  end

  test "trip-scoped questions are visible only to that trip" do
    other = @user.owned_trips.create!(title: "Other", destination: "X", start_date: Date.current, end_date: Date.current + 1)
    other_person = other.people.create!(name: "Pat", interests: [ "space" ], position: 0)
    mine = make_question(trip_id: @trip.id, question: "Trip-only question?")

    assert_equal mine.id, TriviaPool.pick_for(@person)[:id]
    # other trip's person should not see my trip-scoped question
    assert_not_equal "Trip-only question?", TriviaPool.pick_for(other_person)[:q]
  end
end
