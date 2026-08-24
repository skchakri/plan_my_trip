require "test_helper"

class ContactsControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup { @admin = User.create!(email: "admin-contact@example.com", password: "password123", name: "Admin", admin: true) }

  test "the contact page is public" do
    get contact_path
    assert_response :success
    assert_select "form[action=?]", contact_path
  end

  test "a valid message is stored, mails the admins and redirects" do
    assert_difference "ContactMessage.ham.count", 1 do
      assert_enqueued_emails 1 do
        post contact_path, params: { contact_message: { name: "Pat", email: "pat@example.com", body: "Do you support RV trips with a trailer?" } }
      end
    end
    assert_redirected_to root_path
    perform_enqueued_jobs
    mail = ActionMailer::Base.deliveries.last
    assert_includes mail.to, @admin.email
    assert_equal [ "pat@example.com" ], mail.reply_to
    assert_includes mail.subject, "Pat"
    assert_includes mail.text_part.body.to_s, "/admin/contact_messages/"
  end

  test "an invalid message re-renders with errors and stores nothing" do
    assert_no_difference "ContactMessage.count" do
      assert_no_enqueued_emails do
        post contact_path, params: { contact_message: { email: "nope", body: "short" } }
      end
    end
    assert_response :unprocessable_entity
  end

  test "a filled honeypot is stored as spam and not mailed" do
    assert_difference "ContactMessage.where(spam: true).count", 1 do
      assert_no_enqueued_emails do
        post contact_path, params: { contact_message: { email: "bot@example.com", body: "buy my stuff please now", honeypot: "x" } }
      end
    end
    assert_redirected_to root_path
    assert_equal "honeypot filled", ContactMessage.last.spam_reason
  end

  test "boilerplate cyrillic price-list bait is stored flagged as spam and not mailed" do
    assert_no_enqueued_emails do
      post contact_path, params: { contact_message: { name: "Robertjuist", email: "henrydixon487@gmail.com", body: "Прывітанне, я хацеў даведацца Ваш прайс." } }
    end
    m = ContactMessage.last
    assert m.spam?
    assert_includes m.spam_reason, "non-Latin script"
  end
end
