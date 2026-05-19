class PublicPlacesController < ApplicationController
  layout "marketing"
  skip_before_action :authenticate_user!

  # GET /p/:slug — SEO-indexed public landing for a single Place.
  def show
    @place = Place.kept.find_by!(slug: params[:slug])
    @nearby = Place
      .near(@place.latitude, @place.longitude, radius_m: 50_000)
      .with_image
      .where.not(id: @place.id)
      .order(usage_count: :desc)
      .limit(6)
  rescue ActiveRecord::RecordNotFound
    render :not_found, status: :not_found
  end

  # GET /places-sitemap.xml — every kept place with a slug and an image,
  # capped at 50k URLs per the sitemap spec.
  def sitemap
    @places = Place
      .kept
      .where.not(slug: nil)
      .where.not(image_url: nil)
      .order(usage_count: :desc, updated_at: :desc)
      .limit(50_000)
    respond_to do |format|
      format.xml { render layout: false }
    end
  end
end
