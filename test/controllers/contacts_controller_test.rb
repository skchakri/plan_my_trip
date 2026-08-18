require "test_helper"

class ContactsControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup { @admin = User.create!(email: "admin-contact@example.com", password: "password123", name: "Admin", admin: true) }

  test "the contact page is public" do
    get contact_path
    assert_response :success
    assert_select "form[action=?]", contact_path
  end

  test "a valid message mails the admins and redirects" do
    assert_enqueued_emails 1 do
      post contact_path, params: { contact_message: { name: "Pat", email: "pat@example.com", body: "Do you support RV trips with a trailer?" } }
    end
    assert_redirected_to root_path
    perform_enqueued_jobs
    mail = ActionMailer::Base.deliveries.last
    assert_includes mail.to, @admin.email
    assert_equal [ "pat@example.com" ], mail.reply_to
    assert_includes mail.subject, "Pat"
  end

  test "an invalid message re-renders with errors and sends nothing" do
    assert_no_enqueued_emails do
      post contact_path, params: { contact_message: { email: "nope", body: "short" } }
    end
    assert_response :unprocessable_entity
  end

  test "a filled honeypot is silently dropped" do
    assert_no_enqueued_emails do
      post contact_path, params: { contact_message: { email: "bot@example.com", body: "buy my stuff please now", honeypot: "x" } }
    end
    assert_redirected_to root_path
  end
end
