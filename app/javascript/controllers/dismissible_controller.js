import { Controller } from "@hotwired/stimulus"

// Hides its element and remembers the dismissal in localStorage so a nudge
// (e.g. "invite your crew") doesn't nag on every visit.
//   data-controller="dismissible" data-dismissible-key-value="invite-crew-<id>"
export default class extends Controller {
  static values = { key: String }

  connect() {
    if (this.keyValue && this.stored()) this.element.hidden = true
  }

  dismiss() {
    try {
      if (this.keyValue) localStorage.setItem(this.storageKey, "1")
    } catch (_) { /* private mode — just hide for this view */ }
    this.element.hidden = true
  }

  stored() {
    try { return localStorage.getItem(this.storageKey) } catch (_) { return false }
  }

  get storageKey() { return `pmt:dismissed:${this.keyValue}` }
}
