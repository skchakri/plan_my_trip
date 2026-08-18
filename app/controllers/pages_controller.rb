class PagesController < ApplicationController
  skip_before_action :authenticate_user!
  layout "marketing"

  def landing
  end

  def about
  end

  def privacy
  end

  # Site-wide sitemap: marketing pages + blog posts. Place landing pages
  # have their own (larger) sitemap at /places-sitemap.xml; robots.txt
  # lists both.
  # IndexNow key file: GET /<key>.txt must return the key as plain text.
  def indexnow_key
    key = IndexNow.key
    return head :not_found unless key.present? && ActiveSupport::SecurityUtils.secure_compare(key, params[:key].to_s)

    render plain: key, content_type: "text/plain"
  end

  def sitemap
    @posts = BlogPost.published.recent
    @road_trips = RoadTrip.published.ordered
    @quiz_keys = QuizCatalog.keys
    respond_to do |format|
      format.xml { render layout: false }
    end
  end
end
