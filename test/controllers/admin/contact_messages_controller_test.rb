require "test_helper"

class Admin::ContactMessagesControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    @admin = User.create!(email: "adm-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Adm", admin: true)
    @user  = User.create!(email: "usr-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Usr")
    @message = ContactMessage.create!(name: "Pat", email: "pat@example.com", body: "Do you support RV trips with a trailer?")
    @spam = ContactMessage.create!(name: "Robertjuist", email: "henrydixon487@gmail.com", body: "Прывітанне, я хацеў даведацца Ваш прайс.")
  end

  test "non-admin cannot reach the inbox" do
    sign_in_as(@user)
    get admin_contact_messages_path
    assert_response :redirect
  end

  test "inbox lists ham by default, spam under its own filter, and search works" do
    sign_in_as(@admin)
    get admin_contact_messages_path
    assert_response :success
    assert_includes response.body, "pat@example.com"
    refute_includes response.body, "henrydixon487"

    get admin_contact_messages_path(filter: "spam")
    assert_includes response.body, "henrydixon487"

    get admin_contact_messages_path(q: "trailer")
    assert_includes response.body, "pat@example.com"
    get admin_contact_messages_path(q: "zzzz")
    assert_includes response.body, "No messages here."
  end

  test "nav badge shows unread count and show marks read" do
    sign_in_as(@admin)
    get admin_contact_messages_path
    assert_select "nav a[href=?] span", admin_contact_messages_path, text: "1"
    get admin_contact_message_path(@message)
    assert_response :success
    assert @message.reload.read?
    get admin_contact_messages_path
    assert_select "nav a[href=?] span", admin_contact_messages_path, count: 0
  end

  test "reply emails the visitor with the admin as reply-to and records it" do
    sign_in_as(@admin)
    assert_enqueued_emails 1 do
      post reply_admin_contact_message_path(@message), params: { reply: { body: "Yes — pick 'Own car' and add the trailer in preferences." } }
    end
    assert_redirected_to admin_contact_message_path(@message)
    assert @message.reload.replied?
    assert_includes @message.reply_body, "trailer"
    perform_enqueued_jobs
    mail = ActionMailer::Base.deliveries.last
    assert_equal [ "pat@example.com" ], mail.to
    assert_equal [ @admin.email ], mail.reply_to
    assert_includes mail.text_part.body.to_s, "> Do you support RV trips"
  end

  test "empty reply is rejected" do
    sign_in_as(@admin)
    assert_no_enqueued_emails do
      post reply_admin_contact_message_path(@message), params: { reply: { body: "  " } }
    end
    refute @message.reload.replied?
  end

  test "spam toggle and delete" do
    sign_in_as(@admin)
    post spam_admin_contact_message_path(@spam, flag: "false")
    refute @spam.reload.spam?
    post spam_admin_contact_message_path(@spam)
    assert @spam.reload.spam?
    assert_difference "ContactMessage.count", -1 do
      delete admin_contact_message_path(@spam)
    end
  end

  private

  def sign_in_as(user)
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
  end
end
