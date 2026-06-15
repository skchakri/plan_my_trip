import { Controller } from "@hotwired/stimulus"

// Optimistic feedback for the checklist toggle. Acknowledges the tap instantly
// (Turbo replaces the whole <li> with server truth on success, so we don't try
// to mirror the exact checked styling here). On failure, restore the row and
// surface a toast instead of failing silently — important on flaky networks.
export default class extends Controller {
  pending() {
    this.element.classList.add("opacity-50", "pointer-events-none")
  }

  done(event) {
    if (event.detail && event.detail.success === false) {
      this.element.classList.remove("opacity-50", "pointer-events-none")
      window.dispatchEvent(
        new CustomEvent("toast", {
          detail: { type: "alert", message: "Couldn't save that change — check your connection." }
        })
      )
    }
  }
}
