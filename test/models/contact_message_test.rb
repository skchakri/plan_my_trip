require "test_helper"

class ContactMessageTest < ActiveSupport::TestCase
  test "plain english message with a nickname is not spam" do
    m = ContactMessage.create!(name: "Mike", email: "michael.jones@example.com", body: "Can I plan a trip to Zion in October?")
    refute m.spam?
  end

  test "name/email mismatch alone is not enough" do
    m = ContactMessage.create!(name: "Sunshine", email: "kelly.r@example.com", body: "Love the road trip guides, thank you!")
    refute m.spam?
  end

  test "link-stuffed message is spam" do
    m = ContactMessage.create!(email: "seo@example.com", body: "Check https://a.example and https://b.example for backlinks")
    assert m.spam?
    assert_includes m.spam_reason, "links"
  end

  test "email is normalized" do
    m = ContactMessage.create!(email: "  Pat@Example.COM ", body: "Hello there, a question about pricing.")
    assert_equal "pat@example.com", m.email
  end
end
