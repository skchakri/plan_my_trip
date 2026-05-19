class TripTemplatesController < ApplicationController
  # POST /trip_templates/:key/use — materialise the named template into
  # the current user's trips and send them straight to the editor.
  def use
    template = TripTemplate.new(params[:key])
    trip = template.build_for(current_user)
    redirect_to edit_trip_path(trip),
                notice: "Started \"#{trip.title}\" from a template. Tweak the days, dates, and people, then share it with your crew."
  rescue ActiveRecord::RecordNotFound
    redirect_to trips_path, alert: "We don't have that template anymore."
  end
end
