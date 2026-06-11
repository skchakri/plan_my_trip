import { Controller } from "@hotwired/stimulus"

// "Save quizzes for offline" — fetches the manifest of deck pages + flag/logo
// images and asks the service worker to precache them all, so every deck plays
// with no connection (handy mid-travel). Reports progress on a MessageChannel.
export default class extends Controller {
  static values = { url: String }
  static targets = ["button", "status"]

  connect() {
    if (!("serviceWorker" in navigator)) this.element.hidden = true
  }

  async save() {
    const reg = await navigator.serviceWorker.ready
    if (!reg.active) { this.setStatus("Offline mode isn't ready yet — reload and retry."); return }

    this.buttonTarget.disabled = true
    this.setStatus("Preparing…")

    let manifest
    try {
      const res = await fetch(this.urlValue, { headers: { Accept: "application/json" } })
      manifest = await res.json()
    } catch (e) {
      this.setStatus("Couldn't prepare — check your connection.")
      this.buttonTarget.disabled = false
      return
    }

    const channel = new MessageChannel()
    channel.port1.onmessage = (event) => {
      const d = event.data || {}
      if (d.type === "PRECACHE_PROGRESS") {
        this.setStatus(`Saving… ${Math.round((d.cached / d.total) * 100)}%`)
      } else if (d.type === "PRECACHE_DONE") {
        this.setStatus(`✓ Saved — all decks play offline (${d.cached} files)`)
        this.buttonTarget.disabled = false
      } else if (d.type === "PRECACHE_ERROR") {
        this.setStatus("Save failed — try again while online.")
        this.buttonTarget.disabled = false
      }
    }
    reg.active.postMessage(
      { type: "PRECACHE_QUIZ", pages: manifest.pages, images: manifest.images },
      [channel.port2]
    )
  }

  setStatus(text) {
    if (this.hasStatusTarget) this.statusTarget.textContent = text
  }
}
