# Travel Trivia — standalone general-knowledge quizzes (capitals, flags,
# leaders). These are global reference quizzes, not user-owned records, so
# there's no Pundit policy: auth (ApplicationController) is the only gate.
class QuizzesController < ApplicationController
  def index
    @categories = QuizCatalog.all
    @plays = current_user.quiz_attempts.group(:category).count
    @best  = best_by_category(current_user.quiz_attempts)
  end

  def show
    @category = QuizCatalog.find(params[:category])
    unless @category && QuizCatalog.available?(@category.key)
      return redirect_to quizzes_path, alert: "That quiz isn't ready yet."
    end

    @questions = QuizCatalog.build(@category.key)
    @best = best_by_category(current_user.quiz_attempts.for_category(@category.key))[@category.key]
  end

  # Country Explorer — pick a country, see all its national facts. Defaults to
  # the US so the page is never empty.
  def explore
    @countries = Country.alphabetical
    @country = Country.find_by(iso2: params[:c].to_s.downcase.presence) ||
               Country.find_by(iso2: "us") || @countries.first
  end

  # Records a finished attempt (score is computed client-side — casual trivia).
  def record
    category = QuizCatalog.find(params[:category])
    return head :not_found unless category

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

  # => { "countries_capitals" => 90, ... } best percentage per category.
  def best_by_category(scope)
    scope.group(:category)
         .maximum("score * 100.0 / NULLIF(total, 0)")
         .transform_values { |v| v.to_f.round }
  end
end
