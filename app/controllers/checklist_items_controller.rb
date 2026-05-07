class ChecklistItemsController < ApplicationController
  before_action :set_trip
  before_action :set_item, only: %i[update destroy]

  def create
    authorize @trip, :show?
    attrs = item_params.merge(packed: false)
    attrs[:scope] = "before_trip" if attrs[:scope].blank?
    @item = @trip.checklist_items.create!(attrs)
    redirect_to checklist_trip_path(@trip), notice: "Added \"#{@item.title}\""
  end

  def update
    authorize @trip, :show?
    @item.update!(item_params)
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to checklist_trip_path(@trip) }
    end
  end

  def destroy
    authorize @trip, :show?
    @item.destroy
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(@item) }
      format.html { redirect_to checklist_trip_path(@trip) }
    end
  end

  private

  def set_trip
    @trip = Trip.kept.find(params[:trip_id])
  end

  def set_item
    @item = @trip.checklist_items.find(params[:id])
  end

  def item_params
    params.require(:checklist_item).permit(:title, :person, :category, :position, :packed, :scope, :day_label, :activity_label)
  end
end
