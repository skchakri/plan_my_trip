class Users::RegistrationsController < Devise::RegistrationsController
  def new
    super do |resource|
      if (email = session[:invitation_email]).present? && resource.email.blank?
        resource.email = email
      end
    end
  end

  def after_sign_up_path_for(resource)
    if (token = session.delete(:invitation_token))
      session.delete(:invitation_email)
      invitation_path(token)
    else
      super
    end
  end

  protected

  # Skip the current-password requirement when the user isn't changing their
  # password. Toggling AllTrails+, editing name, etc. shouldn't demand it.
  def update_resource(resource, params)
    if params[:password].blank? && params[:password_confirmation].blank?
      params.delete(:current_password)
      resource.update_without_password(params)
    else
      super
    end
  end
end
