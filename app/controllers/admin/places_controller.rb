module Admin
  class PlacesController < BaseController
    before_action :set_place, only: [ :show, :edit, :update, :destroy, :verify ]

    def index
      @scope = (params[:scope].presence_in(%w[all kept discarded verified unverified no_image]) || "kept")
      scope = case @scope
      when "all"        then Place.all
      when "discarded"  then Place.discarded
      when "verified"   then Place.verified
      when "unverified" then Place.kept.where(verified: false)
      when "no_image"   then Place.kept.where(image_url: nil)
      else Place.kept
      end

      if params[:q].present?
        like = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q])}%"
        scope = scope.where("name ILIKE ? OR canonical_name ILIKE ?", like, like)
      end
      scope = scope.where(kind: params[:kind]) if params[:kind].present?

      @places = scope.order(usage_count: :desc, created_at: :desc).limit(200)
      @stats = {
        total: Place.count,
        kept: Place.kept.count,
        verified: Place.verified.count,
        with_image: Place.with_image.count
      }
    end

    def show
      @recent_activities = Activity.where(place_id: @place.id)
                                   .joins(trip_day: :trip)
                                   .includes(trip_day: :trip)
                                   .order(created_at: :desc)
                                   .limit(50)
    end

    def edit; end

    def update
      if @place.update(place_params)
        redirect_to admin_place_path(@place), notice: "Place updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @place.discard
      redirect_to admin_places_path, notice: "Place discarded."
    end

    def verify
      @place.update!(verified: !@place.verified)
      redirect_to admin_place_path(@place), notice: @place.verified ? "Marked verified." : "Verification removed."
    end

    private

    def set_place
      @place = Place.find(params[:id])
    end

    def place_params
      params.require(:place).permit(:name, :canonical_name, :kind, :description, :famous_for,
                                    :image_url, :image_source, :image_attribution,
                                    :latitude, :longitude, :verified)
    end
  end
end
