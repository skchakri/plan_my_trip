import { Controller } from "@hotwired/stimulus"

// Lightweight popover menu (the "•••" trip-card actions). Toggles a panel,
// closes on outside click or Escape, and keeps aria-expanded in sync.
export default class extends Controller {
  static targets = ["panel", "button"]

  connect() {
    this.close = this.close.bind(this)
    this._onKey = this._onKey.bind(this)
  }

  disconnect() {
    document.removeEventListener("click", this.close)
    document.removeEventListener("keydown", this._onKey)
  }

  toggle(event) {
    event.stopPropagation()
    this.panelTarget.hidden ? this.open() : this.close()
  }

  open() {
    this.panelTarget.hidden = false
    if (this.hasButtonTarget) this.buttonTarget.setAttribute("aria-expanded", "true")
    document.addEventListener("click", this.close)
    document.addEventListener("keydown", this._onKey)
  }

  close() {
    this.panelTarget.hidden = true
    if (this.hasButtonTarget) this.buttonTarget.setAttribute("aria-expanded", "false")
    document.removeEventListener("click", this.close)
    document.removeEventListener("keydown", this._onKey)
  }

  _onKey(event) {
    if (event.key === "Escape") this.close()
  }
}
