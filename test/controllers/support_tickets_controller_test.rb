require "test_helper"

class SupportTicketsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user  = User.create!(email: "u-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "U")
    @other = User.create!(email: "o-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "O")
  end

  test "index, new, and show pages render for the owner" do
    ticket = @user.support_tickets.create!(subject: "Renders")
    ticket.support_messages.create!(role: "user", body: "hello", author: @user)
    sign_in_as(@user)

    get support_tickets_path
    assert_response :success
    get new_support_ticket_path
    assert_response :success
    get support_ticket_path(ticket)
    assert_response :success
    assert_includes response.body, "Renders"
  end

  test "creating a ticket also stores the first message" do
    sign_in_as(@user)
    assert_difference [ "SupportTicket.count", "SupportMessage.count" ], 1 do
      post support_tickets_path, params: { support_ticket: { subject: "How do quizzes work?", body: "Are they free?" } }
    end
    ticket = @user.support_tickets.last
    assert_equal "open", ticket.status
    assert_equal "Are they free?", ticket.support_messages.ordered.first.body
    assert_redirected_to support_ticket_path(ticket)
  end

  test "a user cannot view another user's ticket" do
    ticket = @other.support_tickets.create!(subject: "Private")
    sign_in_as(@user)
    get support_ticket_path(ticket)
    assert_response :not_found
  end

  test "replying appends a user message and reopens the ticket" do
    ticket = @user.support_tickets.create!(subject: "Q", status: "ai_answered")
    sign_in_as(@user)
    assert_difference "ticket.support_messages.count", 1 do
      post reply_support_ticket_path(ticket), params: { support_message: { body: "Follow-up question" } }
    end
    assert_equal "open", ticket.reload.status
  end

  private

  def sign_in_as(user)
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
  end
end
