Rails.application.routes.draw do
  devise_for :users, controllers: { registrations: "users/registrations" }

  resources :trips do
    resources :shares, only: [ :new, :create, :destroy ], controller: "trip_shares"
    member do
      patch :rename
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check

  root "trips#index"
end
