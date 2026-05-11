class Users::SessionsController < Devise::SessionsController
  layout "auth", only: [ :new, :create ]
end
