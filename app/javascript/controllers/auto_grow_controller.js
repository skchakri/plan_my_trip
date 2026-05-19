import { Controller } from "@hotwired/stimulus"

// Grow a <textarea> to fit its content as the user types. Capped at 6 rows
// so the form doesn't push the page when someone pastes a wall of text.
export default class extends Controller {
  static MAX_PX = 180

  connect() { this.resize() }

  resize() {
    const el = this.element
    el.style.height = "auto"
    el.style.height = Math.min(el.scrollHeight, 180) + "px"
  }
}
