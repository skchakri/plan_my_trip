import { Controller } from "@hotwired/stimulus"

// Persistent toast stack. Renders client-dispatched toasts on top of any
// server-rendered flash toasts. Fire one from anywhere with:
//   window.dispatchEvent(new CustomEvent("toast",
//     { detail: { type: "alert", message: "Couldn't save." } }))
// type: "notice" (default) | "alert".
export default class extends Controller {
  show(event) {
    const { type = "notice", message } = event.detail || {}
    if (!message) return
    this.element.appendChild(this.build(type, message))
  }

  build(type, message) {
    const alert = type === "alert"
    const el = document.createElement("div")
    el.setAttribute("role", alert ? "alert" : "status")
    el.setAttribute("data-controller", "auto-dismiss")
    el.setAttribute("data-auto-dismiss-delay-value", alert ? "7000" : "4500")
    el.className =
      "pointer-events-auto sm:max-w-sm rounded-xl border bg-slate-900/95 backdrop-blur px-4 py-3 shadow-xl shadow-black/40 flex items-start gap-2.5 " +
      (alert ? "border-rose-500/40 text-rose-100" : "border-emerald-500/40 text-emerald-100")

    const text = document.createElement("span")
    text.className = "text-sm min-w-0 flex-1"
    text.textContent = message

    const close = document.createElement("button")
    close.type = "button"
    close.setAttribute("aria-label", "Dismiss")
    close.setAttribute("data-action", "auto-dismiss#dismiss")
    close.className =
      "shrink-0 -mr-1 -mt-0.5 p-1 rounded hover:bg-white/10 text-slate-400 hover:text-slate-100 cursor-pointer"
    close.textContent = "✕"

    el.appendChild(text)
    el.appendChild(close)
    return el
  }
}
