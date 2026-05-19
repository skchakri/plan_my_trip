namespace :trivia do
  desc "Seed the global trivia pool from TriviaPool::SEED_POOL (idempotent)."
  task seed: :environment do
    inserted = updated = 0

    TriviaPool::SEED_POOL.each do |tag, questions|
      Array(questions).each do |q|
        rec = TriviaQuestion.find_or_initialize_by(tag: tag, question: q[:q], trip_id: nil)
        attrs = {
          options: Array(q[:options]),
          answer_index: q[:answer],
          fun_fact: q[:fun_fact],
          source: "seed"
        }
        if rec.new_record?
          rec.assign_attributes(attrs)
          rec.save!
          inserted += 1
        elsif rec.attributes.slice("options", "answer_index", "fun_fact").symbolize_keys != {
          options: attrs[:options], answer_index: attrs[:answer_index], fun_fact: attrs[:fun_fact]
        }
          rec.update!(attrs)
          updated += 1
        end
      end
    end

    puts "trivia:seed → #{inserted} inserted, #{updated} updated, #{TriviaQuestion.global.kept.count} total in global pool."
  end

  desc "Seed multi-step word-problem chains (idempotent)."
  task seed_chains: :environment do
    chains = [
      {
        difficulty: "medium",
        intro: "There are 20 students in a class. They split into different sports teams and need equipment.",
        steps: [
          { q: "There are 20 students in a class. 14 are boys and the rest are girls. How many girls are in the class?",
            options: %w[4 5 6 7], answer: 2, fun_fact: "20 − 14 = 6 girls." },
          { q: "8 of the boys are on the soccer team, and 4 of the girls are too. How many students are on the soccer team in total?",
            options: %w[10 11 12 13], answer: 2, fun_fact: "8 boys + 4 girls = 12 players." },
          { q: "The baseball team has the rest of the boys plus 1 of the girls. How many players are on the baseball team?",
            options: %w[5 6 7 8], answer: 2, fun_fact: "14 − 8 = 6 boys left, plus 1 girl, makes 7 players." },
          { q: "Each baseball glove costs $25. What does it cost to give all 7 baseball players a glove?",
            options: %w[$150 $165 $175 $200], answer: 2, fun_fact: "7 × $25 = $175." },
          { q: "The school's sports budget is $200. After buying gloves, how much is left?",
            options: %w[$15 $20 $25 $35], answer: 2, fun_fact: "$200 − $175 = $25." },
          { q: "Each soccer ball costs $5. With $25 left, how many soccer balls can they buy?",
            options: %w[3 4 5 6], answer: 2, fun_fact: "$25 ÷ $5 = 5 balls." },
          { q: "The coach wants 2 soccer balls for every player. With 12 players, how many balls do they need?",
            options: %w[14 18 24 30], answer: 2, fun_fact: "12 players × 2 balls = 24 balls." },
          { q: "They already own 5 balls. How many more balls do they need to buy to reach 24?",
            options: %w[15 17 19 21], answer: 2, fun_fact: "24 − 5 = 19 more balls." },
          { q: "Each ball costs $5. What's the cost of buying 19 more balls?",
            options: %w[$85 $90 $95 $100], answer: 2, fun_fact: "19 × $5 = $95." },
          { q: "The school spent $175 on gloves and $95 on balls. The full sports-year budget was $300. How much is left?",
            options: %w[$15 $25 $30 $50], answer: 2, fun_fact: "$300 − ($175 + $95) = $300 − $270 = $30." }
        ]
      },
      {
        difficulty: "easy",
        intro: "Mom orders pizzas for the road trip and the family shares them.",
        steps: [
          { q: "Mom orders 2 large pizzas. Each pizza is cut into 8 slices. How many slices in total?",
            options: %w[10 14 16 18], answer: 2, fun_fact: "2 × 8 = 16 slices." },
          { q: "Dad eats 3 slices and the kids eat 9 slices between them. How many slices are eaten so far?",
            options: %w[10 11 12 13], answer: 2, fun_fact: "3 + 9 = 12 slices eaten." },
          { q: "Out of the 16 slices, how many are left after dad and the kids eat 12?",
            options: %w[2 3 4 5], answer: 2, fun_fact: "16 − 12 = 4 slices left." },
          { q: "Mom and Grandma split the 4 leftover slices equally. How many slices does each one get?",
            options: %w[1 2 3 4], answer: 1, fun_fact: "4 ÷ 2 = 2 slices each." },
          { q: "Each pizza costs $12. What's the total cost for 2 pizzas?",
            options: %w[$22 $24 $26 $28], answer: 1, fun_fact: "2 × $12 = $24." },
          { q: "Mom pays the cashier with $30. How much change does she get back?",
            options: %w[$4 $5 $6 $7], answer: 2, fun_fact: "$30 − $24 = $6." },
          { q: "She leaves a $3 tip. What did she spend in total (pizzas + tip)?",
            options: %w[$25 $26 $27 $28], answer: 2, fun_fact: "$24 + $3 = $27." },
          { q: "Mom, Dad, and Grandma split the $27 evenly. How much does each adult pay?",
            options: %w[$8 $9 $10 $11], answer: 1, fun_fact: "$27 ÷ 3 = $9 each." },
          { q: "What is half of the 16 slices?",
            options: %w[6 7 8 9], answer: 2, fun_fact: "16 ÷ 2 = 8 slices — half the pizza." },
          { q: "Next time, 4 friends come over too — 8 people total. If each person eats 2 slices, how many slices do they need?",
            options: %w[12 14 16 18], answer: 2, fun_fact: "8 people × 2 slices = 16 slices — exactly 2 pizzas again." }
        ]
      },
      {
        difficulty: "medium",
        intro: "A school field trip with 90 students needs buses, lunches, and snacks.",
        steps: [
          { q: "A field trip needs to seat 90 students. Each bus seats 30. How many buses do they need?",
            options: %w[2 3 4 5], answer: 1, fun_fact: "90 ÷ 30 = 3 buses." },
          { q: "Each bus needs 1 driver and 2 chaperones. How many adults total for 3 buses?",
            options: %w[6 7 8 9], answer: 3, fun_fact: "3 × (1 + 2) = 9 adults." },
          { q: "Including students and adults, how many people are on the trip?",
            options: %w[93 95 97 99], answer: 3, fun_fact: "90 + 9 = 99 people." },
          { q: "Renting one bus costs $200. What's the cost for 3 buses?",
            options: %w[$500 $550 $600 $650], answer: 2, fun_fact: "3 × $200 = $600." },
          { q: "Fuel costs $50 per bus. What's the fuel cost for 3 buses?",
            options: %w[$100 $125 $150 $175], answer: 2, fun_fact: "3 × $50 = $150." },
          { q: "What's the total bus cost (rental + fuel)?",
            options: %w[$700 $725 $750 $800], answer: 2, fun_fact: "$600 + $150 = $750." },
          { q: "The school raised $1000. How much is left after paying for buses?",
            options: %w[$200 $225 $250 $275], answer: 2, fun_fact: "$1000 − $750 = $250." },
          { q: "Snack packs cost $5 each. With $250, how many packs can they buy?",
            options: %w[40 45 50 55], answer: 2, fun_fact: "$250 ÷ $5 = 50 packs." },
          { q: "Each pack contains 9 snacks. How many snacks total in 50 packs?",
            options: %w[400 450 500 550], answer: 1, fun_fact: "50 × 9 = 450 snacks." },
          { q: "Splitting 450 snacks evenly among 90 students: how many snacks per student?",
            options: %w[3 4 5 6], answer: 2, fun_fact: "450 ÷ 90 = 5 snacks each." }
        ]
      },
      {
        difficulty: "medium",
        intro: "Mia opens a lemonade stand and tracks her sales over two days.",
        steps: [
          { q: "Mia has 30 lemons. Her recipe uses 5 lemons per pitcher. How many pitchers can she make?",
            options: %w[4 5 6 8], answer: 2, fun_fact: "30 ÷ 5 = 6 pitchers." },
          { q: "Each pitcher fills 8 cups. How many cups can she sell on day 1?",
            options: %w[36 40 48 56], answer: 2, fun_fact: "6 × 8 = 48 cups." },
          { q: "She sells each cup for $1. What are her day-1 sales if all 48 cups sell?",
            options: %w[$36 $42 $48 $54], answer: 2, fun_fact: "48 × $1 = $48." },
          { q: "Her supplies cost $12. What's her day-1 profit?",
            options: %w[$24 $30 $36 $48], answer: 2, fun_fact: "$48 − $12 = $36 profit." },
          { q: "Mia gives 1/4 of her profit to her little sister. How many dollars is that?",
            options: %w[$6 $8 $9 $12], answer: 2, fun_fact: "$36 ÷ 4 = $9." },
          { q: "After paying her sister, how much profit does Mia keep on day 1?",
            options: %w[$24 $25 $27 $30], answer: 2, fun_fact: "$36 − $9 = $27." },
          { q: "On day 2 she makes 60 cups. At $1 per cup, what are her day-2 sales?",
            options: %w[$50 $55 $60 $65], answer: 2, fun_fact: "60 × $1 = $60." },
          { q: "Day-2 supplies cost $15. What's her day-2 profit?",
            options: %w[$40 $42 $45 $50], answer: 2, fun_fact: "$60 − $15 = $45 profit." },
          { q: "Combined sales over both days?",
            options: %w[$98 $102 $108 $112], answer: 2, fun_fact: "$48 + $60 = $108." },
          { q: "Combined profit over both days?",
            options: %w[$75 $78 $81 $84], answer: 2, fun_fact: "$36 + $45 = $81." }
        ]
      },
      {
        difficulty: "easy",
        intro: "Liam invites 9 friends to his birthday party. Mom organizes cake, balloons, and prize bags.",
        steps: [
          { q: "Liam invites 9 friends to his party. Including Liam, how many kids will be there?",
            options: %w[8 9 10 11], answer: 2, fun_fact: "9 + 1 = 10 kids." },
          { q: "Mom buys a cake cut into 20 slices. The 10 kids and Mom each eat 1 slice. How many slices are left?",
            options: %w[8 9 10 11], answer: 1, fun_fact: "20 − 11 = 9 slices left." },
          { q: "Liam gives 3 leftover slices to each of 3 friends to take home. How many slices does he give away?",
            options: %w[6 7 8 9], answer: 3, fun_fact: "3 × 3 = 9 slices given away." },
          { q: "After giving away 9 slices, how many of the 9 leftover slices remain at home?",
            options: %w[0 1 2 3], answer: 0, fun_fact: "9 − 9 = 0 slices." },
          { q: "Mom blows up 30 balloons. Each of the 10 kids takes 2 home. How many balloons are taken away?",
            options: %w[16 18 20 22], answer: 2, fun_fact: "10 × 2 = 20 balloons taken home." },
          { q: "How many balloons stay at the house?",
            options: %w[8 10 12 14], answer: 1, fun_fact: "30 − 20 = 10 balloons left." },
          { q: "Mom prepares 5 prize-bag treats for each of the 10 kids. How many treats does she prepare in total?",
            options: %w[40 45 50 55], answer: 2, fun_fact: "10 × 5 = 50 treats." },
          { q: "Each treat costs 50¢. What's the total cost in dollars?",
            options: %w[$20 $25 $30 $35], answer: 1, fun_fact: "50 × $0.50 = $25." },
          { q: "Mom buys 4 packs of candy. Each pack has 12 pieces. Total candies?",
            options: %w[36 42 48 54], answer: 2, fun_fact: "4 × 12 = 48 candies." },
          { q: "Mom saves 8 candies for later. Sharing the rest evenly among 10 kids: how many candies each?",
            options: %w[2 3 4 5], answer: 2, fun_fact: "(48 − 8) ÷ 10 = 40 ÷ 10 = 4 candies each." }
        ]
      },
      {
        difficulty: "medium",
        intro: "A farmer keeps chickens and cows. He counts heads, legs, eggs, and earnings.",
        steps: [
          { q: "A farmer has 12 chickens and 7 cows. How many animals does he have in total?",
            options: %w[17 18 19 21], answer: 2, fun_fact: "12 + 7 = 19 animals." },
          { q: "Each chicken has 2 legs. How many legs do 12 chickens have?",
            options: %w[20 22 24 26], answer: 2, fun_fact: "12 × 2 = 24 legs." },
          { q: "Each cow has 4 legs. How many legs do 7 cows have?",
            options: %w[24 26 28 30], answer: 2, fun_fact: "7 × 4 = 28 legs." },
          { q: "How many legs are there altogether (chickens + cows)?",
            options: %w[48 50 52 54], answer: 2, fun_fact: "24 + 28 = 52 legs." },
          { q: "3 cows wander into the field. How many cow legs leave with them?",
            options: %w[8 10 12 14], answer: 2, fun_fact: "3 × 4 = 12 legs." },
          { q: "How many legs are left back at the barn after those 3 cows leave?",
            options: %w[36 38 40 42], answer: 2, fun_fact: "52 − 12 = 40 legs." },
          { q: "Each chicken lays 2 eggs a day. How many eggs do 12 chickens lay in one day?",
            options: %w[18 20 22 24], answer: 3, fun_fact: "12 × 2 = 24 eggs/day." },
          { q: "How many eggs are laid in a 7-day week?",
            options: %w[140 154 168 182], answer: 2, fun_fact: "24 × 7 = 168 eggs." },
          { q: "Eggs are sold in cartons of 12. How many full cartons can he make in a week?",
            options: %w[12 13 14 15], answer: 2, fun_fact: "168 ÷ 12 = 14 cartons." },
          { q: "Each carton sells for $4. What's his weekly egg revenue?",
            options: %w[$48 $52 $56 $60], answer: 2, fun_fact: "14 × $4 = $56." }
        ]
      },
      {
        difficulty: "hard",
        intro: "4 friends plan two movie nights and split every cost evenly.",
        steps: [
          { q: "4 friends go to the movies. Tickets cost $12 each. Total ticket cost on night 1?",
            options: %w[$36 $40 $44 $48], answer: 3, fun_fact: "4 × $12 = $48." },
          { q: "They share a $20 popcorn bucket. With 4 sodas at $5 each, what's the soda total?",
            options: %w[$15 $18 $20 $25], answer: 2, fun_fact: "4 × $5 = $20." },
          { q: "Combined snacks (popcorn + sodas) — total snack bill on night 1?",
            options: %w[$30 $35 $40 $45], answer: 2, fun_fact: "$20 + $20 = $40." },
          { q: "Total night-1 cost (tickets + snacks)?",
            options: %w[$78 $82 $88 $92], answer: 2, fun_fact: "$48 + $40 = $88." },
          { q: "Splitting $88 evenly among 4 friends: how much does each pay?",
            options: %w[$20 $22 $24 $26], answer: 1, fun_fact: "$88 ÷ 4 = $22." },
          { q: "Next week tickets jump to $15 each. What's the new total ticket cost for 4?",
            options: %w[$50 $55 $60 $65], answer: 2, fun_fact: "4 × $15 = $60." },
          { q: "Snacks are still $40. What's the total night-2 cost?",
            options: %w[$90 $95 $100 $105], answer: 2, fun_fact: "$60 + $40 = $100." },
          { q: "Each friend pays an equal share on night 2. How much per friend?",
            options: %w[$20 $22 $25 $28], answer: 2, fun_fact: "$100 ÷ 4 = $25." },
          { q: "Combined cost across both movie nights?",
            options: %w[$168 $178 $188 $198], answer: 2, fun_fact: "$88 + $100 = $188." },
          { q: "Each friend's two-night total?",
            options: %w[$42 $45 $47 $50], answer: 2, fun_fact: "$188 ÷ 4 = $47." }
        ]
      },
      {
        difficulty: "medium",
        intro: "Grandpa harvests tomatoes, packs them into baskets, makes sauce, and sells jars.",
        steps: [
          { q: "Grandpa picks 36 tomatoes and packs them into baskets of 6. How many baskets does he fill?",
            options: %w[4 5 6 7], answer: 2, fun_fact: "36 ÷ 6 = 6 baskets." },
          { q: "He gives 2 baskets to neighbors. How many tomatoes does he give away?",
            options: %w[8 10 12 14], answer: 2, fun_fact: "2 × 6 = 12 tomatoes." },
          { q: "How many tomatoes does he keep at home?",
            options: %w[20 22 24 26], answer: 2, fun_fact: "36 − 12 = 24 tomatoes kept." },
          { q: "Half of the 24 tomatoes go into sauce. How many is that?",
            options: %w[10 12 14 16], answer: 1, fun_fact: "24 ÷ 2 = 12 tomatoes for sauce." },
          { q: "Each sauce jar holds 4 tomatoes. How many jars can he fill from 12 tomatoes?",
            options: %w[2 3 4 5], answer: 1, fun_fact: "12 ÷ 4 = 3 jars." },
          { q: "Each jar weighs 2 pounds. How much do 3 jars weigh in total?",
            options: %w[4 5 6 7], answer: 2, fun_fact: "3 × 2 = 6 pounds." },
          { q: "Grandpa sells each jar for $5. What does he earn from selling all 3?",
            options: %w[$10 $12 $15 $18], answer: 2, fun_fact: "3 × $5 = $15." },
          { q: "The next week he picks 50 more tomatoes. Combined harvest across both weeks?",
            options: %w[78 82 86 90], answer: 2, fun_fact: "36 + 50 = 86 tomatoes." },
          { q: "He packs the 50 new tomatoes into baskets of 5. How many new baskets?",
            options: %w[8 9 10 11], answer: 2, fun_fact: "50 ÷ 5 = 10 baskets." },
          { q: "If he keeps half of 86 tomatoes for himself and gives the other half away, how many does he keep?",
            options: %w[40 41 42 43], answer: 3, fun_fact: "86 ÷ 2 = 43 tomatoes." }
        ]
      },
      {
        difficulty: "easy",
        intro: "An aquarium has 3 fish tanks of equal size. The keeper tracks fish, gallons, and filter time.",
        steps: [
          { q: "There are 3 tanks with 8 fish each. How many fish total?",
            options: %w[18 21 24 27], answer: 2, fun_fact: "3 × 8 = 24 fish." },
          { q: "6 of the fish are clownfish. How many fish are NOT clownfish?",
            options: %w[14 16 18 20], answer: 2, fun_fact: "24 − 6 = 18 non-clownfish." },
          { q: "The aquarium adds 4 more clownfish. How many clownfish are there now?",
            options: %w[8 10 12 14], answer: 1, fun_fact: "6 + 4 = 10 clownfish." },
          { q: "Total fish (clownfish + non-clownfish) after the additions?",
            options: %w[24 26 28 30], answer: 2, fun_fact: "10 + 18 = 28 fish." },
          { q: "They split the 28 fish evenly into 4 tanks. How many fish per tank?",
            options: %w[6 7 8 9], answer: 1, fun_fact: "28 ÷ 4 = 7 fish per tank." },
          { q: "Each tank holds 10 gallons of water. How many gallons across 4 tanks?",
            options: %w[30 35 40 45], answer: 2, fun_fact: "4 × 10 = 40 gallons." },
          { q: "A filter cleans 5 gallons per hour. How many hours to clean one 10-gallon tank?",
            options: %w[1 2 3 4], answer: 1, fun_fact: "10 ÷ 5 = 2 hours." },
          { q: "How many hours would 1 filter take to clean all 4 tanks (40 gallons)?",
            options: %w[6 7 8 10], answer: 2, fun_fact: "40 ÷ 5 = 8 hours." },
          { q: "If the filter runs 8 hours a day at 5 gallons/hour, how many gallons does it clean per day?",
            options: %w[30 35 40 45], answer: 2, fun_fact: "8 × 5 = 40 gallons/day." },
          { q: "The aquarium has 2 such filters running. Combined daily gallons cleaned?",
            options: %w[60 70 80 90], answer: 2, fun_fact: "2 × 40 = 80 gallons/day." }
        ]
      },

      # ── SCIENCE CHAINS ───────────────────────────────────────────────────
      {
        tag: "science",
        difficulty: "easy",
        intro: "Maya plants bean seeds for a class greenhouse experiment. She measures, waters, and tracks how the plants grow.",
        steps: [
          { q: "Each bean seed needs 8 hours of light per day. How many hours of light does it get over 7 days?",
            options: %w[42 49 56 63], answer: 2, fun_fact: "7 × 8 = 56 hours of light." },
          { q: "Each plant grows 2 cm per week. After 5 weeks, how tall is one plant?",
            options: %w[6 8 10 12], answer: 2, fun_fact: "5 × 2 = 10 cm." },
          { q: "After 10 weeks at the same rate, how tall is the plant?",
            options: %w[14 18 20 24], answer: 2, fun_fact: "10 × 2 = 20 cm." },
          { q: "Maya waters the plant 50 mL every 2 days. How many waterings in 30 days?",
            options: %w[10 12 15 20], answer: 2, fun_fact: "30 ÷ 2 = 15 waterings." },
          { q: "Total water used in 30 days (in mL)?",
            options: %w[600 700 750 800], answer: 2, fun_fact: "15 × 50 = 750 mL." },
          { q: "Each plant grows 6 new leaves per week. After 5 weeks, how many leaves on 1 plant?",
            options: %w[20 25 30 35], answer: 2, fun_fact: "5 × 6 = 30 leaves." },
          { q: "Maya plants 4 bean seeds. Total leaves after 5 weeks (across all 4 plants)?",
            options: %w[100 110 120 130], answer: 2, fun_fact: "4 × 30 = 120 leaves." },
          { q: "Each leaf releases 5 mg of oxygen per day. From 30 leaves on one plant, daily oxygen?",
            options: %w[120 140 150 160], answer: 2, fun_fact: "30 × 5 = 150 mg/day." },
          { q: "From all 4 plants combined (120 leaves), daily oxygen output?",
            options: %w[500 550 600 650], answer: 2, fun_fact: "120 × 5 = 600 mg/day." },
          { q: "Over a 7-day week, total oxygen produced by all 4 plants?",
            options: %w[3600 3900 4200 4500], answer: 2, fun_fact: "600 × 7 = 4200 mg." }
        ]
      },
      {
        tag: "science",
        difficulty: "medium",
        intro: "Your heart and lungs work non-stop. Let's see how much they actually do over a day.",
        steps: [
          { q: "A kid's heart beats about 80 times a minute. How many beats in 5 minutes?",
            options: %w[300 350 400 450], answer: 2, fun_fact: "5 × 80 = 400 beats." },
          { q: "How many beats in 1 hour (60 minutes)?",
            options: %w[3600 4200 4800 5400], answer: 2, fun_fact: "60 × 80 = 4800 beats." },
          { q: "How many beats in 2 hours?",
            options: %w[8400 9000 9600 10200], answer: 2, fun_fact: "2 × 4800 = 9600 beats." },
          { q: "Each beat pumps 50 mL of blood. Blood pumped in 1 minute (mL)?",
            options: %w[3000 3500 4000 4500], answer: 2, fun_fact: "80 × 50 = 4000 mL = 4 L per minute." },
          { q: "In 10 minutes, blood pumped (in liters)?",
            options: %w[30 35 40 45], answer: 2, fun_fact: "10 × 4 = 40 L." },
          { q: "In 1 hour, total blood pumped (in liters)?",
            options: %w[200 220 240 260], answer: 2, fun_fact: "60 × 4 = 240 L." },
          { q: "You breathe 20 times per minute. How many breaths in 5 minutes?",
            options: %w[80 90 100 110], answer: 2, fun_fact: "5 × 20 = 100 breaths." },
          { q: "Each breath moves 500 mL (½ L) of air. Air moved in 5 minutes (in liters)?",
            options: %w[40 45 50 55], answer: 2, fun_fact: "100 × 0.5 = 50 L." },
          { q: "How many breaths in 1 hour?",
            options: %w[1000 1100 1200 1300], answer: 2, fun_fact: "60 × 20 = 1200 breaths." },
          { q: "Total air moved in 1 hour (in liters)?",
            options: %w[500 550 600 650], answer: 2, fun_fact: "1200 × 0.5 = 600 L." }
        ]
      },
      {
        tag: "science",
        difficulty: "hard",
        intro: "Geologists track an erupting volcano: lava flow, evacuation, and ash spread.",
        steps: [
          { q: "A volcano erupts 200 cubic meters of lava per minute. How much lava in 5 minutes?",
            options: %w[800 900 1000 1100], answer: 2, fun_fact: "5 × 200 = 1000 m³." },
          { q: "How much lava in 1 hour (60 minutes)?",
            options: %w[10000 11000 12000 13000], answer: 2, fun_fact: "60 × 200 = 12000 m³." },
          { q: "How much lava over 5 hours of constant eruption?",
            options: %w[50000 55000 60000 65000], answer: 2, fun_fact: "5 × 12000 = 60000 m³." },
          { q: "The lava front advances at 1000 meters per hour. After 4 hours, how far has it moved?",
            options: %w[3000 3500 4000 4500], answer: 2, fun_fact: "4 × 1000 = 4000 m." },
          { q: "The town sits 5000 m from the crater. Hours until lava reaches the town?",
            options: %w[3 4 5 6], answer: 2, fun_fact: "5000 ÷ 1000 = 5 hours." },
          { q: "The town has 4500 residents. Each bus holds 50 people. Buses needed for one round of evacuation?",
            options: %w[70 80 90 100], answer: 2, fun_fact: "4500 ÷ 50 = 90 buses." },
          { q: "1 bus does a round trip in 30 minutes. How many trips can 1 bus make in 5 hours (300 min)?",
            options: %w[6 8 10 12], answer: 2, fun_fact: "300 ÷ 30 = 10 trips per bus." },
          { q: "If they have 9 buses, total trips possible in 5 hours?",
            options: %w[45 60 75 90], answer: 3, fun_fact: "9 × 10 = 90 trips." },
          { q: "Each trip carries 50 people. Total people moved by 9 buses in 5 hours?",
            options: %w[3500 4000 4500 5000], answer: 2, fun_fact: "90 × 50 = 4500 — exactly the whole town." },
          { q: "Meanwhile the ash cloud spreads 4 km per hour. After 6 hours, how far has it spread?",
            options: %w[18 20 24 28], answer: 2, fun_fact: "6 × 4 = 24 km." }
        ]
      },

      # ── HISTORY CHAINS ───────────────────────────────────────────────────
      {
        tag: "history",
        difficulty: "easy",
        intro: "Pioneers head west on the Oregon Trail in covered wagons. Their journey is 2000 miles long.",
        steps: [
          { q: "A wagon travels 20 miles per day. How many days to cover 200 miles?",
            options: %w[8 10 12 14], answer: 1, fun_fact: "200 ÷ 20 = 10 days." },
          { q: "The full journey is 2000 miles. At 20 miles/day, how many days total?",
            options: %w[80 90 100 120], answer: 2, fun_fact: "2000 ÷ 20 = 100 days." },
          { q: "Each wagon has 4 oxen. With 12 wagons, how many oxen pull the train?",
            options: %w[36 40 48 52], answer: 2, fun_fact: "12 × 4 = 48 oxen." },
          { q: "Each ox eats 30 lbs of grass a day. Daily grass for all 48 oxen (lbs)?",
            options: %w[1200 1320 1440 1560], answer: 2, fun_fact: "48 × 30 = 1440 lbs of grass per day." },
          { q: "The train has 6 families with 4 people each. Total pioneers?",
            options: %w[20 22 24 26], answer: 2, fun_fact: "6 × 4 = 24 people." },
          { q: "Each person eats 2 lbs of flour per day. Daily flour needed for all 24 (lbs)?",
            options: %w[40 44 48 52], answer: 2, fun_fact: "24 × 2 = 48 lbs/day." },
          { q: "For the full 100-day journey, total flour needed (lbs)?",
            options: %w[4400 4600 4800 5000], answer: 2, fun_fact: "100 × 48 = 4800 lbs." },
          { q: "Each sack holds 50 lbs of flour. How many sacks needed?",
            options: %w[88 92 96 100], answer: 2, fun_fact: "4800 ÷ 50 = 96 sacks." },
          { q: "Each wagon can carry 8 sacks of flour. How many wagons needed just for flour?",
            options: %w[10 11 12 14], answer: 2, fun_fact: "96 ÷ 8 = 12 wagons — exactly the number they have!" },
          { q: "If a single ox gets sick on day 50 and they lose 1 ox, how many oxen continue the trail?",
            options: %w[45 46 47 48], answer: 2, fun_fact: "48 − 1 = 47 oxen." }
        ]
      },
      {
        tag: "history",
        difficulty: "medium",
        intro: "A medieval lord defends his castle from siege with knights, soldiers, archers, and food stores.",
        steps: [
          { q: "The lord has 12 knights. Each knight has 4 squires (assistants). How many squires total?",
            options: %w[36 42 48 56], answer: 2, fun_fact: "12 × 4 = 48 squires." },
          { q: "Combined knights + squires?",
            options: %w[50 55 60 65], answer: 2, fun_fact: "12 + 48 = 60 fighters." },
          { q: "Add 80 foot soldiers. Total defenders so far?",
            options: %w[120 130 140 150], answer: 2, fun_fact: "60 + 80 = 140." },
          { q: "Add 30 archers on the walls. Total castle defenders?",
            options: %w[160 165 170 180], answer: 2, fun_fact: "140 + 30 = 170." },
          { q: "Each defender eats 2 lbs of food per day. Daily food needed (lbs)?",
            options: %w[300 320 340 360], answer: 2, fun_fact: "170 × 2 = 340 lbs/day." },
          { q: "The castle has 3400 lbs of food in storage. How many days will it last?",
            options: %w[8 9 10 12], answer: 2, fun_fact: "3400 ÷ 340 = 10 days." },
          { q: "The lord rations meals to 1 lb/day per defender. Days food now lasts?",
            options: %w[15 18 20 25], answer: 2, fun_fact: "3400 ÷ 170 = 20 days." },
          { q: "A supply wagon arrives with 1700 more lbs. New total food (lbs)?",
            options: %w[4800 5000 5100 5300], answer: 2, fun_fact: "3400 + 1700 = 5100 lbs." },
          { q: "At 1 lb/day for 170 defenders, how many days does 5100 lbs last?",
            options: %w[20 25 30 35], answer: 2, fun_fact: "5100 ÷ 170 = 30 days." },
          { q: "The siege is expected to last 60 days. At 1 lb/day for 170 defenders, total food needed (lbs)?",
            options: %w[10000 10200 10400 10800], answer: 1, fun_fact: "60 × 170 = 10200 lbs — they need 5100 more from somewhere!" }
        ]
      },
      {
        tag: "history",
        difficulty: "medium",
        intro: "A lighthouse keeper guides ships through the night. He tracks oil, light flashes, and ships passing.",
        steps: [
          { q: "The lamp burns 4 oz of oil per hour. How much oil for an 8-hour shift?",
            options: %w[24 28 32 36], answer: 2, fun_fact: "8 × 4 = 32 oz." },
          { q: "The lamp runs 12 hours each night. Oil used per night (oz)?",
            options: %w[40 44 48 52], answer: 2, fun_fact: "12 × 4 = 48 oz/night." },
          { q: "Over a 30-day month, total oil used (oz)?",
            options: %w[1200 1320 1440 1560], answer: 2, fun_fact: "30 × 48 = 1440 oz." },
          { q: "The keeper has 1500 oz of oil in stock. After 1 month, oil left?",
            options: %w[40 50 60 70], answer: 2, fun_fact: "1500 − 1440 = 60 oz." },
          { q: "Oil ships come every 3 months. How much oil is needed for 3 months?",
            options: %w[3960 4140 4320 4500], answer: 2, fun_fact: "3 × 1440 = 4320 oz." },
          { q: "He counts about 6 ships passing per night. Ships in a 30-day month?",
            options: %w[150 165 180 195], answer: 2, fun_fact: "30 × 6 = 180 ships." },
          { q: "In a full year (12 months), total ships?",
            options: %w[1800 1980 2160 2280], answer: 2, fun_fact: "12 × 180 = 2160 ships." },
          { q: "The light flashes every 5 seconds. How many flashes in 1 minute (60 sec)?",
            options: %w[6 10 12 15], answer: 2, fun_fact: "60 ÷ 5 = 12 flashes/minute." },
          { q: "How many flashes per hour?",
            options: %w[600 660 720 780], answer: 2, fun_fact: "60 × 12 = 720 flashes/hour." },
          { q: "Per 12-hour night, total flashes?",
            options: %w[7200 8000 8640 9000], answer: 2, fun_fact: "12 × 720 = 8640 flashes." }
        ]
      },

      # ── SPACE ───────────────────────────────────────────────────────────
      { tag: "space", difficulty: "medium",
        intro: "Astronaut Sam lives on the International Space Station and tracks orbits, water, and crew time.",
        steps: [
          { q: "The ISS orbits Earth every 90 minutes. How many orbits in a 24-hour day?",
            options: %w[14 15 16 18], answer: 2, fun_fact: "1440 minutes ÷ 90 = 16 orbits/day." },
          { q: "Over a 7-day week, total orbits?",
            options: %w[98 105 112 119], answer: 2, fun_fact: "7 × 16 = 112 orbits." },
          { q: "The ISS travels 8 km per second. How far in 60 seconds (1 minute)?",
            options: %w[420 450 480 540], answer: 2, fun_fact: "60 × 8 = 480 km/min." },
          { q: "The crew has 7 astronauts. Each needs 2 L of water/day. Daily water (L)?",
            options: %w[10 12 14 16], answer: 2, fun_fact: "7 × 2 = 14 L/day." },
          { q: "Weekly water for the crew (L)?",
            options: %w[84 91 98 105], answer: 2, fun_fact: "7 × 14 = 98 L/week." },
          { q: "A water shipment of 700 L arrives. How many days will it last?",
            options: %w[40 45 50 55], answer: 2, fun_fact: "700 ÷ 14 = 50 days." },
          { q: "Each astronaut sleeps 8 hours per night. Crew nightly sleep total (hours)?",
            options: %w[42 49 56 63], answer: 2, fun_fact: "7 × 8 = 56 hours." },
          { q: "Each astronaut exercises 2 hours/day. Crew daily exercise (hours)?",
            options: %w[10 12 14 16], answer: 2, fun_fact: "7 × 2 = 14 hours." },
          { q: "The mission lasts 300 days. Total water needed for the crew (L)?",
            options: %w[3600 3900 4200 4500], answer: 2, fun_fact: "300 × 14 = 4200 L." },
          { q: "How many 700-L shipments are needed for the full 300-day mission?",
            options: %w[4 5 6 8], answer: 2, fun_fact: "4200 ÷ 700 = 6 shipments." }
        ] },

      # ── ANIMALS ─────────────────────────────────────────────────────────
      { tag: "animals", difficulty: "easy",
        intro: "The zookeeper feeds and waters the animals each morning. There are elephants, lions, and monkeys to take care of.",
        steps: [
          { q: "The zoo has 4 elephants. Each eats 200 lbs of hay per day. Daily hay total (lbs)?",
            options: %w[600 700 800 900], answer: 2, fun_fact: "4 × 200 = 800 lbs." },
          { q: "Hay comes in 100-lb bales. Bales used per day?",
            options: %w[6 7 8 10], answer: 2, fun_fact: "800 ÷ 100 = 8 bales." },
          { q: "Bales used over a 7-day week?",
            options: %w[42 49 56 63], answer: 2, fun_fact: "7 × 8 = 56 bales." },
          { q: "There are 6 lions. Each eats 12 lbs of meat per day. Daily meat (lbs)?",
            options: %w[60 66 72 78], answer: 2, fun_fact: "6 × 12 = 72 lbs." },
          { q: "Weekly meat for the lions (lbs)?",
            options: %w[420 462 504 546], answer: 2, fun_fact: "7 × 72 = 504 lbs." },
          { q: "12 monkeys live in the troop. Each eats 3 bananas per day. Daily bananas?",
            options: %w[24 30 36 42], answer: 2, fun_fact: "12 × 3 = 36 bananas." },
          { q: "Bananas come in bunches of 6. Bunches needed per day?",
            options: %w[4 5 6 8], answer: 2, fun_fact: "36 ÷ 6 = 6 bunches." },
          { q: "Weekly bunches for the monkeys?",
            options: %w[36 39 42 45], answer: 2, fun_fact: "7 × 6 = 42 bunches." },
          { q: "Total animals (elephants + lions + monkeys)?",
            options: %w[18 20 22 24], answer: 2, fun_fact: "4 + 6 + 12 = 22 animals." },
          { q: "Each animal drinks 4 L of water/day. Daily water (L) for all 22?",
            options: %w[80 84 88 96], answer: 2, fun_fact: "22 × 4 = 88 L/day." }
        ] },

      # ── DINOSAURS ───────────────────────────────────────────────────────
      { tag: "dinosaurs", difficulty: "medium",
        intro: "Dr. Carter's dig site has uncovered dinosaur bones across multiple summer seasons.",
        steps: [
          { q: "Last summer, the team found 24 fossils in 4 weeks. Fossils per week?",
            options: %w[4 5 6 8], answer: 2, fun_fact: "24 ÷ 4 = 6 fossils/week." },
          { q: "This summer the team doubled. They find 12 fossils per week. Over 4 weeks, total?",
            options: %w[36 42 48 54], answer: 2, fun_fact: "4 × 12 = 48 fossils." },
          { q: "Combined fossils across both summers?",
            options: %w[60 66 72 78], answer: 2, fun_fact: "24 + 48 = 72 fossils." },
          { q: "They identify 8 different dinosaur species. Average fossils per species?",
            options: %w[7 8 9 10], answer: 2, fun_fact: "72 ÷ 8 = 9 fossils/species." },
          { q: "T. rex was about 40 feet long. Roughly in meters (1 ft ≈ 0.3 m)?",
            options: %w[8 10 12 14], answer: 2, fun_fact: "40 × 0.3 ≈ 12 meters." },
          { q: "T. rex weighed about 7 tons. In pounds (1 ton = 2000 lbs)?",
            options: %w[10000 12000 14000 16000], answer: 2, fun_fact: "7 × 2000 = 14000 lbs." },
          { q: "The dig site is 60 acres. They've explored 25%. Acres explored?",
            options: %w[10 12 15 18], answer: 2, fun_fact: "60 × 0.25 = 15 acres." },
          { q: "Acres still unexplored?",
            options: %w[35 40 45 50], answer: 2, fun_fact: "60 − 15 = 45 acres." },
          { q: "They explore 5 acres per week. Weeks to finish the rest?",
            options: %w[7 8 9 10], answer: 2, fun_fact: "45 ÷ 5 = 9 weeks." },
          { q: "T. rex lived 66 million years ago. Stegosaurus lived 150 million years ago. Time gap (millions of years)?",
            options: %w[74 80 84 90], answer: 2, fun_fact: "150 − 66 = 84 million years." }
        ] },

      # ── SPORTS ──────────────────────────────────────────────────────────
      { tag: "sports", difficulty: "medium",
        intro: "A youth soccer tournament has 8 teams playing across a weekend. Track games, players, and costs.",
        steps: [
          { q: "8 teams play in pairs (4 games per round). The tournament has 5 rounds. Total games?",
            options: %w[16 18 20 24], answer: 2, fun_fact: "5 × 4 = 20 games." },
          { q: "Each game lasts 60 minutes. Total game minutes across the tournament?",
            options: %w[1000 1100 1200 1300], answer: 2, fun_fact: "20 × 60 = 1200 minutes." },
          { q: "In hours?",
            options: %w[18 19 20 22], answer: 2, fun_fact: "1200 ÷ 60 = 20 hours." },
          { q: "Each team has 11 starters + 4 subs = 15 players. Players across all 8 teams?",
            options: %w[100 110 120 130], answer: 2, fun_fact: "8 × 15 = 120 players." },
          { q: "Each player gets a $5 trophy at the end. Total trophy cost?",
            options: %w[$500 $550 $600 $650], answer: 2, fun_fact: "120 × $5 = $600." },
          { q: "Each team has 2 coaches. Total coaches?",
            options: %w[12 14 16 18], answer: 2, fun_fact: "8 × 2 = 16 coaches." },
          { q: "Field rental costs $100/hour. Hours rented = 20. Total field cost?",
            options: %w[$1500 $1800 $2000 $2200], answer: 2, fun_fact: "20 × $100 = $2000." },
          { q: "Each game uses 2 referees, paid $30 per game. Total referee pay?",
            options: %w[$1000 $1100 $1200 $1300], answer: 2, fun_fact: "20 × 2 × $30 = $1200." },
          { q: "Total tournament cost (trophies + field + referees)?",
            options: %w[$3500 $3700 $3800 $4000], answer: 2, fun_fact: "$600 + $2000 + $1200 = $3800." },
          { q: "8 teams pay $500 entry each. Total entry revenue?",
            options: %w[$3500 $3800 $4000 $4500], answer: 2, fun_fact: "8 × $500 = $4000 — leaving $200 profit." }
        ] },

      # ── MUSIC ───────────────────────────────────────────────────────────
      { tag: "music", difficulty: "medium",
        intro: "A 5-piece band tours small venues across 10 weeks. Track set lengths, payroll, and ticket revenue.",
        steps: [
          { q: "The setlist has 12 songs. Each song is 4 minutes. Set length (minutes)?",
            options: %w[40 44 48 52], answer: 2, fun_fact: "12 × 4 = 48 minutes." },
          { q: "The band plays 3 sets per night. Nightly stage time (minutes)?",
            options: %w[120 132 144 156], answer: 2, fun_fact: "3 × 48 = 144 minutes." },
          { q: "5 nights per week. Weekly stage minutes?",
            options: %w[600 660 720 780], answer: 2, fun_fact: "5 × 144 = 720 minutes." },
          { q: "Tour is 10 weeks. Total tour stage minutes?",
            options: %w[6500 7000 7200 7500], answer: 2, fun_fact: "10 × 720 = 7200 minutes." },
          { q: "In hours?",
            options: %w[100 110 120 130], answer: 2, fun_fact: "7200 ÷ 60 = 120 hours." },
          { q: "5 band members each paid $200/night. Nightly payroll?",
            options: %w[$800 $900 $1000 $1100], answer: 2, fun_fact: "5 × $200 = $1000." },
          { q: "Total tour nights = 5 × 10 = 50. Total payroll across the tour?",
            options: %w[$45000 $48000 $50000 $52000], answer: 2, fun_fact: "50 × $1000 = $50000." },
          { q: "Average venue holds 200 people. Sellouts every night × 50 nights = total tickets sold?",
            options: %w[8000 9000 10000 11000], answer: 2, fun_fact: "50 × 200 = 10000 tickets." },
          { q: "Tickets cost $20 each. Total ticket revenue?",
            options: %w[$160000 $180000 $200000 $220000], answer: 2, fun_fact: "10000 × $20 = $200000." },
          { q: "After paying $50000 in payroll, tour profit?",
            options: %w[$140000 $145000 $150000 $155000], answer: 2, fun_fact: "$200000 − $50000 = $150000." }
        ] },

      # ── MOVIES ──────────────────────────────────────────────────────────
      { tag: "movies", difficulty: "medium",
        intro: "A small movie theater shows a Friday-night double feature for the town.",
        steps: [
          { q: "The theater has 8 rows of 15 seats. Total seats?",
            options: %w[100 110 120 130], answer: 2, fun_fact: "8 × 15 = 120 seats." },
          { q: "They show 2 movies, each 2 hours long. Total movie minutes?",
            options: %w[180 210 240 270], answer: 2, fun_fact: "2 × 120 = 240 minutes." },
          { q: "Add a 30-minute intermission. Total runtime (minutes)?",
            options: %w[240 260 270 280], answer: 2, fun_fact: "240 + 30 = 270 minutes." },
          { q: "Tickets are $10 each. If sold out, total ticket revenue?",
            options: %w[$1000 $1100 $1200 $1300], answer: 2, fun_fact: "120 × $10 = $1200." },
          { q: "They actually sell 90 tickets. Revenue?",
            options: %w[$800 $850 $900 $950], answer: 2, fun_fact: "90 × $10 = $900." },
          { q: "Each customer averages $5 in snacks. Snack revenue from 90 customers?",
            options: %w[$400 $425 $450 $475], answer: 2, fun_fact: "90 × $5 = $450." },
          { q: "Total night revenue (tickets + snacks)?",
            options: %w[$1300 $1325 $1350 $1400], answer: 2, fun_fact: "$900 + $450 = $1350." },
          { q: "Operating costs are $400 per night. Profit?",
            options: %w[$900 $925 $950 $1000], answer: 2, fun_fact: "$1350 − $400 = $950." },
          { q: "Over a 5-night week with similar nights, weekly profit?",
            options: %w[$4500 $4650 $4750 $4900], answer: 2, fun_fact: "5 × $950 = $4750." },
          { q: "The manager gets 20% of weekly profit. Manager's cut?",
            options: %w[$850 $900 $950 $1000], answer: 2, fun_fact: "$4750 × 0.20 = $950." }
        ] },

      # ── MOVIES_KIDS ─────────────────────────────────────────────────────
      { tag: "movies_kids", difficulty: "easy",
        intro: "Mrs. Lee's class watches a Disney movie marathon during a rainy afternoon.",
        steps: [
          { q: "The class has 25 kids. They watch 4 short Disney movies, each 30 minutes. Total movie time (min)?",
            options: %w[100 110 120 130], answer: 2, fun_fact: "4 × 30 = 120 minutes." },
          { q: "In hours?",
            options: %w[1 2 3 4], answer: 1, fun_fact: "120 ÷ 60 = 2 hours." },
          { q: "Each kid eats 2 popcorn cups during the marathon. Total popcorn cups?",
            options: %w[40 45 50 55], answer: 2, fun_fact: "25 × 2 = 50 cups." },
          { q: "Popcorn cups come in packs of 10. Packs needed?",
            options: %w[3 4 5 6], answer: 2, fun_fact: "50 ÷ 10 = 5 packs." },
          { q: "Each pack costs $4. Popcorn cost?",
            options: %w[$15 $18 $20 $22], answer: 2, fun_fact: "5 × $4 = $20." },
          { q: "Each kid drinks 1 juice box. Juice boxes come in 5-packs. Packs needed?",
            options: %w[3 4 5 6], answer: 2, fun_fact: "25 ÷ 5 = 5 packs." },
          { q: "Each pack costs $3. Juice cost?",
            options: %w[$12 $13 $15 $18], answer: 2, fun_fact: "5 × $3 = $15." },
          { q: "Total snack cost (popcorn + juice + $15 in extras)?",
            options: %w[$45 $48 $50 $55], answer: 2, fun_fact: "$20 + $15 + $15 = $50." },
          { q: "Splitting $50 across 25 kids: cost per kid?",
            options: %w[$1 $2 $3 $4], answer: 1, fun_fact: "$50 ÷ 25 = $2/kid." },
          { q: "After 5 marathons during the school year, total spent?",
            options: %w[$200 $225 $250 $275], answer: 2, fun_fact: "5 × $50 = $250." }
        ] },

      # ── GEOGRAPHY ───────────────────────────────────────────────────────
      { tag: "geography", difficulty: "medium",
        intro: "A traveler hops between 7 cities on a world tour, tracking flight + train hours.",
        steps: [
          { q: "New York to London is 3500 miles. Plane flies 700 mph. Hours to fly?",
            options: %w[3 4 5 7], answer: 2, fun_fact: "3500 ÷ 700 = 5 hours." },
          { q: "London to Paris is 280 miles by train at 70 mph. Hours?",
            options: %w[2 3 4 5], answer: 2, fun_fact: "280 ÷ 70 = 4 hours." },
          { q: "Paris to Rome is 1100 km by plane at 550 km/hr. Hours?",
            options: %w[1 2 3 4], answer: 1, fun_fact: "1100 ÷ 550 = 2 hours." },
          { q: "Rome to Cairo is 2100 km by plane at 700 km/hr. Hours?",
            options: %w[2 3 4 5], answer: 1, fun_fact: "2100 ÷ 700 = 3 hours." },
          { q: "Total travel hours so far (4 legs)?",
            options: %w[12 13 14 16], answer: 2, fun_fact: "5 + 4 + 2 + 3 = 14 hours." },
          { q: "Cairo to Mumbai is 4200 km at 700 km/hr. Hours?",
            options: %w[5 6 7 8], answer: 1, fun_fact: "4200 ÷ 700 = 6 hours." },
          { q: "Mumbai to Tokyo is 6700 km at 670 km/hr. Hours?",
            options: %w[8 9 10 12], answer: 2, fun_fact: "6700 ÷ 670 = 10 hours." },
          { q: "Tokyo to Sydney is 7800 km at 780 km/hr. Hours?",
            options: %w[8 9 10 12], answer: 2, fun_fact: "7800 ÷ 780 = 10 hours." },
          { q: "Total travel hours across all 7 legs?",
            options: %w[36 38 40 42], answer: 2, fun_fact: "14 + 6 + 10 + 10 = 40 hours." },
          { q: "Time difference between New York (UTC −5) and Tokyo (UTC +9). Hours apart?",
            options: %w[12 13 14 16], answer: 2, fun_fact: "9 − (−5) = 14 hours." }
        ] },

      # ── CARS ────────────────────────────────────────────────────────────
      { tag: "cars", difficulty: "easy",
        intro: "4 friends take a 600-mile road trip and split every cost.",
        steps: [
          { q: "Trip distance: 600 miles. Car gets 30 mpg. Gallons of gas needed?",
            options: %w[15 18 20 22], answer: 2, fun_fact: "600 ÷ 30 = 20 gallons." },
          { q: "Gas costs $4/gallon. Total gas cost?",
            options: %w[$60 $70 $80 $90], answer: 2, fun_fact: "20 × $4 = $80." },
          { q: "Average speed 60 mph. Total driving hours?",
            options: %w[8 9 10 12], answer: 2, fun_fact: "600 ÷ 60 = 10 hours." },
          { q: "They drive 5 hours per day. Days needed?",
            options: %w[1 2 3 4], answer: 1, fun_fact: "10 ÷ 5 = 2 days." },
          { q: "Lunch costs $30 each day. Total lunch cost?",
            options: %w[$40 $50 $60 $70], answer: 2, fun_fact: "2 × $30 = $60." },
          { q: "1 hotel night at $120. Total trip cost (gas + lunch + hotel)?",
            options: %w[$240 $250 $260 $270], answer: 2, fun_fact: "$80 + $60 + $120 = $260." },
          { q: "Splitting $260 four ways: cost per friend?",
            options: %w[$60 $65 $70 $75], answer: 1, fun_fact: "$260 ÷ 4 = $65/friend." },
          { q: "Tank holds 10 gallons. They need 20 gallons total. Fill-ups needed?",
            options: %w[1 2 3 4], answer: 1, fun_fact: "20 ÷ 10 = 2 fill-ups." },
          { q: "Each fill-up takes 5 minutes. Total fill-up time (min)?",
            options: %w[5 8 10 15], answer: 2, fun_fact: "2 × 5 = 10 minutes." },
          { q: "Lunch breaks total 60 min. Total non-driving time including fill-ups (min)?",
            options: %w[60 65 70 75], answer: 2, fun_fact: "60 + 10 = 70 minutes." }
        ] },

      # ── VIDEO_GAMES ─────────────────────────────────────────────────────
      { tag: "video_games", difficulty: "easy",
        intro: "You're playing a level-based game: collect coins, defeat enemies, finish all the levels.",
        steps: [
          { q: "You collect 10 coins per level. After 8 levels, total coins?",
            options: %w[60 70 80 90], answer: 2, fun_fact: "8 × 10 = 80 coins." },
          { q: "Each enemy gives 5 bonus coins. You defeated 12. Bonus coins?",
            options: %w[40 50 60 70], answer: 2, fun_fact: "12 × 5 = 60 coins." },
          { q: "Total coins (level + enemy)?",
            options: %w[120 130 140 150], answer: 2, fun_fact: "80 + 60 = 140 coins." },
          { q: "Each extra life costs 70 coins. Lives you can buy?",
            options: %w[1 2 3 4], answer: 1, fun_fact: "140 ÷ 70 = 2 lives." },
          { q: "You start with 3 lives. After buying 2 more, total lives?",
            options: %w[4 5 6 7], answer: 1, fun_fact: "3 + 2 = 5 lives." },
          { q: "You played 4 hours and finished 8 levels. Levels per hour?",
            options: %w[1 2 3 4], answer: 1, fun_fact: "8 ÷ 4 = 2 levels/hour." },
          { q: "The game has 50 levels. At 2/hour, hours to finish them all?",
            options: %w[20 22 25 28], answer: 2, fun_fact: "50 ÷ 2 = 25 hours." },
          { q: "Max possible score = 1000 points/level. Max total score for all 50?",
            options: %w[40000 45000 50000 55000], answer: 2, fun_fact: "50 × 1000 = 50000." },
          { q: "Your friend scored 35000. Difference between max and your friend?",
            options: %w[10000 12500 15000 17500], answer: 2, fun_fact: "50000 − 35000 = 15000." },
          { q: "If you play 5 hours per weekend, weekends to finish the 25 hours total?",
            options: %w[3 4 5 6], answer: 2, fun_fact: "25 ÷ 5 = 5 weekends." }
        ] },

      # ── DISNEY ──────────────────────────────────────────────────────────
      { tag: "disney", difficulty: "easy",
        intro: "You spend the day at Disney World. Plan your time across rides, shows, meals, and tickets.",
        steps: [
          { q: "The park is open 12 hours. You arrive 1 hour after opening. Hours you'll be there?",
            options: %w[10 11 12 13], answer: 1, fun_fact: "12 − 1 = 11 hours." },
          { q: "You want to ride 8 rides. Each takes 30 min including waiting. Ride time (min)?",
            options: %w[180 210 240 270], answer: 2, fun_fact: "8 × 30 = 240 minutes." },
          { q: "240 minutes of rides — how many hours is that?",
            options: %w[3 4 5 6], answer: 1, fun_fact: "240 ÷ 60 = 4 hours." },
          { q: "You watch 2 shows, 30 minutes each. Show time (min)?",
            options: %w[40 50 60 70], answer: 2, fun_fact: "2 × 30 = 60 minutes." },
          { q: "Lunch + dinner = 2 meals × 30 min each. Meal time (min)?",
            options: %w[40 50 60 70], answer: 2, fun_fact: "2 × 30 = 60 minutes." },
          { q: "Total active time (rides + shows + meals) in minutes?",
            options: %w[330 345 360 375], answer: 2, fun_fact: "240 + 60 + 60 = 360 minutes." },
          { q: "Convert that 360-minute active total to hours.",
            options: %w[5 6 7 8], answer: 1, fun_fact: "360 ÷ 60 = 6 hours." },
          { q: "Of the 11 hours at the park, hours left for walking + breaks?",
            options: %w[3 4 5 6], answer: 2, fun_fact: "11 − 6 = 5 hours." },
          { q: "Tickets are $120/person. 4 people in your group. Total ticket cost?",
            options: %w[$420 $450 $480 $500], answer: 2, fun_fact: "4 × $120 = $480." },
          { q: "Add $15/person in snacks. Total day cost (tickets + snacks)?",
            options: %w[$520 $530 $540 $560], answer: 2, fun_fact: "$480 + (4 × $15) = $480 + $60 = $540." }
        ] },

      # ── SUPERHERO ───────────────────────────────────────────────────────
      { tag: "superhero", difficulty: "medium",
        intro: "The Avengers assemble for missions across the year. Track team size, training, and missions.",
        steps: [
          { q: "Original Avengers: Iron Man, Captain America, Thor, Hulk, Black Widow, Hawkeye. How many?",
            options: %w[4 5 6 7], answer: 2, fun_fact: "6 founding members." },
          { q: "After Phase 2, 6 more heroes join. Total team size?",
            options: %w[10 11 12 13], answer: 2, fun_fact: "6 + 6 = 12 Avengers." },
          { q: "Each Avenger does 5 missions per year. Total missions across the team?",
            options: %w[50 55 60 65], answer: 2, fun_fact: "12 × 5 = 60 missions." },
          { q: "Each mission lasts 3 days on average. Total mission days across the year?",
            options: %w[160 170 180 190], answer: 2, fun_fact: "60 × 3 = 180 days." },
          { q: "There are 365 days in a year. Days NOT on missions?",
            options: %w[175 180 185 190], answer: 2, fun_fact: "365 − 180 = 185 days." },
          { q: "Each Avenger trains 2 hours/day. Daily team training (hours)?",
            options: %w[20 22 24 26], answer: 2, fun_fact: "12 × 2 = 24 hours." },
          { q: "Weekly team training (7 days)?",
            options: %w[150 160 168 180], answer: 2, fun_fact: "7 × 24 = 168 hours." },
          { q: "Avengers have 4 quinjets, each holding 6 heroes. Max heroes transported?",
            options: %w[18 20 22 24], answer: 3, fun_fact: "4 × 6 = 24 — fits the whole team." },
          { q: "Splitting 12 Avengers evenly across 4 jets: heroes per jet?",
            options: %w[2 3 4 5], answer: 1, fun_fact: "12 ÷ 4 = 3 heroes/jet." },
          { q: "Each Avenger has saved an estimated 1000 lives in their career. Total lives saved by 12?",
            options: %w[10000 11000 12000 13000], answer: 2, fun_fact: "12 × 1000 = 12000 lives." }
        ] },

      # ── FOOD ────────────────────────────────────────────────────────────
      { tag: "food", difficulty: "easy",
        intro: "Sara runs a bake sale to raise money for the school library.",
        steps: [
          { q: "She bakes 6 batches of cookies. Each batch makes 12 cookies. Total cookies?",
            options: %w[60 66 72 78], answer: 2, fun_fact: "6 × 12 = 72 cookies." },
          { q: "She sells each cookie for $1. Possible revenue if all sell?",
            options: %w[$60 $66 $72 $78], answer: 2, fun_fact: "72 × $1 = $72." },
          { q: "Cookie ingredients cost $20. Profit if all 72 cookies sell?",
            options: %w[$42 $48 $52 $58], answer: 2, fun_fact: "$72 − $20 = $52." },
          { q: "She actually sells 60 cookies. Real cookie revenue?",
            options: %w[$50 $55 $60 $65], answer: 2, fun_fact: "60 × $1 = $60." },
          { q: "Real cookie profit (revenue − ingredients)?",
            options: %w[$30 $35 $40 $45], answer: 2, fun_fact: "$60 − $20 = $40." },
          { q: "She also bakes 24 cupcakes at $2 each. Cupcake revenue if all sell?",
            options: %w[$36 $42 $48 $54], answer: 2, fun_fact: "24 × $2 = $48." },
          { q: "Cupcake ingredients cost $10. Cupcake profit?",
            options: %w[$32 $35 $38 $42], answer: 2, fun_fact: "$48 − $10 = $38." },
          { q: "Total bake sale profit (cookies + cupcakes)?",
            options: %w[$72 $75 $78 $82], answer: 2, fun_fact: "$40 + $38 = $78." },
          { q: "Library goal: $200. Shortfall after 1 sale?",
            options: %w[$112 $118 $122 $128], answer: 2, fun_fact: "$200 − $78 = $122." },
          { q: "If Sara repeats the sale every month for 3 months, total profit?",
            options: %w[$214 $224 $234 $244], answer: 2, fun_fact: "3 × $78 = $234 — beats the goal!" }
        ] },

      # ── BOOKS ───────────────────────────────────────────────────────────
      { tag: "books", difficulty: "easy",
        intro: "You sign up for the summer reading challenge at the library.",
        steps: [
          { q: "Goal: 12 books. Each book is 150 pages. Total pages over the summer?",
            options: %w[1500 1650 1800 1950], answer: 2, fun_fact: "12 × 150 = 1800 pages." },
          { q: "Summer is 90 days. Pages per day to finish?",
            options: %w[15 18 20 22], answer: 2, fun_fact: "1800 ÷ 90 = 20 pages/day." },
          { q: "You actually read 30 pages per day. Days to finish 1 book?",
            options: %w[3 4 5 6], answer: 2, fun_fact: "150 ÷ 30 = 5 days." },
          { q: "At your pace, days to finish all 12 books?",
            options: %w[50 55 60 65], answer: 2, fun_fact: "12 × 5 = 60 days." },
          { q: "Days early you'll finish before summer ends?",
            options: %w[20 25 30 35], answer: 2, fun_fact: "90 − 60 = 30 days." },
          { q: "The library lets you borrow 2 books at a time. Trips needed for 12 books?",
            options: %w[4 5 6 7], answer: 2, fun_fact: "12 ÷ 2 = 6 trips." },
          { q: "Each library trip is 30 min round trip. Total library time (min)?",
            options: %w[120 150 180 210], answer: 2, fun_fact: "6 × 30 = 180 minutes." },
          { q: "In hours?",
            options: %w[2 3 4 5], answer: 1, fun_fact: "180 ÷ 60 = 3 hours." },
          { q: "After 4 summers like this, total books read?",
            options: %w[36 42 48 54], answer: 2, fun_fact: "4 × 12 = 48 books." },
          { q: "Total pages across 4 summers (48 books × 150 pages)?",
            options: %w[6800 7000 7200 7400], answer: 2, fun_fact: "48 × 150 = 7200 pages." }
        ] },

      # ── ART ─────────────────────────────────────────────────────────────
      { tag: "art", difficulty: "easy",
        intro: "The art teacher sets up supplies for a class of 18 kids.",
        steps: [
          { q: "18 kids each get 1 canvas. Canvases needed?",
            options: %w[16 17 18 20], answer: 2, fun_fact: "1 per kid = 18 canvases." },
          { q: "Canvases come in packs of 6. Packs needed?",
            options: %w[2 3 4 5], answer: 1, fun_fact: "18 ÷ 6 = 3 packs." },
          { q: "Each pack costs $20. Total canvas cost?",
            options: %w[$50 $55 $60 $65], answer: 2, fun_fact: "3 × $20 = $60." },
          { q: "Each kid needs 4 brushes. Total brushes?",
            options: %w[64 68 72 76], answer: 2, fun_fact: "18 × 4 = 72 brushes." },
          { q: "Brushes come in sets of 12. Sets needed?",
            options: %w[4 5 6 7], answer: 2, fun_fact: "72 ÷ 12 = 6 sets." },
          { q: "Each set costs $8. Total brush cost?",
            options: %w[$42 $44 $48 $52], answer: 2, fun_fact: "6 × $8 = $48." },
          { q: "The teacher provides 3 colors of paint per kid. Paint tubes needed?",
            options: %w[48 50 54 60], answer: 2, fun_fact: "18 × 3 = 54 tubes." },
          { q: "Paint comes in 6-packs ($15 each). Packs needed?",
            options: %w[7 8 9 10], answer: 2, fun_fact: "54 ÷ 6 = 9 packs." },
          { q: "Total paint cost?",
            options: %w[$120 $130 $135 $140], answer: 2, fun_fact: "9 × $15 = $135." },
          { q: "Total class supply cost (canvas + brush + paint)?",
            options: %w[$235 $240 $243 $250], answer: 2, fun_fact: "$60 + $48 + $135 = $243." }
        ] },

      # ── TRAVEL ──────────────────────────────────────────────────────────
      { tag: "travel", difficulty: "medium",
        intro: "You backpack across Europe for 3 weeks, visiting 6 cities and tracking your budget.",
        steps: [
          { q: "You stay 3 nights in each of 6 cities. Total nights?",
            options: %w[15 16 18 21], answer: 2, fun_fact: "6 × 3 = 18 nights." },
          { q: "Hostels cost $30/night. Total lodging?",
            options: %w[$480 $510 $540 $570], answer: 2, fun_fact: "18 × $30 = $540." },
          { q: "5 train trips between cities at $40 each. Train cost?",
            options: %w[$160 $180 $200 $220], answer: 2, fun_fact: "5 × $40 = $200." },
          { q: "Daily food budget: $25. Over 18 days, food cost?",
            options: %w[$400 $425 $450 $475], answer: 2, fun_fact: "18 × $25 = $450." },
          { q: "You visit 2 museums in each of 6 cities, $15 each. Museum cost?",
            options: %w[$150 $165 $180 $195], answer: 2, fun_fact: "6 × 2 × $15 = $180." },
          { q: "Total expenses (lodging + train + food + museum)?",
            options: %w[$1320 $1350 $1370 $1400], answer: 2, fun_fact: "$540 + $200 + $450 + $180 = $1370." },
          { q: "You brought $1500 cash. Money left at the end?",
            options: %w[$110 $120 $130 $140], answer: 2, fun_fact: "$1500 − $1370 = $130." },
          { q: "You take 50 photos in each of the 6 cities. Total photos?",
            options: %w[250 275 300 325], answer: 2, fun_fact: "6 × 50 = 300 photos." },
          { q: "You walk 5 miles average per day for 18 days. Total miles?",
            options: %w[80 85 90 95], answer: 2, fun_fact: "18 × 5 = 90 miles." },
          { q: "The trip lasts 3 weeks. Average walking miles per week?",
            options: %w[25 28 30 32], answer: 2, fun_fact: "90 ÷ 3 = 30 miles/week." }
        ] },

      # ── PHOTOGRAPHY ─────────────────────────────────────────────────────
      { tag: "photography", difficulty: "medium",
        intro: "You're shooting a wedding and managing memory cards, batteries, and editing time.",
        steps: [
          { q: "Each SD card holds 500 photos. You bring 4 cards. Total photo capacity?",
            options: %w[1500 1750 2000 2500], answer: 2, fun_fact: "4 × 500 = 2000 photos." },
          { q: "You take 800 photos at the ceremony and 400 at the reception. Total taken?",
            options: %w[1000 1100 1200 1300], answer: 2, fun_fact: "800 + 400 = 1200 photos." },
          { q: "Storage capacity remaining (capacity − taken)?",
            options: %w[600 700 800 900], answer: 2, fun_fact: "2000 − 1200 = 800 photos." },
          { q: "Each battery lasts 2 hours. Wedding lasts 8 hours. Batteries needed?",
            options: %w[2 3 4 5], answer: 2, fun_fact: "8 ÷ 2 = 4 batteries." },
          { q: "Batteries cost $30 each. Total battery cost?",
            options: %w[$100 $110 $120 $130], answer: 2, fun_fact: "4 × $30 = $120." },
          { q: "Editing 1 photo takes 2 minutes. Total edit time for 1200 photos (min)?",
            options: %w[2200 2300 2400 2500], answer: 2, fun_fact: "1200 × 2 = 2400 minutes." },
          { q: "In hours?",
            options: %w[35 38 40 45], answer: 2, fun_fact: "2400 ÷ 60 = 40 hours." },
          { q: "You edit 5 hours per day. Days to finish editing?",
            options: %w[6 7 8 9], answer: 2, fun_fact: "40 ÷ 5 = 8 days." },
          { q: "Client expects photos in 14 days. Days to spare?",
            options: %w[4 5 6 7], answer: 2, fun_fact: "14 − 8 = 6 days." },
          { q: "You charge $2000 for the wedding. After the $120 battery cost, profit?",
            options: %w[$1850 $1870 $1880 $1900], answer: 2, fun_fact: "$2000 − $120 = $1880." }
        ] },

      # ── COOKING ─────────────────────────────────────────────────────────
      { tag: "cooking", difficulty: "medium",
        intro: "Mom is hosting a family dinner for 12 and scaling up a recipe meant for 4.",
        steps: [
          { q: "Recipe serves 4. She needs to feed 12. What's the multiplier?",
            options: %w[2 3 4 5], answer: 1, fun_fact: "12 ÷ 4 = 3× the recipe." },
          { q: "Recipe needs 2 cups of flour. Scaled to 12 servings, cups of flour?",
            options: %w[4 5 6 8], answer: 2, fun_fact: "2 × 3 = 6 cups." },
          { q: "Recipe needs 4 eggs. Scaled?",
            options: %w[8 10 12 14], answer: 2, fun_fact: "4 × 3 = 12 eggs." },
          { q: "Recipe needs 1 cup sugar. Scaled (cups)?",
            options: %w[2 3 4 5], answer: 1, fun_fact: "1 × 3 = 3 cups." },
          { q: "Recipe needs 8 oz of cheese. Scaled (oz)?",
            options: %w[16 20 24 28], answer: 2, fun_fact: "8 × 3 = 24 oz." },
          { q: "Cheese comes in 8-oz blocks. Blocks needed?",
            options: %w[2 3 4 5], answer: 1, fun_fact: "24 ÷ 8 = 3 blocks." },
          { q: "Each block costs $5. Cheese cost?",
            options: %w[$10 $12 $15 $18], answer: 2, fun_fact: "3 × $5 = $15." },
          { q: "Eggs come by the dozen. How many dozens for 12 eggs?",
            options: %w[1 2 3 4], answer: 0, fun_fact: "12 ÷ 12 = 1 dozen." },
          { q: "Recipe takes 45 min to bake. The big batch fills 2 trays baked one after the other. Total bake time (min)?",
            options: %w[60 75 90 105], answer: 2, fun_fact: "2 × 45 = 90 minutes." },
          { q: "With 15 min of prep before baking, total kitchen time (min)?",
            options: %w[90 100 105 120], answer: 2, fun_fact: "15 + 90 = 105 minutes." }
        ] },

      # ── GARDENING ───────────────────────────────────────────────────────
      { tag: "gardening", difficulty: "easy",
        intro: "Grandma plants a vegetable garden with rows of tomatoes, cucumbers, and lettuce.",
        steps: [
          { q: "The garden has 6 rows. Each row holds 8 plants. Total plants?",
            options: %w[40 44 48 56], answer: 2, fun_fact: "6 × 8 = 48 plants." },
          { q: "Half the rows are tomatoes. How many tomato rows?",
            options: %w[2 3 4 5], answer: 1, fun_fact: "6 ÷ 2 = 3 rows." },
          { q: "Tomato plants total (3 rows × 8 plants)?",
            options: %w[18 21 24 27], answer: 2, fun_fact: "3 × 8 = 24 tomato plants." },
          { q: "2 rows are cucumbers. Cucumber plants?",
            options: %w[10 12 14 16], answer: 3, fun_fact: "2 × 8 = 16 cucumber plants." },
          { q: "The last row is lettuce (8 plants). Combined plants (tomatoes + cucumbers + lettuce)?",
            options: %w[42 44 46 48], answer: 3, fun_fact: "24 + 16 + 8 = 48 — matches the total." },
          { q: "Each tomato plant yields 10 tomatoes. Total tomato harvest?",
            options: %w[200 220 240 260], answer: 2, fun_fact: "24 × 10 = 240 tomatoes." },
          { q: "Each cucumber plant yields 5 cucumbers. Total cucumber harvest?",
            options: %w[60 70 80 90], answer: 2, fun_fact: "16 × 5 = 80 cucumbers." },
          { q: "Combined harvest (tomatoes + cucumbers + 8 heads of lettuce)?",
            options: %w[308 318 328 338], answer: 2, fun_fact: "240 + 80 + 8 = 328 vegetables." },
          { q: "Grandma sells tomatoes at $1 each. Tomato revenue?",
            options: %w[$200 $220 $240 $260], answer: 2, fun_fact: "240 × $1 = $240." },
          { q: "Cucumbers sell at $2 each. Total revenue (tomatoes + cucumbers)?",
            options: %w[$360 $380 $400 $420], answer: 2, fun_fact: "$240 + $160 = $400." }
        ] }
    ]

    inserted = updated = 0
    chains.each do |chain|
      tag = chain[:tag] || "math"
      prev = nil
      chain[:steps].each_with_index do |step, idx|
        attrs = {
          tag: tag,
          question: step[:q],
          options: step[:options],
          answer_index: step[:answer],
          fun_fact: step[:fun_fact],
          difficulty: chain[:difficulty],
          source: "seed",
          parent_id: prev&.id,
          chain_intro: (idx.zero? ? chain[:intro] : nil)
        }
        rec = TriviaQuestion.find_or_initialize_by(question: step[:q], tag: tag, trip_id: nil)
        if rec.new_record?
          rec.assign_attributes(attrs)
          rec.save!
          inserted += 1
        else
          rec.update!(attrs)
          updated += 1
        end
        prev = rec
      end
    end

    puts "trivia:seed_chains → #{inserted} inserted, #{updated} updated."
    puts "  Chains by tag: #{chains.group_by { |c| c[:tag] || 'math' }.transform_values(&:size)}"
    %w[math science history].each do |t|
      diff = TriviaQuestion.where(tag: t).where.not(difficulty: nil).group(:difficulty).count
      puts "  #{t.ljust(8)} difficulty: #{diff}"
    end
  end

  # Procedurally generates and seeds a bulk pool of math word-problem chains
  # via MathChainGenerator. Defaults to 100 chains × 10 steps = 1000 questions.
  # Idempotent: each step is upserted by (tag: "math", question: "...", trip_id: nil),
  # and the generator is deterministic — re-running yields the same questions.
  desc "Seed procedurally generated math chains (default: 100 chains, 1000 questions)."
  task :seed_math_bulk, [ :count ] => :environment do |_t, args|
    count = (args[:count] || 100).to_i
    chains = MathChainGenerator.generate(target_count: count)

    inserted = updated = 0
    chains.each do |chain|
      tag = chain[:tag] || "math"
      prev = nil
      chain[:steps].each_with_index do |step, idx|
        # Scope the lookup by chain identity so duplicate step-text across
        # different chains doesn't collapse into one row:
        # - root step (idx 0) is identified by its unique chain_intro
        # - subsequent steps are identified by their parent_id
        finder = { tag: tag, trip_id: nil, question: step[:q] }
        if idx.zero?
          finder[:chain_intro] = chain[:intro]
        else
          finder[:parent_id] = prev.id
        end
        rec = TriviaQuestion.find_or_initialize_by(finder)
        attrs = {
          options: step[:options],
          answer_index: step[:answer],
          fun_fact: step[:fun_fact],
          difficulty: chain[:difficulty],
          source: "seed",
          parent_id: prev&.id,
          chain_intro: (idx.zero? ? chain[:intro] : nil)
        }
        if rec.new_record?
          rec.assign_attributes(attrs)
          rec.save!
          inserted += 1
        else
          rec.update!(attrs)
          updated += 1
        end
        prev = rec
      end
    end

    total_steps = chains.sum { |c| c[:steps].size }
    puts "trivia:seed_math_bulk → #{chains.size} chains, #{total_steps} questions (#{inserted} inserted, #{updated} updated)."
    puts "  math pool now: #{TriviaQuestion.kept.where(tag: 'math', trip_id: nil).count} total, #{TriviaQuestion.kept.chain_roots.where(tag: 'math', trip_id: nil).count} chain roots."
  end

  # Procedurally generates fact-quiz chains for all 21 non-math, non-riddle
  # tags via TopicTriviaGenerator, then seeds them. Each tag gets `count`
  # questions by combining its FACTS pool into chains. Idempotent: chains
  # are keyed by (chain_intro, question) for the root and (parent_id, question)
  # for follow-ups.
  desc "Bulk-seed procedural fact-quiz chains for all non-math tags (default 1000 per tag)."
  task :seed_factquiz_bulk, [ :count ] => :environment do |_t, args|
    count = (args[:count] || 1000).to_i
    grand_inserted = grand_updated = 0
    per_tag = {}

    TopicTriviaGenerator.categories.each do |tag|
      inserted = updated = 0
      chains = TopicTriviaGenerator.generate(tag, target_count: count)
      chains.each do |chain|
        prev = nil
        chain[:steps].each_with_index do |step, idx|
          finder = { tag: tag, trip_id: nil, question: step[:q] }
          if idx.zero?
            finder[:chain_intro] = chain[:intro]
          else
            finder[:parent_id] = prev.id
          end
          rec = TriviaQuestion.find_or_initialize_by(finder)
          attrs = {
            options: step[:options],
            answer_index: step[:answer],
            fun_fact: step[:fun_fact],
            difficulty: chain[:difficulty],
            source: "seed",
            parent_id: prev&.id,
            chain_intro: (idx.zero? ? chain[:intro] : nil)
          }
          if rec.new_record?
            rec.assign_attributes(attrs)
            rec.save!
            inserted += 1
          else
            rec.update!(attrs)
            updated += 1
          end
          prev = rec
        end
      end
      grand_inserted += inserted
      grand_updated += updated
      per_tag[tag] = TriviaQuestion.kept.where(tag: tag).count
    end

    puts "trivia:seed_factquiz_bulk → #{grand_inserted} inserted, #{grand_updated} updated."
    puts "  Tag totals after seed:"
    per_tag.sort.each { |tag, total| puts "    #{tag.ljust(14)} #{total}" }
  end

  # Calls the riddle_pack.v1 AI prompt repeatedly via Claude CLI until at
  # least `count` riddle rows exist (the prompt asks for 10 per call).
  # Idempotent: existing rows are skipped by (tag: "riddles", question:).
  # Run in background — each AI call takes ~10-30s.
  # Themes vary the prompt across batches so each call produces a different
  # set of 10 riddles — and so the Ai::Caller 30-day cache keys by rendered
  # prompt give each batch its own cache entry instead of collapsing into one.
  RIDDLE_BATCH_THEMES = [
    "everyday objects", "kitchen and food", "school and learning", "weather and seasons",
    "animals you might meet on a road trip", "vehicles and travel", "tools and gadgets",
    "musical instruments", "clothes and shoes", "sports gear", "garden and plants",
    "books and writing", "letters of the alphabet and numbers", "buildings and places",
    "shadows, mirrors, and reflections", "time, clocks, and calendars",
    "natural wonders (mountains, rivers, caves)", "art and colors",
    "communication (phones, mail, signs)", "money, coins, and shopping",
    "puzzles and games", "the human body", "the night sky and stars",
    "doors, keys, locks, and windows", "boats, ships, and the sea",
    "winter and snow", "summer and beaches", "fall leaves and autumn",
    "spring flowers and rain", "trees and forests", "deserts and dunes",
    "farms and barns", "birds and feathers", "fish and underwater life",
    "bugs and insects", "machines that move", "wordplay and double meanings",
    "what has X but no Y patterns", "things that come in pairs", "things you wear",
    "things in a classroom"
  ].freeze

  desc "AI-generate riddles in batches until pool has at least N (default 1000)."
  task :seed_riddles_bulk, [ :target ] => :environment do |_t, args|
    require "set"
    target = (args[:target] || 1000).to_i
    starting = TriviaQuestion.kept.where(tag: "riddles", trip_id: nil).count
    puts "Starting riddles in pool: #{starting} → target: #{target}"

    normalize = ->(text) { text.to_s.downcase.gsub(/[^a-z0-9]+/, " ").strip }
    # Build a Set of normalized existing questions up front so cross-batch
    # dedup is O(1). Updated as we insert.
    seen_normalized = Set.new(
      TriviaQuestion.where(tag: "riddles", trip_id: nil).pluck(:question).map(&normalize)
    )

    batches_run = inserted_total = dup_skipped = 0
    while TriviaQuestion.kept.where(tag: "riddles", trip_id: nil).count < target
      theme = "#{RIDDLE_BATCH_THEMES[batches_run % RIDDLE_BATCH_THEMES.size]} (batch ##{batches_run + 1} · seen #{seen_normalized.size})"
      batches_run += 1
      # cache: false — every call must hit Claude live so the pool actually
      # grows on re-runs. The 30-day Ai::Caller cache is meant for stable
      # lookups (highlight_detail, destination_brief), not bulk generation.
      result = Ai::Caller.call(
        slug: "riddle_pack.v1",
        variables: { count: 10, theme: theme },
        cache: false
      )
      if result.error || result.text.blank?
        puts "  batch #{batches_run} failed: #{result.error.to_s.presence || 'empty'}"
        break
      end
      payload = result.json
      payload = payload["riddles"] if payload.is_a?(Hash) && payload["riddles"].is_a?(Array)
      unless payload.is_a?(Array)
        puts "  batch #{batches_run}: bad JSON shape, stopping."
        break
      end
      batch_in = batch_dup = 0
      payload.each do |row|
        next unless row.is_a?(Hash)
        q = row["question"].to_s.strip
        opts = Array(row["options"]).map { |o| o.to_s.strip }.reject(&:blank?)
        idx = row["answer_index"].to_i
        fact = row["fun_fact"].to_s.strip
        next if q.blank? || opts.size < 2 || idx.negative? || idx >= opts.size

        norm = normalize.call(q)
        if seen_normalized.include?(norm)
          batch_dup += 1
          next
        end

        # Belt-and-suspenders: also check DB with exact text in case another
        # process inserted concurrently, then add to in-memory set on save.
        rec = TriviaQuestion.find_or_initialize_by(tag: "riddles", question: q, trip_id: nil)
        if rec.persisted?
          batch_dup += 1
          seen_normalized << norm
          next
        end
        rec.assign_attributes(options: opts, answer_index: idx, fun_fact: fact, source: "ai")
        if rec.save
          batch_in += 1
          seen_normalized << norm
        end
      end
      inserted_total += batch_in
      dup_skipped += batch_dup
      puts "  batch #{batches_run}: +#{batch_in} new, #{batch_dup} dup (pool now #{TriviaQuestion.kept.where(tag: 'riddles', trip_id: nil).count})"
      break if batches_run > 500
    end

    puts "trivia:seed_riddles_bulk → ran #{batches_run} batches, inserted #{inserted_total} riddles, skipped #{dup_skipped} dups."
    puts "  Riddles pool now: #{TriviaQuestion.kept.where(tag: 'riddles', trip_id: nil).count}."
  end

  # Seeds the hand-curated topic packs from TriviaTopicPacks::PACKS — one or
  # more multi-step chains per interest tag. Idempotent: each chain is keyed
  # by (chain_intro, question) for the root and (parent_id, question) for
  # follow-ups, matching the bulk math seeder's strategy.
  desc "Seed hand-curated topic-pack chains for all non-math tags."
  task seed_topic_packs: :environment do
    inserted = updated = 0
    tag_changes = Hash.new { |h, k| h[k] = { inserted: 0, updated: 0 } }

    TriviaTopicPacks::PACKS.each do |tag, packs|
      packs.each do |chain|
        prev = nil
        chain[:steps].each_with_index do |step, idx|
          finder = { tag: tag, trip_id: nil, question: step[:q] }
          if idx.zero?
            finder[:chain_intro] = chain[:intro]
          else
            finder[:parent_id] = prev.id
          end
          rec = TriviaQuestion.find_or_initialize_by(finder)
          attrs = {
            options: step[:options],
            answer_index: step[:answer],
            fun_fact: step[:fun_fact],
            difficulty: chain[:difficulty],
            source: "seed",
            parent_id: prev&.id,
            chain_intro: (idx.zero? ? chain[:intro] : nil)
          }
          if rec.new_record?
            rec.assign_attributes(attrs)
            rec.save!
            inserted += 1
            tag_changes[tag][:inserted] += 1
          else
            rec.update!(attrs)
            updated += 1
            tag_changes[tag][:updated] += 1
          end
          prev = rec
        end
      end
    end

    puts "trivia:seed_topic_packs → #{inserted} inserted, #{updated} updated across #{tag_changes.size} tags."
    tag_changes.sort.each do |tag, h|
      total = TriviaQuestion.kept.where(tag: tag).count
      puts "  #{tag.ljust(14)} +#{h[:inserted]} new (#{h[:updated]} updated) → #{total} total"
    end
  end

  # Riddles share the trivia_questions table — they're rows with tag="riddles".
  # The picker (TriviaPool.pick_riddle_for) bypasses the interest-tag filter
  # so riddles don't have to compete with topic trivia for selection.
  desc "Seed classic kid-friendly riddles (idempotent)."
  task seed_riddles: :environment do
    riddles = [
      { q: "I have hands but cannot clap. What am I?",
        options: [ "A statue", "A clock", "A glove", "A robot" ], answer: 1,
        fun_fact: "Clock hands sweep, but they never meet to clap." },
      { q: "The more you take, the more you leave behind. What are they?",
        options: %w[Memories Footsteps Breaths Shadows], answer: 1,
        fun_fact: "Each step you take leaves another footprint behind you." },
      { q: "I'm full of holes but still hold water. What am I?",
        options: [ "A net", "A sponge", "A sieve", "A cracked bucket" ], answer: 1,
        fun_fact: "Sponges trap water in tiny pores — that's how sailors used them at sea." },
      { q: "I have a face and two hands but no arms or legs. What am I?",
        options: [ "A mirror", "A clock", "A coin", "A doll" ], answer: 1,
        fun_fact: "An analog clock has an hour hand and a minute hand." },
      { q: "What has to be broken before you can use it?",
        options: [ "A promise", "An egg", "A window", "A rule" ], answer: 1,
        fun_fact: "Crack the shell and you can scramble, fry, or bake what's inside." },
      { q: "I'm tall when I'm young and short when I'm old. What am I?",
        options: [ "A tree", "A candle", "A pencil", "A person" ], answer: 1,
        fun_fact: "A burning candle shrinks as the wax melts away." },
      { q: "What gets wetter the more it dries?",
        options: [ "A sponge", "A towel", "A raincoat", "A shirt" ], answer: 1,
        fun_fact: "Towels soak up water — drying you off makes them wetter." },
      { q: "I have keys but no locks. I have space but no room. What am I?",
        options: [ "A piano", "A keyboard", "A car", "A house" ], answer: 1,
        fun_fact: "Computer keyboards have a Space key but no actual room." },
      { q: "What has many teeth but cannot bite?",
        options: [ "A shark", "A comb", "A saw", "A zipper" ], answer: 1,
        fun_fact: "Combs have teeth — that's what they're literally called." },
      { q: "I go up but never come down. What am I?",
        options: [ "A balloon", "Your age", "A rocket", "The sun" ], answer: 1,
        fun_fact: "Every birthday your age goes up by one — and stays there." },
      { q: "What has a thumb and four fingers but isn't alive?",
        options: [ "A statue", "A glove", "A puppet", "A mannequin" ], answer: 1,
        fun_fact: "Mittens just have a thumb and one big pocket — gloves have all five." },
      { q: "I'm light as a feather, yet the strongest person can't hold me for long. What am I?",
        options: [ "Breath", "A secret", "Time", "Wind" ], answer: 0,
        fun_fact: "Try holding your breath — most people max out around a minute." },
      { q: "What has one eye but cannot see?",
        options: [ "A pirate", "A needle", "A potato", "A storm" ], answer: 1,
        fun_fact: "The hole at the top of a sewing needle is called its eye." },
      { q: "What kind of room has no doors or windows?",
        options: [ "A basement", "A mushroom", "A bathroom", "A classroom" ], answer: 1,
        fun_fact: "A mushroom is a fungus — \"room\" is just hiding in the word." },
      { q: "What gets bigger the more you take away from it?",
        options: [ "A balloon", "A hole", "A shadow", "A puddle" ], answer: 1,
        fun_fact: "Dig more dirt out of a hole and the hole grows." },
      { q: "I have cities but no houses, mountains but no trees, and water but no fish. What am I?",
        options: [ "A planet", "A map", "A dream", "A snow globe" ], answer: 1,
        fun_fact: "Maps show all those things as symbols, not the real thing." },
      { q: "What has a head and a tail but no body?",
        options: [ "A snake", "A coin", "A comet", "A kite" ], answer: 1,
        fun_fact: "Coins have a \"heads\" side and a \"tails\" side." },
      { q: "I follow you all day but disappear at night. What am I?",
        options: [ "Your shadow", "The wind", "Your phone", "A cloud" ], answer: 0,
        fun_fact: "No light, no shadow — that's why shadows vanish in the dark." },
      { q: "What can travel around the world while staying in the same corner?",
        options: [ "A balloon", "A stamp", "A turtle", "A whisper" ], answer: 1,
        fun_fact: "Stamps ride in the corner of an envelope wherever it goes." },
      { q: "I have a neck but no head, and a body but no arms. What am I?",
        options: [ "A guitar", "A bottle", "A shirt", "A lamp" ], answer: 1,
        fun_fact: "Bottles have a neck, shoulders, and a body — like a tiny person." },
      { q: "The more of me you have, the less you see. What am I?",
        options: [ "Fog", "Darkness", "Rain", "Smoke" ], answer: 1,
        fun_fact: "Pure darkness is the absence of light — more dark = less seen." },
      { q: "I have branches but no fruit, trunk, or leaves. What am I?",
        options: [ "A river", "A bank", "A candelabra", "A family tree" ], answer: 1,
        fun_fact: "Banks have branches — buildings, not trees." },
      { q: "What can you catch but not throw?",
        options: [ "A ball", "A cold", "A wave", "A fly" ], answer: 1,
        fun_fact: "You can catch a cold from someone, but you can't throw it back." },
      { q: "I have lakes but no water, mountains but no stones, and roads but no cars. What am I?",
        options: [ "A painting", "A map", "A globe", "A puzzle" ], answer: 1,
        fun_fact: "Same idea as the cities riddle — maps represent the world without being it." },
      { q: "What goes up and down but doesn't move?",
        options: [ "An elevator", "A staircase", "A wave", "A balloon" ], answer: 1,
        fun_fact: "Stairs reach both up and down floors but stay perfectly still." },
      { q: "I have a ring but no finger. What am I?",
        options: [ "A bell", "A phone", "A planet", "A donut" ], answer: 1,
        fun_fact: "Phones ring when someone calls — no finger required." },
      { q: "What has 13 hearts but no other organs?",
        options: [ "A poker hand", "A deck of cards", "A valentine", "An octopus" ], answer: 1,
        fun_fact: "A standard deck has 13 cards in the hearts suit." },
      { q: "Forward I am heavy, but backward I am not. What am I?",
        options: [ "Stone", "Ton", "Pound", "Truck" ], answer: 1,
        fun_fact: "\"Ton\" forward is heavy. Spelled backward it's \"not\"." },
      { q: "What kind of band never plays music?",
        options: [ "A marching band", "A rubber band", "A hair band", "A garage band" ], answer: 1,
        fun_fact: "Rubber bands stretch and snap — no instruments needed." },
      { q: "I have wheels and flies, but I'm not an aircraft. What am I?",
        options: [ "A skateboard", "A garbage truck", "A bicycle", "A train" ], answer: 1,
        fun_fact: "Garbage trucks have wheels — and, unfortunately, flies." }
    ]

    inserted = updated = 0
    riddles.each do |r|
      rec = TriviaQuestion.find_or_initialize_by(tag: "riddles", question: r[:q], trip_id: nil)
      attrs = {
        options: Array(r[:options]),
        answer_index: r[:answer],
        fun_fact: r[:fun_fact],
        source: "seed"
      }
      if rec.new_record?
        rec.assign_attributes(attrs)
        rec.save!
        inserted += 1
      elsif rec.attributes.slice("options", "answer_index", "fun_fact").symbolize_keys != {
        options: attrs[:options], answer_index: attrs[:answer_index], fun_fact: attrs[:fun_fact]
      }
        rec.update!(attrs)
        updated += 1
      end
    end

    puts "trivia:seed_riddles → #{inserted} inserted, #{updated} updated, #{TriviaQuestion.kept.where(tag: "riddles", trip_id: nil).count} total riddles."
  end
end
