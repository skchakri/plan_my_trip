require "test_helper"

class Admin::SupportTicketsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(email: "adm-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Adm", admin: true)
    @user  = User.create!(email: "usr-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Usr")
    @ticket = @user.support_tickets.create!(subject: "Refund please", status: "escalated",
                                            admin_draft: "Draft reply about the refund.", escalation_reason: "refund request")
    @ticket.support_messages.create!(role: "user", body: "I want a refund", author: @user)
  end

  test "non-admin cannot reach the admin support queue" do
    sign_in_as(@user)
    get admin_support_tickets_path
    assert_response :redirect
  end

  test "admin index and show pages render, showing the AI draft" do
    sign_in_as(@admin)
    get admin_support_tickets_path
    assert_response :success
    assert_includes response.body, "Refund please"
    get admin_support_ticket_path(@ticket)
    assert_response :success
    assert_includes response.body, "Draft reply about the refund."
  end

  test "admin reply sends an admin message, answers the ticket, and notifies the user" do
    sign_in_as(@admin)
    assert_difference "@ticket.support_messages.count", 1 do
      post reply_admin_support_ticket_path(@ticket), params: { support_message: { body: "We've issued your refund." } }
    end
    @ticket.reload
    assert_equal "ai_answered", @ticket.status
    assert_nil @ticket.admin_draft
    assert_equal "admin", @ticket.support_messages.ordered.last.role
    assert Notification.exists?(recipient: @user, kind: "support_reply")
  end

  test "admin can resolve a ticket" do
    sign_in_as(@admin)
    post resolve_admin_support_ticket_path(@ticket)
    assert_equal "resolved", @ticket.reload.status
  end

  private

  def sign_in_as(user)
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
  end
end
