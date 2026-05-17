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
