# frozen_string_literal: true

namespace :pins do
  desc "Export published road trips as JSON for bin/generate-pins (Pinterest cards)"
  task export: :environment do
    puts RoadTrip.published.ordered.map { |rt|
      rt.slice(:slug, :title, :hero_image_url, :distance_label, :drive_time_label, :suggested_days).merge("stops" => rt.stops)
    }.to_json
  end
end
