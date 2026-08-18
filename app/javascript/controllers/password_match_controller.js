import { Controller } from "@hotwired/stimulus"

// Live "passwords don't match" feedback on the sign-up form so a typo doesn't
// cost a full round-trip (and the rest of the form) at the highest-value moment.
//   <form data-controller="password-match">
//     <input data-password-match-target="password">
//     <input data-password-match-target="confirmation" data-action="input->password-match#check blur->password-match#check">
//     <p data-password-match-target="hint" hidden>Passwords don't match</p>
export default class extends Controller {
  static targets = ["password", "confirmation", "hint"]

  check() {
    const a = this.passwordTarget.value, b = this.confirmationTarget.value
    const mismatch = b.length > 0 && a !== b
    this.confirmationTarget.setAttribute("aria-invalid", mismatch ? "true" : "false")
    this.confirmationTarget.classList.toggle("border-rose-500", mismatch)
    if (this.hasHintTarget) this.hintTarget.hidden = !mismatch
  }
}
