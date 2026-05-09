import { Controller } from "@hotwired/stimulus"

// Triggers the service worker to pre-cache a list of OSM tile URLs so the
// trip's map thumbnails are available offline. Used by the "Save maps
// offline" button on the Final plan page.
//
// Usage:
//   <button data-controller="offline-maps"
//           data-action="offline-maps#cache"
//           data-offline-maps-urls-value='["https://tile.openstreetmap.org/14/3052/6285.png", ...]'>
//     <span data-offline-maps-target="status">Save maps offline</span>
//   </button>
export default class extends Controller {
  static targets = ["status"]
  static values  = { urls: Array }

  connect() {
    if (!("serviceWorker" in navigator)) {
      this.element.disabled = true
      this.element.title = "Offline maps need a browser with service worker support."
    }
  }

  async cache(event) {
    event.preventDefault()
    const urls = this.urlsValue
    if (!urls.length) return

    this.element.disabled = true
    const baseLabel = this.statusTarget.textContent

    try {
      const reg = await navigator.serviceWorker.ready
      if (!reg.active) {
        this._setStatus("Service worker not active yet — reload and try again")
        this.element.disabled = false
        return
      }

      const total = urls.length
      this._setStatus(`Caching 0/${total}…`)

      await new Promise((resolve) => {
        const channel = new MessageChannel()
        channel.port1.onmessage = (e) => {
          const { type, cached, total: t, error } = e.data || {}
          if (type === "PRECACHE_PROGRESS") {
            this._setStatus(`Caching ${cached}/${t}…`)
          } else if (type === "PRECACHE_DONE") {
            this._setStatus(`✓ ${cached}/${t} maps saved offline`)
            resolve()
          } else if (type === "PRECACHE_ERROR") {
            this._setStatus(`Error: ${error || "unknown"}`)
            resolve()
          }
        }
        reg.active.postMessage({ type: "PRECACHE", urls }, [channel.port2])
      })
    } catch (err) {
      this._setStatus(`Error: ${err.message || err}`)
    } finally {
      // Re-enable after a short pause so the success message is readable.
      setTimeout(() => {
        this.element.disabled = false
        if (this.statusTarget.textContent.startsWith("✓")) {
          // keep the success label
        } else {
          this.statusTarget.textContent = baseLabel
        }
      }, 4000)
    }
  }

  _setStatus(text) {
    this.statusTarget.textContent = text
  }
}
