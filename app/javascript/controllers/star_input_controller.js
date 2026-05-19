import { Controller } from "@hotwired/stimulus"

// 5-star clickable rating input. Hover previews, click commits, the
// underlying hidden <input> ends up with the selected value so the form
// posts a normal rating field.
export default class extends Controller {
  static targets = ["star", "input", "label"]
  static values  = { value: Number }

  static LABELS = ["", "Bad", "Meh", "OK", "Great", "Loved it"]

  connect()    { this.render(this.valueValue) }
  reset()      { this.render(this.valueValue) }
  preview(e)   { this.render(parseInt(e.currentTarget.dataset.value, 10)) }
  select(e) {
    this.valueValue = parseInt(e.currentTarget.dataset.value, 10)
    this.inputTarget.value = this.valueValue
    this.render(this.valueValue)
  }

  render(n) {
    this.starTargets.forEach((s, i) => {
      s.classList.toggle("text-amber-300", i < n)
      s.classList.toggle("text-slate-700", i >= n)
    })
    if (this.hasLabelTarget) this.labelTarget.textContent = this.constructor.LABELS[n] || ""
  }
}
