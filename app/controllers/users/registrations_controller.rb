class Users::RegistrationsController < Devise::RegistrationsController
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
