Rails.application.routes.draw do
  devise_for :users, controllers: { registrations: "users/registrations" }

  resources :trips do
    resources :shares, only: [ :new, :create, :destroy ], controller: "trip_shares"
    resources :invitations, only: [ :destroy ], controller: "trip_invitations"
    member do
      patch :rename
    end
  end

  # Trip invitations sent by email — magic-link landing
  get "invitations/:token", to: "invitations#show", as: :invitation
  post "invitations/:token/accept", to: "invitations#accept", as: :accept_invitation
  delete "invitations/:token", to: "invitations#decline", as: :decline_invitation

  get "up" => "rails/health#show", as: :rails_health_check

  root "trips#index"
end
