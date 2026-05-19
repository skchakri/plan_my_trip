import { Controller } from "@hotwired/stimulus"

// Lives inside the day-trip-idea-modal turbo-frame body. Owns the "Add to
// my day plan" button — clicking it dispatches `idea-picker:toggle` on
// window so the parent page's idea-picker controller flips the matching
// hidden checkbox. Listens back on `idea-picker:changed` to update the
// button label in real time.
export default class extends Controller {
  static targets = ["planButton", "planLabel"]
  static values = { slug: String }

  connect() {
    this._changedHandler = (e) => {
      if (e.detail?.slug !== this.slugValue) return
      this._reflect(e.detail.checked)
    }
    window.addEventListener("idea-picker:changed", this._changedHandler)
    this._reflect(this._currentCheckedState())
  }

  disconnect() {
    window.removeEventListener("idea-picker:changed", this._changedHandler)
  }

  togglePlan(event) {
    event?.preventDefault?.()
    window.dispatchEvent(new CustomEvent("idea-picker:toggle", {
      detail: { slug: this.slugValue }
    }))
  }

  _currentCheckedState() {
    const cb = document.querySelector(
      `input[type="checkbox"][name="selected_slugs[]"][value="${CSS.escape(this.slugValue)}"]`
    )
    return !!(cb && cb.checked)
  }

  _reflect(checked) {
    if (!this.hasPlanLabelTarget) return
    this.planLabelTarget.textContent = checked
      ? "Remove from my day plan"
      : "Add to my day plan"
    if (this.hasPlanButtonTarget) {
      this.planButtonTarget.classList.toggle("bg-emerald-500", !checked)
      this.planButtonTarget.classList.toggle("hover:bg-emerald-400", !checked)
      this.planButtonTarget.classList.toggle("bg-rose-500/90", checked)
      this.planButtonTarget.classList.toggle("hover:bg-rose-500", checked)
      this.planButtonTarget.classList.toggle("text-white", checked)
      this.planButtonTarget.classList.toggle("text-slate-950", !checked)
    }
  }
}
