# Curated playlist deep links by interest. Each entry returns a Spotify
# *search* URL plus a YouTube fallback — no auth, no API, just public links.
# When the device has the Spotify or YouTube app installed these open
# natively; otherwise the web player.
module RoadTripPlaylists
  Link = Struct.new(:label, :spotify, :youtube, keyword_init: true)

  CATALOG = {
    "math"        => Link.new(label: "Lo-fi study beats", spotify: "lofi%20hip%20hop%20study", youtube: "lofi+hip+hop+study"),
    "science"     => Link.new(label: "Space jams + sci-fi vibes", spotify: "space%20ambient", youtube: "space+ambient+playlist"),
    "space"       => Link.new(label: "Space jams + sci-fi vibes", spotify: "space%20music", youtube: "space+music+playlist"),
    "animals"     => Link.new(label: "Nature + animal sounds", spotify: "nature%20sounds", youtube: "kids+animal+songs"),
    "dinosaurs"   => Link.new(label: "Dinosaur songs for kids", spotify: "dinosaur%20songs%20for%20kids", youtube: "dinosaur+songs+for+kids"),
    "sports"      => Link.new(label: "Pump-up workout mix", spotify: "workout%20pump%20up", youtube: "workout+pump+up+mix"),
    "music"       => Link.new(label: "Indie road trip", spotify: "road%20trip%20indie", youtube: "indie+road+trip"),
    "movies"      => Link.new(label: "Movie soundtracks", spotify: "movie%20soundtracks", youtube: "best+movie+soundtracks"),
    "movies_kids" => Link.new(label: "Disney + Pixar songs", spotify: "disney%20pixar%20kids", youtube: "disney+songs+for+kids"),
    "history"     => Link.new(label: "Hamilton + history hits", spotify: "hamilton", youtube: "hamilton+soundtrack"),
    "geography"   => Link.new(label: "Around the world", spotify: "around%20the%20world", youtube: "world+music+road+trip"),
    "cars"        => Link.new(label: "Classic car cruising", spotify: "classic%20rock%20road%20trip", youtube: "classic+rock+road+trip"),
    "video_games" => Link.new(label: "Epic video game soundtracks", spotify: "video%20game%20soundtrack", youtube: "best+video+game+music"),
    "disney"      => Link.new(label: "Disney sing-along", spotify: "disney%20sing%20along", youtube: "disney+sing+along"),
    "superhero"   => Link.new(label: "Hero anthems", spotify: "marvel%20soundtrack", youtube: "marvel+best+soundtrack"),
    "food"        => Link.new(label: "Cooking + chillout", spotify: "cooking%20jazz", youtube: "jazz+cooking+playlist"),
    "books"       => Link.new(label: "Bookstore café vibes", spotify: "coffee%20shop%20jazz", youtube: "coffee+shop+jazz"),
    "art"         => Link.new(label: "Painter's playlist", spotify: "classical%20focus", youtube: "classical+focus+music"),
    "travel"      => Link.new(label: "Open road anthems", spotify: "road%20trip", youtube: "ultimate+road+trip+playlist"),
    "photography" => Link.new(label: "Cinematic instrumentals", spotify: "cinematic%20instrumental", youtube: "cinematic+instrumental"),
    "cooking"     => Link.new(label: "Italian dinner jazz", spotify: "italian%20dinner", youtube: "italian+dinner+jazz"),
    "gardening"   => Link.new(label: "Garden chill", spotify: "garden%20chill", youtube: "garden+chill+playlist")
  }.freeze

  GENERIC = Link.new(label: "Family road trip", spotify: "family%20road%20trip", youtube: "family+road+trip+songs")

  def self.spotify_url(query)
    "https://open.spotify.com/search/#{query}"
  end

  def self.youtube_url(query)
    "https://www.youtube.com/results?search_query=#{query}"
  end

  def self.for_person(person)
    person.interests.each do |tag|
      link = CATALOG[tag]
      return link if link
    end
    GENERIC
  end
end
