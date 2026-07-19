# Imports the legacy file-based blog posts (app/views/blog/posts/*.md, YAML-ish
# front matter + Markdown body) into `blog_posts` rows. Idempotent by slug —
# existing rows are left alone unless `force:` is passed. Run by db/seeds/blog.rb
# so a fresh DB keeps the live posts; the .md files stay as the import source.
class BlogImporter
  POSTS_DIR = Rails.root.join("app/views/blog/posts").freeze

  def self.call(...) = new(...).call

  def initialize(force: false)
    @force = force
  end

  # Returns the list of slugs imported (created or, with force:, updated).
  def call
    Dir.glob(POSTS_DIR.join("*.md")).sort.filter_map { |path| import(path) }
  end

  private

  def import(path)
    slug = File.basename(path, ".md")
    post = BlogPost.find_or_initialize_by(slug: slug)
    return nil if post.persisted? && !@force

    attrs, body = parse(File.read(path))
    published_on = parse_date(attrs["published_on"])

    post.assign_attributes(
      title:           attrs["title"].to_s,
      excerpt:         attrs["excerpt"],
      body:            body.to_s.strip,
      author_name:     attrs["author"],
      cover_image_url: attrs["cover"],
      tags:            Array(attrs["tag"]).map(&:to_s).reject(&:blank?),
      reading_minutes: attrs["reading_minutes"].presence&.to_i,
      status:          "published",
      published_at:    published_on&.to_time || Time.current
    )
    post.save! ? slug : nil
  end

  def parse(raw)
    if raw =~ /\A---\s*\n(.*?)\n---\s*\n(.*)\z/m
      [ parse_front_matter(Regexp.last_match(1)), Regexp.last_match(2) ]
    else
      [ {}, raw ]
    end
  end

  def parse_front_matter(text)
    text.each_line.with_object({}) do |line, acc|
      key, _, value = line.partition(":")
      next if key.blank?
      acc[key.strip] = value.strip
    end
  end

  def parse_date(str)
    return nil if str.blank?
    Date.parse(str)
  rescue ArgumentError
    nil
  end
end
