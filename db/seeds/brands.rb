# Logo decks (cars + airlines). Keys are Simple Icons slugs — all verified to
# resolve at cdn.simpleicons.org. Mercedes-Benz, Jaguar, Lexus etc. aren't in
# Simple Icons (trademark removals), so they're omitted rather than broken.
# { slug => display name }
CAR_BRANDS = {
  "toyota" => "Toyota", "bmw" => "BMW", "audi" => "Audi", "volkswagen" => "Volkswagen",
  "honda" => "Honda", "ford" => "Ford", "tesla" => "Tesla", "ferrari" => "Ferrari",
  "lamborghini" => "Lamborghini", "porsche" => "Porsche", "nissan" => "Nissan",
  "hyundai" => "Hyundai", "kia" => "Kia", "jeep" => "Jeep", "volvo" => "Volvo",
  "mazda" => "Mazda", "subaru" => "Subaru", "chevrolet" => "Chevrolet", "mini" => "MINI",
  "peugeot" => "Peugeot", "renault" => "Renault", "fiat" => "Fiat", "bugatti" => "Bugatti",
  "mclaren" => "McLaren", "astonmartin" => "Aston Martin", "rollsroyce" => "Rolls-Royce",
  "bentley" => "Bentley", "maserati" => "Maserati", "skoda" => "Škoda", "suzuki" => "Suzuki",
  "mitsubishi" => "Mitsubishi", "cadillac" => "Cadillac", "opel" => "Opel",
  "citroen" => "Citroën", "acura" => "Acura", "polestar" => "Polestar", "mahindra" => "Mahindra"
}.freeze

AIRLINE_BRANDS = {
  "emirates" => "Emirates", "qatarairways" => "Qatar Airways", "lufthansa" => "Lufthansa",
  "unitedairlines" => "United Airlines", "americanairlines" => "American Airlines",
  "britishairways" => "British Airways", "airfrance" => "Air France", "klm" => "KLM",
  "ryanair" => "Ryanair", "easyjet" => "easyJet", "singaporeairlines" => "Singapore Airlines",
  "turkishairlines" => "Turkish Airlines", "qantas" => "Qantas", "airindia" => "Air India",
  "etihadairways" => "Etihad Airways", "jetblue" => "JetBlue", "southwestairlines" => "Southwest Airlines",
  "airchina" => "Air China", "japanairlines" => "Japan Airlines", "aircanada" => "Air Canada",
  "wizzair" => "Wizz Air", "aeroflot" => "Aeroflot", "virginatlantic" => "Virgin Atlantic",
  "saudia" => "Saudia", "aeromexico" => "Aeroméxico", "avianca" => "Avianca",
  "iberia" => "Iberia", "airasia" => "AirAsia"
}.freeze

{ "car" => CAR_BRANDS, "airline" => AIRLINE_BRANDS }.each do |category, brands|
  brands.each do |slug, name|
    Brand.find_or_initialize_by(slug: slug).update!(name: name, category: category)
  end
end

puts "Brands: #{Brand.for_category('car').count} cars, #{Brand.for_category('airline').count} airlines"
