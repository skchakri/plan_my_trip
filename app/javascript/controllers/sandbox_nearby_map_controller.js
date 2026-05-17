import { Controller } from "@hotwired/stimulus"
import * as L from "leaflet"

// Renders the static Leaflet map for the admin "places nearby" panel.
//
// Values:
//   origin: { lat, lng, label, radiusKm }
//   places: [{ id, name, lat, lng, kind, tier, distance_m, image_url, url }]
//
// Sync behavior: hovering a row in the sister table (data-place-row="<id>")
// pops up that pin's popup. Clicking a pin scrolls the row into view.
export default class extends Controller {
  static values = {
    origin: Object,
    places: Array
  }

  connect() {
    this._initMap()
    this._renderPins()
    this._wireTableHover()
  }

  disconnect() {
    if (this._map) { this._map.remove(); this._map = null }
    this._markers = {}
  }

  _initMap() {
    const { lat, lng, radiusKm } = this.originValue
    this._map = L.map(this.element, {
      zoomControl: true,
      scrollWheelZoom: false,
      attributionControl: true
    }).setView([lat, lng], this._zoomFor(radiusKm))

    L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
      attribution: "© OpenStreetMap",
      maxZoom: 18
    }).addTo(this._map)

    // Origin marker + radius ring
    L.circleMarker([lat, lng], {
      radius: 7, color: "#fbbf24", fillColor: "#fbbf24", fillOpacity: 0.9, weight: 2
    }).addTo(this._map).bindPopup(`<b>${this.originValue.label || "Origin"}</b>`)

    L.circle([lat, lng], {
      radius: radiusKm * 1000,
      color: "#fbbf24", fillColor: "#fbbf24", fillOpacity: 0.04, weight: 1, dashArray: "4 4"
    }).addTo(this._map)
  }

  _renderPins() {
    this._markers = {}
    const places = this.placesValue || []
    if (!places.length) return

    const tierColor = {
      iconic:     "#fbbf24",
      well_known: "#a78bfa",
      underrated: "#34d399",
      hidden_gem: "#22d3ee"
    }

    places.forEach(p => {
      const color = tierColor[p.tier] || "#94a3b8"
      const m = L.circleMarker([p.lat, p.lng], {
        radius: 5, color: color, fillColor: color, fillOpacity: 0.85, weight: 1
      }).addTo(this._map)

      const popupHtml = `
        <div style="font-family:system-ui;font-size:12px;color:#0f172a;min-width:180px">
          ${p.image_url ? `<img src="${p.image_url}" style="width:100%;height:80px;object-fit:cover;border-radius:4px;margin-bottom:6px">` : ""}
          <div style="font-weight:600">${this._escape(p.name)}</div>
          <div style="color:#64748b;font-size:11px">${p.kind || ""}${p.tier ? " · " + p.tier : ""}</div>
          <div style="color:#64748b;font-size:11px;margin-top:2px">${(p.distance_m / 1000).toFixed(1)} km away</div>
          ${p.url ? `<a href="${p.url}" data-turbo-frame="sandbox-place-modal" style="color:#b45309;font-size:11px;font-weight:600">Details →</a>` : ""}
        </div>`
      m.bindPopup(popupHtml)
      m.on("click", () => this._scrollRowIntoView(p.id))
      this._markers[p.id] = m
    })
  }

  _wireTableHover() {
    const rows = document.querySelectorAll("[data-place-row]")
    rows.forEach(row => {
      const id = row.dataset.placeRow
      row.addEventListener("mouseenter", () => {
        const m = this._markers[id]
        if (m) m.openPopup()
      })
      row.addEventListener("mouseleave", () => {
        const m = this._markers[id]
        if (m) m.closePopup()
      })
    })
  }

  _scrollRowIntoView(id) {
    const row = document.querySelector(`[data-place-row="${id}"]`)
    if (row) row.scrollIntoView({ behavior: "smooth", block: "center" })
  }

  _zoomFor(radiusKm) {
    if (radiusKm <= 10)  return 11
    if (radiusKm <= 25)  return 10
    if (radiusKm <= 50)  return 9
    if (radiusKm <= 100) return 8
    return 7
  }

  _escape(s) {
    return String(s || "").replace(/[<>&"']/g, c => ({ "<": "&lt;", ">": "&gt;", "&": "&amp;", '"': "&quot;", "'": "&#39;" }[c]))
  }
}
