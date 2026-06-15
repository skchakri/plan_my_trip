import { Controller } from "@hotwired/stimulus"

// Removes its element after a delay. Used for transient undo bars / toasts.
// data-auto-dismiss-delay-value="8000" (ms, default 6000).
export default class extends Controller {
  static values = { delay: { type: Number, default: 6000 } }

  connect() {
    this.timeout = setTimeout(() => this.dismiss(), this.delayValue)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  dismiss() {
    this.element.style.transition = "opacity .3s ease"
    this.element.style.opacity = "0"
    setTimeout(() => this.element.remove(), 300)
  }
}
