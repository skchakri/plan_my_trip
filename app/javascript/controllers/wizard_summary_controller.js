import { Controller } from "@hotwired/stimulus"

// Live "Your trip so far" rail on wizard step 1. Mirrors the form fields
// (destination, dates, travelers, transport mode, must-include chips) into
// the right-hand summary card as the user types — no server round-trip.
//
// Attach to an element wrapping BOTH the form and the summary card, with
// input/change/click/keydown actions pointing at #refresh. Chip add/remove
// (interests-input) mutates hidden inputs in the same task as the event we
// react to, so rendering is deferred a frame to read the settled DOM.
const DRIVING_MODES = ["own_car", "rental", "mixed"]

export default class extends Controller {
  static targets = ["destination", "dates", "travelers", "mode",
                    "favourites", "favouritesEmpty", "driveNote", "driveHint"]
  static values = { modeLabels: { type: Object, default: {} } }

  connect() { this.refresh() }

  disconnect() {
    if (this._raf) cancelAnimationFrame(this._raf)
  }

  refresh() {
    if (this._raf) cancelAnimationFrame(this._raf)
    this._raf = requestAnimationFrame(() => this._render())
  }

  // --- private ---

  _render() {
    const val = (name) => this.element.querySelector(`[name="wizard[${name}]"]`)?.value?.trim() || ""

    // The rail is an aria-live region: only touch the DOM when a value
    // actually changed, or screen readers re-announce the card on every
    // keystroke anywhere in the form.
    if (this.hasDestinationTarget) this._setText(this.destinationTarget, val("destination") || "—")
    if (this.hasDatesTarget) this._setText(this.datesTarget, this._dateRange(val("start_date"), val("end_date")))
    if (this.hasTravelersTarget) this._setText(this.travelersTarget, val("traveler_count") || "—")

    const mode = this.element.querySelector('input[name="wizard[transport_mode]"]:checked')?.value
    if (this.hasModeTarget) this._setText(this.modeTarget, (mode && this.modeLabelsValue[mode]) || "Not set yet")

    const driving = DRIVING_MODES.includes(mode)
    if (this.hasDriveNoteTarget && this.driveNoteTarget.hidden === driving) this.driveNoteTarget.hidden = !driving
    if (this.hasDriveHintTarget && this.driveHintTarget.hidden === driving) this.driveHintTarget.hidden = !driving

    this._renderFavourites()
  }

  _setText(target, text) {
    if (target.textContent !== text) target.textContent = text
  }

  _renderFavourites() {
    if (!this.hasFavouritesTarget) return
    // Committed chips only (hidden inputs). The visible text input shares the
    // name so an uncommitted entry still SUBMITS, but it is excluded here —
    // previewing it per keystroke would spam the aria-live region.
    const values = Array.from(this.element.querySelectorAll('input[type="hidden"][name="wizard[must_includes][]"]'))
      .map(input => input.value.trim())
      .filter(Boolean)
      .filter((v, i, all) => all.indexOf(v) === i)

    // Same live-region rule: rebuild the list only when it changed.
    const key = JSON.stringify(values)
    if (key === this._lastFavourites) return
    this._lastFavourites = key

    this.favouritesTarget.replaceChildren(...values.map(v => {
      const li = document.createElement("li")
      li.className = "inline-flex items-center px-2 py-0.5 rounded-md bg-amber-500/10 border border-amber-500/25 text-amber-200 text-xs"
      li.textContent = v
      return li
    }))
    this.favouritesTarget.hidden = values.length === 0
    if (this.hasFavouritesEmptyTarget) this.favouritesEmptyTarget.hidden = values.length > 0
  }

  _dateRange(start, end) {
    if (!start && !end) return "—"
    const fmt = (s) => {
      const d = new Date(`${s}T00:00:00`)
      return isNaN(d) ? s : d.toLocaleDateString(undefined, { month: "short", day: "numeric" })
    }
    if (!(start && end)) return fmt(start || end)

    const nights = Math.round((new Date(`${end}T00:00:00`) - new Date(`${start}T00:00:00`)) / 86400000)
    const days = isNaN(nights) || nights < 0 ? null : nights + 1
    return `${fmt(start)} → ${fmt(end)}${days ? ` · ${days} day${days === 1 ? "" : "s"}` : ""}`
  }
}
