import { Controller } from "@hotwired/stimulus"

// Toggles a row between its display view and an inline edit form.
// Targets: display (shown normally), form (hidden until edit), field (focused).
export default class extends Controller {
  static targets = ["display", "form", "field"]

  edit(event) {
    event?.preventDefault()
    this.displayTarget.hidden = true
    this.formTarget.hidden = false
    if (this.hasFieldTarget) {
      this.fieldTarget.focus()
      this.fieldTarget.select?.()
    }
  }

  cancel(event) {
    event?.preventDefault()
    this.formTarget.hidden = true
    this.displayTarget.hidden = false
  }

  // Escape key cancels the edit.
  keydown(event) {
    if (event.key === "Escape") this.cancel(event)
  }
}
