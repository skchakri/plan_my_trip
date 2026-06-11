namespace :quiz do
  desc "Regenerate the stored quiz question bank from reference data (Country/UsState/Landmark/Brand)."
  task rebuild: :environment do
    total = QuizQuestion.rebuild!
    decks = QuizQuestion.distinct.pluck(:category).size
    puts "Quiz bank rebuilt: #{total} questions across #{decks} decks."
  end
end
