import { Controller } from "@hotwired/stimulus"

// Tracks day-trip idea-card selections. Lights up the sticky build-button
// once at least one idea is checked, and shows a running counter.
//
// Two ways the cards can be toggled now:
//   1. The card body itself opens the detail modal (turbo-frame nav); the
//      modal's "Add to my plan" button dispatches `idea-picker:toggle` with
//      `{ slug }` in detail which we catch via #toggleFromEvent.
//   2. A small +/✓ button overlaid on the card calls #toggle directly with
//      data-slug — same effect, no modal trip.
export default class extends Controller {
  static targets = ["checkbox", "counter", "summary", "submit"]

  connect() {
    this._eventHandler = (e) => this.toggleFromEvent(e)
    window.addEventListener("idea-picker:toggle", this._eventHandler)
    this.update()
    this._syncSelectionUi()
  }

  disconnect() {
    window.removeEventListener("idea-picker:toggle", this._eventHandler)
  }

  update() {
    const count = this.checkboxTargets.filter(cb => cb.checked).length
    if (this.hasCounterTarget) this.counterTarget.textContent = `${count} selected`
    if (this.hasSummaryTarget) this.summaryTarget.textContent = count
    if (this.hasSubmitTarget) this.submitTarget.disabled = count === 0
    this._syncSelectionUi()
  }

  // data-action="click->idea-picker#toggle" on a button that carries
  // data-slug="<idea slug>". Flips the matching hidden checkbox.
  toggle(event) {
    event?.preventDefault?.()
    event?.stopPropagation?.()
    const slug = event.currentTarget.dataset.slug
    this._setChecked(slug, undefined)
  }

  // Window-level event fired by the modal's add/remove button.
  // detail: { slug, checked? } — checked omitted means "flip".
  toggleFromEvent(event) {
    const { slug, checked } = event.detail || {}
    if (!slug) return
    this._setChecked(slug, checked)
  }

  _setChecked(slug, forced) {
    const cb = this.checkboxTargets.find(c => c.value === slug)
    if (!cb) return
    cb.checked = (forced === undefined) ? !cb.checked : !!forced
    this.update()
    // Broadcast so the modal (if open and showing this slug) can flip its
    // own button label in real time.
    window.dispatchEvent(new CustomEvent("idea-picker:changed", {
      detail: { slug, checked: cb.checked }
    }))
  }

  _syncSelectionUi() {
    // Toggle a [data-selected] flag on each card root so CSS can highlight
    // selected cards without depending on :has() (better mobile compat).
    this.checkboxTargets.forEach(cb => {
      const card = cb.closest("[data-idea-card]")
      if (card) card.dataset.selected = cb.checked ? "true" : "false"
    })
  }
}
