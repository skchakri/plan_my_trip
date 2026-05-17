import { Controller } from "@hotwired/stimulus"

// Toggles between admin Sandbox panels (Plan a trip / Places nearby).
// Active panel is reflected in the URL via ?tab=<name> so refresh sticks.
export default class extends Controller {
  static targets = ["tab", "panel"]

  connect() {
    const active = new URLSearchParams(window.location.search).get("tab") || "plan"
    this._activate(active)
  }

  switch(event) {
    const name = event.currentTarget.dataset.tab
    this._activate(name)
  }

  _activate(name) {
    this.tabTargets.forEach(t => {
      const on = t.dataset.tab === name
      t.classList.toggle("border-amber-400", on)
      t.classList.toggle("border-transparent", !on)
      t.classList.toggle("text-amber-300", on)
      t.classList.toggle("text-slate-400", !on)
      t.classList.toggle("font-semibold", on)
    })
    this.panelTargets.forEach(p => {
      p.classList.toggle("hidden", p.dataset.tab !== name)
    })
  }
}
