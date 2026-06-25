require "test_helper"
require "rake"

# Guards the db:seed fix: db/seeds.rb must invoke trivia:seed_chains so a fresh
# install has the multi-step word-problem chains TriviaPool.pick_for biases
# toward — otherwise the Drive Co-Pilot falls back to the hardcoded GENERIC pool.
class TriviaSeedChainsTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("trivia:seed_chains")
    @task = Rake::Task["trivia:seed_chains"]
  end

  test "seed_chains creates global chain roots with linked follow-up steps" do
    assert_equal 0, chain_root_count, "expected a clean trivia table before seeding"

    silence_stdout { @task.execute }

    assert_operator chain_root_count, :>, 0, "seed_chains should create chain roots"
    # A chain root must actually start a chain: a follow-up step points back to it.
    assert_operator follow_up_count, :>, 0, "seed_chains should create linked follow-up steps"
  end

  test "seed_chains is idempotent — re-running does not duplicate" do
    silence_stdout { @task.execute }
    first = global_question_count

    silence_stdout { @task.execute }
    assert_equal first, global_question_count, "re-running seed_chains must not add rows"
  end

  private

  def chain_root_count
    TriviaQuestion.kept.chain_roots.where(trip_id: nil).where.not(chain_intro: nil).count
  end

  def follow_up_count
    TriviaQuestion.where(trip_id: nil).where.not(parent_id: nil).count
  end

  def global_question_count
    TriviaQuestion.where(trip_id: nil).count
  end

  def silence_stdout
    original = $stdout
    $stdout = File.open(File::NULL, "w")
    yield
  ensure
    $stdout = original
  end
end
