import { Controller } from "@hotwired/stimulus"
import * as L from "leaflet"

// Opens an interactive Leaflet map in a modal — pan, zoom, multiple pins.
// Single instance per page; the same map is reused across opens so we don't
// pay the init cost on every click.
//
// Tile source is tile.openstreetmap.org (same URL pattern the SW already
// caches), so a tap on a thumbnail reuses tiles you've seen offline.
//
// Action params on the trigger element:
//   data-interactive-map-pins-param='[{"lat":..., "lng":..., "name":..., "kind":"itinerary|scenic|...", "mapsHref":"..."}]'
//   data-interactive-map-focus-param='{"lat":..., "lng":..., "name":"..."}'  (optional — pin to highlight)
//   data-interactive-map-title-param="Day 1 — Strip & shows"
export default class extends Controller {
  static targets = ["modal", "mapEl", "title", "subtitle"]

  connect() {
    this._escHandler = (e) => { if (e.key === "Escape") this.close() }
    document.addEventListener("keydown", this._escHandler)
  }

  disconnect() {
    document.removeEventListener("keydown", this._escHandler)
    if (this._map) {
      this._map.remove()
      this._map = null
    }
  }

  open(event) {
    try {
      const params = (event && event.params) || {}
      const pins   = this._parseJSONLike(params.pins)
      const focus  = this._parseJSONLike(params.focus)
      const title  = params.title || "Map"

      if (!Array.isArray(pins) || pins.length === 0) {
        console.warn("[interactive-map] no pins in params", params)
        return
      }

      this.titleTarget.textContent = title
      this.subtitleTarget.textContent = pins.length === 1
        ? (pins[0].name || "")
        : `${pins.length} stops`

      this.modalTarget.hidden = false
      document.body.style.overflow = "hidden"
      requestAnimationFrame(() => {
        this.modalTarget.dataset.open = "true"
        try {
          this._ensureMap()
          this._map.invalidateSize()
          this._renderPins(pins, focus)
        } catch (err) {
          console.error("[interactive-map] map render failed:", err)
        }
      })
    } catch (err) {
      console.error("[interactive-map] open failed:", err)
    }
  }

  // Stimulus auto-parses `[...]` / `{...}` action params, but be defensive
  // — accept already-parsed values OR JSON strings interchangeably.
  _parseJSONLike(value) {
    if (value == null) return null
    if (typeof value !== "string") return value
    try { return JSON.parse(value) } catch { return value }
  }

  close() {
    if (!this.hasModalTarget || this.modalTarget.hidden) return
    this.modalTarget.dataset.open = "false"
    document.body.style.overflow = ""
    setTimeout(() => { this.modalTarget.hidden = true }, 180)
  }

  closeOnBackdrop(event) {
    if (event.target === this.modalTarget) this.close()
  }

  // --- private ---

  _ensureMap() {
    if (this._map) return

    this._map = L.map(this.mapElTarget, {
      zoomControl: true,
      attributionControl: false,
      scrollWheelZoom: true,
      worldCopyJump: true
    }).setView([39.8, -98.5], 4)

    // No crossOrigin — the SW caches tiles as opaque (mode: "no-cors"),
    // and the browser refuses to render opaque responses through a
    // crossorigin="anonymous" <img>.
    L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
      maxZoom: 19
    }).addTo(this._map)

    L.control.attribution({ prefix: false })
      .addAttribution('&copy; <a href="https://openstreetmap.org/copyright">OpenStreetMap</a>')
      .addTo(this._map)

    this._markers = L.layerGroup().addTo(this._map)
  }

  _renderPins(pins, focus) {
    this._markers.clearLayers()
    const latlngs = []

    pins.forEach((pin) => {
      if (typeof pin.lat !== "number" || typeof pin.lng !== "number") return
      const isFocus = focus && pin.lat === focus.lat && pin.lng === focus.lng
      const marker = L.marker([pin.lat, pin.lng], {
        icon: this._icon(pin.kind, isFocus),
        title: pin.name || ""
      })
      const popup = this._popupHtml(pin)
      if (popup) marker.bindPopup(popup)
      marker.addTo(this._markers)
      latlngs.push([pin.lat, pin.lng])
    })

    if (latlngs.length === 1) {
      this._map.setView(latlngs[0], 14)
    } else if (latlngs.length > 1) {
      this._map.fitBounds(L.latLngBounds(latlngs), { padding: [40, 40], maxZoom: 14 })
    }
  }

  _popupHtml(pin) {
    const safe = (s) => String(s || "").replace(/[&<>"']/g, (c) => (
      { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]
    ))
    const parts = []
    if (pin.name) parts.push(`<div class="font-semibold text-slate-900 leading-tight">${safe(pin.name)}</div>`)
    if (pin.mapsHref) {
      parts.push(`<a href="${safe(pin.mapsHref)}" target="_blank" rel="noopener" class="mt-1 inline-block text-xs text-blue-600 underline">Open in Maps &rarr;</a>`)
    }
    return parts.length ? `<div class="text-sm">${parts.join("")}</div>` : null
  }

  _icon(kind, isFocus) {
    const color = isFocus
      ? "#f59e0b"
      : kind === "scenic" ? "#10b981"
      : kind === "landmark" ? "#a78bfa"
      : "#f43f5e"
    const size = isFocus ? 36 : 30
    const svg = `
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="${color}" stroke="#0a0e1a" stroke-width="1.2" stroke-linejoin="round" style="filter:drop-shadow(0 1px 2px rgba(0,0,0,.5))">
        <path d="M12 22s-7-7.5-7-13a7 7 0 1 1 14 0c0 5.5-7 13-7 13Z"/>
        <circle cx="12" cy="9" r="2.5" fill="#fff" stroke="none"/>
      </svg>`
    return L.divIcon({
      className: "pmt-pin",
      html: svg,
      iconSize: [size, size],
      iconAnchor: [size / 2, size]
    })
  }
}
