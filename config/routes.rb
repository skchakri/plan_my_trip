Rails.application.routes.draw do
  devise_for :users, controllers: {
    registrations: "users/registrations",
    sessions:      "users/sessions"
  }

  # Guided trip-creation wizard — destination → travelers → highlights → review.
  # State lives in session[:trip_wizard]; the Trip row is only created at the
  # final step. /trips/new redirects into the first step.
  scope "trip_wizard", controller: "trips/wizard" do
    get  "destination", action: :destination,      as: :wizard_destination
    post "destination", action: :save_destination
    get  "travelers",   action: :travelers,        as: :wizard_travelers
    post "travelers",   action: :save_travelers
    get  "highlights",  action: :highlights,       as: :wizard_highlights
    post "highlights",  action: :save_highlights
    get  "highlights/:slug/details", action: :highlight_details, as: :wizard_highlight_details
    get  "review",      action: :review,           as: :wizard_review
    post "",            action: :create,           as: :wizard_create
    delete "",          action: :reset,            as: :wizard_reset
  end

  # Shared place catalog — the same Goblin Valley row is referenced by
  # every trip that visits it. Show-only for now; index/upload/admin
  # tools land in a later slice.
  resources :places, only: [ :show ] do
    collection do
      get :search
    end
  end

  resources :trips do
    resources :shares, only: [ :new, :create, :destroy ], controller: "trip_shares"
    resources :invitations, only: [ :destroy ], controller: "trip_invitations"
    resources :checklist_items, only: [ :create, :update, :destroy ]
    resources :activities, only: [] do
      resources :documents, only: [ :create, :destroy ], controller: "activity_documents"
      resources :photos, only: [ :create, :destroy ], controller: "activity_photos"
    end
    resources :people, only: [ :create, :destroy ]
    resources :documents, only: [ :create, :destroy ], controller: "trip_documents"
    resources :booking_claims, only: [ :create, :destroy ] do
      member do
        delete "documents/:doc_id", to: "booking_claims#destroy_document", as: :document
      end
    end
    member do
      patch :rename
      get :plan
      get :checklist
      get :copilot
      get :copilot_question
      post :copilot_response
    end
  end

  # ── Admin (DB-stored AI prompts + audit log) ──────────────────────
  namespace :admin do
    root to: "dashboard#index"
    resources :ai_prompts do
      member { post :test_run }
    end
    resources :ai_calls, only: [ :index, :show, :destroy ]
    resources :places, only: [ :index, :show, :edit, :update, :destroy ] do
      member { post :verify }
    end
    resources :landmarks, only: [ :index, :show ]
    resources :users, only: [ :index, :show, :edit, :update ]
    resources :trivia, only: [ :index, :show ], constraints: { id: /[^\/]+/ } do
      collection { post :generate_riddles }
    end

    # Read-only sandbox to exercise the trip-planning AI pipeline + place
    # catalog without persisting a Trip. Each block is a lazy-loaded
    # turbo-frame so the page paints immediately and blocks fill in as
    # their AI calls return. Results cached 1h in Rails.cache.
    get "sandbox",                 to: "sandbox#show",            as: :sandbox
    get "sandbox/brief",           to: "sandbox#brief",           as: :sandbox_brief
    get "sandbox/highlights",      to: "sandbox#highlights",      as: :sandbox_highlights
    get "sandbox/route_landmarks", to: "sandbox#route_landmarks", as: :sandbox_route_landmarks
    get "sandbox/structure",       to: "sandbox#structure",       as: :sandbox_structure
    get "sandbox/itinerary",       to: "sandbox#itinerary",       as: :sandbox_itinerary
    get "sandbox/nearby",          to: "sandbox#nearby",          as: :sandbox_nearby
    get "sandbox/places/:id",      to: "sandbox#place_modal",     as: :sandbox_place_modal
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
