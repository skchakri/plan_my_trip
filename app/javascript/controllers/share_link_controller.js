import { Controller } from "@hotwired/stimulus"

// Copy the read-only share URL to the clipboard and flash "Copied" on the
// button. Falls back to the legacy execCommand path for pre-Clipboard-API
// browsers (older mobile WebViews).
export default class extends Controller {
  static targets = ["url", "copyBtn"]

  async copy() {
    const value = this.urlTarget.value
    let ok = false
    try {
      if (navigator.clipboard && window.isSecureContext) {
        await navigator.clipboard.writeText(value)
        ok = true
      } else {
        this.urlTarget.select()
        ok = document.execCommand("copy")
      }
    } catch (_) { ok = false }
    this.#flash(ok ? "Copied" : "Press ⌘C")
  }

  #flash(text) {
    const btn = this.copyBtnTarget
    const orig = btn.textContent
    btn.textContent = text
    btn.disabled = true
    setTimeout(() => { btn.textContent = orig; btn.disabled = false }, 1400)
  }
}
