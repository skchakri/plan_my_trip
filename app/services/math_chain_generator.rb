# Procedurally generates math word-problem chains for the Drive Co-Pilot trivia
# pool. Each call to {.generate} returns an array of chain hashes shaped like
# the seed_chains rake task expects:
#
#   { difficulty:, intro:, steps: [{ q:, options:, answer:, fun_fact: }, ...] }
#
# Themes are deterministic functions of an integer seed — re-running the
# generator with the same parameters produces the same questions, which keeps
# `find_or_initialize_by(question: ..., tag: "math")` idempotent across reseeds.
class MathChainGenerator
  NAMES_KID  = %w[Mia Liam Aria Noah Zoe Eli Maya Owen Ivy Kai Ava Leo Riya Asha Theo Nora Jonah Cora Sam Ezra].freeze
  NAMES_ADULT = %w[Mom Dad Grandma Grandpa Auntie Uncle Coach Mrs.Patel Mr.Singh Miss.Lee].freeze

  # Used to anchor each chain's intro to a unique-per-variant phrase so two
  # chains from the same theme don't collapse into the same DB row when their
  # randomized numbers happen to match. 32 places × 8 descriptors = 256
  # unique combinations; a numeric suffix extends past that.
  CTX_PLACES = %w[
    Maplewood Pinegrove Birchcreek Cedarhill Willowpark Oakridge Riverside Hillside
    Lakeview Sunset Eastfield Westwood Greenbrook Foxglove Stonebridge Lakeshore
    Elmwood Brookside Fairview Glenwood Highland Ironwood Junipercrest Kestrel
    Lavender Meadowbrook Northgate Oakvale Pinepoint Quailridge Redrock Springfield
  ].freeze

  CTX_DESCRIPTORS = %w[Park Hills Heights Springs Meadows Grove Court Crossing].freeze

  def self.ctx_for(variant_index)
    base_size = CTX_PLACES.size * CTX_DESCRIPTORS.size
    place = CTX_PLACES[variant_index % CTX_PLACES.size]
    desc  = CTX_DESCRIPTORS[(variant_index / CTX_PLACES.size) % CTX_DESCRIPTORS.size]
    suffix = variant_index >= base_size ? " #{variant_index / base_size + 1}" : ""
    "#{place} #{desc}#{suffix}"
  end

  # Each theme is a Proc(rng, variant_index) returning a chain hash.
  # 10 themes × 10 variants each = 100 chains × 10 steps = 1000 questions.
  THEMES = []

  # --- helper: build the standard {options:, answer:} multi-choice pair ---
  # For numeric answers, distractors are nearby plausible offsets.
  def self.numeric_options(answer, rng, currency: false)
    spread = [ -3, -2, -1, 1, 2, 3 ]
    distractors = spread.sample(3, random: rng).map { |o| answer + o }
    pool = ([ answer ] + distractors).map { |v| [ v, 0 ].max }.uniq
    # Always keep the actual answer in the pool — clamping may have moved it.
    pool << answer unless pool.include?(answer)
    while pool.size < 4
      pool << (pool.max + rng.rand(1..4))
    end
    pool = pool.uniq.first(4).shuffle(random: rng)
    { options: pool.map { |n| currency ? "$#{n}" : n.to_s }, answer: pool.index(answer) }
  end

  def self.step(question:, answer:, fun_fact:, rng:, currency: false)
    o = numeric_options(answer, rng, currency: currency)
    { q: question, options: o[:options], answer: o[:answer], fun_fact: fun_fact }
  end

  # ============================================================
  # THEME 1 — Sports gear budget
  # ============================================================
  THEMES << ->(rng, _vi) {
    boys  = rng.rand(8..16)
    girls = rng.rand(6..14)
    total = boys + girls
    soccer_b = [ boys / 2, 4 ].max
    soccer_g = [ girls / 2, 3 ].max
    soccer_total = soccer_b + soccer_g
    bb_b = boys - soccer_b
    bb_g = 1
    bb_total = bb_b + bb_g
    glove = [ 15, 20, 25, 30 ].sample(random: rng)
    glove_cost = bb_total * glove
    budget = ((glove_cost / 25.0).ceil * 25) + [ 25, 50, 75 ].sample(random: rng)
    left = budget - glove_cost
    ball = [ 5, 10 ].sample(random: rng)
    balls_buyable = left / ball
    target_balls = soccer_total * 2
    own = [ rng.rand(3..6), target_balls - 1 ].min
    needed = target_balls - own
    ball_cost = needed * ball
    full_budget = budget + ((ball_cost / 50.0).ceil * 50) + [ 25, 50 ].sample(random: rng)
    remaining = full_budget - glove_cost - ball_cost
    intro = "A class of #{total} students splits into teams and needs equipment."
    steps = [
      step(question: "There are #{total} students in a class. #{boys} are boys and the rest are girls. How many girls are in the class?",
           answer: girls, fun_fact: "#{total} − #{boys} = #{girls}.", rng: rng),
      step(question: "#{soccer_b} of the boys are on the soccer team, and #{soccer_g} of the girls are too. How many students are on the soccer team in total?",
           answer: soccer_total, fun_fact: "#{soccer_b} + #{soccer_g} = #{soccer_total}.", rng: rng),
      step(question: "The baseball team has the rest of the boys plus #{bb_g} of the girls. How many players are on the baseball team?",
           answer: bb_total, fun_fact: "#{boys} − #{soccer_b} = #{bb_b} boys left, plus #{bb_g} girl, makes #{bb_total}.", rng: rng),
      step(question: "Each glove costs $#{glove}. What does it cost to give all #{bb_total} baseball players a glove?",
           answer: glove_cost, fun_fact: "#{bb_total} × $#{glove} = $#{glove_cost}.", rng: rng, currency: true),
      step(question: "The team budget is $#{budget}. After buying gloves, how much is left?",
           answer: left, fun_fact: "$#{budget} − $#{glove_cost} = $#{left}.", rng: rng, currency: true),
      step(question: "Each ball costs $#{ball}. With $#{left} left, how many balls can they buy?",
           answer: balls_buyable, fun_fact: "$#{left} ÷ $#{ball} = #{balls_buyable} balls.", rng: rng),
      step(question: "The coach wants 2 balls for every soccer player. With #{soccer_total} players, how many balls are needed?",
           answer: target_balls, fun_fact: "#{soccer_total} × 2 = #{target_balls} balls.", rng: rng),
      step(question: "They already own #{own} balls. How many more balls do they need to reach #{target_balls}?",
           answer: needed, fun_fact: "#{target_balls} − #{own} = #{needed}.", rng: rng),
      step(question: "Each ball costs $#{ball}. What's the cost of buying #{needed} more balls?",
           answer: ball_cost, fun_fact: "#{needed} × $#{ball} = $#{ball_cost}.", rng: rng, currency: true),
      step(question: "The full sports-year budget was $#{full_budget}. After gloves and balls, how much is left?",
           answer: remaining, fun_fact: "$#{full_budget} − ($#{glove_cost} + $#{ball_cost}) = $#{remaining}.", rng: rng, currency: true)
    ]
    { difficulty: "medium", intro: intro, steps: steps }
  }

  # ============================================================
  # THEME 2 — Pizza party
  # ============================================================
  THEMES << ->(rng, _vi) {
    pizzas = rng.rand(2..5)
    slices = [ 6, 8, 10 ].sample(random: rng)
    total_slices = pizzas * slices
    dad_eats = rng.rand(2..4)
    kids_eat = rng.rand(6..(total_slices - dad_eats - 2))
    eaten = dad_eats + kids_eat
    left = total_slices - eaten
    sharers = [ 2, 3, 4 ].select { |n| left % n == 0 }.last || 2
    per_share = left / sharers
    cost_each = [ 10, 12, 15 ].sample(random: rng)
    total_cost = pizzas * cost_each
    pay = ((total_cost / 10.0).ceil * 10) + [ 0, 5, 10 ].sample(random: rng)
    change = pay - total_cost
    tip = [ 2, 3, 5 ].sample(random: rng)
    spent = total_cost + tip
    splitters = [ 2, 3 ].sample(random: rng)
    per_adult = ((spent / splitters.to_f).round)
    half = total_slices / 2
    next_people = 8
    needed_slices = next_people * 2
    intro = "#{NAMES_ADULT.sample(random: rng)} orders pizzas for the family."
    steps = [
      step(question: "#{NAMES_ADULT.sample(random: rng)} orders #{pizzas} pizzas. Each pizza has #{slices} slices. How many slices in total?",
           answer: total_slices, fun_fact: "#{pizzas} × #{slices} = #{total_slices}.", rng: rng),
      step(question: "Dad eats #{dad_eats} slices and the kids eat #{kids_eat} between them. How many slices have been eaten?",
           answer: eaten, fun_fact: "#{dad_eats} + #{kids_eat} = #{eaten}.", rng: rng),
      step(question: "Out of the #{total_slices} slices, how many are left after #{eaten} were eaten?",
           answer: left, fun_fact: "#{total_slices} − #{eaten} = #{left}.", rng: rng),
      step(question: "#{sharers} adults split the #{left} leftover slices equally. How many slices does each get?",
           answer: per_share, fun_fact: "#{left} ÷ #{sharers} = #{per_share}.", rng: rng),
      step(question: "Each pizza cost $#{cost_each}. What's the total cost for #{pizzas} pizzas?",
           answer: total_cost, fun_fact: "#{pizzas} × $#{cost_each} = $#{total_cost}.", rng: rng, currency: true),
      step(question: "Mom pays with $#{pay}. How much change does she get back?",
           answer: change, fun_fact: "$#{pay} − $#{total_cost} = $#{change}.", rng: rng, currency: true),
      step(question: "She leaves a $#{tip} tip. What did she spend in total?",
           answer: spent, fun_fact: "$#{total_cost} + $#{tip} = $#{spent}.", rng: rng, currency: true),
      step(question: "#{splitters} adults split the $#{spent} evenly. About how much does each adult pay?",
           answer: per_adult, fun_fact: "$#{spent} ÷ #{splitters} ≈ $#{per_adult}.", rng: rng, currency: true),
      step(question: "What is half of the #{total_slices} slices?",
           answer: half, fun_fact: "#{total_slices} ÷ 2 = #{half}.", rng: rng),
      step(question: "Next time, #{next_people} people come over. If each eats 2 slices, how many slices total?",
           answer: needed_slices, fun_fact: "#{next_people} × 2 = #{needed_slices}.", rng: rng)
    ]
    { difficulty: "easy", intro: intro, steps: steps }
  }

  # ============================================================
  # THEME 3 — Lemonade stand
  # ============================================================
  THEMES << ->(rng, _vi) {
    name = NAMES_KID.sample(random: rng)
    lemons = [ 30, 36, 42, 48 ].sample(random: rng)
    per_pitcher = [ 5, 6 ].sample(random: rng)
    pitchers = lemons / per_pitcher
    cups_per = [ 6, 8 ].sample(random: rng)
    day1_cups = pitchers * cups_per
    price = [ 1, 2 ].sample(random: rng)
    day1_sales = day1_cups * price
    sugar_cost = [ 4, 5, 6 ].sample(random: rng)
    cups_cost = [ 3, 4, 5 ].sample(random: rng)
    total_cost = sugar_cost + cups_cost
    profit = day1_sales - total_cost
    day2_extra = [ 12, 16, 20 ].sample(random: rng)
    day2_cups = day1_cups + day2_extra
    day2_sales = day2_cups * price
    two_day_total = day1_sales + day2_sales
    save_share = two_day_total / 2
    intro = "#{name} opens a lemonade stand and tracks sales for two days."
    steps = [
      step(question: "#{name} has #{lemons} lemons. The recipe uses #{per_pitcher} lemons per pitcher. How many pitchers can she make?",
           answer: pitchers, fun_fact: "#{lemons} ÷ #{per_pitcher} = #{pitchers}.", rng: rng),
      step(question: "Each pitcher fills #{cups_per} cups. How many cups can she sell on day 1?",
           answer: day1_cups, fun_fact: "#{pitchers} × #{cups_per} = #{day1_cups}.", rng: rng),
      step(question: "She sells each cup for $#{price}. Day-1 sales if all #{day1_cups} cups sell?",
           answer: day1_sales, fun_fact: "#{day1_cups} × $#{price} = $#{day1_sales}.", rng: rng, currency: true),
      step(question: "Sugar cost $#{sugar_cost} and cups cost $#{cups_cost}. Total supply cost?",
           answer: total_cost, fun_fact: "$#{sugar_cost} + $#{cups_cost} = $#{total_cost}.", rng: rng, currency: true),
      step(question: "What is her day-1 profit (sales − cost)?",
           answer: profit, fun_fact: "$#{day1_sales} − $#{total_cost} = $#{profit}.", rng: rng, currency: true),
      step(question: "Day 2 she sells #{day2_extra} more cups than day 1. How many cups on day 2?",
           answer: day2_cups, fun_fact: "#{day1_cups} + #{day2_extra} = #{day2_cups}.", rng: rng),
      step(question: "Day-2 sales if every cup sells at $#{price}?",
           answer: day2_sales, fun_fact: "#{day2_cups} × $#{price} = $#{day2_sales}.", rng: rng, currency: true),
      step(question: "Two-day total sales?",
           answer: two_day_total, fun_fact: "$#{day1_sales} + $#{day2_sales} = $#{two_day_total}.", rng: rng, currency: true),
      step(question: "#{name} saves half her two-day total. How much does she save?",
           answer: save_share, fun_fact: "$#{two_day_total} ÷ 2 = $#{save_share}.", rng: rng, currency: true),
      step(question: "If she keeps the other half as spending money, how much can she spend?",
           answer: two_day_total - save_share, fun_fact: "$#{two_day_total} − $#{save_share} = $#{two_day_total - save_share}.", rng: rng, currency: true)
    ]
    { difficulty: "medium", intro: intro, steps: steps }
  }

  # ============================================================
  # THEME 4 — Field trip / buses
  # ============================================================
  THEMES << ->(rng, _vi) {
    students = [ 60, 90, 120, 150 ].sample(random: rng)
    per_bus = [ 30, 40, 50 ].sample(random: rng)
    buses = (students.to_f / per_bus).ceil
    chaperones = [ 1, 2 ].sample(random: rng)
    adults = buses * (1 + chaperones)
    people = students + adults
    rent = [ 150, 200, 250 ].sample(random: rng)
    rent_cost = buses * rent
    fuel = [ 40, 50, 60 ].sample(random: rng)
    fuel_cost = buses * fuel
    bus_total = rent_cost + fuel_cost
    raised = ((bus_total / 100.0).ceil * 100) + [ 100, 200, 300 ].sample(random: rng)
    left = raised - bus_total
    pack_price = [ 4, 5, 6 ].sample(random: rng)
    packs = left / pack_price
    snacks_per = [ 6, 8, 10 ].sample(random: rng)
    snacks_total = packs * snacks_per
    per_student = snacks_total / students
    intro = "A field trip of #{students} students needs buses, chaperones, and snacks."
    steps = [
      step(question: "A field trip needs to seat #{students} students. Each bus seats #{per_bus}. How many buses are needed?",
           answer: buses, fun_fact: "#{students} ÷ #{per_bus} ≈ #{buses} buses (round up).", rng: rng),
      step(question: "Each bus needs 1 driver and #{chaperones} chaperones. Total adults for #{buses} buses?",
           answer: adults, fun_fact: "#{buses} × (1 + #{chaperones}) = #{adults}.", rng: rng),
      step(question: "Students + adults = how many people on the trip?",
           answer: people, fun_fact: "#{students} + #{adults} = #{people}.", rng: rng),
      step(question: "Renting one bus costs $#{rent}. Cost for #{buses} buses?",
           answer: rent_cost, fun_fact: "#{buses} × $#{rent} = $#{rent_cost}.", rng: rng, currency: true),
      step(question: "Fuel is $#{fuel} per bus. Fuel cost for #{buses} buses?",
           answer: fuel_cost, fun_fact: "#{buses} × $#{fuel} = $#{fuel_cost}.", rng: rng, currency: true),
      step(question: "Total bus cost (rental + fuel)?",
           answer: bus_total, fun_fact: "$#{rent_cost} + $#{fuel_cost} = $#{bus_total}.", rng: rng, currency: true),
      step(question: "The school raised $#{raised}. How much is left after buses?",
           answer: left, fun_fact: "$#{raised} − $#{bus_total} = $#{left}.", rng: rng, currency: true),
      step(question: "Snack packs cost $#{pack_price}. With $#{left}, how many packs can they buy?",
           answer: packs, fun_fact: "$#{left} ÷ $#{pack_price} = #{packs} packs.", rng: rng),
      step(question: "Each pack has #{snacks_per} snacks. Total snacks from #{packs} packs?",
           answer: snacks_total, fun_fact: "#{packs} × #{snacks_per} = #{snacks_total}.", rng: rng),
      step(question: "#{snacks_total} snacks split evenly among #{students} students — snacks per student?",
           answer: per_student, fun_fact: "#{snacks_total} ÷ #{students} = #{per_student}.", rng: rng)
    ]
    { difficulty: "medium", intro: intro, steps: steps }
  }

  # ============================================================
  # THEME 5 — Birthday party
  # ============================================================
  THEMES << ->(rng, _vi) {
    host = NAMES_KID.sample(random: rng)
    friends = rng.rand(6..14)
    party = friends + 1
    cupcakes_each = rng.rand(2..3)
    cupcakes = party * cupcakes_each
    boxes = (cupcakes / 6.0).ceil
    box_cost = [ 4, 5, 6 ].sample(random: rng)
    cupcake_cost = boxes * box_cost
    gift_each = [ 5, 8, 10 ].sample(random: rng)
    gift_total = friends * gift_each
    decor = [ 15, 20, 25 ].sample(random: rng)
    total = cupcake_cost + gift_total + decor
    juice_each = [ 1, 2 ].sample(random: rng)
    juice_total = party * juice_each
    # Budget always covers the whole party plus a buffer so subtractions stay positive.
    budget = (((total + juice_total) / 25.0).ceil * 25) + [ 25, 50 ].sample(random: rng)
    left = budget - total
    grand_left = left - juice_total
    intro = "#{host} is throwing a birthday party with #{friends} friends."
    steps = [
      step(question: "#{host} invites #{friends} friends. Including #{host}, how many kids will be there?",
           answer: party, fun_fact: "#{friends} + 1 = #{party}.", rng: rng),
      step(question: "Each kid eats #{cupcakes_each} cupcakes. Total cupcakes needed?",
           answer: cupcakes, fun_fact: "#{party} × #{cupcakes_each} = #{cupcakes}.", rng: rng),
      step(question: "Cupcakes come in boxes of 6. How many boxes are needed for #{cupcakes}?",
           answer: boxes, fun_fact: "#{cupcakes} ÷ 6 (rounded up) = #{boxes} boxes.", rng: rng),
      step(question: "Each box costs $#{box_cost}. Cost for #{boxes} boxes?",
           answer: cupcake_cost, fun_fact: "#{boxes} × $#{box_cost} = $#{cupcake_cost}.", rng: rng, currency: true),
      step(question: "Goodie gifts cost $#{gift_each} each. Total gift cost for #{friends} friends?",
           answer: gift_total, fun_fact: "#{friends} × $#{gift_each} = $#{gift_total}.", rng: rng, currency: true),
      step(question: "Decorations cost $#{decor}. Cupcakes + gifts + decor — total spent?",
           answer: total, fun_fact: "$#{cupcake_cost} + $#{gift_total} + $#{decor} = $#{total}.", rng: rng, currency: true),
      step(question: "Mom budgeted $#{budget}. How much is left after #{host}'s purchases?",
           answer: left, fun_fact: "$#{budget} − $#{total} = $#{left}.", rng: rng, currency: true),
      step(question: "Juice boxes cost $#{juice_each} each. Total juice for #{party} kids?",
           answer: juice_total, fun_fact: "#{party} × $#{juice_each} = $#{juice_total}.", rng: rng, currency: true),
      step(question: "After buying juice, how much of the $#{budget} budget is left?",
           answer: grand_left, fun_fact: "$#{left} − $#{juice_total} = $#{grand_left}.", rng: rng, currency: true),
      step(question: "Half the cupcakes are vanilla. How many vanilla cupcakes?",
           answer: cupcakes / 2, fun_fact: "#{cupcakes} ÷ 2 = #{cupcakes / 2}.", rng: rng)
    ]
    { difficulty: "easy", intro: intro, steps: steps }
  }

  # ============================================================
  # THEME 6 — Farm animals
  # ============================================================
  THEMES << ->(rng, _vi) {
    chickens = rng.rand(8..20)
    cows = rng.rand(3..10)
    animals = chickens + cows
    eggs_each = rng.rand(2..4)
    daily_eggs = chickens * eggs_each
    weekly = daily_eggs * 7
    dozens = weekly / 12
    price = [ 4, 5, 6 ].sample(random: rng)
    weekly_sales = dozens * price
    feed_each = [ 1, 2 ].sample(random: rng)
    feed_cost = animals * feed_each
    # Guarantee positive profit: bump price until sales > feed_cost.
    while weekly_sales <= feed_cost
      price += 1
      weekly_sales = dozens * price
    end
    profit = weekly_sales - feed_cost
    months = 4
    monthly = profit * months
    intro = "A small farm has chickens and cows that need feeding and produce eggs."
    steps = [
      step(question: "A farmer has #{chickens} chickens and #{cows} cows. How many animals total?",
           answer: animals, fun_fact: "#{chickens} + #{cows} = #{animals}.", rng: rng),
      step(question: "Each chicken lays #{eggs_each} eggs per day. Daily eggs from #{chickens} chickens?",
           answer: daily_eggs, fun_fact: "#{chickens} × #{eggs_each} = #{daily_eggs}.", rng: rng),
      step(question: "Eggs in a week (7 days)?",
           answer: weekly, fun_fact: "#{daily_eggs} × 7 = #{weekly}.", rng: rng),
      step(question: "Eggs come in dozens (12). How many full dozens from #{weekly} eggs?",
           answer: dozens, fun_fact: "#{weekly} ÷ 12 = #{dozens} dozens.", rng: rng),
      step(question: "Each dozen sells for $#{price}. Weekly egg sales?",
           answer: weekly_sales, fun_fact: "#{dozens} × $#{price} = $#{weekly_sales}.", rng: rng, currency: true),
      step(question: "Each animal eats $#{feed_each} of feed per week. Total feed cost?",
           answer: feed_cost, fun_fact: "#{animals} × $#{feed_each} = $#{feed_cost}.", rng: rng, currency: true),
      step(question: "Weekly profit (sales − feed)?",
           answer: profit, fun_fact: "$#{weekly_sales} − $#{feed_cost} = $#{profit}.", rng: rng, currency: true),
      step(question: "Over #{months} weeks, total profit?",
           answer: monthly, fun_fact: "$#{profit} × #{months} = $#{monthly}.", rng: rng, currency: true),
      step(question: "If the farmer adds 4 more chickens, how many chickens total?",
           answer: chickens + 4, fun_fact: "#{chickens} + 4 = #{chickens + 4}.", rng: rng),
      step(question: "With #{chickens + 4} chickens each laying #{eggs_each} eggs/day, new daily total?",
           answer: (chickens + 4) * eggs_each, fun_fact: "#{chickens + 4} × #{eggs_each} = #{(chickens + 4) * eggs_each}.", rng: rng)
    ]
    { difficulty: "medium", intro: intro, steps: steps }
  }

  # ============================================================
  # THEME 7 — Movie outing
  # ============================================================
  THEMES << ->(rng, _vi) {
    friends = [ 4, 5, 6, 8 ].sample(random: rng)
    ticket = [ 8, 10, 12, 15 ].sample(random: rng)
    n1_tix = friends * ticket
    popcorn = [ 6, 7, 8 ].sample(random: rng)
    popcorns = friends / 2
    pop_cost = popcorns * popcorn
    drink = [ 3, 4, 5 ].sample(random: rng)
    drinks = friends
    drink_cost = drinks * drink
    n1_total = n1_tix + pop_cost + drink_cost
    nights = 3
    full = n1_total * nights
    saved = full / 4
    intro = "#{friends} friends go to the movies and track what they spend."
    steps = [
      step(question: "#{friends} friends go to the movies. Tickets cost $#{ticket} each. Total ticket cost on night 1?",
           answer: n1_tix, fun_fact: "#{friends} × $#{ticket} = $#{n1_tix}.", rng: rng, currency: true),
      step(question: "They share popcorn — 1 bag per 2 friends. How many popcorn bags?",
           answer: popcorns, fun_fact: "#{friends} ÷ 2 = #{popcorns} bags.", rng: rng),
      step(question: "Each popcorn is $#{popcorn}. Total popcorn cost?",
           answer: pop_cost, fun_fact: "#{popcorns} × $#{popcorn} = $#{pop_cost}.", rng: rng, currency: true),
      step(question: "Each friend buys a $#{drink} drink. Total drink cost?",
           answer: drink_cost, fun_fact: "#{friends} × $#{drink} = $#{drink_cost}.", rng: rng, currency: true),
      step(question: "Night-1 total (tickets + popcorn + drinks)?",
           answer: n1_total, fun_fact: "$#{n1_tix} + $#{pop_cost} + $#{drink_cost} = $#{n1_total}.", rng: rng, currency: true),
      step(question: "They go #{nights} nights in a row, spending the same. Total?",
           answer: full, fun_fact: "$#{n1_total} × #{nights} = $#{full}.", rng: rng, currency: true),
      step(question: "Splitting the night-1 total among #{friends} friends — cost per friend?",
           answer: n1_total / friends, fun_fact: "$#{n1_total} ÷ #{friends} = $#{n1_total / friends}.", rng: rng, currency: true),
      step(question: "If they got 25% off tickets (paid $#{ticket - ticket / 4} each), what's the new ticket total?",
           answer: friends * (ticket - ticket / 4), fun_fact: "#{friends} × $#{ticket - ticket / 4} = $#{friends * (ticket - ticket / 4)}.", rng: rng, currency: true),
      step(question: "How much would they save on tickets across all #{nights} nights with that discount?",
           answer: saved, fun_fact: "Discount saves ≈ $#{saved}.", rng: rng, currency: true),
      step(question: "If each friend skipped one drink, total drink cost saved across #{nights} nights?",
           answer: friends * drink * nights, fun_fact: "#{friends} × $#{drink} × #{nights} = $#{friends * drink * nights}.", rng: rng, currency: true)
    ]
    { difficulty: "medium", intro: intro, steps: steps }
  }

  # ============================================================
  # THEME 8 — Garden harvest
  # ============================================================
  THEMES << ->(rng, _vi) {
    name = NAMES_ADULT.sample(random: rng)
    tomatoes = [ 24, 30, 36, 48 ].sample(random: rng)
    per_basket = [ 4, 6, 8 ].sample(random: rng)
    baskets = tomatoes / per_basket
    give_away = baskets / 3
    keep = baskets - give_away
    cucumbers = rng.rand(8..20)
    total_veg = tomatoes + cucumbers
    rows = [ 3, 4, 5 ].sample(random: rng)
    per_row = total_veg / rows
    sale_price = [ 2, 3 ].sample(random: rng)
    sale_total = keep * per_basket * sale_price
    intro = "#{name} grows tomatoes and cucumbers and shares the harvest."
    steps = [
      step(question: "#{name} picks #{tomatoes} tomatoes and packs them into baskets of #{per_basket}. How many baskets?",
           answer: baskets, fun_fact: "#{tomatoes} ÷ #{per_basket} = #{baskets}.", rng: rng),
      step(question: "She gives 1/3 of the #{baskets} baskets to a neighbor. How many baskets given away?",
           answer: give_away, fun_fact: "#{baskets} ÷ 3 = #{give_away}.", rng: rng),
      step(question: "How many baskets does she keep?",
           answer: keep, fun_fact: "#{baskets} − #{give_away} = #{keep}.", rng: rng),
      step(question: "She also picks #{cucumbers} cucumbers. Total vegetables (tomatoes + cucumbers)?",
           answer: total_veg, fun_fact: "#{tomatoes} + #{cucumbers} = #{total_veg}.", rng: rng),
      step(question: "The garden has #{rows} rows. Average vegetables per row?",
           answer: per_row, fun_fact: "#{total_veg} ÷ #{rows} ≈ #{per_row}.", rng: rng),
      step(question: "Each tomato basket sells for $#{sale_price}. Money from selling her kept baskets?",
           answer: keep * sale_price, fun_fact: "#{keep} × $#{sale_price} = $#{keep * sale_price}.", rng: rng, currency: true),
      step(question: "If a basket holds #{per_basket} tomatoes priced at $#{sale_price} each, what would #{keep} baskets fetch tomato-by-tomato?",
           answer: sale_total, fun_fact: "#{keep} × #{per_basket} × $#{sale_price} = $#{sale_total}.", rng: rng, currency: true),
      step(question: "Half the cucumbers are pickled. How many pickled cucumbers?",
           answer: cucumbers / 2, fun_fact: "#{cucumbers} ÷ 2 = #{cucumbers / 2}.", rng: rng),
      step(question: "Next month, the harvest doubles. New tomato count?",
           answer: tomatoes * 2, fun_fact: "#{tomatoes} × 2 = #{tomatoes * 2}.", rng: rng),
      step(question: "Doubled tomatoes in baskets of #{per_basket}: how many baskets?",
           answer: (tomatoes * 2) / per_basket, fun_fact: "#{tomatoes * 2} ÷ #{per_basket} = #{(tomatoes * 2) / per_basket}.", rng: rng)
    ]
    { difficulty: "medium", intro: intro, steps: steps }
  }

  # ============================================================
  # THEME 9 — Fish tanks
  # ============================================================
  THEMES << ->(rng, _vi) {
    tanks = rng.rand(2..5)
    per_tank = [ 6, 8, 10, 12 ].sample(random: rng)
    fish = tanks * per_tank
    new_fish = rng.rand(4..10)
    after_new = fish + new_fish
    sick = rng.rand(2..5)
    healthy = after_new - sick
    new_tanks = tanks + 1
    even = healthy / new_tanks
    food_each = [ 1, 2 ].sample(random: rng)
    weekly_food = healthy * food_each
    months = 4
    monthly_food = weekly_food * months
    intro = "An aquarium owner buys, sells, and feeds fish across several tanks."
    steps = [
      step(question: "There are #{tanks} tanks with #{per_tank} fish each. How many fish total?",
           answer: fish, fun_fact: "#{tanks} × #{per_tank} = #{fish}.", rng: rng),
      step(question: "He buys #{new_fish} more fish. How many total now?",
           answer: after_new, fun_fact: "#{fish} + #{new_fish} = #{after_new}.", rng: rng),
      step(question: "Sadly, #{sick} fish become sick and are isolated. How many healthy fish are left in the tanks?",
           answer: healthy, fun_fact: "#{after_new} − #{sick} = #{healthy}.", rng: rng),
      step(question: "He sets up #{new_tanks} tanks total. Splitting #{healthy} healthy fish evenly: fish per tank?",
           answer: even, fun_fact: "#{healthy} ÷ #{new_tanks} ≈ #{even}.", rng: rng),
      step(question: "Each fish eats $#{food_each} of food per week. Weekly food cost?",
           answer: weekly_food, fun_fact: "#{healthy} × $#{food_each} = $#{weekly_food}.", rng: rng, currency: true),
      step(question: "Over #{months} weeks, how much does food cost?",
           answer: monthly_food, fun_fact: "$#{weekly_food} × #{months} = $#{monthly_food}.", rng: rng, currency: true),
      step(question: "Half the healthy fish are goldfish. How many goldfish?",
           answer: healthy / 2, fun_fact: "#{healthy} ÷ 2 = #{healthy / 2}.", rng: rng),
      step(question: "If he sells 1/4 of his goldfish, how many does he sell?",
           answer: (healthy / 2) / 4, fun_fact: "#{healthy / 2} ÷ 4 = #{(healthy / 2) / 4}.", rng: rng),
      step(question: "After selling those goldfish, how many fish remain in total?",
           answer: healthy - ((healthy / 2) / 4), fun_fact: "#{healthy} − #{(healthy / 2) / 4} = #{healthy - ((healthy / 2) / 4)}.", rng: rng),
      step(question: "A new tank fits #{per_tank * 2} fish. Could the remaining fish fit in 2 such tanks?",
           answer: (healthy - ((healthy / 2) / 4) <= per_tank * 2 * 2) ? 1 : 0,
           fun_fact: "#{healthy - ((healthy / 2) / 4)} vs #{per_tank * 2 * 2} — answer 1=yes, 0=no.", rng: rng)
    ]
    { difficulty: "medium", intro: intro, steps: steps }
  }

  # ============================================================
  # THEME 10 — Bake sale
  # ============================================================
  THEMES << ->(rng, _vi) {
    name = NAMES_KID.sample(random: rng)
    cookies = [ 36, 48, 60, 72 ].sample(random: rng)
    per_bag = [ 4, 6 ].sample(random: rng)
    bags = cookies / per_bag
    price = [ 3, 4, 5 ].sample(random: rng)
    sales = bags * price
    flour = [ 4, 5, 6 ].sample(random: rng)
    sugar = [ 2, 3, 4 ].sample(random: rng)
    butter = [ 3, 4, 5 ].sample(random: rng)
    supply = flour + sugar + butter
    # Guarantee a profitable bake sale.
    while sales <= supply
      price += 1
      sales = bags * price
    end
    profit = sales - supply
    days = 4
    weekly = profit * days
    save = weekly / 2
    intro = "#{name} runs a bake sale and counts profit each day."
    steps = [
      step(question: "#{name} bakes #{cookies} cookies and bags them in groups of #{per_bag}. How many bags?",
           answer: bags, fun_fact: "#{cookies} ÷ #{per_bag} = #{bags}.", rng: rng),
      step(question: "Each bag sells for $#{price}. Day-1 sales if all bags sell?",
           answer: sales, fun_fact: "#{bags} × $#{price} = $#{sales}.", rng: rng, currency: true),
      step(question: "Flour cost $#{flour}, sugar $#{sugar}, butter $#{butter}. Total supplies?",
           answer: supply, fun_fact: "$#{flour} + $#{sugar} + $#{butter} = $#{supply}.", rng: rng, currency: true),
      step(question: "Daily profit (sales − supplies)?",
           answer: profit, fun_fact: "$#{sales} − $#{supply} = $#{profit}.", rng: rng, currency: true),
      step(question: "He bakes for #{days} days. Weekly profit?",
           answer: weekly, fun_fact: "$#{profit} × #{days} = $#{weekly}.", rng: rng, currency: true),
      step(question: "He saves half. How much does he save weekly?",
           answer: save, fun_fact: "$#{weekly} ÷ 2 = $#{save}.", rng: rng, currency: true),
      step(question: "If he doubles the cookies, how many cookies?",
           answer: cookies * 2, fun_fact: "#{cookies} × 2 = #{cookies * 2}.", rng: rng),
      step(question: "Doubled cookies bagged in #{per_bag}s: how many bags?",
           answer: (cookies * 2) / per_bag, fun_fact: "#{cookies * 2} ÷ #{per_bag} = #{(cookies * 2) / per_bag}.", rng: rng),
      step(question: "A third of the bags are chocolate chip. How many chocolate-chip bags?",
           answer: bags / 3, fun_fact: "#{bags} ÷ 3 = #{bags / 3}.", rng: rng),
      step(question: "If a kind customer tips $#{[ 5, 10 ].sample(random: rng)}, what's day-1 take-home (profit + tip)?",
           answer: profit + 5, fun_fact: "Profit + tip ≈ $#{profit + 5}.", rng: rng, currency: true)
    ]
    { difficulty: "easy", intro: intro, steps: steps }
  }

  # ============================================================
  # Public API
  # ============================================================

  # Returns an array of `target_count` chain hashes. Each chain is shaped
  # for the existing trivia:seed_chains task: { difficulty:, intro:, steps: [..] }.
  # Variant indices guarantee deterministic seeds — re-running yields identical
  # chains, so reseeding is idempotent. A unique context phrase is appended
  # to each chain's intro so chains stay distinguishable even when numeric
  # parameters collide across variants.
  def self.generate(target_count: 100)
    chains = []
    variants_per_theme = (target_count.to_f / THEMES.size).ceil
    THEMES.each_with_index do |theme, ti|
      variants_per_theme.times do |vi|
        rng = Random.new(ti * 100_000 + vi)
        chain = theme.call(rng, vi)
        chain[:intro] = "#{chain[:intro]} · #{ctx_for(vi)}"
        chain[:tag] = "math"
        chains << chain
      end
    end
    chains.first(target_count)
  end
end
