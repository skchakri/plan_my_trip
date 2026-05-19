module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    private

    # Pull the current Devise user out of the warden session cookie. Reject
    # the WebSocket if no user is signed in — presence is for trip members.
    def find_verified_user
      verified = env["warden"]&.user(:user)
      verified || reject_unauthorized_connection
    end
  end
end
