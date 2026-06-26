class ChecklistItemsController < ApplicationController
  before_action :set_trip
  before_action :set_item, only: %i[update destroy]
  before_action :set_discarded_item, only: %i[restore]

  def create
    authorize @trip, :update?
    attrs = item_params.merge(packed: false)
    attrs[:scope] = "before_trip" if attrs[:scope].blank?
    @item = @trip.checklist_items.create!(attrs)
    redirect_to checklist_trip_path(@trip), notice: "Added \"#{@item.title}\""
  end

  def update
    authorize @trip, :update?
    @item.update!(item_params)
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to checklist_trip_path(@trip), notice: "Updated \"#{@item.title}\"" }
    end
  end

  # Soft-delete so it can be undone. The row vanishes via Turbo + an undo bar
  # is rendered into #checklist-flash.
  def destroy
    authorize @trip, :update?
    @item.discard
    respond_to do |format|
      format.turbo_stream { render :destroy }
      format.html { redirect_to checklist_trip_path(@trip), notice: "Removed \"#{@item.title}\"" }
    end
  end

  # Undo a soft-delete. Full reload re-inserts the row in its original section.
  def restore
    authorize @trip, :update?
    @item.undiscard
    redirect_to checklist_trip_path(@trip), notice: "Restored \"#{@item.title}\""
  end

  private

  def set_trip
    @trip = Trip.kept.find(params[:trip_id])
  end

  def set_item
    @item = @trip.checklist_items.kept.find(params[:id])
  end

  def set_discarded_item
    @item = @trip.checklist_items.discarded.find(params[:id])
  end

  def item_params
    params.require(:checklist_item).permit(:title, :person, :category, :position, :packed, :scope, :day_label, :activity_label)
  end
end
