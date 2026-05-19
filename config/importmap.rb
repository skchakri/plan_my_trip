# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin "@rails/actioncable", to: "actioncable.esm.js"
pin "tts_settings", to: "tts_settings.js"
pin "leaflet" # vendor/javascript/leaflet.js
pin_all_from "app/javascript/controllers", under: "controllers"
