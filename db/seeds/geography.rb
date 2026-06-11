# Curated reference data powering the standalone Travel Trivia quizzes
# (see QuizCatalog). Capitals and ISO-3166 alpha-2 codes are stable facts.
# `leader_name` reflects heads of state/government as of
# QuizCatalog::LEADERS_AS_OF and should be re-verified periodically — re-running
# this seed refreshes leaders in place (idempotent upsert keyed on iso2).
#
# Where a country has more than one capital city (administrative vs. legislative
# vs. judicial, or de-facto vs. official) the most widely taught answer is used.

# [name, capital, iso2, continent]
COUNTRIES = [
  # ── Europe ──────────────────────────────────────────────────────────
  [ "Albania", "Tirana", "al", "Europe" ],
  [ "Andorra", "Andorra la Vella", "ad", "Europe" ],
  [ "Austria", "Vienna", "at", "Europe" ],
  [ "Belarus", "Minsk", "by", "Europe" ],
  [ "Belgium", "Brussels", "be", "Europe" ],
  [ "Bosnia and Herzegovina", "Sarajevo", "ba", "Europe" ],
  [ "Bulgaria", "Sofia", "bg", "Europe" ],
  [ "Croatia", "Zagreb", "hr", "Europe" ],
  [ "Czechia", "Prague", "cz", "Europe" ],
  [ "Denmark", "Copenhagen", "dk", "Europe" ],
  [ "Estonia", "Tallinn", "ee", "Europe" ],
  [ "Finland", "Helsinki", "fi", "Europe" ],
  [ "France", "Paris", "fr", "Europe" ],
  [ "Germany", "Berlin", "de", "Europe" ],
  [ "Greece", "Athens", "gr", "Europe" ],
  [ "Hungary", "Budapest", "hu", "Europe" ],
  [ "Iceland", "Reykjavik", "is", "Europe" ],
  [ "Ireland", "Dublin", "ie", "Europe" ],
  [ "Italy", "Rome", "it", "Europe" ],
  [ "Latvia", "Riga", "lv", "Europe" ],
  [ "Lithuania", "Vilnius", "lt", "Europe" ],
  [ "Luxembourg", "Luxembourg City", "lu", "Europe" ],
  [ "Malta", "Valletta", "mt", "Europe" ],
  [ "Moldova", "Chișinău", "md", "Europe" ],
  [ "Monaco", "Monaco", "mc", "Europe" ],
  [ "Montenegro", "Podgorica", "me", "Europe" ],
  [ "Netherlands", "Amsterdam", "nl", "Europe" ],
  [ "North Macedonia", "Skopje", "mk", "Europe" ],
  [ "Norway", "Oslo", "no", "Europe" ],
  [ "Poland", "Warsaw", "pl", "Europe" ],
  [ "Portugal", "Lisbon", "pt", "Europe" ],
  [ "Romania", "Bucharest", "ro", "Europe" ],
  [ "Russia", "Moscow", "ru", "Europe" ],
  [ "San Marino", "San Marino", "sm", "Europe" ],
  [ "Serbia", "Belgrade", "rs", "Europe" ],
  [ "Slovakia", "Bratislava", "sk", "Europe" ],
  [ "Slovenia", "Ljubljana", "si", "Europe" ],
  [ "Spain", "Madrid", "es", "Europe" ],
  [ "Sweden", "Stockholm", "se", "Europe" ],
  [ "Switzerland", "Bern", "ch", "Europe" ],
  [ "Ukraine", "Kyiv", "ua", "Europe" ],
  [ "United Kingdom", "London", "gb", "Europe" ],
  [ "Vatican City", "Vatican City", "va", "Europe" ],

  # ── Asia ────────────────────────────────────────────────────────────
  [ "Afghanistan", "Kabul", "af", "Asia" ],
  [ "Armenia", "Yerevan", "am", "Asia" ],
  [ "Azerbaijan", "Baku", "az", "Asia" ],
  [ "Bahrain", "Manama", "bh", "Asia" ],
  [ "Bangladesh", "Dhaka", "bd", "Asia" ],
  [ "Bhutan", "Thimphu", "bt", "Asia" ],
  [ "Brunei", "Bandar Seri Begawan", "bn", "Asia" ],
  [ "Cambodia", "Phnom Penh", "kh", "Asia" ],
  [ "China", "Beijing", "cn", "Asia" ],
  [ "Cyprus", "Nicosia", "cy", "Asia" ],
  [ "Georgia", "Tbilisi", "ge", "Asia" ],
  [ "India", "New Delhi", "in", "Asia" ],
  [ "Indonesia", "Jakarta", "id", "Asia" ],
  [ "Iran", "Tehran", "ir", "Asia" ],
  [ "Iraq", "Baghdad", "iq", "Asia" ],
  [ "Israel", "Jerusalem", "il", "Asia" ],
  [ "Japan", "Tokyo", "jp", "Asia" ],
  [ "Jordan", "Amman", "jo", "Asia" ],
  [ "Kazakhstan", "Astana", "kz", "Asia" ],
  [ "Kuwait", "Kuwait City", "kw", "Asia" ],
  [ "Kyrgyzstan", "Bishkek", "kg", "Asia" ],
  [ "Laos", "Vientiane", "la", "Asia" ],
  [ "Lebanon", "Beirut", "lb", "Asia" ],
  [ "Malaysia", "Kuala Lumpur", "my", "Asia" ],
  [ "Maldives", "Malé", "mv", "Asia" ],
  [ "Mongolia", "Ulaanbaatar", "mn", "Asia" ],
  [ "Myanmar", "Naypyidaw", "mm", "Asia" ],
  [ "Nepal", "Kathmandu", "np", "Asia" ],
  [ "North Korea", "Pyongyang", "kp", "Asia" ],
  [ "Oman", "Muscat", "om", "Asia" ],
  [ "Pakistan", "Islamabad", "pk", "Asia" ],
  [ "Philippines", "Manila", "ph", "Asia" ],
  [ "Qatar", "Doha", "qa", "Asia" ],
  [ "Saudi Arabia", "Riyadh", "sa", "Asia" ],
  [ "Singapore", "Singapore", "sg", "Asia" ],
  [ "South Korea", "Seoul", "kr", "Asia" ],
  [ "Sri Lanka", "Colombo", "lk", "Asia" ],
  [ "Syria", "Damascus", "sy", "Asia" ],
  [ "Taiwan", "Taipei", "tw", "Asia" ],
  [ "Tajikistan", "Dushanbe", "tj", "Asia" ],
  [ "Thailand", "Bangkok", "th", "Asia" ],
  [ "Timor-Leste", "Dili", "tl", "Asia" ],
  [ "Turkey", "Ankara", "tr", "Asia" ],
  [ "Turkmenistan", "Ashgabat", "tm", "Asia" ],
  [ "United Arab Emirates", "Abu Dhabi", "ae", "Asia" ],
  [ "Uzbekistan", "Tashkent", "uz", "Asia" ],
  [ "Vietnam", "Hanoi", "vn", "Asia" ],
  [ "Yemen", "Sanaa", "ye", "Asia" ],

  # ── Africa ──────────────────────────────────────────────────────────
  [ "Algeria", "Algiers", "dz", "Africa" ],
  [ "Angola", "Luanda", "ao", "Africa" ],
  [ "Benin", "Porto-Novo", "bj", "Africa" ],
  [ "Botswana", "Gaborone", "bw", "Africa" ],
  [ "Burkina Faso", "Ouagadougou", "bf", "Africa" ],
  [ "Burundi", "Gitega", "bi", "Africa" ],
  [ "Cameroon", "Yaoundé", "cm", "Africa" ],
  [ "Cape Verde", "Praia", "cv", "Africa" ],
  [ "Chad", "N'Djamena", "td", "Africa" ],
  [ "Democratic Republic of the Congo", "Kinshasa", "cd", "Africa" ],
  [ "Republic of the Congo", "Brazzaville", "cg", "Africa" ],
  [ "Djibouti", "Djibouti", "dj", "Africa" ],
  [ "Egypt", "Cairo", "eg", "Africa" ],
  [ "Equatorial Guinea", "Malabo", "gq", "Africa" ],
  [ "Eritrea", "Asmara", "er", "Africa" ],
  [ "Eswatini", "Mbabane", "sz", "Africa" ],
  [ "Ethiopia", "Addis Ababa", "et", "Africa" ],
  [ "Gabon", "Libreville", "ga", "Africa" ],
  [ "Gambia", "Banjul", "gm", "Africa" ],
  [ "Ghana", "Accra", "gh", "Africa" ],
  [ "Guinea", "Conakry", "gn", "Africa" ],
  [ "Ivory Coast", "Yamoussoukro", "ci", "Africa" ],
  [ "Kenya", "Nairobi", "ke", "Africa" ],
  [ "Lesotho", "Maseru", "ls", "Africa" ],
  [ "Liberia", "Monrovia", "lr", "Africa" ],
  [ "Libya", "Tripoli", "ly", "Africa" ],
  [ "Madagascar", "Antananarivo", "mg", "Africa" ],
  [ "Malawi", "Lilongwe", "mw", "Africa" ],
  [ "Mali", "Bamako", "ml", "Africa" ],
  [ "Mauritania", "Nouakchott", "mr", "Africa" ],
  [ "Mauritius", "Port Louis", "mu", "Africa" ],
  [ "Morocco", "Rabat", "ma", "Africa" ],
  [ "Mozambique", "Maputo", "mz", "Africa" ],
  [ "Namibia", "Windhoek", "na", "Africa" ],
  [ "Niger", "Niamey", "ne", "Africa" ],
  [ "Nigeria", "Abuja", "ng", "Africa" ],
  [ "Rwanda", "Kigali", "rw", "Africa" ],
  [ "Senegal", "Dakar", "sn", "Africa" ],
  [ "Sierra Leone", "Freetown", "sl", "Africa" ],
  [ "Somalia", "Mogadishu", "so", "Africa" ],
  [ "South Africa", "Pretoria", "za", "Africa" ],
  [ "South Sudan", "Juba", "ss", "Africa" ],
  [ "Sudan", "Khartoum", "sd", "Africa" ],
  [ "Tanzania", "Dodoma", "tz", "Africa" ],
  [ "Togo", "Lomé", "tg", "Africa" ],
  [ "Tunisia", "Tunis", "tn", "Africa" ],
  [ "Uganda", "Kampala", "ug", "Africa" ],
  [ "Zambia", "Lusaka", "zm", "Africa" ],
  [ "Zimbabwe", "Harare", "zw", "Africa" ],

  # ── North America ───────────────────────────────────────────────────
  [ "Bahamas", "Nassau", "bs", "North America" ],
  [ "Barbados", "Bridgetown", "bb", "North America" ],
  [ "Belize", "Belmopan", "bz", "North America" ],
  [ "Canada", "Ottawa", "ca", "North America" ],
  [ "Costa Rica", "San José", "cr", "North America" ],
  [ "Cuba", "Havana", "cu", "North America" ],
  [ "Dominican Republic", "Santo Domingo", "do", "North America" ],
  [ "El Salvador", "San Salvador", "sv", "North America" ],
  [ "Guatemala", "Guatemala City", "gt", "North America" ],
  [ "Haiti", "Port-au-Prince", "ht", "North America" ],
  [ "Honduras", "Tegucigalpa", "hn", "North America" ],
  [ "Jamaica", "Kingston", "jm", "North America" ],
  [ "Mexico", "Mexico City", "mx", "North America" ],
  [ "Nicaragua", "Managua", "ni", "North America" ],
  [ "Panama", "Panama City", "pa", "North America" ],
  [ "Trinidad and Tobago", "Port of Spain", "tt", "North America" ],
  [ "United States", "Washington, D.C.", "us", "North America" ],

  # ── South America ───────────────────────────────────────────────────
  [ "Argentina", "Buenos Aires", "ar", "South America" ],
  [ "Bolivia", "Sucre", "bo", "South America" ],
  [ "Brazil", "Brasília", "br", "South America" ],
  [ "Chile", "Santiago", "cl", "South America" ],
  [ "Colombia", "Bogotá", "co", "South America" ],
  [ "Ecuador", "Quito", "ec", "South America" ],
  [ "Guyana", "Georgetown", "gy", "South America" ],
  [ "Paraguay", "Asunción", "py", "South America" ],
  [ "Peru", "Lima", "pe", "South America" ],
  [ "Suriname", "Paramaribo", "sr", "South America" ],
  [ "Uruguay", "Montevideo", "uy", "South America" ],
  [ "Venezuela", "Caracas", "ve", "South America" ],

  # ── Oceania ─────────────────────────────────────────────────────────
  [ "Australia", "Canberra", "au", "Oceania" ],
  [ "Fiji", "Suva", "fj", "Oceania" ],
  [ "New Zealand", "Wellington", "nz", "Oceania" ],
  [ "Papua New Guinea", "Port Moresby", "pg", "Oceania" ],
  [ "Samoa", "Apia", "ws", "Oceania" ],
  [ "Tonga", "Nuku'alofa", "to", "Oceania" ],
  [ "Vanuatu", "Port Vila", "vu", "Oceania" ]
].freeze

# Heads of state/government as of QuizCatalog::LEADERS_AS_OF.
# { country_name => [title, name] }
LEADERS = {
  "United States"  => [ "President", "Donald Trump" ],
  "United Kingdom" => [ "Prime Minister", "Keir Starmer" ],
  "France"         => [ "President", "Emmanuel Macron" ],
  "Germany"        => [ "Chancellor", "Friedrich Merz" ],
  "Russia"         => [ "President", "Vladimir Putin" ],
  "China"          => [ "President", "Xi Jinping" ],
  "India"          => [ "Prime Minister", "Narendra Modi" ],
  "Canada"         => [ "Prime Minister", "Mark Carney" ],
  "Italy"          => [ "Prime Minister", "Giorgia Meloni" ],
  "Mexico"         => [ "President", "Claudia Sheinbaum" ],
  "Brazil"         => [ "President", "Luiz Inácio Lula da Silva" ],
  "Australia"      => [ "Prime Minister", "Anthony Albanese" ],
  "Spain"          => [ "Prime Minister", "Pedro Sánchez" ],
  "Argentina"      => [ "President", "Javier Milei" ],
  "Ukraine"        => [ "President", "Volodymyr Zelenskyy" ],
  "Turkey"         => [ "President", "Recep Tayyip Erdoğan" ],
  "Egypt"          => [ "President", "Abdel Fattah el-Sisi" ],
  "South Africa"   => [ "President", "Cyril Ramaphosa" ],
  "Israel"         => [ "Prime Minister", "Benjamin Netanyahu" ],
  "Netherlands"    => [ "Prime Minister", "Dick Schoof" ],
  "Poland"         => [ "Prime Minister", "Donald Tusk" ],
  "Indonesia"      => [ "President", "Prabowo Subianto" ],
  "Pakistan"       => [ "Prime Minister", "Shehbaz Sharif" ],
  "New Zealand"    => [ "Prime Minister", "Christopher Luxon" ],
  "Hungary"        => [ "Prime Minister", "Viktor Orbán" ],
  "Venezuela"      => [ "President", "Nicolás Maduro" ],
  "Philippines"    => [ "President", "Ferdinand Marcos Jr." ],
  "Greece"         => [ "Prime Minister", "Kyriakos Mitsotakis" ],
  "Portugal"       => [ "Prime Minister", "Luís Montenegro" ],
  "Sweden"         => [ "Prime Minister", "Ulf Kristersson" ],
  "Norway"         => [ "Prime Minister", "Jonas Gahr Støre" ],
  "Finland"        => [ "Prime Minister", "Petteri Orpo" ],
  "Cuba"           => [ "President", "Miguel Díaz-Canel" ],
  "Colombia"       => [ "President", "Gustavo Petro" ],
  "Saudi Arabia"   => [ "King", "Salman bin Abdulaziz" ]
}.freeze

# Official currency by country (most widely taught answer). Powers the
# "World Currencies" deck — not every country needs one for a strong quiz.
# { country_name => currency_name }
CURRENCIES = {
  # Europe
  "Albania" => "Albanian Lek", "Austria" => "Euro", "Belarus" => "Belarusian Ruble",
  "Belgium" => "Euro", "Bulgaria" => "Bulgarian Lev", "Croatia" => "Euro",
  "Czechia" => "Czech Koruna", "Denmark" => "Danish Krone", "Estonia" => "Euro",
  "Finland" => "Euro", "France" => "Euro", "Germany" => "Euro", "Greece" => "Euro",
  "Hungary" => "Hungarian Forint", "Iceland" => "Icelandic Króna", "Ireland" => "Euro",
  "Italy" => "Euro", "Latvia" => "Euro", "Lithuania" => "Euro", "Luxembourg" => "Euro",
  "Malta" => "Euro", "Moldova" => "Moldovan Leu", "Netherlands" => "Euro",
  "Norway" => "Norwegian Krone", "Poland" => "Polish Złoty", "Portugal" => "Euro",
  "Romania" => "Romanian Leu", "Russia" => "Russian Ruble", "Serbia" => "Serbian Dinar",
  "Slovakia" => "Euro", "Slovenia" => "Euro", "Spain" => "Euro", "Sweden" => "Swedish Krona",
  "Switzerland" => "Swiss Franc", "Ukraine" => "Ukrainian Hryvnia", "United Kingdom" => "British Pound",
  # Asia
  "Afghanistan" => "Afghan Afghani", "Armenia" => "Armenian Dram", "Azerbaijan" => "Azerbaijani Manat",
  "Bahrain" => "Bahraini Dinar", "Bangladesh" => "Bangladeshi Taka", "Cambodia" => "Cambodian Riel",
  "China" => "Chinese Yuan", "Georgia" => "Georgian Lari", "India" => "Indian Rupee",
  "Indonesia" => "Indonesian Rupiah", "Iran" => "Iranian Rial", "Iraq" => "Iraqi Dinar",
  "Israel" => "Israeli Shekel", "Japan" => "Japanese Yen", "Jordan" => "Jordanian Dinar",
  "Kazakhstan" => "Kazakhstani Tenge", "Kuwait" => "Kuwaiti Dinar", "Laos" => "Lao Kip",
  "Lebanon" => "Lebanese Pound", "Malaysia" => "Malaysian Ringgit", "Mongolia" => "Mongolian Tögrög",
  "Myanmar" => "Burmese Kyat", "Nepal" => "Nepalese Rupee", "North Korea" => "North Korean Won",
  "Oman" => "Omani Rial", "Pakistan" => "Pakistani Rupee", "Philippines" => "Philippine Peso",
  "Qatar" => "Qatari Riyal", "Saudi Arabia" => "Saudi Riyal", "Singapore" => "Singapore Dollar",
  "South Korea" => "South Korean Won", "Sri Lanka" => "Sri Lankan Rupee", "Syria" => "Syrian Pound",
  "Taiwan" => "New Taiwan Dollar", "Thailand" => "Thai Baht", "Turkey" => "Turkish Lira",
  "United Arab Emirates" => "UAE Dirham", "Uzbekistan" => "Uzbekistani Som",
  "Vietnam" => "Vietnamese Đồng", "Yemen" => "Yemeni Rial",
  # Africa
  "Algeria" => "Algerian Dinar", "Angola" => "Angolan Kwanza", "Botswana" => "Botswana Pula",
  "Egypt" => "Egyptian Pound", "Ethiopia" => "Ethiopian Birr", "Ghana" => "Ghanaian Cedi",
  "Kenya" => "Kenyan Shilling", "Libya" => "Libyan Dinar", "Madagascar" => "Malagasy Ariary",
  "Malawi" => "Malawian Kwacha", "Mauritius" => "Mauritian Rupee", "Morocco" => "Moroccan Dirham",
  "Mozambique" => "Mozambican Metical", "Namibia" => "Namibian Dollar", "Nigeria" => "Nigerian Naira",
  "Rwanda" => "Rwandan Franc", "Sierra Leone" => "Sierra Leonean Leone", "Somalia" => "Somali Shilling",
  "South Africa" => "South African Rand", "Sudan" => "Sudanese Pound", "Tanzania" => "Tanzanian Shilling",
  "Tunisia" => "Tunisian Dinar", "Uganda" => "Ugandan Shilling", "Zambia" => "Zambian Kwacha",
  # North America
  "Bahamas" => "Bahamian Dollar", "Barbados" => "Barbadian Dollar", "Belize" => "Belize Dollar",
  "Canada" => "Canadian Dollar", "Costa Rica" => "Costa Rican Colón", "Cuba" => "Cuban Peso",
  "Dominican Republic" => "Dominican Peso", "El Salvador" => "US Dollar",
  "Guatemala" => "Guatemalan Quetzal", "Haiti" => "Haitian Gourde", "Honduras" => "Honduran Lempira",
  "Jamaica" => "Jamaican Dollar", "Mexico" => "Mexican Peso", "Nicaragua" => "Nicaraguan Córdoba",
  "Panama" => "Panamanian Balboa", "Trinidad and Tobago" => "Trinidad & Tobago Dollar",
  "United States" => "US Dollar",
  # South America
  "Argentina" => "Argentine Peso", "Bolivia" => "Bolivian Boliviano", "Brazil" => "Brazilian Real",
  "Chile" => "Chilean Peso", "Colombia" => "Colombian Peso", "Ecuador" => "US Dollar",
  "Guyana" => "Guyanese Dollar", "Paraguay" => "Paraguayan Guaraní", "Peru" => "Peruvian Sol",
  "Suriname" => "Surinamese Dollar", "Uruguay" => "Uruguayan Peso", "Venezuela" => "Venezuelan Bolívar",
  # Oceania
  "Australia" => "Australian Dollar", "Fiji" => "Fijian Dollar", "New Zealand" => "New Zealand Dollar",
  "Papua New Guinea" => "Papua New Guinean Kina", "Samoa" => "Samoan Tālā", "Tonga" => "Tongan Paʻanga",
  "Vanuatu" => "Vanuatu Vatu"
}.freeze

# Main language spoken (the most widely taught single answer). Genuinely
# multilingual countries with no clear dominant tongue (Belgium, Switzerland,
# Singapore, South Africa, …) are intentionally left out of this deck.
# { country_name => language }
LANGUAGES = {
  # Europe
  "Albania" => "Albanian", "Austria" => "German", "Belarus" => "Belarusian",
  "Bulgaria" => "Bulgarian", "Croatia" => "Croatian", "Czechia" => "Czech",
  "Denmark" => "Danish", "Estonia" => "Estonian", "Finland" => "Finnish",
  "France" => "French", "Germany" => "German", "Greece" => "Greek",
  "Hungary" => "Hungarian", "Iceland" => "Icelandic", "Italy" => "Italian",
  "Latvia" => "Latvian", "Lithuania" => "Lithuanian", "Malta" => "Maltese",
  "Moldova" => "Romanian", "Netherlands" => "Dutch", "Norway" => "Norwegian",
  "Poland" => "Polish", "Portugal" => "Portuguese", "Romania" => "Romanian",
  "Russia" => "Russian", "Serbia" => "Serbian", "Slovakia" => "Slovak",
  "Slovenia" => "Slovenian", "Spain" => "Spanish", "Sweden" => "Swedish",
  "Ukraine" => "Ukrainian", "United Kingdom" => "English",
  # Asia
  "Armenia" => "Armenian", "Azerbaijan" => "Azerbaijani", "Bahrain" => "Arabic",
  "Bangladesh" => "Bengali", "Cambodia" => "Khmer", "China" => "Mandarin Chinese",
  "Georgia" => "Georgian", "India" => "Hindi", "Indonesia" => "Indonesian",
  "Iran" => "Persian", "Iraq" => "Arabic", "Israel" => "Hebrew", "Japan" => "Japanese",
  "Jordan" => "Arabic", "Kazakhstan" => "Kazakh", "Kuwait" => "Arabic", "Laos" => "Lao",
  "Lebanon" => "Arabic", "Malaysia" => "Malay", "Mongolia" => "Mongolian",
  "Myanmar" => "Burmese", "Nepal" => "Nepali", "North Korea" => "Korean", "Oman" => "Arabic",
  "Pakistan" => "Urdu", "Philippines" => "Filipino", "Qatar" => "Arabic",
  "Saudi Arabia" => "Arabic", "South Korea" => "Korean", "Sri Lanka" => "Sinhala",
  "Syria" => "Arabic", "Taiwan" => "Mandarin Chinese", "Tajikistan" => "Tajik",
  "Thailand" => "Thai", "Turkey" => "Turkish", "Turkmenistan" => "Turkmen",
  "United Arab Emirates" => "Arabic", "Uzbekistan" => "Uzbek", "Vietnam" => "Vietnamese",
  "Yemen" => "Arabic",
  # Africa
  "Algeria" => "Arabic", "Angola" => "Portuguese", "Egypt" => "Arabic",
  "Ethiopia" => "Amharic", "Ghana" => "English", "Ivory Coast" => "French",
  "Kenya" => "Swahili", "Libya" => "Arabic", "Madagascar" => "Malagasy",
  "Morocco" => "Arabic", "Mozambique" => "Portuguese", "Nigeria" => "English",
  "Rwanda" => "Kinyarwanda", "Senegal" => "French", "Somalia" => "Somali",
  "Sudan" => "Arabic", "Tanzania" => "Swahili", "Tunisia" => "Arabic",
  "Uganda" => "English", "Zambia" => "English", "Zimbabwe" => "English",
  # North America
  "Bahamas" => "English", "Barbados" => "English", "Belize" => "English",
  "Canada" => "English", "Costa Rica" => "Spanish", "Cuba" => "Spanish",
  "Dominican Republic" => "Spanish", "El Salvador" => "Spanish", "Guatemala" => "Spanish",
  "Honduras" => "Spanish", "Jamaica" => "English", "Mexico" => "Spanish",
  "Nicaragua" => "Spanish", "Panama" => "Spanish", "Trinidad and Tobago" => "English",
  "United States" => "English",
  # South America
  "Argentina" => "Spanish", "Bolivia" => "Spanish", "Brazil" => "Portuguese",
  "Chile" => "Spanish", "Colombia" => "Spanish", "Ecuador" => "Spanish",
  "Guyana" => "English", "Paraguay" => "Spanish", "Peru" => "Spanish",
  "Suriname" => "Dutch", "Uruguay" => "Spanish", "Venezuela" => "Spanish",
  # Oceania
  "Australia" => "English", "Fiji" => "English", "New Zealand" => "English",
  "Papua New Guinea" => "English", "Samoa" => "Samoan", "Tonga" => "Tongan",
  "Vanuatu" => "Bislama"
}.freeze

# International dialing codes. NANP micro-states that share "+1" with the
# US/Canada are left blank so the deck stays varied. { country_name => "+code" }
CALLING_CODES = {
  # Europe
  "Albania" => "+355", "Andorra" => "+376", "Austria" => "+43", "Belarus" => "+375",
  "Belgium" => "+32", "Bosnia and Herzegovina" => "+387", "Bulgaria" => "+359",
  "Croatia" => "+385", "Czechia" => "+420", "Denmark" => "+45", "Estonia" => "+372",
  "Finland" => "+358", "France" => "+33", "Germany" => "+49", "Greece" => "+30",
  "Hungary" => "+36", "Iceland" => "+354", "Ireland" => "+353", "Italy" => "+39",
  "Latvia" => "+371", "Lithuania" => "+370", "Luxembourg" => "+352", "Malta" => "+356",
  "Moldova" => "+373", "Monaco" => "+377", "Montenegro" => "+382", "Netherlands" => "+31",
  "North Macedonia" => "+389", "Norway" => "+47", "Poland" => "+48", "Portugal" => "+351",
  "Romania" => "+40", "Russia" => "+7", "San Marino" => "+378", "Serbia" => "+381",
  "Slovakia" => "+421", "Slovenia" => "+386", "Spain" => "+34", "Sweden" => "+46",
  "Switzerland" => "+41", "Ukraine" => "+380", "United Kingdom" => "+44",
  # Asia
  "Afghanistan" => "+93", "Armenia" => "+374", "Azerbaijan" => "+994", "Bahrain" => "+973",
  "Bangladesh" => "+880", "Bhutan" => "+975", "Brunei" => "+673", "Cambodia" => "+855",
  "China" => "+86", "Cyprus" => "+357", "Georgia" => "+995", "India" => "+91",
  "Indonesia" => "+62", "Iran" => "+98", "Iraq" => "+964", "Israel" => "+972",
  "Japan" => "+81", "Jordan" => "+962", "Kazakhstan" => "+7", "Kuwait" => "+965",
  "Kyrgyzstan" => "+996", "Laos" => "+856", "Lebanon" => "+961", "Malaysia" => "+60",
  "Maldives" => "+960", "Mongolia" => "+976", "Myanmar" => "+95", "Nepal" => "+977",
  "North Korea" => "+850", "Oman" => "+968", "Pakistan" => "+92", "Philippines" => "+63",
  "Qatar" => "+974", "Saudi Arabia" => "+966", "Singapore" => "+65", "South Korea" => "+82",
  "Sri Lanka" => "+94", "Syria" => "+963", "Taiwan" => "+886", "Tajikistan" => "+992",
  "Thailand" => "+66", "Timor-Leste" => "+670", "Turkey" => "+90", "Turkmenistan" => "+993",
  "United Arab Emirates" => "+971", "Uzbekistan" => "+998", "Vietnam" => "+84", "Yemen" => "+967",
  # Africa
  "Algeria" => "+213", "Angola" => "+244", "Benin" => "+229", "Botswana" => "+267",
  "Burkina Faso" => "+226", "Burundi" => "+257", "Cameroon" => "+237", "Cape Verde" => "+238",
  "Chad" => "+235", "Democratic Republic of the Congo" => "+243", "Republic of the Congo" => "+242",
  "Djibouti" => "+253", "Egypt" => "+20", "Equatorial Guinea" => "+240", "Eritrea" => "+291",
  "Eswatini" => "+268", "Ethiopia" => "+251", "Gabon" => "+241", "Gambia" => "+220",
  "Ghana" => "+233", "Guinea" => "+224", "Ivory Coast" => "+225", "Kenya" => "+254",
  "Lesotho" => "+266", "Liberia" => "+231", "Libya" => "+218", "Madagascar" => "+261",
  "Malawi" => "+265", "Mali" => "+223", "Mauritania" => "+222", "Mauritius" => "+230",
  "Morocco" => "+212", "Mozambique" => "+258", "Namibia" => "+264", "Niger" => "+227",
  "Nigeria" => "+234", "Rwanda" => "+250", "Senegal" => "+221", "Sierra Leone" => "+232",
  "Somalia" => "+252", "South Africa" => "+27", "South Sudan" => "+211", "Sudan" => "+249",
  "Tanzania" => "+255", "Togo" => "+228", "Tunisia" => "+216", "Uganda" => "+256",
  "Zambia" => "+260", "Zimbabwe" => "+263",
  # North America
  "Belize" => "+501", "Canada" => "+1", "Costa Rica" => "+506", "Cuba" => "+53",
  "El Salvador" => "+503", "Guatemala" => "+502", "Haiti" => "+509", "Honduras" => "+504",
  "Mexico" => "+52", "Nicaragua" => "+505", "Panama" => "+507", "United States" => "+1",
  # South America
  "Argentina" => "+54", "Bolivia" => "+591", "Brazil" => "+55", "Chile" => "+56",
  "Colombia" => "+57", "Ecuador" => "+593", "Guyana" => "+592", "Paraguay" => "+595",
  "Peru" => "+51", "Suriname" => "+597", "Uruguay" => "+598", "Venezuela" => "+58",
  # Oceania
  "Australia" => "+61", "Fiji" => "+679", "New Zealand" => "+64", "Papua New Guinea" => "+675",
  "Samoa" => "+685", "Tonga" => "+676", "Vanuatu" => "+678"
}.freeze

# "All the national stuff" — feeds the Country Explorer + the anthem/bird/sport
# decks. Fields are filled only where confidently known; missing ones simply
# don't show. National sport/animal are often traditional rather than legally
# official (see the deck note). { country => { anthem:, animal:, bird:, flower:,
# sport:, motto:, dish: } }
NATIONAL_SYMBOLS = {
  "United States"  => { anthem: "The Star-Spangled Banner", animal: "American Bison", bird: "Bald Eagle", flower: "Rose", sport: "Baseball", motto: "In God We Trust", dish: "Hamburger" },
  "India"          => { anthem: "Jana Gana Mana", animal: "Bengal Tiger", bird: "Indian Peacock", flower: "Lotus", sport: "Field Hockey", motto: "Satyameva Jayate" },
  "United Kingdom" => { anthem: "God Save the King", animal: "Lion", bird: "European Robin", motto: "Dieu et mon droit", dish: "Fish and Chips" },
  "France"         => { anthem: "La Marseillaise", animal: "Gallic Rooster", motto: "Liberté, égalité, fraternité", dish: "Baguette" },
  "Germany"        => { anthem: "Deutschlandlied", animal: "Federal Eagle", flower: "Cornflower", motto: "Einigkeit und Recht und Freiheit", dish: "Bratwurst" },
  "Canada"         => { anthem: "O Canada", animal: "Beaver", sport: "Ice Hockey", motto: "A Mari usque ad Mare", dish: "Poutine" },
  "Australia"      => { anthem: "Advance Australia Fair", animal: "Kangaroo", bird: "Emu", flower: "Golden Wattle", dish: "Meat Pie" },
  "Japan"          => { anthem: "Kimigayo", bird: "Green Pheasant", flower: "Cherry Blossom", sport: "Sumo Wrestling", dish: "Sushi" },
  "China"          => { anthem: "March of the Volunteers", animal: "Giant Panda", bird: "Red-crowned Crane", flower: "Peony", sport: "Table Tennis", dish: "Peking Duck" },
  "Russia"         => { anthem: "State Anthem of the Russian Federation", animal: "Brown Bear", flower: "Chamomile", dish: "Borscht" },
  "Brazil"         => { anthem: "Hino Nacional Brasileiro", animal: "Jaguar", bird: "Rufous-bellied Thrush", flower: "Ipê-amarelo", sport: "Football", motto: "Ordem e Progresso", dish: "Feijoada" },
  "Mexico"         => { anthem: "Himno Nacional Mexicano", bird: "Golden Eagle", flower: "Dahlia", sport: "Charrería", dish: "Tacos" },
  "Spain"          => { anthem: "Marcha Real", animal: "Bull", flower: "Carnation", motto: "Plus Ultra", dish: "Paella" },
  "Italy"          => { anthem: "Il Canto degli Italiani", animal: "Italian Wolf", dish: "Pizza" },
  "New Zealand"    => { anthem: "God Defend New Zealand", bird: "Kiwi", flower: "Kōwhai", sport: "Rugby Union" },
  "South Africa"   => { anthem: "Nkosi Sikelel' iAfrika", animal: "Springbok", bird: "Blue Crane", flower: "King Protea" },
  "Egypt"          => { anthem: "Bilady, Bilady, Bilady", bird: "Steppe Eagle", flower: "Egyptian Lotus", dish: "Koshari" },
  "Kenya"          => { anthem: "Ee Mungu Nguvu Yetu", animal: "Lion", bird: "Lilac-breasted Roller", motto: "Harambee", dish: "Ugali" },
  "Nigeria"        => { anthem: "Nigeria, We Hail Thee", bird: "Black Crowned Crane", dish: "Jollof Rice" },
  "Thailand"       => { anthem: "Phleng Chat Thai", animal: "Thai Elephant", bird: "Siamese Fireback", flower: "Golden Shower", sport: "Muay Thai", dish: "Pad Thai" },
  "Indonesia"      => { anthem: "Indonesia Raya", animal: "Komodo Dragon", bird: "Javan Hawk-Eagle", flower: "Jasmine", sport: "Badminton", motto: "Bhinneka Tunggal Ika", dish: "Nasi Goreng" },
  "Philippines"    => { anthem: "Lupang Hinirang", animal: "Carabao", bird: "Philippine Eagle", flower: "Sampaguita", sport: "Arnis", dish: "Adobo" },
  "Pakistan"       => { anthem: "Qaumi Taranah", animal: "Markhor", bird: "Chukar Partridge", flower: "Jasmine", sport: "Field Hockey", motto: "Faith, Unity, Discipline" },
  "Nepal"          => { anthem: "Sayaun Thunga Phulka", animal: "Cow", bird: "Himalayan Monal", flower: "Rhododendron", sport: "Volleyball", dish: "Dal Bhat" },
  "Sri Lanka"      => { anthem: "Sri Lanka Matha", bird: "Sri Lanka Junglefowl", flower: "Blue Water Lily", sport: "Volleyball", dish: "Rice and Curry" },
  "Israel"         => { anthem: "Hatikvah", bird: "Hoopoe", flower: "Cyclamen", dish: "Falafel" },
  "Argentina"      => { anthem: "Himno Nacional Argentino", bird: "Rufous Hornero", flower: "Ceibo", sport: "Pato", dish: "Asado" },
  "Peru"           => { animal: "Vicuña", bird: "Andean Cock-of-the-rock", flower: "Cantuta", dish: "Ceviche" },
  "Colombia"       => { animal: "Andean Condor", bird: "Andean Condor", flower: "Cattleya Orchid", sport: "Tejo", dish: "Bandeja Paisa" },
  "Chile"          => { animal: "Huemul", bird: "Andean Condor", flower: "Copihue", sport: "Rodeo", dish: "Empanada" },
  "Netherlands"    => { anthem: "Wilhelmus", flower: "Tulip", dish: "Stroopwafel" },
  "Sweden"         => { anthem: "Du gamla, du fria", animal: "Moose", bird: "Common Blackbird", flower: "Twinflower", dish: "Swedish Meatballs" },
  "Norway"         => { anthem: "Ja, vi elsker dette landet", bird: "White-throated Dipper", flower: "Purple Heather", sport: "Cross-country Skiing" },
  "Denmark"        => { anthem: "Der er et yndigt land", bird: "Mute Swan", flower: "Marguerite Daisy" },
  "Finland"        => { anthem: "Maamme", animal: "Brown Bear", bird: "Whooper Swan", flower: "Lily of the Valley", sport: "Pesäpallo" },
  "Ireland"        => { anthem: "Amhrán na bhFiann", flower: "Shamrock", sport: "Hurling", dish: "Irish Stew" },
  "Greece"         => { anthem: "Hymn to Liberty", motto: "Freedom or Death", dish: "Moussaka" },
  "Turkey"         => { anthem: "İstiklal Marşı", animal: "Grey Wolf", flower: "Tulip", sport: "Oil Wrestling", dish: "Kebab" },
  "South Korea"    => { anthem: "Aegukga", animal: "Siberian Tiger", bird: "Korean Magpie", flower: "Hibiscus", sport: "Taekwondo", dish: "Kimchi" },
  "Bhutan"         => { anthem: "Druk tsendhen", animal: "Takin", bird: "Raven", flower: "Blue Poppy", sport: "Archery", dish: "Ema Datshi" },
  "Bangladesh"     => { anthem: "Amar Sonar Bangla", animal: "Bengal Tiger", bird: "Oriental Magpie-Robin", flower: "Water Lily", sport: "Kabaddi" },
  "Iran"           => { animal: "Asiatic Cheetah", sport: "Wrestling", dish: "Chelo Kabab" },
  "Cuba"           => { anthem: "La Bayamesa", bird: "Cuban Trogon", flower: "Mariposa", sport: "Baseball" },
  "Ukraine"        => { anthem: "Shche ne vmerla Ukraina", flower: "Sunflower", dish: "Borscht" },
  "Portugal"       => { anthem: "A Portuguesa", animal: "Iberian Wolf", dish: "Bacalhau" },
  "Poland"         => { anthem: "Mazurek Dąbrowskiego", animal: "White-tailed Eagle", flower: "Corn Poppy", dish: "Pierogi" },
  "Switzerland"    => { anthem: "Swiss Psalm", flower: "Edelweiss", dish: "Fondue" },
  "Austria"        => { anthem: "Land der Berge, Land am Strome", bird: "Barn Swallow", flower: "Edelweiss", dish: "Wiener Schnitzel" },
  "Vietnam"        => { anthem: "Tiến Quân Ca", flower: "Lotus", dish: "Phở" }
}.freeze

COUNTRIES.each do |name, capital, iso2, continent|
  title, leader = LEADERS[name]
  ns = NATIONAL_SYMBOLS[name] || {}
  country = Country.find_or_initialize_by(iso2: iso2)
  country.assign_attributes(
    name: name, capital: capital, continent: continent,
    leader_title: title, leader_name: leader, currency_name: CURRENCIES[name],
    primary_language: LANGUAGES[name], calling_code: CALLING_CODES[name],
    national_anthem: ns[:anthem], national_animal: ns[:animal], national_bird: ns[:bird],
    national_flower: ns[:flower], national_sport: ns[:sport], national_motto: ns[:motto],
    national_dish: ns[:dish]
  )
  country.save!
end

# All 50 U.S. states + capitals. [name, capital, abbreviation]
US_STATES = [
  [ "Alabama", "Montgomery", "AL" ], [ "Alaska", "Juneau", "AK" ],
  [ "Arizona", "Phoenix", "AZ" ], [ "Arkansas", "Little Rock", "AR" ],
  [ "California", "Sacramento", "CA" ], [ "Colorado", "Denver", "CO" ],
  [ "Connecticut", "Hartford", "CT" ], [ "Delaware", "Dover", "DE" ],
  [ "Florida", "Tallahassee", "FL" ], [ "Georgia", "Atlanta", "GA" ],
  [ "Hawaii", "Honolulu", "HI" ], [ "Idaho", "Boise", "ID" ],
  [ "Illinois", "Springfield", "IL" ], [ "Indiana", "Indianapolis", "IN" ],
  [ "Iowa", "Des Moines", "IA" ], [ "Kansas", "Topeka", "KS" ],
  [ "Kentucky", "Frankfort", "KY" ], [ "Louisiana", "Baton Rouge", "LA" ],
  [ "Maine", "Augusta", "ME" ], [ "Maryland", "Annapolis", "MD" ],
  [ "Massachusetts", "Boston", "MA" ], [ "Michigan", "Lansing", "MI" ],
  [ "Minnesota", "Saint Paul", "MN" ], [ "Mississippi", "Jackson", "MS" ],
  [ "Missouri", "Jefferson City", "MO" ], [ "Montana", "Helena", "MT" ],
  [ "Nebraska", "Lincoln", "NE" ], [ "Nevada", "Carson City", "NV" ],
  [ "New Hampshire", "Concord", "NH" ], [ "New Jersey", "Trenton", "NJ" ],
  [ "New Mexico", "Santa Fe", "NM" ], [ "New York", "Albany", "NY" ],
  [ "North Carolina", "Raleigh", "NC" ], [ "North Dakota", "Bismarck", "ND" ],
  [ "Ohio", "Columbus", "OH" ], [ "Oklahoma", "Oklahoma City", "OK" ],
  [ "Oregon", "Salem", "OR" ], [ "Pennsylvania", "Harrisburg", "PA" ],
  [ "Rhode Island", "Providence", "RI" ], [ "South Carolina", "Columbia", "SC" ],
  [ "South Dakota", "Pierre", "SD" ], [ "Tennessee", "Nashville", "TN" ],
  [ "Texas", "Austin", "TX" ], [ "Utah", "Salt Lake City", "UT" ],
  [ "Vermont", "Montpelier", "VT" ], [ "Virginia", "Richmond", "VA" ],
  [ "Washington", "Olympia", "WA" ], [ "West Virginia", "Charleston", "WV" ],
  [ "Wisconsin", "Madison", "WI" ], [ "Wyoming", "Cheyenne", "WY" ]
].freeze

US_STATES.each do |name, capital, abbreviation|
  state = UsState.find_or_initialize_by(abbreviation: abbreviation)
  state.assign_attributes(name: name, capital: capital)
  state.save!
end

# Famous landmarks → host country. Border-shared icons (Niagara, Victoria,
# Iguazú falls) are deliberately omitted to keep a single correct answer.
# `continent` matches the host country's continent (for distractor grouping).
# [name (with natural article), country, continent]
LANDMARKS = [
  [ "the Eiffel Tower", "France", "Europe" ],
  [ "the Colosseum", "Italy", "Europe" ],
  [ "the Leaning Tower of Pisa", "Italy", "Europe" ],
  [ "the Trevi Fountain", "Italy", "Europe" ],
  [ "Big Ben", "United Kingdom", "Europe" ],
  [ "Stonehenge", "United Kingdom", "Europe" ],
  [ "the Sagrada Família", "Spain", "Europe" ],
  [ "the Acropolis of Athens", "Greece", "Europe" ],
  [ "the Brandenburg Gate", "Germany", "Europe" ],
  [ "Neuschwanstein Castle", "Germany", "Europe" ],
  [ "Saint Basil's Cathedral", "Russia", "Europe" ],
  [ "Charles Bridge", "Czechia", "Europe" ],
  [ "the Little Mermaid statue", "Denmark", "Europe" ],
  [ "the Taj Mahal", "India", "Asia" ],
  [ "the Great Wall of China", "China", "Asia" ],
  [ "the Forbidden City", "China", "Asia" ],
  [ "Mount Fuji", "Japan", "Asia" ],
  [ "the Tokyo Tower", "Japan", "Asia" ],
  [ "Angkor Wat", "Cambodia", "Asia" ],
  [ "the Petronas Towers", "Malaysia", "Asia" ],
  [ "the Burj Khalifa", "United Arab Emirates", "Asia" ],
  [ "Marina Bay Sands", "Singapore", "Asia" ],
  [ "the Hagia Sophia", "Turkey", "Asia" ],
  [ "Petra", "Jordan", "Asia" ],
  [ "Wat Arun", "Thailand", "Asia" ],
  [ "Borobudur", "Indonesia", "Asia" ],
  [ "the Great Pyramid of Giza", "Egypt", "Africa" ],
  [ "the Great Sphinx of Giza", "Egypt", "Africa" ],
  [ "Table Mountain", "South Africa", "Africa" ],
  [ "Mount Kilimanjaro", "Tanzania", "Africa" ],
  [ "the Great Mosque of Djenné", "Mali", "Africa" ],
  [ "the Statue of Liberty", "United States", "North America" ],
  [ "the Golden Gate Bridge", "United States", "North America" ],
  [ "the Grand Canyon", "United States", "North America" ],
  [ "Mount Rushmore", "United States", "North America" ],
  [ "the CN Tower", "Canada", "North America" ],
  [ "Chichen Itza", "Mexico", "North America" ],
  [ "Teotihuacan", "Mexico", "North America" ],
  [ "Machu Picchu", "Peru", "South America" ],
  [ "Christ the Redeemer", "Brazil", "South America" ],
  [ "the Moai of Easter Island", "Chile", "South America" ],
  [ "the Salar de Uyuni salt flats", "Bolivia", "South America" ],
  [ "Angel Falls", "Venezuela", "South America" ],
  [ "the Galápagos Islands", "Ecuador", "South America" ],
  [ "the Sydney Opera House", "Australia", "Oceania" ],
  [ "Uluru", "Australia", "Oceania" ],
  [ "Milford Sound", "New Zealand", "Oceania" ],
  [ "Hobbiton", "New Zealand", "Oceania" ]
].freeze

LANDMARKS.each do |name, country, continent|
  landmark = Landmark.find_or_initialize_by(name: name)
  landmark.assign_attributes(country: country, continent: continent)
  landmark.save!
end

puts "Geography: #{Country.count} countries (#{Country.with_leader.count} leaders, " \
     "#{Country.with_currency.count} currencies, #{Country.with_language.count} languages, " \
     "#{Country.with_calling_code.count} codes, #{Country.with_anthem.count} anthems, " \
     "#{Country.with_national_bird.count} birds, #{Country.with_national_sport.count} sports), " \
     "#{UsState.count} U.S. states, #{Landmark.count} landmarks"
