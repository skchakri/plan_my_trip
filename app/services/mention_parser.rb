class MentionParser
  # Match @ followed by 1–32 word/dash chars, lookbehind to skip emails &
  # already-tokenised handles (so "alice@example.com" doesn't false-positive).
  MENTION_RE = /(?<![\w@])@([\w-]{1,32})/

  attr_reader :trip

  def initialize(trip)
    @trip = trip
  end

  # Returns the de-duplicated list of @-tokens (without the @) found in text.
  def tokens_in(text)
    text.to_s.scan(MENTION_RE).flatten.map(&:downcase).uniq
  end

  # Users on this trip whose first-name (or full display name normalised)
  # matches any @token in text. Used by the dispatcher to send per-mention
  # notifications.
  def mentioned_users(text)
    tokens = tokens_in(text)
    return User.none if tokens.empty?

    member_users = User.where(id: trip.trip_memberships.select(:user_id))
    member_users.select { |u| token_match?(tokens, u) }
  end

  # Render text with @tokens that match a Person/User wrapped in a span.
  # HTML-escapes everything else. Returns html_safe.
  def render_html(text)
    return "".html_safe if text.blank?

    name_set = known_names
    escaped  = ERB::Util.html_escape(text.to_s)
    escaped.gsub(MENTION_RE) do |match|
      token = Regexp.last_match(1).downcase
      if name_set.include?(token)
        %(<span class="px-1 rounded bg-amber-500/20 text-amber-200 font-medium">@#{Regexp.last_match(1)}</span>)
      else
        match
      end
    end.html_safe
  end

  private

  # Lower-cased first names + full display name slugs for everyone the
  # author can plausibly mention: trip members (Users) and trip Persons.
  def known_names
    @known_names ||= begin
      from_users   = trip.members.flat_map { |u| name_variants(u.display_name) }
      from_people  = trip.people.flat_map  { |p| name_variants(p.name) }
      (from_users + from_people).reject(&:blank?).to_set
    end
  end

  def token_match?(tokens, user)
    variants = name_variants(user.display_name)
    (tokens & variants).any?
  end

  def name_variants(name)
    s = name.to_s.downcase.strip
    return [] if s.blank?
    first = s.split(/\s+/).first
    [ first, s.parameterize.tr("-", "") ].uniq
  end
end
