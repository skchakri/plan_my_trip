class PagesController < ApplicationController
  skip_before_action :authenticate_user!
  layout "marketing"

  def landing
  end

  def about
  end

  def privacy
  end
end
