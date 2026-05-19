class TripPresenceTracker
  # Rails.cache-backed presence: one entry per (trip, user) with a 60s TTL.
  # The Stimulus controller pings every 25s; viewers naturally drop off the
  # list one TTL after their last ping. Works on Solid Cache (DB) without
  # needing Redis.
  TTL = 60.seconds

  def self.touch(trip_id:, user_id:)
    Rails.cache.write(key_for(trip_id, user_id), Time.current.to_i, expires_in: TTL)
  end

  def self.remove(trip_id:, user_id:)
    Rails.cache.delete(key_for(trip_id, user_id))
  end

  # Live viewers right now — returns the User rows currently in the cache
  # for this trip. Skips the requesting user so each viewer sees "others
  # also viewing," not themselves.
  def self.viewers_for(trip, excluding: nil)
    member_ids = trip.trip_memberships.pluck(:user_id)
    return User.none if member_ids.empty?

    live = member_ids.select { |uid| Rails.cache.exist?(key_for(trip.id, uid)) }
    live -= [ excluding.id ] if excluding
    User.where(id: live)
  end

  def self.key_for(trip_id, user_id)
    "presence:trip:#{trip_id}:#{user_id}"
  end
end
