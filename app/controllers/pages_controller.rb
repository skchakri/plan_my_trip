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
  def sitemap
    @posts = BlogPost.all
    respond_to do |format|
      format.xml { render layout: false }
    end
  end
end
