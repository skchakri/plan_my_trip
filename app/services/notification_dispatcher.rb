class NotificationDispatcher
  # Notify every trip member except the actor that a comment was posted.
  # Idempotent on the same `(recipient, subject, kind)` within the same
  # second — guards against double-create on accidental form re-submits.
  def self.comment_posted(comment)
    trip = comment.trip
    return unless trip
    url  = Rails.application.routes.url_helpers.plan_trip_path(trip, anchor: "activity-#{comment.activity_id}")

    # 1. Personal `comment_mention` for each @-tagged trip member (not the
    #    author themselves). These outrank the generic notification.
    mentioned_ids = MentionParser.new(trip).mentioned_users(comment.body).map(&:id) - [ comment.author_id ]
    mentioned_ids.each do |uid|
      Notification.find_or_create_by!(
        recipient_id: uid, actor_id: comment.author_id, subject: comment, kind: "comment_mention"
      ) do |n|
        n.url  = url
        n.body = "#{comment.author.display_name} mentioned you on #{comment.activity.title} (#{trip.title})"
      end
    end

    # 2. Generic `comment_posted` for everyone else on the trip.
    skip_ids = mentioned_ids + [ comment.author_id ]
    trip.trip_memberships.where.not(user_id: skip_ids).find_each do |m|
      Notification.find_or_create_by!(
        recipient_id: m.user_id, actor_id: comment.author_id, subject: comment, kind: "comment_posted"
      ) do |n|
        n.url  = url
        n.body = "#{comment.author.display_name} commented on #{comment.activity.title} (#{trip.title})"
      end
    end
  end

  # Notify the trip owner when someone accepts a share invitation.
  def self.trip_share_accepted(membership)
    return if membership.user_id == membership.trip.owner_id

    Notification.create!(
      recipient_id: membership.trip.owner_id,
      actor_id:     membership.user_id,
      subject:      membership.trip,
      kind:         "trip_share_accepted",
      url:          Rails.application.routes.url_helpers.trip_path(membership.trip),
      body:         "#{membership.user.display_name} accepted your invite to #{membership.trip.title}"
    )
  end
end
