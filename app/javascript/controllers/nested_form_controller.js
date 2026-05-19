import { Controller } from "@hotwired/stimulus"

// Adds and removes rows of a nested-attribute form section, like the
// "Travelers" fieldset on the trip form. The controller is responsible
// for cloning a <template> row, rewriting its child index from
// "NEW_RECORD" to a unique value, and appending it to the container.
//
// Markup contract (see app/views/trips/_form.html.erb):
//   <fieldset data-controller="nested-form">
//     <div data-nested-form-target="container">…existing rows…</div>
//     <template data-nested-form-target="template">…one row…</template>
//     <button data-action="nested-form#add">Add another</button>
//   </fieldset>
//
// Per-row, a "remove" button on a brand-new (unsaved) row simply hides
// the row in the DOM. For persisted rows the standard `_destroy`
// checkbox handles deletion server-side.
export default class extends Controller {
  static targets = ["container", "template"]

  add(event) {
    event.preventDefault()
    if (!this.hasTemplateTarget || !this.hasContainerTarget) return
    const html = this.templateTarget.innerHTML.replace(/NEW_RECORD/g, Date.now().toString())
    this.containerTarget.insertAdjacentHTML("beforeend", html)
  }

  // Inserts a new row pre-filled with name, age, and interest chips read
  // from the clicked element's data attributes. Used by the wizard's
  // "travel with someone again?" suggestion cards.
  //
  //   <button data-action="nested-form#addFrom"
  //           data-name="Mani" data-age="12"
  //           data-interests='["legos","minecraft"]'>...</button>
  addFrom(event) {
    event.preventDefault()
    if (!this.hasTemplateTarget || !this.hasContainerTarget) return
    const card = event.currentTarget
    const name = card.dataset.name || ""
    const age = card.dataset.age || ""
    let interests = []
    try { interests = JSON.parse(card.dataset.interests || "[]") } catch (_) {}

    // Find an existing blank row before cloning — pre-fill it instead of
    // appending so a fresh wizard load doesn't end up with an empty
    // "untitled" row + the prefilled one.
    let row = Array.from(this.containerTarget.querySelectorAll(".traveler-row")).find(r => {
      const n = r.querySelector('input[name$="[name]"]')
      return n && !n.value.trim()
    })

    if (!row) {
      const html = this.templateTarget.innerHTML.replace(/NEW_RECORD/g, Date.now().toString())
      this.containerTarget.insertAdjacentHTML("beforeend", html)
      row = this.containerTarget.querySelector(".traveler-row:last-child")
    }
    if (!row) return

    const nameInput = row.querySelector('input[name$="[name]"]')
    const ageInput = row.querySelector('input[name$="[age]"]')
    if (nameInput) nameInput.value = name
    if (ageInput) ageInput.value = age

    // Skip the interests-input prefill-from-name path so it doesn't
    // double-up our chips. Mark this row's interests controller as
    // already-prefilled before we add chips manually.
    const interestsHost = row.querySelector('[data-controller~="interests-input"]')
    const chipNameAttr = interestsHost?.dataset.interestsInputNameValue
    const chipsContainer = row.querySelector('[data-interests-input-target="chips"]')
    const newInputEl = row.querySelector('[data-interests-input-target="newInput"]')
    if (chipsContainer && chipNameAttr) {
      interests.forEach(v => {
        const value = (v || "").toString().trim()
        if (!value) return
        const chip = document.createElement("span")
        chip.setAttribute("data-interests-input-target", "chip")
        chip.setAttribute("data-value", value)
        chip.className = "inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs bg-amber-500/20 border border-amber-500/50 text-amber-200"

        const hidden = document.createElement("input")
        hidden.type = "hidden"
        hidden.name = chipNameAttr
        hidden.value = value
        chip.appendChild(hidden)
        chip.appendChild(document.createTextNode(value))

        const btn = document.createElement("button")
        btn.type = "button"
        btn.className = "text-amber-200/70 hover:text-rose-300 ml-0.5 cursor-pointer leading-none"
        btn.setAttribute("aria-label", `Remove ${value}`)
        btn.setAttribute("data-action", "interests-input#removeChip")
        btn.textContent = "×"
        chip.appendChild(btn)

        if (newInputEl && chipsContainer.contains(newInputEl)) {
          chipsContainer.insertBefore(chip, newInputEl)
        } else {
          chipsContainer.appendChild(chip)
        }
      })
    }

    // Hide the suggestion card so the same person can't be added twice.
    const suggestion = card.closest("[data-known-traveler]")
    if (suggestion) suggestion.remove()

    if (nameInput) nameInput.focus()
  }

  remove(event) {
    event.preventDefault()
    const row = event.target.closest(".traveler-row, [data-nested-form-row]")
    if (!row) return
    // Tell Rails to ignore this row on submit (in case it had any id) and
    // visually drop it. For brand-new rows the hidden _destroy=1 + display:none
    // is enough; for persisted rows the form already has the _destroy checkbox.
    const destroy = row.querySelector('input[name$="[_destroy]"]')
    if (destroy) destroy.value = "1"
    row.style.display = "none"
  }
}
