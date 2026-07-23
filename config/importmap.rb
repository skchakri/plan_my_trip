# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin "@rails/actioncable", to: "actioncable.esm.js"
pin "tts_settings", to: "tts_settings.js"
pin "leaflet" # vendor/javascript/leaflet.js
# Vendored, not pinned from jspm — jspm has no copy of this package.
# Source: https://cdn.jsdelivr.net/npm/@hotwired/hotwire-native-bridge@1.2.2/dist/hotwire-native-bridge.js
pin "@hotwired/hotwire-native-bridge", to: "hotwire-native-bridge.js"
pin "speech" # app/javascript/speech.js — Web Speech API / native bridge façade
pin_all_from "app/javascript/controllers", under: "controllers"
