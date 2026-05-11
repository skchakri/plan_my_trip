class ApplicationController < ActionController::Base
  include Pundit::Authorization

  allow_browser versions: :modern
  stale_when_importmap_changes

  before_action :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  # When a user signs in (e.g. after clicking an invitation link), if they
  # have a pending invitation token in the session, route them to the
  # accept-invite page instead of the default landing.
  def after_sign_in_path_for(resource)
    if (token = session.delete(:invitation_token))
      session.delete(:invitation_email)
      invitation_path(token)
    else
      stored_location_for(resource) || trips_path
    end
  end

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :name ])
    devise_parameter_sanitizer.permit(
      :account_update,
      keys: [ :name, :alltrails_pro, { discount_memberships: User::MEMBERSHIPS.keys.map(&:to_s) } ]
    )
  end

  def user_not_authorized
    redirect_to(request.referer || root_path, alert: "You are not authorized to do that.")
  end
end
