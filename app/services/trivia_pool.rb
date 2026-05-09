# Curated trivia by interest. All offline — no API calls. 5+ questions per
# tag, mostly multiple choice so the road-trip game flow is "tap an answer".
# Difficulty is mixed but lean kid-friendly because the typical use is for
# kids during a long drive.
module TriviaPool
  # { tag => [ {q:, options: [], answer: index, fun_fact: } ] }
  POOL = {
    "math" => [
      { q: "What is 7 × 8?", options: %w[54 56 64 48], answer: 1, fun_fact: "Seven and eight together make 56 — a friendly number to memorize." },
      { q: "Which is a prime number?", options: %w[9 15 17 21], answer: 2, fun_fact: "17 is only divisible by 1 and itself." },
      { q: "What is 144 ÷ 12?", options: %w[10 11 12 14], answer: 2, fun_fact: "12 is a 'gross' — old word for a dozen dozens." },
      { q: "What is the next number? 2, 4, 8, 16, ___", options: %w[24 30 32 64], answer: 2, fun_fact: "Each step doubles — that's exponential growth." },
      { q: "How many sides does a hexagon have?", options: %w[5 6 7 8], answer: 1, fun_fact: "Beehive cells are hexagons because that shape uses the least wax for the most space." },
      { q: "What is 25% of 200?", options: %w[25 40 50 75], answer: 2, fun_fact: "A quarter of 200 is 50." }
    ],
    "science" => [
      { q: "Water boils at what Celsius temperature at sea level?", options: %w[90° 100° 110° 120°], answer: 1, fun_fact: "At higher altitudes water boils at a lower temperature." },
      { q: "How many bones are in an adult human body?", options: %w[186 206 226 246], answer: 1, fun_fact: "Babies are born with about 270 — many fuse together as they grow." },
      { q: "What gas do plants take in?", options: %w[Oxygen Nitrogen CO₂ Helium], answer: 2, fun_fact: "Plants 'breathe' carbon dioxide and release oxygen — handy for us!" },
      { q: "What's the hardest natural substance?", options: %w[Steel Diamond Granite Iron], answer: 1, fun_fact: "Diamonds form deep underground over a billion years." },
      { q: "Which planet has the most moons?", options: %w[Earth Jupiter Mars Saturn], answer: 3, fun_fact: "Saturn has more than 140 confirmed moons." }
    ],
    "space" => [
      { q: "What's the closest star to Earth?", options: ["The Sun", "Polaris", "Proxima Centauri", "Sirius"], answer: 0, fun_fact: "It takes light about 8 minutes to reach Earth from the Sun." },
      { q: "Which planet is famous for its rings?", options: %w[Mars Jupiter Saturn Neptune], answer: 2, fun_fact: "Saturn's rings are mostly chunks of ice and rock." },
      { q: "What galaxy do we live in?", options: ["Andromeda", "Milky Way", "Whirlpool", "Sombrero"], answer: 1, fun_fact: "The Milky Way has somewhere between 100 and 400 billion stars." },
      { q: "Who was the first person on the Moon?", options: ["Buzz Aldrin", "Yuri Gagarin", "Neil Armstrong", "John Glenn"], answer: 2, fun_fact: "He stepped down on July 20, 1969." },
      { q: "What's the largest planet in our solar system?", options: %w[Earth Saturn Jupiter Uranus], answer: 2, fun_fact: "Jupiter is so big over 1,300 Earths could fit inside it." }
    ],
    "animals" => [
      { q: "What's the fastest land animal?", options: %w[Lion Cheetah Horse Greyhound], answer: 1, fun_fact: "Cheetahs can hit 70 mph in short bursts." },
      { q: "How many hearts does an octopus have?", options: %w[1 2 3 4], answer: 2, fun_fact: "Three hearts — two pump blood through the gills, one through the body." },
      { q: "Which is the largest mammal on Earth?", options: ["African elephant", "Blue whale", "Giraffe", "Polar bear"], answer: 1, fun_fact: "A blue whale's tongue alone weighs as much as an elephant." },
      { q: "What's a baby kangaroo called?", options: %w[Cub Joey Kit Pup], answer: 1, fun_fact: "Joeys live in their mom's pouch for several months." },
      { q: "How many legs does a spider have?", options: %w[6 7 8 10], answer: 2, fun_fact: "Insects have 6 legs; spiders are arachnids and have 8." }
    ],
    "dinosaurs" => [
      { q: "Which dinosaur's name means 'tyrant lizard king'?", options: ["Stegosaurus", "Velociraptor", "T. rex", "Brachiosaurus"], answer: 2, fun_fact: "T. rex's full name is Tyrannosaurus rex." },
      { q: "Roughly how long ago did the dinosaurs go extinct?", options: ["6 thousand years", "6 million", "66 million", "660 million"], answer: 2, fun_fact: "An asteroid impact 66 million years ago wiped out the non-avian dinosaurs." },
      { q: "Which dinosaur had plates along its back?", options: ["Triceratops", "Stegosaurus", "Velociraptor", "Iguanodon"], answer: 1, fun_fact: "Stegosaurus plates may have helped regulate body temperature." }
    ],
    "sports" => [
      { q: "How many players are on a soccer team on the field?", options: %w[9 10 11 12], answer: 2, fun_fact: "11 including the goalkeeper." },
      { q: "How many points is a touchdown in NFL football?", options: %w[3 6 7 10], answer: 1, fun_fact: "6 for the touchdown plus a kicked extra point makes 7." },
      { q: "Where were the first modern Olympics held?", options: %w[Paris Athens London Rome], answer: 1, fun_fact: "1896 in Athens — Greece, the home of the original Olympics." },
      { q: "How many holes are in a standard round of golf?", options: %w[9 12 18 24], answer: 2, fun_fact: "18 holes — the number was standardized at St Andrews in Scotland." }
    ],
    "music" => [
      { q: "Which Beatle was known as 'the Quiet One'?", options: ["John Lennon", "Paul McCartney", "George Harrison", "Ringo Starr"], answer: 2, fun_fact: "George wrote 'Here Comes the Sun' and 'Something'." },
      { q: "How many strings does a standard guitar have?", options: %w[4 6 8 12], answer: 1, fun_fact: "6 strings — though 12-string guitars exist for a fuller sound." },
      { q: "What's the highest-pitched of these instruments?", options: ["Cello", "Violin", "Double bass", "Viola"], answer: 1, fun_fact: "Violins are tuned an octave above violas." }
    ],
    "movies" => [
      { q: "What movie won Best Picture at the very first Oscars?", options: ["Casablanca", "Wings", "Gone with the Wind", "Citizen Kane"], answer: 1, fun_fact: "'Wings' (1927) — a silent film about WWI pilots." },
      { q: "Which director made 'Jurassic Park' and 'E.T.'?", options: %w[Spielberg Lucas Cameron Tarantino], answer: 0, fun_fact: "Steven Spielberg practically defined the summer blockbuster." }
    ],
    "movies_kids" => [
      { q: "What does Buzz Lightyear say?", options: ["Yabba dabba doo", "To infinity and beyond", "Hakuna matata", "May the Force be with you"], answer: 1, fun_fact: "Buzz believes he's a real space ranger throughout most of Toy Story." },
      { q: "What kind of animal is Simba in The Lion King?", options: %w[Tiger Cheetah Lion Leopard], answer: 2, fun_fact: "His name even means 'lion' in Swahili." },
      { q: "Which Disney princess has a pet tiger named Rajah?", options: %w[Belle Jasmine Mulan Moana], answer: 1, fun_fact: "Princess Jasmine — from Aladdin." }
    ],
    "history" => [
      { q: "In what year did World War II end?", options: %w[1942 1944 1945 1948], answer: 2, fun_fact: "1945 — Japan surrendered in September." },
      { q: "Who was the first US President?", options: ["Thomas Jefferson", "George Washington", "Abraham Lincoln", "John Adams"], answer: 1, fun_fact: "Sworn in on April 30, 1789." },
      { q: "Which civilization built Machu Picchu?", options: %w[Aztec Maya Inca Olmec], answer: 2, fun_fact: "The Inca built it high in the Peruvian Andes around 1450." }
    ],
    "geography" => [
      { q: "What's the largest desert on Earth?", options: ["Sahara", "Gobi", "Antarctic", "Arabian"], answer: 2, fun_fact: "Antarctica counts as a desert — it gets very little precipitation." },
      { q: "Which river is the longest in the world?", options: %w[Amazon Nile Yangtze Mississippi], answer: 1, fun_fact: "The Nile is just over 4,100 miles long." },
      { q: "How many countries border the United States?", options: %w[1 2 3 4], answer: 1, fun_fact: "Canada and Mexico — only two." },
      { q: "What state is Las Vegas in?", options: %w[California Nevada Arizona Utah], answer: 1, fun_fact: "And the city is in the Mojave Desert." }
    ],
    "cars" => [
      { q: "What does 'EV' stand for?", options: ["Extra Vehicle", "Electric Vehicle", "Engine Variant", "Express Van"], answer: 1, fun_fact: "Electric vehicles charge from the grid instead of burning gas." },
      { q: "Which car brand makes the Mustang?", options: %w[Chevrolet Ford Dodge Toyota], answer: 1, fun_fact: "Ford launched the Mustang in 1964." }
    ],
    "video_games" => [
      { q: "What's Mario's brother's name?", options: %w[Luigi Wario Toad Yoshi], answer: 0, fun_fact: "Luigi is taller and a bit braver than Mario in newer games." },
      { q: "What game has a character named Link?", options: %w[Mario "Final Fantasy" Pokémon Zelda], answer: 3, fun_fact: "The Legend of Zelda — Link is the hero, Zelda is the princess." }
    ],
    "disney" => [
      { q: "What's the name of Mickey's dog?", options: %w[Goofy Pluto Donald Daisy], answer: 1, fun_fact: "Pluto is the only main character in Mickey's group who doesn't talk." },
      { q: "What is Elsa's sister's name in Frozen?", options: %w[Anna Aurora Ariel Belle], answer: 0, fun_fact: "Anna is the younger, more outgoing sister." }
    ],
    "superhero" => [
      { q: "What's Spider-Man's real name?", options: ["Bruce Wayne", "Peter Parker", "Tony Stark", "Steve Rogers"], answer: 1, fun_fact: "He gets his powers from a radioactive spider bite." },
      { q: "Which superhero is from Krypton?", options: %w[Batman Superman Flash Aquaman], answer: 1, fun_fact: "Superman's birth name is Kal-El." }
    ],
    "food" => [
      { q: "What's the main ingredient in guacamole?", options: %w[Tomato Avocado Onion Lime], answer: 1, fun_fact: "Avocados are technically a berry." },
      { q: "Which country invented pizza?", options: %w[USA Italy Greece France], answer: 1, fun_fact: "Modern pizza comes from Naples, Italy." }
    ],
    "books" => [
      { q: "Who wrote Harry Potter?", options: ["Roald Dahl", "C.S. Lewis", "J.K. Rowling", "Suzanne Collins"], answer: 2, fun_fact: "She wrote much of the first book in Edinburgh cafés." }
    ],
    "art" => [
      { q: "Who painted the Mona Lisa?", options: ["Picasso", "Van Gogh", "Da Vinci", "Michelangelo"], answer: 2, fun_fact: "Leonardo started it around 1503 and never quite finished." }
    ],
    "travel" => [
      { q: "How tall is the Eiffel Tower (roughly)?", options: ["100 ft", "330 ft", "1,000 ft", "2,000 ft"], answer: 2, fun_fact: "About 1,083 feet to the tip — once the tallest in the world." }
    ],
    "photography" => [
      { q: "What does ISO control on a camera?", options: ["Color", "Sensor sensitivity", "Shutter speed", "Aperture"], answer: 1, fun_fact: "Higher ISO = brighter photo but more grain." }
    ],
    "cooking" => [
      { q: "What temperature does water freeze at, in Celsius?", options: ["-10°", "0°", "10°", "32°"], answer: 1, fun_fact: "32°F is the same temperature." }
    ],
    "gardening" => [
      { q: "What do bees collect from flowers?", options: %w[Pollen Nectar Both Honey], answer: 2, fun_fact: "Bees gather pollen and nectar; they make honey from nectar." }
    ]
  }.freeze

  GENERIC = [
    { q: "How many wheels are on this minivan?", options: %w[2 3 4 5], answer: 2, fun_fact: "Four — and the spare in the back makes five." },
    { q: "True or false: a tomato is a fruit.", options: %w[True False], answer: 0, fun_fact: "Botanically a fruit, but legally taxed as a vegetable in the US since 1893!" }
  ].freeze

  def self.pick_for(person)
    available = person.interests.flat_map { |i| POOL[i] || [] }
    pool = available.any? ? available : GENERIC
    pool.sample
  end

  def self.has_interest?(tag)
    POOL.key?(tag.to_s)
  end
end
