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

  # Alert every trip member that a tracked flight's status changed (gate/delay/
  # cancellation). `changes` is a short list of human phrases from
  # PollFlightStatusJob. One notification per member per change batch.
  def self.flight_status_changed(reservation, changes)
    trip = reservation.trip
    return if trip.nil? || Array(changes).empty?

    label = [ reservation.flight_number.presence, reservation.headline ].compact.uniq.join(" · ")
    body  = "#{label}: #{Array(changes).join(', ')} (#{trip.title})"
    url   = Rails.application.routes.url_helpers.trip_path(trip)

    trip.trip_memberships.find_each do |m|
      Notification.create!(
        recipient_id: m.user_id, subject: reservation, kind: "flight_status", url: url, body: body
      )
    end
  end

  # Tell the ticket owner their support question got a reply — whether the AI
  # answered it directly (`support_answered`) or an admin followed up
  # (`support_reply`).
  def self.support_answered(ticket, kind: "support_answered")
    Notification.create!(
      recipient_id: ticket.user_id,
      subject:      ticket,
      kind:         kind,
      url:          Rails.application.routes.url_helpers.support_ticket_path(ticket),
      body:         "We replied to your support request: #{ticket.subject}"
    )
  end

  # Ping every admin that a ticket needs a human. A drafted reply is already
  # waiting on the ticket (admin_draft) for them to review, edit, and send.
  def self.support_escalated(ticket)
    url = Rails.application.routes.url_helpers.admin_support_ticket_path(ticket)
    User.where(admin: true).find_each do |admin|
      Notification.create!(
        recipient_id: admin.id,
        actor_id:     ticket.user_id,
        subject:      ticket,
        kind:         "support_escalated",
        url:          url,
        body:         "Support ticket needs you: #{ticket.subject} (#{ticket.escalation_reason.presence || 'flagged by AI'})"
      )
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

  # Tell the sharer that someone saved their trip and both earned a bonus build.
  def self.referral_credit(credit)
    return unless credit
    Notification.find_or_create_by!(recipient_id: credit.referrer_id, actor_id: credit.referee_id, subject: credit, kind: "referral_credit") do |n|
      n.url  = Rails.application.routes.url_helpers.trips_path
      n.body = "#{credit.referee.display_name} saved your shared trip#{credit.trip ? " “#{credit.trip.title}”" : ""} — you both earned an extra AI build this month."
    end
  end
end
