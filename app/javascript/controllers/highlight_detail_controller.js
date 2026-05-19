import { Controller } from "@hotwired/stimulus"

// Controls the "exciting" detail modal for a highlight card on the wizard
// highlights step. Cards carry their primary attributes as data-* so the
// modal opens instantly with everything we already know; richer content
// (tagline, why-you'll-love-it, pro tips) is fetched async and slotted in.
//
// Selection state for the wizard form lives in `selectedContainerTarget` —
// one <input type="hidden" name="wizard[selected_slugs][]" value="{slug}">
// per chosen card. Card visuals are driven by `data-selected="true|false"`,
// not native checkboxes, so we can drive them from the modal CTA too.
export default class extends Controller {
  static targets = [
    "modal", "modalImage", "modalCategory", "modalName", "modalTagline",
    "modalOverview", "modalLove", "modalBestTime", "modalTips", "modalPerfectFor",
    "modalWikipedia", "modalMaps", "modalToggle", "modalToggleLabel",
    "modalSkeleton", "modalBody",
    "selectedContainer", "card", "selectedCount",
    "ratingStar", "ratingLabel", "ratingBody", "ratingStatus",
    "modalRatingCaption", "modalAllReviews"
  ]

  static RATING_LABELS = ["", "Bad", "Meh", "OK", "Great", "Loved it"]
  static values = {
    detailUrlTemplate: String,  // e.g. "/trip_wizard/highlights/SLUG/details"
    initialSlugs: Array,        // slugs preselected on render
  }

  connect() {
    this._closeHandler = (e) => { if (e.key === "Escape") this.close() }
    document.addEventListener("keydown", this._closeHandler)
    this._refreshCount()
  }

  disconnect() {
    document.removeEventListener("keydown", this._closeHandler)
  }

  open(event) {
    const card = event.currentTarget
    const data = card.dataset
    this._currentSlug = data.slug
    this._currentCard = data
    this._myRating = 0
    this._resetRatingUi()
    this._renderRatingCaption(parseFloat(data.rating || "0"), parseInt(data.ratingCount || "0", 10))
    this._renderAllReviewsLink(data.placeId)

    // Reset modal content to "loading" state
    this.modalImageTarget.style.backgroundImage = data.image ? `url(${this._cssEscape(data.image)})` : ""
    this.modalImageTarget.classList.toggle("bg-gradient-to-br", !data.image)
    this.modalCategoryTarget.textContent = data.category || ""
    this.modalCategoryTarget.hidden = !data.category
    this.modalNameTarget.textContent = data.name || ""
    this.modalTaglineTarget.textContent = ""
    this.modalTaglineTarget.hidden = true
    this.modalOverviewTarget.textContent = data.summary || ""

    // Build Wikipedia + Maps links
    if (data.wikipediaUrl) {
      this.modalWikipediaTarget.href = data.wikipediaUrl
      this.modalWikipediaTarget.hidden = false
    } else {
      this.modalWikipediaTarget.hidden = true
    }
    const mapsQuery = encodeURIComponent(`${data.name} ${data.destination || ""}`.trim())
    this.modalMapsTarget.href = `https://www.google.com/maps/search/?api=1&query=${mapsQuery}`

    // Clear the async-filled sections
    this._clearList(this.modalLoveTarget)
    this._clearList(this.modalTipsTarget)
    this._clearList(this.modalPerfectForTarget)
    this.modalBestTimeTarget.textContent = ""
    this.modalBestTimeTarget.hidden = true
    this.modalSkeletonTarget.hidden = false
    this.modalBodyTarget.hidden = true

    // Sync the CTA to selection state
    this._refreshModalToggle()

    // Show
    this.modalTarget.hidden = false
    requestAnimationFrame(() => {
      this.modalTarget.classList.add("is-open")
    })
    document.body.style.overflow = "hidden"

    // Fire async detail fetch
    this._fetchDetail(data.slug)
  }

  close() {
    if (!this.hasModalTarget || this.modalTarget.hidden) return
    this.modalTarget.classList.remove("is-open")
    document.body.style.overflow = ""
    setTimeout(() => { this.modalTarget.hidden = true }, 180)
    this._currentSlug = null
  }

  closeOnBackdrop(event) {
    if (event.target === this.modalTarget) this.close()
  }

  toggleSelection() {
    if (!this._currentSlug) return
    this._toggleSlug(this._currentSlug)
  }

  // Selects/deselects directly from a card's check icon. Stops propagation
  // so the surrounding card's click→open handler doesn't also fire.
  toggleFromCard(event) {
    event.stopPropagation()
    event.preventDefault()
    const card = event.currentTarget.closest("[data-slug]")
    if (!card) return
    this._toggleSlug(card.dataset.slug)
  }

  _toggleSlug(slug) {
    if (this._isSelected(slug)) {
      this._removeSelected(slug)
    } else {
      this._addSelected(slug)
    }
    this._refreshCard(slug)
    if (slug === this._currentSlug) this._refreshModalToggle()
    this._refreshCount()
  }

  // --- private ---

  async _fetchDetail(slug) {
    try {
      const url = this.detailUrlTemplateValue.replace("SLUG", encodeURIComponent(slug))
      const res = await fetch(url, { headers: { Accept: "application/json" } })
      if (!res.ok) throw new Error(`HTTP ${res.status}`)
      const data = await res.json()
      // Bail if user already opened a different card while we waited
      if (this._currentSlug !== slug) return

      if (data.tagline) {
        this.modalTaglineTarget.textContent = data.tagline
        this.modalTaglineTarget.hidden = false
      }
      if (data.overview) {
        this.modalOverviewTarget.textContent = data.overview
      }
      this._fillList(this.modalLoveTarget, data.why_youll_love_it)
      this._fillList(this.modalTipsTarget, data.pro_tips)
      this._fillList(this.modalPerfectForTarget, data.perfect_for, { pill: true })
      if (data.best_time) {
        this.modalBestTimeTarget.textContent = data.best_time
        this.modalBestTimeTarget.hidden = false
      }
    } catch (e) {
      console.warn("[highlight-detail] fetch failed", e)
    } finally {
      if (this._currentSlug === slug) {
        this.modalSkeletonTarget.hidden = true
        this.modalBodyTarget.hidden = false
      }
    }
  }

  _isSelected(slug) {
    return !!this.selectedContainerTarget.querySelector(`input[value="${CSS.escape(slug)}"]`)
  }

  _addSelected(slug) {
    if (this._isSelected(slug)) return
    const input = document.createElement("input")
    input.type = "hidden"
    input.name = "wizard[selected_slugs][]"
    input.value = slug
    this.selectedContainerTarget.appendChild(input)
  }

  _removeSelected(slug) {
    const el = this.selectedContainerTarget.querySelector(`input[value="${CSS.escape(slug)}"]`)
    if (el) el.remove()
  }

  _refreshCard(slug) {
    const card = this.cardTargets.find(c => c.dataset.slug === slug)
    if (!card) return
    card.dataset.selected = this._isSelected(slug) ? "true" : "false"
  }

  _refreshModalToggle() {
    if (!this._currentSlug) return
    const sel = this._isSelected(this._currentSlug)
    this.modalToggleTarget.dataset.selected = sel ? "true" : "false"
    this.modalToggleLabelTarget.textContent = sel ? "Remove from my plan" : "Add to my plan"
  }

  _refreshCount() {
    if (!this.hasSelectedCountTarget) return
    const n = this.selectedContainerTarget.querySelectorAll("input").length
    this.selectedCountTarget.textContent = n
    this.selectedCountTarget.dataset.empty = n === 0 ? "true" : "false"
  }

  _clearList(el) {
    while (el.firstChild) el.removeChild(el.firstChild)
  }

  _fillList(el, items, { pill = false } = {}) {
    this._clearList(el)
    if (!items || !items.length) {
      el.hidden = true
      return
    }
    el.hidden = false
    items.forEach(text => {
      const node = document.createElement(pill ? "span" : "li")
      if (pill) {
        node.className = "inline-flex items-center px-2.5 py-1 rounded-full text-xs bg-amber-500/15 border border-amber-500/40 text-amber-200"
      } else {
        node.className = "leading-relaxed"
      }
      node.textContent = text
      el.appendChild(node)
    })
  }

  _cssEscape(str) {
    return String(str).replace(/'/g, "\\'").replace(/"/g, '\\"')
  }

  // --- Rate this place ---

  previewRating(event) {
    const n = parseInt(event.currentTarget.dataset.value, 10)
    this._paintStars(n)
    if (this.hasRatingLabelTarget) this.ratingLabelTarget.textContent = this.constructor.RATING_LABELS[n]
  }

  resetRatingPreview() {
    this._paintStars(this._myRating)
    if (this.hasRatingLabelTarget) this.ratingLabelTarget.textContent = this._myRating ? this.constructor.RATING_LABELS[this._myRating] : ""
  }

  async submitRating(event) {
    const rating = parseInt(event.currentTarget.dataset.value, 10)
    if (!this._currentCard) return
    this._myRating = rating
    this._paintStars(rating)
    this.ratingStatusTarget.textContent = "Saving…"

    const payload = new FormData()
    payload.append("rating", rating)
    payload.append("name", this._currentCard.name || "")
    if (this._currentCard.lat) payload.append("latitude", this._currentCard.lat)
    if (this._currentCard.lng) payload.append("longitude", this._currentCard.lng)
    payload.append("summary", this._currentCard.summary || "")
    if (this._currentCard.image) payload.append("image_url", this._currentCard.image)
    if (this._currentCard.wikipediaUrl) payload.append("wikipedia_url", this._currentCard.wikipediaUrl)
    if (this.hasRatingBodyTarget && this.ratingBodyTarget.value.trim()) {
      payload.append("body", this.ratingBodyTarget.value.trim())
    }

    try {
      const csrf = document.querySelector('meta[name="csrf-token"]')?.content
      const res = await fetch("/places/rate", {
        method: "POST",
        headers: { Accept: "application/json", "X-CSRF-Token": csrf || "" },
        body: payload,
        credentials: "same-origin"
      })
      if (!res.ok) throw new Error(`HTTP ${res.status}`)
      const data = await res.json()
      this.ratingStatusTarget.textContent = "Thanks — saved."
      this._renderRatingCaption(data.rating || rating, data.rating_count || 1)
      // Cache the new aggregate on the card so reopening shows it.
      const card = this.cardTargets.find(c => c.dataset.slug === this._currentSlug)
      if (card) {
        card.dataset.rating = data.rating || rating
        card.dataset.ratingCount = data.rating_count || 1
        if (data.place_id) card.dataset.placeId = data.place_id
      }
      if (data.path) {
        this.modalAllReviewsTarget.href = data.path
        this.modalAllReviewsTarget.hidden = false
      }
    } catch (e) {
      console.warn("[highlight-detail] rate failed", e)
      this.ratingStatusTarget.textContent = "Couldn't save — try again."
    }
  }

  _resetRatingUi() {
    if (!this.hasRatingStarTarget) return
    this._paintStars(0)
    if (this.hasRatingLabelTarget)  this.ratingLabelTarget.textContent  = ""
    if (this.hasRatingBodyTarget)   this.ratingBodyTarget.value         = ""
    if (this.hasRatingStatusTarget) this.ratingStatusTarget.textContent = ""
  }

  _paintStars(n) {
    if (!this.hasRatingStarTarget) return
    this.ratingStarTargets.forEach((s, i) => {
      s.classList.toggle("text-amber-300", i < n)
      s.classList.toggle("text-slate-700", i >= n)
    })
  }

  _renderRatingCaption(rating, count) {
    if (!this.hasModalRatingCaptionTarget) return
    if (!count || count < 1) {
      this.modalRatingCaptionTarget.textContent = "No ratings yet — be first."
    } else {
      this.modalRatingCaptionTarget.textContent = `★ ${rating.toFixed(1)} · ${count} review${count === 1 ? "" : "s"}`
    }
  }

  _renderAllReviewsLink(placeId) {
    if (!this.hasModalAllReviewsTarget) return
    if (placeId) {
      this.modalAllReviewsTarget.href = `/places/${placeId}#reviews`
      this.modalAllReviewsTarget.hidden = false
    } else {
      this.modalAllReviewsTarget.hidden = true
    }
  }
}
