import { Controller } from "@hotwired/stimulus"

// Guards a <turbo-frame> against hanging forever on a slow or failed AI
// request. If a fetch hasn't loaded within `timeout` ms (or errors), it swaps
// the skeleton for a friendly retry card. The original fetch is not cancelled,
// so if it eventually arrives it still replaces this.
//
// Attach to the <turbo-frame> itself:
//   data: { controller: "frame-timeout", frame_timeout_timeout_value: 45000 }
//
// The clock starts when a fetch actually begins (turbo:before-fetch-request),
// not merely on connect. That makes it correct for BOTH auto-loading lazy
// frames (which fetch on connect / when scrolled into view) and click-triggered
// frames that sit idle with no `src` until tapped — starting on connect would
// wrongly time those out before the user ever clicks.
//
// NOTE: only classes that already appear in the compiled Tailwind bundle are
// used below — the v4 scanner can't see JS-interpolated class names.
export default class extends Controller {
  static values = { timeout: { type: Number, default: 45000 } }

  connect() {
    this.loaded = false
    this.onFetchStart = () => this.startTimer()
    this.onLoad = () => { this.loaded = true; this.clearTimer() }
    this.onError = () => this.fail()
    this.element.addEventListener("turbo:before-fetch-request", this.onFetchStart)
    this.element.addEventListener("turbo:frame-load", this.onLoad)
    this.element.addEventListener("turbo:fetch-request-error", this.onError)
    // A frame that already has a src fetches immediately — start the clock now.
    // A click-triggered frame (no src) waits for the tap's fetch to start it.
    if (this.element.hasAttribute("src")) this.startTimer()
  }

  disconnect() {
    this.clearTimer()
    this.element.removeEventListener("turbo:before-fetch-request", this.onFetchStart)
    this.element.removeEventListener("turbo:frame-load", this.onLoad)
    this.element.removeEventListener("turbo:fetch-request-error", this.onError)
  }

  startTimer() {
    this.loaded = false
    this.clearTimer()
    this.timer = setTimeout(() => this.fail(), this.timeoutValue)
  }

  clearTimer() { clearTimeout(this.timer) }

  fail() {
    this.clearTimer()
    if (this.loaded) return
    this.element.removeAttribute("aria-busy")
    this.element.innerHTML = `
      <div class="rounded-2xl border border-slate-800 bg-slate-900/40 p-6 text-center">
        <p class="text-slate-200 font-medium">This is taking longer than usual</p>
        <p class="text-sm text-slate-400 mt-1">Our research service is slow or unreachable right now.</p>
        <button type="button" data-action="frame-timeout#retry"
                class="mt-4 inline-flex items-center gap-1.5 px-4 py-2 rounded-lg bg-amber-500 text-slate-950 font-semibold text-sm hover:bg-amber-400 transition-colors cursor-pointer">
          Try again
        </button>
      </div>`
  }

  retry() {
    this.loaded = false
    this.element.setAttribute("aria-busy", "true")
    this.element.innerHTML = `<div class="p-6 text-center text-sm text-slate-400">Retrying…</div>`
    this.timer = setTimeout(() => this.fail(), this.timeoutValue)
    if (typeof this.element.reload === "function") {
      this.element.reload()
    } else if (this.element.src) {
      const src = this.element.src
      this.element.removeAttribute("src")
      this.element.src = src
    }
  }
}
