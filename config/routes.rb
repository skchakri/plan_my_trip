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
    # Lazy turbo-frame body: the highlights step renders instantly with a
    # skeleton; this endpoint runs the (slow) DestinationHighlights + brief
    # research and streams the picker back into the frame.
    get  "highlights/results", action: :highlights_results, as: :wizard_highlights_results
    post "highlights",  action: :save_highlights
    get  "highlights/:slug/details", action: :highlight_details, as: :wizard_highlight_details
    get  "review",      action: :review,           as: :wizard_review
    # Lazy turbo-frame body: per-day weather for the drafted dates, loaded
    # off the review page so the Open-Meteo call never blocks it.
    get  "weather",     action: :weather,          as: :wizard_weather
    post "",            action: :create,           as: :wizard_create
    delete "",          action: :reset,            as: :wizard_reset
  end

  # Day-trip flow: home base + interests → AI-curated nearby ideas →
  # one-day Trip. The /day_trips routes only handle planning; the saved
  # trip lives at /trips/:id like any other trip.
  scope "day_trips", controller: "day_trips" do
    get  "new",            action: :new,            as: :day_trips_new
    get  "suggestions",    action: :suggestions,    as: :day_trip_suggestions
    # Lazy turbo-frame target: the suggestions page renders instantly with a
    # skeleton, then this endpoint runs the (slow) NearbyIdeas research and
    # streams the cards back into the frame — no multi-minute blocked page load.
    get  "suggestions_results", action: :suggestions_results, as: :day_trip_suggestions_results
    get  "idea_detail",    action: :idea_detail,    as: :day_trip_idea_detail
    # Click-to-load "More about this place" frame inside the idea modal —
    # runs HighlightDetail (cached AI) off the initial modal render.
    get  "idea_more",      action: :idea_more,      as: :day_trip_idea_more
    post "",               action: :create,         as: :day_trips
    post "save_home_base", action: :save_home_base, as: :day_trip_save_home_base
  end

  # Shared place catalog — the same Goblin Valley row is referenced by
  # every trip that visits it. Show-only for now; index/upload/admin
  # tools land in a later slice.
  resources :places, only: [ :index, :show ] do
    collection do
      get :search
      post :rate # find-or-create from card metadata + POST review in one shot
    end
    member do
      get :more_info # lazy "More about this place" frame (HighlightDetail)
    end
    resources :reviews, only: [ :create, :destroy ], controller: "place_reviews"
  end

  # Lazy stock-photo resolver for highlight cards lacking a Wikimedia image.
  get "place_image", to: "place_images#show", as: :place_image

  resources :trips do
    resources :trip_days, only: [ :create, :update, :destroy ] do
      member { patch :move }
      resources :suggestions, only: [ :create, :destroy ] do
        member { post :vote }
      end
    end
    resources :shares, only: [ :new, :create, :update, :destroy ], controller: "trip_shares"
    resources :invitations, only: [ :destroy ], controller: "trip_invitations"
    resources :checklist_items, only: [ :create, :update, :destroy ] do
      member { patch :restore }
    end
    resources :activities, only: [ :create, :update, :destroy ] do
      member { patch :move }
      resources :documents, only: [ :create, :destroy ], controller: "activity_documents"
      resources :photos, only: [ :create, :destroy ], controller: "activity_photos"
      resources :comments, only: [ :create, :destroy ]
    end
    resources :people, only: [ :create, :destroy ]
    resources :documents, only: [ :create, :destroy ], controller: "trip_documents"
    resources :booking_claims, only: [ :create, :destroy ] do
      member do
        delete "documents/:doc_id", to: "booking_claims#destroy_document", as: :document
      end
    end
    # Parsed booking-confirmation emails (forwarded to the per-trip address).
    resources :reservations, only: [ :destroy ] do
      post :retry, on: :member
    end
    member do
      patch :rename
      patch :archive
      patch :restore
      delete :destroy_permanently
      post :rebuild
      post :skip_build
      get :plan
      get :edit_plan
      get :brief
      get :road_trip_stats
      get :weather
      get :checklist
      get :copilot
      get :copilot_question
      post :copilot_response
      post :concierge
      post :concierge_edit
      post   :share_link,        to: "public_trips#enable",  as: :enable_public_share
      delete :share_link,        to: "public_trips#disable", as: :disable_public_share
      post   :share_link_rotate, to: "public_trips#rotate",  as: :rotate_public_share
      post   :duplicate
      get    :calendar, defaults: { format: :ics }, constraints: { format: :ics }
      get    :wallet
      get    :printable
    end
  end

  # Public read-only trip view — anyone with the link can see a stripped-down
  # plan. No auth. Revocation/rotation lives under /trips/:id/share_link.
  get "s/:token", to: "public_trips#show", as: :public_trip, constraints: { token: /[A-Za-z0-9_-]+/ }
  get "s/:token/calendar.ics", to: "public_trips#calendar", as: :public_trip_calendar, constraints: { token: /[A-Za-z0-9_-]+/ }
  # Clone a publicly-shared trip into the signed-in viewer's own trips.
  post "s/:token/save", to: "public_trips#copy", as: :save_public_trip, constraints: { token: /[A-Za-z0-9_-]+/ }

  # SEO-indexed Place landing pages — public, crawlable, slug-stable.
  # Distinct from the auth-gated /places/:id used during trip planning.
  get "p/:slug", to: "public_places#show", as: :public_place, constraints: { slug: /[a-z0-9-]+/ }
  get "places-sitemap.xml", to: "public_places#sitemap", as: :places_sitemap, defaults: { format: :xml }
  # Site-wide sitemap (marketing pages + blog); robots.txt lists both.
  get "sitemap.xml", to: "pages#sitemap", as: :sitemap, defaults: { format: :xml }

  # ── Admin (DB-stored AI prompts + audit log) ──────────────────────
  namespace :admin do
    root to: "dashboard#index"
    resources :ai_prompts do
      member { post :test_run }
    end
    resources :ai_calls, only: [ :index, :show, :destroy ]
    # Central store for API keys / affiliate IDs / paths (AppSetting).
    resource :app_settings, only: [ :show, :update ], controller: "app_settings"
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

  resources :notifications, only: [ :index ] do
    member     { post :read }
    collection { post :read_all }
  end

  # Travel Trivia — standalone general-knowledge quizzes (capitals, flags,
  # leaders). Questions are generated fresh from curated seed data on each
  # play and graded client-side; #record persists the final score.
  get  "quizzes",                     to: "quizzes#index",  as: :quizzes
  # Country Explorer — pick a country, see all its national facts. Defined
  # before the :category catch-all so "explore" isn't read as a deck key.
  get  "quizzes/explore",             to: "quizzes#explore", as: :quiz_explore
  # Offline manifest: every deck page URL + all flag/logo image URLs, consumed
  # by the "Save for offline" button to pre-warm the service-worker cache.
  get  "quizzes/offline",             to: "quizzes#offline_manifest", as: :quiz_offline, defaults: { format: :json }
  get  "quizzes/:category",           to: "quizzes#show",   as: :quiz,          constraints: { category: /[a-z_]+/ }
  post "quizzes/:category/attempts",  to: "quizzes#record", as: :quiz_attempts, constraints: { category: /[a-z_]+/ }

  # Starter templates for the empty-state dashboard. The list lives in
  # app/services/trip_template.rb — no DB row, no admin tooling.
  post "trip_templates/:key/use", to: "trip_templates#use", as: :use_trip_template,
       constraints: { key: /[a-z0-9-]+/ }

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
  get  "privacy", to: "pages#privacy", as: :privacy
  get  "blog",  to: "blog#index", as: :blog_index
  get  "blog/:slug", to: "blog#show", as: :blog, constraints: { slug: %r{[^/]+} }

  root "pages#landing"
end
