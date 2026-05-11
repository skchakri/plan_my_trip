# File-based blog posts — each post is a Markdown file in
# app/views/blog/posts/<slug>.md with a YAML-ish front matter block:
#
#   ---
#   title: Why we built Plan My Trip
#   excerpt: A short summary used on the index page.
#   author: Kalyan Setti
#   published_on: 2026-05-01
#   cover: https://images.unsplash.com/photo-...?w=1200
#   reading_minutes: 4
#   tag: Behind the scenes
#   ---
#   # Body...
#
# Kept file-based on purpose: posts are content, not data — versioned
# with the app, edited like code, no DB roundtrips.
class BlogPost
  POSTS_DIR = Rails.root.join("app/views/blog/posts").freeze

  attr_reader :slug, :title, :excerpt, :author, :published_on, :cover,
              :reading_minutes, :tag, :body

  def self.all
    Dir.glob(POSTS_DIR.join("*.md")).map { |path| load(path) }
       .sort_by { |p| p.published_on || Date.new(1970, 1, 1) }
       .reverse
  end

  def self.find(slug)
    path = POSTS_DIR.join("#{slug}.md")
    return nil unless File.exist?(path)
    load(path)
  end

  def self.load(path)
    raw = File.read(path)
    if raw =~ /\A---\s*\n(.*?)\n---\s*\n(.*)\z/m
      meta, body = Regexp.last_match(1), Regexp.last_match(2)
      attrs = parse_front_matter(meta)
    else
      attrs = {}
      body  = raw
    end
    new(
      slug: File.basename(path, ".md"),
      title: attrs["title"],
      excerpt: attrs["excerpt"],
      author: attrs["author"],
      published_on: parse_date(attrs["published_on"]),
      cover: attrs["cover"],
      reading_minutes: attrs["reading_minutes"]&.to_i,
      tag: attrs["tag"],
      body: body
    )
  end

  def self.parse_front_matter(text)
    text.each_line.with_object({}) do |line, acc|
      key, _, value = line.partition(":")
      next if key.blank?
      acc[key.strip] = value.strip
    end
  end

  def self.parse_date(str)
    return nil if str.blank?
    Date.parse(str)
  rescue ArgumentError
    nil
  end

  def initialize(slug:, title:, excerpt:, author:, published_on:, cover:, reading_minutes:, tag:, body:)
    @slug = slug
    @title = title
    @excerpt = excerpt
    @author = author
    @published_on = published_on
    @cover = cover
    @reading_minutes = reading_minutes
    @tag = tag
    @body = body
  end

  def to_param
    slug
  end
end
