require "test_helper"

class AnswerSupportTicketJobTest < ActiveJob::TestCase
  setup do
    @user  = User.create!(email: "u-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Traveler")
    @admin = User.create!(email: "a-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Admin", admin: true)
    @ticket = @user.support_tickets.create!(subject: "How do I share a trip?")
    @ticket.support_messages.create!(role: "user", body: "How do I share a trip with my wife?", author: @user)
  end

  test "confident answer is posted to the user and they are notified" do
    with_fake_ai({ "reply" => "Open the trip and tap Share, then enter her email.",
                   "needs_human" => false, "reason" => "", "confidence" => "high" }) do
      AnswerSupportTicketJob.perform_now(@ticket.id)
    end

    @ticket.reload
    assert_equal "ai_answered", @ticket.status
    assert_equal 1, @ticket.ai_attempts
    assert_equal "assistant", @ticket.support_messages.ordered.last.role
    assert_includes @ticket.support_messages.ordered.last.body, "tap Share"
    assert Notification.exists?(recipient: @user, kind: "support_answered")
    refute Notification.exists?(kind: "support_escalated")
  end

  test "flagged ticket is escalated with a draft and admins are notified, user not messaged" do
    with_fake_ai({ "reply" => "I've asked our team to process your refund.",
                   "needs_human" => true, "reason" => "refund request", "confidence" => "low" }) do
      AnswerSupportTicketJob.perform_now(@ticket.id)
    end

    @ticket.reload
    assert_equal "escalated", @ticket.status
    assert_equal "refund request", @ticket.escalation_reason
    assert_includes @ticket.admin_draft, "refund"
    # No assistant message went out to the user.
    assert_equal %w[user], @ticket.support_messages.ordered.map(&:role)
    assert Notification.exists?(recipient: @admin, kind: "support_escalated")
    refute Notification.exists?(recipient: @user, kind: "support_answered")
  end

  test "does nothing when the ticket is no longer open" do
    @ticket.update!(status: "resolved")
    with_fake_ai({ "reply" => "x", "needs_human" => false, "reason" => "", "confidence" => "high" }) do
      AnswerSupportTicketJob.perform_now(@ticket.id)
    end
    assert_equal "resolved", @ticket.reload.status
    assert_equal 0, @ticket.ai_attempts
  end

  test "hourly fan-out enqueues one worker per open ticket" do
    other = @user.support_tickets.create!(subject: "Another")
    other.support_messages.create!(role: "user", body: "hi", author: @user)

    assert_enqueued_jobs 2, only: AnswerSupportTicketJob do
      AnswerSupportTicketsJob.perform_now
    end
  end
end
