# Public "Contact us" — the one way a logged-out visitor (press, partner, a
# prospect with a pre-signup question) can reach Wanderply. Nothing is stored;
# the message is mailed to every admin. Guarded by a honeypot field and a
# Rack::Attack throttle (config/initializers/rack_attack.rb).
class ContactsController < ApplicationController
  skip_before_action :authenticate_user!
  layout "marketing"

  def new
    @contact = ContactMessage.new(email: current_user&.email, name: current_user&.display_name)
  end

  def create
    @contact = ContactMessage.new(contact_params)
    if @contact.honeypot.present? # bot filled the hidden field — pretend success
      redirect_to root_path, notice: "Thanks — we got your message." and return
    end

    if @contact.valid?
      ContactMailer.new_message(@contact.to_h).deliver_later
      redirect_to root_path, notice: "Thanks — we got your message and will reply by email."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def contact_params
    params.fetch(:contact_message, {}).permit(:name, :email, :body, :honeypot)
  end
end
