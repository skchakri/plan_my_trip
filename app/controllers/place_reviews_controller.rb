# Review create/destroy from the dedicated /places/:id page. The modal
# quick-rate uses PlacesController#rate (a single endpoint that does
# find-or-create + upsert). This controller is the form-post analog for
# the full place page.
class PlaceReviewsController < ApplicationController
  before_action :load_place

  def create
    review = PlaceReview.where(place_id: @place.id, author_id: current_user.id).kept.first ||
             PlaceReview.new(place_id: @place.id, author_id: current_user.id)
    review.assign_attributes(review_params)
    if review.save
      redirect_to place_path(@place.slug.presence || @place.id), notice: "Thanks — your review is live."
    else
      redirect_to place_path(@place.slug.presence || @place.id), alert: review.errors.full_messages.first
    end
  end

  def destroy
    review = PlaceReview.kept.find(params[:id])
    return head(:forbidden) unless review.author_id == current_user.id
    review.discard
    redirect_to place_path(@place.slug.presence || @place.id), notice: "Review removed."
  end

  private

  def load_place
    @place = Place.kept.find_by(slug: params[:place_id]) || Place.kept.find(params[:place_id])
  end

  def review_params
    params.require(:place_review).permit(:rating, :body)
  end
end
