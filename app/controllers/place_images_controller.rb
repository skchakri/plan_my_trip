require "base64"

# Lazy image resolver for highlight cards that have no Wikimedia photo. The card
# points an <img> here; it loads after the page so it never blocks the (slow)
# highlights research. Cache hit -> 302 to the resolved stock photo; miss ->
# enqueue a background resolve and return a 1x1 transparent pixel so the card's
# gradient/icon fallback shows until the photo fills in on a later view.
class PlaceImagesController < ApplicationController
  # 1x1 transparent GIF.
  PIXEL = Base64.decode64("R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7").freeze

  def show
    name = params[:q].to_s.strip
    return render_pixel if name.blank?

    cached = Rails.cache.read(ResolvePlaceImageJob.cache_key(name))
    if cached.to_s.start_with?("http")
      expires_in 30.days, public: true
      redirect_to cached, allow_other_host: true
    else
      enqueue_resolve(name) if cached.nil? # nil = never resolved; "none" = resolved-empty
      render_pixel
    end
  end

  private

  # Enqueue at most once per name per 10 minutes (fetch dedupes the enqueue).
  def enqueue_resolve(name)
    Rails.cache.fetch("#{ResolvePlaceImageJob.cache_key(name)}/pending", expires_in: 10.minutes) do
      ResolvePlaceImageJob.perform_later(name, params[:d].to_s.presence)
      true
    end
  end

  def render_pixel
    expires_in 30.seconds, public: false # short, so the resolved photo appears on a later request
    send_data PIXEL, type: "image/gif", disposition: "inline"
  end
end
