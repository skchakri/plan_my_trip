class TripPresenceChannel < ApplicationCable::Channel
  # subscribe-side ping per trip. Client opens this channel when the user
  # lands on /trips/:id or /trips/:id/plan, sends `ping` every 25s, and
  # we broadcast the refreshed viewer list to every subscriber.
  def subscribed
    trip = Trip.kept.find_by(id: params[:trip_id])
    return reject unless trip&.shared_with?(current_user)

    @trip = trip
    stream_for trip
    TripPresenceTracker.touch(trip_id: trip.id, user_id: current_user.id)
    broadcast_viewers
  end

  def unsubscribed
    return unless @trip
    TripPresenceTracker.remove(trip_id: @trip.id, user_id: current_user.id)
    broadcast_viewers
  end

  def ping(_payload = nil)
    return unless @trip
    TripPresenceTracker.touch(trip_id: @trip.id, user_id: current_user.id)
    broadcast_viewers
  end

  private

  def broadcast_viewers
    viewers = TripPresenceTracker.viewers_for(@trip).map do |u|
      { id: u.id, name: u.display_name, initials: u.display_name.to_s.split(/\s+/).first(2).map { |w| w[0] }.join.upcase }
    end
    TripPresenceChannel.broadcast_to(@trip, viewers: viewers)
  end
end
