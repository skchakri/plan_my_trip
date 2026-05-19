import { Controller } from "@hotwired/stimulus"

// Tracks day-trip idea-card selections. Lights up the sticky build-button
// once at least one idea is checked, and shows a running counter.
export default class extends Controller {
  static targets = ["checkbox", "counter", "summary", "submit"]

  connect() {
    this.update()
  }

  update() {
    const count = this.checkboxTargets.filter(cb => cb.checked).length
    if (this.hasCounterTarget) this.counterTarget.textContent = `${count} selected`
    if (this.hasSummaryTarget) this.summaryTarget.textContent = count
    if (this.hasSubmitTarget) this.submitTarget.disabled = count === 0
  }
}
