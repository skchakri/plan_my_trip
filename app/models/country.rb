class Country < ApplicationRecord
  validates :name, :capital, :iso2, presence: true
  validates :iso2, length: { is: 2 }

  # Countries with a known head of state/government — the pool for the
  # "World Leaders" quiz. The rest still power capitals and flags.
  scope :with_leader,        -> { where.not(leader_name: [ nil, "" ]) }
  scope :with_currency,      -> { where.not(currency_name: [ nil, "" ]) }
  scope :with_language,      -> { where.not(primary_language: [ nil, "" ]) }
  scope :with_calling_code,  -> { where.not(calling_code: [ nil, "" ]) }
  scope :with_anthem,        -> { where.not(national_anthem: [ nil, "" ]) }
  scope :with_national_bird, -> { where.not(national_bird: [ nil, "" ]) }
  scope :with_national_sport, -> { where.not(national_sport: [ nil, "" ]) }
  scope :alphabetical,       -> { order(:name) }

  # Best-effort: find the country named in a free-text destination string
  # ("Paris, France" -> France, "Tokyo, Japan" -> Japan). Matches whole words
  # so "Chad" doesn't match "Chadds Ford". Prefers the longest name match.
  def self.for_destination(text)
    str = text.to_s.downcase
    return nil if str.blank?
    order(Arel.sql("length(name) DESC")).find do |c|
      str.match?(/\b#{Regexp.escape(c.name.downcase)}\b/)
    end
  end

  # flagcdn.com serves free flag PNGs keyed by the lowercase alpha-2 code.
  # Supported widths: 20,40,80,160,320,640,1280,2560.
  def flag_url(width: 320)
    "https://flagcdn.com/w#{width}/#{iso2.downcase}.png"
  end

  # Internet ccTLD — equals the ISO alpha-2 for every country except the UK,
  # which uses .uk rather than its ISO code .gb.
  def tld
    iso2.casecmp?("gb") ? ".uk" : ".#{iso2.downcase}"
  end

  # Ordered (label, value, icon) rows for the Country Explorer fact-sheet.
  # Only rows with a value are kept, so partially-filled countries degrade
  # gracefully.
  def fact_rows
    [
      [ "Capital",         capital,          :map_pin ],
      [ "Continent",       continent,        :map ],
      [ "Currency",        currency_name,    :coins ],
      [ "Main language",   primary_language, :languages ],
      [ "Dialing code",    calling_code,     :phone ],
      [ "Internet domain", tld,              :link ],
      [ leader_title.presence || "Leader", leader_name, :crown ],
      [ "National anthem", national_anthem,  :music ],
      [ "National animal", national_animal,  :compass ],
      [ "National bird",   national_bird,    :bird ],
      [ "National flower", national_flower,  :sparkles ],
      [ "National sport",  national_sport,   :trophy ],
      [ "National motto",  national_motto,   :star ],
      [ "National dish",   national_dish,    :ticket ]
    ].select { |(_, value, _)| value.present? }
  end
end
