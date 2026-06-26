import { Controller } from "@hotwired/stimulus"

// Typeahead for the wizard's destination input — suggests places from
// the shared Place catalog as the user types. Suggestions are ordered
// by usage_count, so heavily-trafficked destinations bubble up.
//
// Markup contract (see wizard/destination.html.erb):
//   <div data-controller="place-autocomplete"
//        data-place-autocomplete-search-url-value="/places/search"
//        class="relative">
//     <input data-place-autocomplete-target="input"
//            data-action="input->place-autocomplete#query
//                         focus->place-autocomplete#query
//                         keydown->place-autocomplete#navigate
//                         blur->place-autocomplete#blur">
//     <ul data-place-autocomplete-target="results" hidden></ul>
//     <input type="hidden" data-place-autocomplete-target="placeId">
//     <input type="hidden" data-place-autocomplete-target="lat">
//     <input type="hidden" data-place-autocomplete-target="lng">
//   </div>
export default class extends Controller {
  static targets = [ "input", "results", "placeId", "lat", "lng" ]
  static values = {
    searchUrl: { type: String, default: "/places/search" },
    debounceMs: { type: Number, default: 180 },
    minChars:   { type: Number, default: 2 }
  }

  connect() {
    this._timer = null
    this._activeIndex = -1
    this._items = []
    this._lastQuery = ""
    this._abort = null
    this._discoverAbort = null
    this._cache = new Map() // query -> results, so backspace/retype is instant
  }

  disconnect() {
    if (this._timer) clearTimeout(this._timer)
    if (this._abort) this._abort.abort()
    if (this._discoverAbort) this._discoverAbort.abort()
  }

  // Debounced fetch on every keystroke (and on focus).
  query() {
    if (this._timer) clearTimeout(this._timer)
    const q = this.inputTarget.value.trim()
    if (q.length < this.minCharsValue) {
      this._hide()
      return
    }
    this._timer = setTimeout(() => this._fetch(q), this.debounceMsValue)
  }

  // Phase 1: instant catalog results (no AI). Then, if the catalog is thin,
  // phase 2 runs the slow web-discovery pass in the background and appends.
  async _fetch(q) {
    if (q === this._lastQuery) return
    this._lastQuery = q
    if (this._discoverAbort) this._discoverAbort.abort()

    if (this._cache.has(q)) { this._render(this._cache.get(q)); return }

    if (this._abort) this._abort.abort()
    this._abort = new AbortController()
    try {
      const url = `${this.searchUrlValue}?q=${encodeURIComponent(q)}&limit=8`
      const res = await fetch(url, {
        headers: { Accept: "application/json" },
        credentials: "same-origin",
        signal: this._abort.signal
      })
      if (!res.ok) return
      const data = await res.json()
      const results = data.results || []
      this._cache.set(q, results)
      this._render(results)
      if (data.discoverable) this._fetchDiscover(q, results)
    } catch (err) {
      if (err.name !== "AbortError") console.warn("[place-autocomplete]", err)
    }
  }

  // Phase 2: the ~3-5s web search, fired only when the catalog was thin. Appends
  // its results to the already-visible dropdown, unless the user has moved on.
  async _fetchDiscover(q, base) {
    if (this._discoverAbort) this._discoverAbort.abort()
    this._discoverAbort = new AbortController()
    if (!this.resultsTarget.hidden) {
      const hint = document.createElement("li")
      hint.dataset.discoverHint = "1"
      hint.className = "px-3 py-2 text-[11px] text-slate-400 border-t border-slate-800/80"
      hint.textContent = "Searching the web…"
      this.resultsTarget.appendChild(hint)
    }
    try {
      const url = `${this.searchUrlValue}?q=${encodeURIComponent(q)}&limit=8&discover=1`
      const res = await fetch(url, {
        headers: { Accept: "application/json" },
        credentials: "same-origin",
        signal: this._discoverAbort.signal
      })
      if (!res.ok || this._lastQuery !== q) return
      const data = await res.json()
      const merged = (data.results && data.results.length) ? data.results : base
      this._cache.set(q, merged)
      this._render(merged)
    } catch (err) {
      const hint = this.resultsTarget.querySelector("[data-discover-hint]")
      if (hint) hint.remove()
      if (err.name !== "AbortError") console.warn("[place-autocomplete]", err)
    }
  }

  _render(items) {
    this._items = items
    this._activeIndex = -1
    const ul = this.resultsTarget
    ul.innerHTML = ""
    if (!items.length) { this._hide(); return }

    items.forEach((p, i) => {
      const li = document.createElement("li")
      li.dataset.idx = i
      li.className = [
        "flex items-center gap-3 px-3 py-2.5 cursor-pointer transition-colors",
        "hover:bg-slate-800/80 data-[active=true]:bg-slate-800"
      ].join(" ")
      li.addEventListener("mousedown", (e) => {
        // mousedown (not click) so it fires before the input's blur
        e.preventDefault()
        this._pick(i)
      })

      // Thumbnail
      const thumb = document.createElement("div")
      thumb.className = "w-10 h-10 rounded-lg shrink-0 bg-slate-700 overflow-hidden"
      if (p.image_url) {
        const img = document.createElement("img")
        img.src = p.image_url
        img.alt = ""
        img.referrerPolicy = "no-referrer"
        img.className = "w-full h-full object-cover"
        thumb.appendChild(img)
      }
      li.appendChild(thumb)

      // Body
      const body = document.createElement("div")
      body.className = "min-w-0 flex-1"
      const top = document.createElement("div")
      top.className = "flex items-baseline gap-2 flex-wrap"
      const nameEl = document.createElement("span")
      nameEl.className = "text-sm font-semibold text-slate-100 truncate"
      nameEl.textContent = p.name
      top.appendChild(nameEl)
      if (p.kind) {
        const kind = document.createElement("span")
        kind.className = "text-[10px] uppercase tracking-widest text-amber-200/80 font-semibold"
        kind.textContent = p.kind.replace(/_/g, " ")
        top.appendChild(kind)
      }
      body.appendChild(top)
      if (p.summary) {
        const sum = document.createElement("p")
        sum.className = "text-xs text-slate-400 mt-0.5 truncate"
        sum.textContent = p.summary
        body.appendChild(sum)
      }
      li.appendChild(body)

      // Usage badge
      if (p.usage_count > 0) {
        const badge = document.createElement("span")
        badge.className = "shrink-0 text-[10px] tabular-nums text-slate-400 font-medium"
        badge.textContent = `${p.usage_count}× used`
        li.appendChild(badge)
      }

      ul.appendChild(li)
    })
    ul.hidden = false
  }

  _hide() {
    this.resultsTarget.hidden = true
    this.resultsTarget.innerHTML = ""
    this._items = []
    this._activeIndex = -1
  }

  navigate(event) {
    const k = event.key
    if (this.resultsTarget.hidden || !this._items.length) return
    if (k === "ArrowDown") {
      event.preventDefault()
      this._activeIndex = (this._activeIndex + 1) % this._items.length
      this._highlight()
    } else if (k === "ArrowUp") {
      event.preventDefault()
      this._activeIndex = this._activeIndex <= 0 ? this._items.length - 1 : this._activeIndex - 1
      this._highlight()
    } else if (k === "Enter" && this._activeIndex >= 0) {
      event.preventDefault()
      this._pick(this._activeIndex)
    } else if (k === "Escape") {
      this._hide()
    }
  }

  _highlight() {
    Array.from(this.resultsTarget.children).forEach((el, i) => {
      el.dataset.active = (i === this._activeIndex) ? "true" : "false"
    })
  }

  _pick(i) {
    const p = this._items[i]
    if (!p) return
    this.inputTarget.value = p.canonical_name || p.name
    if (this.hasPlaceIdTarget) this.placeIdTarget.value = p.id || ""
    if (this.hasLatTarget) this.latTarget.value = p.lat ?? ""
    if (this.hasLngTarget) this.lngTarget.value = p.lng ?? ""
    this._hide()
    // Let the input lose focus to commit the selection.
    this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }))
  }

  blur() {
    // Small delay so the mousedown handler on the list runs first.
    setTimeout(() => this._hide(), 120)
  }
}
