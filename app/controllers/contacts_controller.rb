# Public "Contact us" — the one way a logged-out visitor (press, partner, a
# prospect with a pre-signup question) can reach Wanderply. Every submission
# is stored as a ContactMessage (admin inbox at /admin/contact_messages);
# non-spam ones are also mailed to every admin. Guarded by a honeypot field,
# spam heuristics on the model, and a Rack::Attack throttle
# (config/initializers/rack_attack.rb).
class ContactsController < ApplicationController
  skip_before_action :authenticate_user!
  layout "marketing"

  def new
    @contact = ContactMessage.new(email: current_user&.email, name: current_user&.display_name)
  end

  def create
    @contact = ContactMessage.new(contact_params.merge(user: current_user, ip: request.remote_ip,
                                                       user_agent: request.user_agent.to_s.first(255)))
    if @contact.honeypot.present? # bot filled the hidden field — store flagged, pretend success
      @contact.spam = true
      @contact.spam_reason = "honeypot filled"
      @contact.save(validate: false)
      redirect_to root_path, notice: "Thanks — we got your message." and return
    end

    if @contact.save
      ContactMailer.new_message(@contact).deliver_later unless @contact.spam?
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
