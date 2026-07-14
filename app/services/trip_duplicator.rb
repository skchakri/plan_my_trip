class TripDuplicator
  # Whitelist of Trip columns we copy. Anything else (timestamps, share_token,
  # share_revoked_at, owner_id) is intentionally excluded so future migrations
  # don't accidentally leak per-trip state into clones.
  COPYABLE_TRIP_FIELDS = %w[
    title destination origin body pwa_plan_url pwa_packing_url
    traveler_count transport_mode must_includes vehicle_mpg departure_time return_time
    day_trip max_radius_km interests anchor_label anchor_lat anchor_lng
    excitement_pitch
  ].freeze

  COPYABLE_DAY_FIELDS      = %w[label title accent summary theme position].freeze
  COPYABLE_ACTIVITY_FIELDS = %w[
    time_label title location_name address photo_url notes group_label
    maps_url uber_url position latitude longitude famous_for guide_script place_id
  ].freeze
  COPYABLE_CHECKLIST_FIELDS = %w[
    title category person day_label activity_label position scope
  ].freeze
  COPYABLE_PERSON_FIELDS   = %w[name interests position age].freeze
  COPYABLE_TRAIL_FIELDS    = %w[name alltrails_url notes position].freeze
  COPYABLE_LANDMARK_FIELDS = %w[
    name kind latitude longitude narration image_url wikipedia_url position source
  ].freeze

  def initialize(source:, owner:, new_title: nil, new_start_date: nil)
    @source = source
    @owner  = owner
    @new_title      = new_title.presence || "Copy of #{source.title}"
    @new_start_date = new_start_date
  end

  def call
    Trip.transaction do
      trip = build_trip
      trip.save!
      clone_people(trip)
      clone_trails(trip)
      day_map = clone_days(trip)
      clone_activities(day_map)
      clone_checklist_items(trip)
      clone_route_landmarks(trip)
      trip
    end
  end

  private

  attr_reader :source, :owner, :new_title, :new_start_date

  # Number of days to shift every date by. Zero when no new start date is
  # given — checklist day_labels and trip_day.date stay aligned.
  def date_shift
    return @date_shift if defined?(@date_shift)
    @date_shift =
      if new_start_date.present? && source.start_date.present?
        (new_start_date.to_date - source.start_date.to_date).to_i
      else
        0
      end
  end

  def build_trip
    attrs = source.attributes.slice(*COPYABLE_TRIP_FIELDS)
    attrs["title"] = new_title
    if date_shift != 0
      attrs["start_date"] = source.start_date + date_shift.days if source.start_date
      attrs["end_date"]   = source.end_date   + date_shift.days if source.end_date
    else
      attrs["start_date"] = source.start_date
      attrs["end_date"]   = source.end_date
    end
    owner.owned_trips.build(attrs)
  end

  def clone_people(trip)
    source.people.find_each do |p|
      trip.people.create!(p.attributes.slice(*COPYABLE_PERSON_FIELDS))
    end
  end

  def clone_trails(trip)
    source.trails.find_each do |t|
      trip.trails.create!(t.attributes.slice(*COPYABLE_TRAIL_FIELDS))
    end
  end

  # Returns { source_day_id => new_day } so activity cloning can stitch
  # children back to their cloned parent in a single pass.
  def clone_days(trip)
    source.trip_days.order(:position).each_with_object({}) do |day, map|
      attrs = day.attributes.slice(*COPYABLE_DAY_FIELDS)
      attrs["date"] = day.date + date_shift.days if day.respond_to?(:date) && day.date
      map[day.id] = trip.trip_days.create!(attrs)
    end
  end

  def clone_activities(day_map)
    source.trip_days.includes(activities: { photos_attachments: :blob }).each do |source_day|
      new_day = day_map[source_day.id]
      source_day.activities.order(:position).each do |a|
        new_activity = new_day.activities.create!(a.attributes.slice(*COPYABLE_ACTIVITY_FIELDS))
        # Attach existing blobs — Active Storage just makes new attachment rows
        # pointing at the same blob, so no re-upload.
        a.photos.each { |photo| new_activity.photos.attach(photo.blob) } if a.photos.attached?
      end
    end
  end

  def clone_checklist_items(trip)
    # Day labels stay the same string — we shifted dates but not labels, so
    # day-scoped items still anchor correctly to their cloned trip_days.
    source.checklist_items.kept.find_each do |item|
      attrs = item.attributes.slice(*COPYABLE_CHECKLIST_FIELDS).merge("packed" => false)
      trip.checklist_items.create!(attrs)
    end
  end

  def clone_route_landmarks(trip)
    # Only trip-scoped landmarks clone; the global catalog (trip_id IS NULL)
    # is shared, not duplicated.
    source.route_landmarks.kept.where.not(trip_id: nil).find_each do |lm|
      trip.route_landmarks.create!(lm.attributes.slice(*COPYABLE_LANDMARK_FIELDS))
    end
  end
end
