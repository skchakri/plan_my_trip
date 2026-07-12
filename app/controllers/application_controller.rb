class ApplicationController < ActionController::Base
  include Pundit::Authorization

  allow_browser versions: :modern
  stale_when_importmap_changes

  before_action :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?
  # Capture a "save this shared trip" intent carried on the sign-in/up links
  # (e.g. /users/sign_in?save_trip=<share_token>) so we can return the visitor
  # to that trip after auth. Mirrors how InvitationsController stashes
  # :invitation_token. Devise pages only, so a stray ?save_trip elsewhere is
  # ignored.
  before_action :stash_save_trip_token, if: :devise_controller?

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  # When a user signs in, route them by the strongest pending intent: an
  # invitation link, then a "save this shared trip" link (back to /s/:token so
  # they can tap Save), then any stored location, else the default landing.
  def after_sign_in_path_for(resource)
    if (token = session.delete(:invitation_token))
      session.delete(:invitation_email)
      invitation_path(token)
    elsif (share_token = session.delete(:save_trip_token))
      public_trip_path(share_token)
    elsif (stored = stored_location_for(resource))
      stored
    elsif resource.is_a?(User) && resource.trips.kept.none?
      wizard_destination_path
    else
      trips_path
    end
  end

  protected

  def stash_save_trip_token
    token = params[:save_trip].to_s
    session[:save_trip_token] = token if token.present?
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :name ])
    devise_parameter_sanitizer.permit(
      :account_update,
      keys: [
        :name, :alltrails_pro, :receive_digest,
        :home_city, :home_lat, :home_lng, :default_radius_km,
        { discount_memberships: User::MEMBERSHIPS.keys.map(&:to_s),
          default_interests: [] }
      ]
    )
  end

  def user_not_authorized
    redirect_to(request.referer || root_path, alert: "You are not authorized to do that.")
  end
end
