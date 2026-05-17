import { Controller } from "@hotwired/stimulus"

// Client-side filter for the highlights step.
//
// Each card carries `data-vibe-filter-target="card" data-category="..."`.
// Vibe chips are <input type="checkbox"> with data-action="vibe-filter#refresh".
// When any chips are checked, only matching cards stay visible. When none
// are checked, everything shows.
//
// We also mirror the selected vibes into the URL via history.replaceState
// so the choice is shareable and survives a hard refresh, without paying
// a server round-trip on every toggle.
export default class extends Controller {
  static targets = ["card", "count", "empty"]

  refresh() {
    const selected = this._selectedVibes()
    let shown = 0
    this.cardTargets.forEach(card => {
      const cat = (card.dataset.category || "").toLowerCase()
      const match = selected.length === 0 || selected.includes(cat)
      card.hidden = !match
      if (match) shown++
    })

    if (this.hasCountTarget) this.countTarget.textContent = shown
    if (this.hasEmptyTarget) this.emptyTarget.hidden = shown > 0

    this._updateUrl(selected)
  }

  clear() {
    this.element.querySelectorAll("input[type='checkbox'][name='vibes[]']").forEach(cb => {
      cb.checked = false
    })
    this.refresh()
  }

  _selectedVibes() {
    return Array.from(this.element.querySelectorAll("input[type='checkbox'][name='vibes[]']:checked"))
      .map(cb => cb.value.toLowerCase())
      .filter(Boolean)
  }

  _updateUrl(selected) {
    const url = new URL(window.location.href)
    url.searchParams.delete("vibes[]")
    selected.forEach(v => url.searchParams.append("vibes[]", v))
    window.history.replaceState({}, "", url.toString())
  }
}
