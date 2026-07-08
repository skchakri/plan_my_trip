import { Controller } from "@hotwired/stimulus"

// Scroll choreography for the marketing landing page.
//
//   reveal targets — fade/rise in once as they enter the viewport
//                    (stagger per-element via the --lp-d CSS var)
//   route target   — the amber "traveled so far" line of the itinerary
//                    spine; its stroke draws in as the chapters section
//                    scrolls through the viewport
//
// Everything collapses to a static, fully-drawn page under
// prefers-reduced-motion.
export default class extends Controller {
  static targets = ["reveal", "route", "chapters"]

  connect() {
    this.reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    this.setupReveals()
    this.setupRoute()
  }

  disconnect() {
    this.observer?.disconnect()
    if (this.onScroll) {
      window.removeEventListener("scroll", this.onScroll)
      window.removeEventListener("resize", this.onScroll)
    }
    if (this.raf) cancelAnimationFrame(this.raf)
  }

  setupReveals() {
    if (this.reduced || !("IntersectionObserver" in window)) {
      this.revealTargets.forEach((el) => el.classList.add("lp-in"))
      return
    }
    this.observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add("lp-in")
            this.observer.unobserve(entry.target)
          }
        })
      },
      { threshold: 0.15, rootMargin: "0px 0px -48px 0px" }
    )
    this.revealTargets.forEach((el) => this.observer.observe(el))
  }

  setupRoute() {
    if (!this.hasRouteTarget || !this.hasChaptersTarget) return

    const path = this.routeTarget
    this.routeLength = path.getTotalLength()
    path.style.strokeDasharray = `${this.routeLength}`

    if (this.reduced) {
      path.style.strokeDashoffset = "0"
      return
    }
    path.style.strokeDashoffset = `${this.routeLength}`

    this.onScroll = () => {
      if (this.raf) return
      this.raf = requestAnimationFrame(() => {
        this.raf = null
        this.drawRoute()
      })
    }
    window.addEventListener("scroll", this.onScroll, { passive: true })
    window.addEventListener("resize", this.onScroll, { passive: true })
    this.drawRoute()
  }

  drawRoute() {
    const rect = this.chaptersTarget.getBoundingClientRect()
    const viewport = window.innerHeight
    // 0 when the section's top reaches ~80% down the screen,
    // 1 shortly before its bottom leaves the viewport.
    const traveled = viewport * 0.8 - rect.top
    const span = rect.height + viewport * 0.3
    const progress = Math.min(1, Math.max(0, traveled / span))
    this.routeTarget.style.strokeDashoffset = `${this.routeLength * (1 - progress)}`
  }
}
