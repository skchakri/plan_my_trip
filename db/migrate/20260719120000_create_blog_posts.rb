class CreateBlogPosts < ActiveRecord::Migration[8.1]
  def change
    create_table :blog_posts, id: :uuid do |t|
      t.string   :title,           null: false
      t.string   :slug,            null: false
      t.text     :excerpt
      t.text     :body,            null: false
      t.string   :status,          null: false, default: "draft"
      t.datetime :published_at
      t.string   :cover_image_url
      t.string   :tags, array: true, default: [], null: false
      t.string   :author_name
      t.string   :seo_description
      t.integer  :reading_minutes
      t.datetime :discarded_at
      t.timestamps
    end

    add_index :blog_posts, :slug, unique: true
    add_index :blog_posts, :status
    add_index :blog_posts, :published_at
    add_index :blog_posts, :discarded_at
    add_index :blog_posts, :tags, using: :gin
  end
end
