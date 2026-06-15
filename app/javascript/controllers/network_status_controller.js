import { Controller } from "@hotwired/stimulus"

// Shows its element only while the browser is offline. Cached pages stay
// viewable offline, but writes (checklist toggles, edits) need a connection —
// this is the honest signal that new changes won't save until reconnect.
export default class extends Controller {
  connect() {
    this.update = this.update.bind(this)
    window.addEventListener("online", this.update)
    window.addEventListener("offline", this.update)
    this.update()
  }

  disconnect() {
    window.removeEventListener("online", this.update)
    window.removeEventListener("offline", this.update)
  }

  update() {
    this.element.hidden = navigator.onLine
  }
}
