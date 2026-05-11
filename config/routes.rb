Rails.application.routes.draw do
  devise_for :users, controllers: {
    registrations: "users/registrations",
    sessions:      "users/sessions"
  }

  resources :trips do
    resources :shares, only: [ :new, :create, :destroy ], controller: "trip_shares"
    resources :invitations, only: [ :destroy ], controller: "trip_invitations"
    resources :checklist_items, only: [ :create, :update, :destroy ]
    resources :activities, only: [] do
      resources :documents, only: [ :create, :destroy ], controller: "activity_documents"
    end
    resources :people, only: [ :create, :destroy ]
    resources :documents, only: [ :create, :destroy ], controller: "trip_documents"
    member do
      patch :rename
      get :plan
      get :checklist
      get :copilot
      get :copilot_question
    end
  end

  # Trip invitations sent by email — magic-link landing
  get "invitations/:token", to: "invitations#show", as: :invitation
  post "invitations/:token/accept", to: "invitations#accept", as: :accept_invitation
  delete "invitations/:token", to: "invitations#decline", as: :decline_invitation

  get "up" => "rails/health#show", as: :rails_health_check

  # PWA — installable + offline support
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Marketing site
  get  "about", to: "pages#about", as: :about
  get  "blog",  to: "blog#index", as: :blog_index
  get  "blog/:slug", to: "blog#show", as: :blog, constraints: { slug: %r{[^/]+} }

  root "pages#landing"
end
