import { Controller } from "@hotwired/stimulus"

// Product-analytics beacon. Fires one PostHog event when the element connects.
//   data-controller="track" data-track-event-value="trip_built"
//   data-track-props-value='{"days":3}'   (optional JSON)
//   data-track-once-value="trip:UUID:built" (optional — dedupe key kept in
//   localStorage so a Turbo refresh / revisit doesn't double count)
// No-op when analytics is off (window.posthog undefined), so it's safe to
// sprinkle on any view.
export default class extends Controller {
  static values = { event: String, props: Object, once: String }

  connect() {
    if (!this.eventValue) return
    if (this.onceValue) {
      const key = `wp:tracked:${this.onceValue}`
      try {
        if (localStorage.getItem(key)) return
        localStorage.setItem(key, "1")
      } catch (_) { /* private mode — just fire */ }
    }
    track(this.eventValue, this.propsValue || {})
  }
}

export function track(event, props = {}) {
  try {
    if (window.posthog && typeof window.posthog.capture === "function") window.posthog.capture(event, props)
  } catch (_) { /* analytics must never break the page */ }
}
