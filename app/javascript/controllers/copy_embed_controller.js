import { Controller } from "@hotwired/stimulus"

// Copies the embed snippet to the clipboard with a brief "Copied" label swap.
export default class extends Controller {
  static targets = ["source", "label"]

  select() { this.sourceTarget.select() }

  async copy() {
    const text = this.sourceTarget.value
    try {
      await navigator.clipboard.writeText(text)
      this._flash("Copied!")
    } catch (_) {
      this.sourceTarget.select()
      document.execCommand && document.execCommand("copy")
      this._flash("Copied!")
    }
  }

  _flash(msg) {
    if (!this.hasLabelTarget) return
    const prev = this.labelTarget.textContent
    this.labelTarget.textContent = msg
    setTimeout(() => { this.labelTarget.textContent = prev }, 1600)
  }
}
