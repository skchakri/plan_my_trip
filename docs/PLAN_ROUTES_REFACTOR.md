# Plan: Refactor `config/routes.rb` with concerns

Status: **plan only — do not execute without approval**.
Owner: TBD. Estimated effort: ~3 hours including controller-test sweep.

## Why

`config/routes.rb` is 148 lines today. `resources :trips` carries **eleven**
member actions plus six nested resource blocks. The block is unscannable —
half the lines are member shortcuts for cross-cutting concerns (share link,
ICS export, wallet) and a one-off Drive Co-Pilot question/response pair.

Concrete pain points:

- Three `share_link` actions (`POST`, `DELETE`, `POST :share_link_rotate`)
  reach into `public_trips_controller` — naming is split across `trips`
  and `public_trips`.
- `calendar` and `wallet` are read-only exports living next to mutating
  actions like `:rename` and `:duplicate`.
- `copilot_question` and `copilot_response` are member actions but they're
  really a one-resource RPC pair — they should be a nested resource.
- The trips block is becoming the kitchen sink: any new feature ends up
  as a member action because that's where everything else is.

## Target shape

Three routing concerns that capture cross-cutting features:

```ruby
# Share link CRUD + rotation (was: 3 member actions, 2 controllers)
concern :sharable do
  resource :share_link, only: %i[create destroy], controller: "public_trips" do
    post :rotate, on: :collection
  end
end

# Exports (was: member actions on trips_controller)
concern :exportable do
  member do
    get :wallet
    get :calendar, defaults: { format: :ics }, constraints: { format: :ics }
  end
end

# AI Drive Co-Pilot Q&A pair (was: 3 member actions)
concern :copilotable do
  resource :copilot, only: :show, controller: "trip_copilot" do
    get  :question
    post :respond,  as: :response
  end
end
```

Then `resources :trips` becomes:

```ruby
resources :trips, concerns: %i[sharable exportable copilotable] do
  # nested resources
  resources :trip_days,        only: [], shallow: true do
    resources :suggestions,    only: %i[create destroy] do
      member { post :vote }
    end
  end
  resources :shares,           only: %i[new create destroy], controller: "trip_shares"
  resources :invitations,      only: :destroy, controller: "trip_invitations"
  resources :checklist_items,  only: %i[create update destroy]
  resources :activities,       only: [] do
    resources :documents, only: %i[create destroy], controller: "activity_documents"
    resources :photos,    only: %i[create destroy], controller: "activity_photos"
    resources :comments,  only: %i[create destroy]
  end
  resources :people,         only: %i[create destroy]
  resources :documents,      only: %i[create destroy], controller: "trip_documents"
  resources :booking_claims, only: %i[create destroy] do
    member { delete "documents/:doc_id", to: "booking_claims#destroy_document", as: :document }
  end

  member do
    patch :rename
    get   :plan
    get   :checklist
    post  :duplicate
  end
end
```

Line count for the trips block drops from ~36 to ~22.

## Path map (before → after)

| Today | After |
|---|---|
| `POST /trips/:id/share_link` → `public_trips#enable` | `POST /trips/:trip_id/share_link` → `public_trips#create` |
| `DELETE /trips/:id/share_link` → `public_trips#disable` | `DELETE /trips/:trip_id/share_link` → `public_trips#destroy` |
| `POST /trips/:id/share_link_rotate` → `public_trips#rotate` | `POST /trips/:trip_id/share_link/rotate` → `public_trips#rotate` |
| `GET /trips/:id/copilot` → `trips#copilot` | `GET /trips/:trip_id/copilot` → `trip_copilot#show` |
| `GET /trips/:id/copilot_question` → `trips#copilot_question` | `GET /trips/:trip_id/copilot/question` → `trip_copilot#question` |
| `POST /trips/:id/copilot_response` → `trips#copilot_response` | `POST /trips/:trip_id/copilot/response` → `trip_copilot#respond` |
| `GET /trips/:id/wallet` → `trips#wallet` | `GET /trips/:trip_id/wallet` → `trips#wallet` *(no path change, just grouped)* |
| `GET /trips/:id/calendar.ics` → `trips#calendar` | `GET /trips/:trip_id/calendar.ics` → `trips#calendar` *(no path change)* |

URL changes are limited to:
- `/trips/:id/share_link_rotate` → `/trips/:id/share_link/rotate`
- `/trips/:id/copilot_question` → `/trips/:id/copilot/question`
- `/trips/:id/copilot_response` → `/trips/:id/copilot/response`

Add `get "/trips/:trip_id/copilot_question", to: redirect("/trips/%{trip_id}/copilot/question")` etc. for the duration of one deploy window so any bookmarked / Hotwire-Native-cached URLs survive.

## Controller moves

Extract `app/controllers/trip_copilot_controller.rb` from the three actions
currently on `trips_controller.rb`. `TripsController` shrinks; the new
controller's setup (auth, set_trip, authorize) inherits from `ApplicationController`
or a thin `Trips::BaseController`.

## Sandbox block

The admin sandbox routes (`/admin/sandbox/*`) are eight GETs in a row. After
the trips refactor, fold them into a single nested resource:

```ruby
resource :sandbox, only: :show, controller: "sandbox" do
  get :brief
  get :highlights
  get :route_landmarks
  get :structure
  get :itinerary
  get :nearby
  get "places/:id", action: :place_modal, as: :place_modal
end
```

## Test surface needed before executing

- `bin/rails routes` snapshot test or a spec that asserts every named helper
  still exists with the same path (modulo the three explicit URL changes above).
- Hotwire Native: confirm `public/configurations/{ios,android}.json` paths
  still match. The configurations match on regex patterns, so the
  `share_link` / `copilot_question` changes need a config bump.

## Decision needed before executing

1. OK to break the three URLs above (with redirects for one deploy cycle)?
2. Extract `TripCopilotController` now, or wait until the Drive Co-Pilot
   gains more endpoints?
3. Hotwire Native path configs are fetched at app launch — when do we cut
   over so both old + new builds keep working?
