require "test_helper"

class SupportTicketTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "u-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "U")
  end

  test "defaults to open and stamps last_activity_at" do
    ticket = @user.support_tickets.create!(subject: "Help")
    assert_equal "open", ticket.status
    assert_not_nil ticket.last_activity_at
    assert ticket.needs_ai_answer?
  end

  test "needs_ai scope only returns open, kept tickets" do
    open      = @user.support_tickets.create!(subject: "Open")
    answered  = @user.support_tickets.create!(subject: "Done", status: "ai_answered")
    discarded = @user.support_tickets.create!(subject: "Gone")
    discarded.discard

    ids = SupportTicket.needs_ai.pluck(:id)
    assert_includes ids, open.id
    refute_includes ids, answered.id
    refute_includes ids, discarded.id
  end

  test "reopen! moves an answered ticket back to open" do
    ticket = @user.support_tickets.create!(subject: "Q", status: "ai_answered")
    ticket.reopen!
    assert_equal "open", ticket.reload.status
  end

  test "validates status inclusion" do
    ticket = @user.support_tickets.new(subject: "Q", status: "bogus")
    refute ticket.valid?
  end
end
