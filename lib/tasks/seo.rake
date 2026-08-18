# frozen_string_literal: true

namespace :seo do
  desc "Submit every public URL (blog, road trips, quizzes, places) to IndexNow (Bing/DDG/Yandex)"
  task indexnow_all: :environment do
    IndexNow.ensure_key!
    urls = IndexNow.all_public_urls
    res = IndexNow.submit(urls)
    puts "IndexNow: #{res.status} — submitted #{res.submitted}/#{urls.size} url(s) (enabled=#{IndexNow.enabled?})"
  end

  desc "Print the public URL inventory the sitemaps expose"
  task urls: :environment do
    puts IndexNow.all_public_urls
  end
end
