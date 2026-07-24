require "test_helper"

class TripDocumentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @owner = User.create!(email: "owner-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Olive")
    @trip = @owner.owned_trips.create!(
      title: "Zion loop", destination: "Springdale", start_date: Date.current, end_date: Date.current + 2
    )
    sign_in_as(@owner)
  end

  test "attaches an allowed document type" do
    pdf = Rack::Test::UploadedFile.new(StringIO.new("%PDF-1.4 fake"), "application/pdf", original_filename: "confirmation.pdf")
    post trip_documents_path(@trip), params: { trip: { documents: [ pdf ] } }
    assert_redirected_to trip_path(@trip)
    assert_equal 1, @trip.reload.documents.count
  end

  test "redirects with an alert when the form is submitted with no file part" do
    # The upload form runs turbo:false and posts straight to this URL; a submit
    # with no `trip` key must not raise ParameterMissing -> a bare 400 page.
    post trip_documents_path(@trip)
    assert_redirected_to trip_path(@trip)
    assert_match(/Pick at least one file/, flash[:alert])
    assert_equal 0, @trip.reload.documents.count
  end

  test "rejects html uploads before attaching anything" do
    html = Rack::Test::UploadedFile.new(StringIO.new("<script>alert(1)</script>"), "text/html", original_filename: "evil.html")
    post trip_documents_path(@trip), params: { trip: { documents: [ html ] } }
    assert_redirected_to trip_path(@trip)
    assert_match(/Unsupported file type/, flash[:alert])
    assert_equal 0, @trip.reload.documents.count
  end

  test "rejects svg uploads (script-capable) before attaching anything" do
    svg = Rack::Test::UploadedFile.new(StringIO.new("<svg onload='alert(1)'/>"), "image/svg+xml", original_filename: "evil.svg")
    post trip_documents_path(@trip), params: { trip: { documents: [ svg ] } }
    assert_match(/Unsupported file type/, flash[:alert])
    assert_equal 0, @trip.reload.documents.count
  end

  private

  def sign_in_as(user)
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
  end
end
