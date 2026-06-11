import { Controller } from "@hotwired/stimulus"

// Submit the host <form> whenever a control fires the `submit` action — used by
// the Country Explorer's country picker so changing the <select> navigates.
export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }
}
