import { Controller } from "@hotwired/stimulus"
import * as L from "leaflet"

// Leaflet map for the wizard's "Pick the must-sees" step. Renders one pin
// per highlight that has coordinates, color-coded by category. Hovering a
// highlight card opens the matching pin's popup; clicking a pin scrolls
// the matching card into view and highlights it.
//
// Values:
//   points: [{ slug, name, lat, lng, category, image_url, selected }]
//   center: { lat, lng }              // optional; defaults to bounds of points
//
// Cards in the grid use data-slug="…" so the controller can wire up the
// two-way hover/scroll sync without coupling to the grid markup.
export default class extends Controller {
  static targets = ["map"]
  static values = {
    points: Array,
    center: Object
  }

  connect() {
    if (!this.pointsValue || this.pointsValue.length === 0) {
      this.element.hidden = true
      return
    }
    this._initMap()
    this._renderPins()
    this._wireCardSync()
  }

  disconnect() {
    if (this._map) { this._map.remove(); this._map = null }
    this._markers = {}
    this._cardListeners?.forEach(({ el, enter, leave }) => {
      el.removeEventListener("mouseenter", enter)
      el.removeEventListener("mouseleave", leave)
    })
    this._cardListeners = []
  }

  _initMap() {
    this._map = L.map(this.mapTarget, {
      zoomControl: true,
      scrollWheelZoom: false,
      attributionControl: true
    })

    L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
      attribution: "© OpenStreetMap",
      maxZoom: 18
    }).addTo(this._map)

    const pts = this.pointsValue.map(p => [p.lat, p.lng])
    if (pts.length === 1) {
      this._map.setView(pts[0], 11)
    } else {
      this._map.fitBounds(L.latLngBounds(pts), { padding: [30, 30] })
    }
  }

  _renderPins() {
    this._markers = {}
    const categoryColor = {
      nature: "#34d399", scenic: "#22d3ee", adventure: "#f97316",
      photography: "#a78bfa", history: "#fbbf24", cultural: "#facc15",
      family: "#fb7185", food: "#f472b6", relaxing: "#60a5fa",
      shopping: "#e879f9", nightlife: "#c084fc"
    }

    this.pointsValue.forEach(p => {
      const color = categoryColor[p.category] || "#94a3b8"
      const m = L.circleMarker([p.lat, p.lng], {
        radius: p.selected ? 8 : 6,
        color: p.selected ? "#fbbf24" : color,
        fillColor: color,
        fillOpacity: p.selected ? 1 : 0.85,
        weight: p.selected ? 3 : 1.5
      }).addTo(this._map)

      const popupHtml = `
        <div style="font-family:system-ui;font-size:12px;color:#0f172a;min-width:180px;max-width:220px">
          ${p.image_url ? `<img src="${p.image_url}" referrerpolicy="no-referrer" style="width:100%;height:80px;object-fit:cover;border-radius:4px;margin-bottom:6px">` : ""}
          <div style="font-weight:600">${this._escape(p.name)}</div>
          ${p.category ? `<div style="color:#64748b;font-size:11px;text-transform:uppercase;letter-spacing:0.08em;margin-top:2px">${this._escape(p.category)}</div>` : ""}
        </div>`
      m.bindPopup(popupHtml)
      m.on("click", () => this._focusCard(p.slug))
      this._markers[p.slug] = m
    })
  }

  _wireCardSync() {
    this._cardListeners = []
    const cards = document.querySelectorAll("[data-slug]")
    cards.forEach(el => {
      const slug = el.dataset.slug
      const m = this._markers[slug]
      if (!m) return
      const enter = () => m.openPopup()
      const leave = () => m.closePopup()
      el.addEventListener("mouseenter", enter)
      el.addEventListener("mouseleave", leave)
      this._cardListeners.push({ el, enter, leave })
    })
  }

  _focusCard(slug) {
    const card = document.querySelector(`[data-slug="${slug}"]`)
    if (!card) return
    card.scrollIntoView({ behavior: "smooth", block: "center" })
    card.classList.add("ring-2", "ring-amber-400/70")
    setTimeout(() => card.classList.remove("ring-2", "ring-amber-400/70"), 1600)
  }

  _escape(s) {
    return String(s || "").replace(/[<>&"']/g, c => ({ "<": "&lt;", ">": "&gt;", "&": "&amp;", '"': "&quot;", "'": "&#39;" }[c]))
  }
}
