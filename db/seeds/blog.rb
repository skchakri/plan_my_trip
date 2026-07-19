# Import the file-based blog posts (app/views/blog/posts/*.md) into blog_posts.
# Idempotent — skips slugs already present. Loaded by db/seeds.rb.
imported = BlogImporter.call
puts "Blog posts: #{BlogPost.count} total (#{imported.any? ? "imported #{imported.join(', ')}" : 'none new'})"
