import { Controller } from "@hotwired/stimulus"

// Sandbox place-detail modal — opened by clicking a row in the nearby
// table or a pin popup on the map. The actual content lives inside a
// turbo-frame (#sandbox-place-modal); we just toggle visibility and wire
// Esc / backdrop / close-button dismissal.
//
// Flow:
//   1. Trigger element has data-turbo-frame="sandbox-place-modal" and a
//      data-action="click->place-modal#open" on it.
//   2. Turbo loads the frame's URL → frame's body changes → the
//      `turbo:frame-load` listener opens the dialog.
//   3. Clicking the × button dispatches close; Esc / backdrop also close.
export default class extends Controller {
  static targets = ["dialog", "frame"]

  connect() {
    this._escHandler = (e) => { if (e.key === "Escape" && this._isOpen()) this.close() }
    document.addEventListener("keydown", this._escHandler)

    this._frameHandler = (event) => {
      if (event.target?.id !== "sandbox-place-modal") return
      // turbo:frame-load fires on Turbo-driven frame navigations (a user
      // click that targets this frame), not on initial server-rendered
      // placeholder. So this opens precisely when the modal content has
      // been fetched in.
      this.open()
    }
    document.addEventListener("turbo:frame-load", this._frameHandler)
  }

  disconnect() {
    document.removeEventListener("keydown", this._escHandler)
    document.removeEventListener("turbo:frame-load", this._frameHandler)
  }

  // data-action="click->place-modal#open" on the trigger.
  // The link's data-turbo-frame attribute does the fetch; we just preempt
  // the open so the user sees a loading state instead of a blank flash.
  open() {
    this.dialogTarget.hidden = false
    requestAnimationFrame(() => {
      this.dialogTarget.dataset.open = "true"
    })
    document.body.style.overflow = "hidden"
  }

  close() {
    this.dialogTarget.dataset.open = "false"
    document.body.style.overflow = ""
    // Wait for the fade-out transition before hiding completely + clearing
    // the frame, so reopening the same place re-fetches fresh data.
    setTimeout(() => {
      this.dialogTarget.hidden = true
      if (this.hasFrameTarget) this.frameTarget.innerHTML = ""
    }, 180)
  }

  // Backdrop click — only fires when the user clicks the dim layer, not
  // when clicks bubble up from the modal panel itself.
  backdrop(event) {
    if (event.target === event.currentTarget) this.close()
  }

  _isOpen() {
    return this.dialogTarget.dataset.open === "true"
  }
}
