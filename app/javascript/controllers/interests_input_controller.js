import { Controller } from "@hotwired/stimulus"

// Chip-style free-form interests input.
//
// Markup contract:
//   <div data-controller="interests-input"
//        data-interests-input-name-value="trip[people_attributes][0][interests][]"
//        data-interests-input-known-value='{"kalyan":["sports","art"]}'>
//     <input data-interests-input-target="nameField" ...>          <!-- traveler name -->
//     <div data-interests-input-target="chips" class="...">
//       <!-- one <span data-interests-input-target="chip" data-value="sports"> per existing tag -->
//       <input data-interests-input-target="newInput" ...>
//     </div>
//     <input type="hidden" data-interests-input-target="emptyMarker" name="..." value="">
//   </div>
//
// Each chip carries its own hidden <input name="...[interests][]">, so the
// Rails form params reflect exactly the visible chips.
export default class extends Controller {
  static targets = ["chips", "chip", "newInput", "nameField", "emptyMarker", "limitHint"]
  static values = {
    name: String,       // hidden-input name to use for each chip
    known: { type: Object, default: {} }, // { lowercase-name => [interests] }
    max: { type: Number, default: 0 }     // 0 = unlimited; else cap + "n/max" hint
  }

  connect() {
    this._lastPrefilledFor = this._nameKey()
    this._renderLimit()
  }

  // ENTER or COMMA in the new-tag input → commit it as a chip
  keydown(event) {
    if (event.key === "Enter" || event.key === ",") {
      event.preventDefault()
      this.commit()
    } else if (event.key === "Backspace" && event.target.value === "") {
      // backspace on empty input → remove the last chip
      const chips = this.chipTargets
      if (chips.length > 0) chips[chips.length - 1].remove()
    }
  }

  // Blur on the new-tag input → commit whatever the user typed
  commit() {
    if (!this.hasNewInputTarget) return
    const raw = this.newInputTarget.value
    raw.split(",").map(s => s.trim()).filter(Boolean).forEach(v => this._addChip(v))
    this.newInputTarget.value = ""
  }

  removeChip(event) {
    event.preventDefault()
    const chip = event.currentTarget.closest("[data-interests-input-target='chip']")
    if (chip) chip.remove()
    this._renderLimit()
  }

  // Server-side the list is capped (Trip::MUST_INCLUDES_MAX) — silently. Mirror
  // the cap here so the 13th favourite is refused with a visible reason instead
  // of vanishing after the build.
  _atLimit() { return this.maxValue > 0 && this.chipTargets.length >= this.maxValue }

  _renderLimit() {
    if (!this.maxValue) return
    const n = this.chipTargets.length
    if (this.hasLimitHintTarget) {
      this.limitHintTarget.textContent = this._atLimit() ? `${n}/${this.maxValue} — that's the max; remove one to add another` : `${n}/${this.maxValue}`
      this.limitHintTarget.classList.toggle("text-amber-300", this._atLimit())
    }
    if (this.hasNewInputTarget) {
      this.newInputTarget.disabled = this._atLimit()
      this.newInputTarget.placeholder = this._atLimit() ? "Max reached" : (this.newInputTarget.dataset.placeholder || this.newInputTarget.placeholder)
    }
  }

  // When traveler name changes, if interests are empty for this row and we
  // have a saved list for that name, pre-fill the chips.
  nameChanged() {
    const key = this._nameKey()
    if (!key || key === this._lastPrefilledFor) return
    this._lastPrefilledFor = key
    if (this.chipTargets.length > 0) return
    const saved = this.knownValue[key]
    if (!saved || !saved.length) return
    saved.forEach(v => this._addChip(v))
  }

  // --- private ---

  _nameKey() {
    if (!this.hasNameFieldTarget) return ""
    return this.nameFieldTarget.value.toString().toLowerCase().trim()
  }

  _addChip(value) {
    const v = value.toString().trim()
    if (!v) return
    if (this._atLimit()) { this._renderLimit(); return }
    const existing = this.chipTargets.map(c => c.dataset.value.toLowerCase())
    if (existing.includes(v.toLowerCase())) return

    const chip = document.createElement("span")
    chip.setAttribute("data-interests-input-target", "chip")
    chip.setAttribute("data-value", v)
    chip.className = "inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs bg-amber-500/20 border border-amber-500/50 text-amber-200"

    const hidden = document.createElement("input")
    hidden.type = "hidden"
    hidden.name = this.nameValue
    hidden.value = v
    chip.appendChild(hidden)

    const label = document.createTextNode(v)
    chip.appendChild(label)

    const btn = document.createElement("button")
    btn.type = "button"
    btn.className = "inline-flex items-center justify-center w-6 h-6 -mr-1 rounded-full text-amber-200/70 hover:text-rose-300 hover:bg-rose-500/10 cursor-pointer leading-none"
    btn.setAttribute("aria-label", `Remove ${v}`)
    btn.setAttribute("data-action", "interests-input#removeChip")
    btn.textContent = "×"
    chip.appendChild(btn)

    // Insert before the new-tag input if it lives inside the chips container,
    // otherwise just append.
    if (this.hasNewInputTarget && this.chipsTarget.contains(this.newInputTarget)) {
      this.chipsTarget.insertBefore(chip, this.newInputTarget)
    } else {
      this.chipsTarget.appendChild(chip)
    }
    this._renderLimit()
  }
}
