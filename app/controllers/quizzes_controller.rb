# Travel Trivia — standalone general-knowledge quizzes (capitals, flags,
# leaders). These are global reference quizzes, not user-owned records, so
# there's no Pundit policy.
#
# Playing is deliberately PUBLIC. The decks are the app's organic front door —
# people search "guess the flag quiz" / "world capitals quiz" far more than they
# search for a trip planner — and a login wall would hide ~1,500 ready-made
# questions from both crawlers and first-time visitors. Only `record`, which
# writes a QuizAttempt, needs an account; scores simply aren't saved for guests.
class QuizzesController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[index show explore offline_manifest record]

  def index
    @categories = QuizCatalog.all
    @plays = attempts_scope.group(:category).count
    @best  = best_by_category(attempts_scope)
  end

  def show
    @category = QuizCatalog.find(params[:category])
    # Questions are pre-generated and stored (rake quiz:rebuild); a play pulls a
    # random handful from the bank.
    @questions = @category ? QuizQuestion.sample_for_play(@category.key, QuizCatalog::DEFAULT_COUNT) : []
    if @category.nil? || @questions.empty?
      return redirect_to quizzes_path, alert: "That quiz isn't ready yet."
    end

    @best = best_by_category(attempts_scope.for_category(@category.key))[@category.key]
  end

  # Country Explorer — pick a country, see all its national facts. Defaults to
  # the US so the page is never empty.
  def explore
    @countries = Country.alphabetical
    @country = Country.find_by(iso2: params[:c].to_s.downcase.presence) ||
               Country.find_by(iso2: "us") || @countries.first
  end

  # All URLs the quiz section needs offline — deck pages + every flag/logo image
  # (both flag sizes the decks use). Drives the "Save for offline" precache.
  def offline_manifest
    flags = Country.pluck(:iso2).flat_map do |iso2|
      [ "https://flagcdn.com/w80/#{iso2.downcase}.png", "https://flagcdn.com/w320/#{iso2.downcase}.png" ]
    end
    logos = Brand.pluck(:slug).map { |slug| "https://cdn.simpleicons.org/#{slug}" }
    render json: {
      pages: QuizCatalog.keys.map { |key| quiz_path(key) },
      images: flags + logos
    }
  end

  # Records a finished attempt (score is computed client-side — casual trivia).
  #
  # Guests reach here too, since playing is public. Rather than 401 (which the
  # player would read as a failed save, retry, and queue forever), answer 200
  # with guest: true — finishing a deck is peak engagement, so the client turns
  # it into a "create an account to keep your scores" prompt instead of an error.
  def record
    category = QuizCatalog.find(params[:category])
    return head :not_found unless category

    unless current_user
      return render json: { ok: false, guest: true, sign_up_url: new_user_registration_path }
    end

    total = params[:total].to_i
    current_user.quiz_attempts.create!(
      category: category.key,
      total:    total,
      score:    params[:score].to_i.clamp(0, total)
    )

    scope = current_user.quiz_attempts.for_category(category.key)
    render json: { ok: true, best: best_by_category(scope)[category.key], plays: scope.count }
  end

  private

  # Guests have no attempts — an empty relation keeps the "personal best" badges
  # off without branching in every view.
  def attempts_scope
    current_user&.quiz_attempts || QuizAttempt.none
  end

  # => { "countries_capitals" => 90, ... } best percentage per category.
  def best_by_category(scope)
    scope.group(:category)
         .maximum("score * 100.0 / NULLIF(total, 0)")
         .transform_values { |v| v.to_f.round }
  end
end
