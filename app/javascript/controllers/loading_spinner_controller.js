import { Controller } from "@hotwired/stimulus"

// Replaces Turbo's default top progress bar with a centered spinner overlay.
// Shows on full-page Turbo visits and form submissions; ignores turbo-frame loads
// (those already render their own inline placeholders).
export default class extends Controller {
  static targets = ["overlay"]
  static values  = { delay: { type: Number, default: 200 } }

  connect() {
    this.timer = null

    this._show = this._show.bind(this)
    this._hide = this._hide.bind(this)

    document.addEventListener("turbo:visit",        this._show)
    document.addEventListener("turbo:submit-start", this._show)

    document.addEventListener("turbo:load",         this._hide)
    document.addEventListener("turbo:submit-end",   this._hide)
    document.addEventListener("turbo:render",       this._hide)
    document.addEventListener("turbo:frame-missing", this._hide)
    window.addEventListener("pageshow",             this._hide)
  }

  disconnect() {
    document.removeEventListener("turbo:visit",        this._show)
    document.removeEventListener("turbo:submit-start", this._show)
    document.removeEventListener("turbo:load",         this._hide)
    document.removeEventListener("turbo:submit-end",   this._hide)
    document.removeEventListener("turbo:render",       this._hide)
    document.removeEventListener("turbo:frame-missing", this._hide)
    window.removeEventListener("pageshow",             this._hide)
    clearTimeout(this.timer)
  }

  _show() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => {
      this.overlayTarget.classList.add("is-visible")
      this.overlayTarget.setAttribute("aria-hidden", "false")
    }, this.delayValue)
  }

  _hide() {
    clearTimeout(this.timer)
    this.overlayTarget.classList.remove("is-visible")
    this.overlayTarget.setAttribute("aria-hidden", "true")
  }
}
