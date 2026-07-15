import { Controller } from "@hotwired/stimulus"

// Travel Trivia player. Questions (with their answer keys) are embedded by the
// server and graded client-side for a snappy, no-round-trip feel — acceptable
// for casual trivia. The final score is POSTed once to record a QuizAttempt.
const LETTERS = ["A", "B", "C", "D", "E", "F"]
const CIRC = 339.292 // 2π·54, matches the results ring in the view

// Full, standalone option classNames (literal so Tailwind v4 compiles them).
const OPT = "quiz-opt-in w-full flex items-center gap-3.5 px-4 py-3.5 rounded-xl border text-left text-[15px] font-medium transition-all duration-200 disabled:cursor-default"
const IDLE = `${OPT} border-slate-700/70 bg-slate-800/40 text-slate-100 cursor-pointer hover:border-amber-400/70 hover:bg-slate-800`
const CORRECT = `${OPT} border-emerald-400 bg-emerald-500/15 text-emerald-50 ring-1 ring-emerald-400/40`
const WRONG = `${OPT} border-rose-400 bg-rose-500/15 text-rose-50`
const DIM = `${OPT} border-slate-800 bg-slate-800/20 text-slate-400`

// Image-option variant: a logo on a light card you tap (the "pick the logo" twist).
const IMG = "quiz-opt-in relative block rounded-xl border-2 p-2 transition-all duration-200 disabled:cursor-default"
const IMG_IDLE = `${IMG} border-slate-700/70 bg-slate-800/40 cursor-pointer hover:border-amber-400/70`
const IMG_CORRECT = `${IMG} border-emerald-400 bg-emerald-500/10 ring-1 ring-emerald-400/40`
const IMG_WRONG = `${IMG} border-rose-400 bg-rose-500/10`
const IMG_DIM = `${IMG} border-slate-800 bg-slate-800/20 opacity-50`

const CHECK = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" class="w-5 h-5"><polyline points="20 6 9 17 4 12"/></svg>`
const CROSS = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" class="w-5 h-5"><path d="M18 6 6 18"/><path d="m6 6 12 12"/></svg>`

export default class extends Controller {
  static values = { questions: Array, recordUrl: String, best: Number }
  static targets = [
    "question", "results", "prompt", "media", "options", "progressBar",
    "counter", "score", "streak", "nextWrap", "nextLabel",
    "finalScore", "finalHeadline", "finalMessage", "recap", "ring", "bestBadge",
    "guestCta"
  ]

  connect() {
    this.index = 0
    this.correct = 0
    this.streak = 0
    this.locked = false
    this.log = []
    this.flushQueuedAttempts()
    if (this.questionsValue.length) this.renderQuestion()
  }

  get question() { return this.questionsValue[this.index] }
  get total() { return this.questionsValue.length }

  renderQuestion() {
    const q = this.question
    this.locked = false
    this.nextWrapTarget.hidden = true

    this.promptTarget.textContent = q.prompt
    this.renderMedia(q)

    // Two layouts: text options (default) or a 2×2 grid of logo images (the
    // "four logos, pick the brand" twist).
    this.imageMode = Array.isArray(q.option_images)
    const choices = this.imageMode ? q.option_images : q.options
    this.optionsTarget.className = this.imageMode ? "grid grid-cols-2 gap-2.5" : "grid gap-2.5"
    this.optionsTarget.innerHTML = ""

    choices.forEach((choice, i) => {
      const btn = document.createElement("button")
      btn.type = "button"
      btn.style.animationDelay = `${i * 55}ms`
      if (this.imageMode) {
        btn.className = IMG_IDLE
        btn.setAttribute("aria-label", q.option_labels?.[i] || `Option ${i + 1}`)
        btn.innerHTML = `
          <span class="flex items-center justify-center bg-white rounded-lg w-full h-24 sm:h-28 p-3">
            <img src="${choice}" alt="" class="max-h-14 sm:max-h-16 max-w-[75%] w-auto">
          </span>
          <span data-mark class="absolute top-2 right-2"></span>`
      } else {
        btn.className = IDLE
        btn.innerHTML = `
          <span class="flex items-center justify-center w-7 h-7 shrink-0 rounded-lg bg-slate-700/60 text-slate-300 text-xs font-bold">${LETTERS[i]}</span>
          <span class="flex-1">${escapeHtml(choice)}</span>
          <span data-mark class="shrink-0"></span>`
      }
      btn.addEventListener("click", () => this.choose(i, btn))
      this.optionsTarget.appendChild(btn)
    })

    this.counterTarget.textContent = `Question ${this.index + 1} of ${this.total}`
    this.scoreTarget.textContent = this.correct
    this.streakTarget.textContent = this.streak
    this.progressBarTarget.style.width = `${(this.index / this.total) * 100}%`
  }

  renderMedia(q) {
    const m = this.mediaTarget
    if (q.logo && q.image_url) {
      // Logos can be any colour — render on a light card so they're always legible.
      m.hidden = false
      m.innerHTML = `<div class="flex justify-center"><div class="flex items-center justify-center bg-white rounded-xl w-44 h-28 sm:w-52 sm:h-32 shadow-lg shadow-black/30"><img src="${q.image_url}" alt="Logo to identify" class="max-h-16 sm:max-h-20 max-w-[70%] w-auto"></div></div>`
    } else if (q.image_url) {
      m.hidden = false
      m.innerHTML = `<div class="flex justify-center"><img src="${q.image_url}" alt="Flag to identify" loading="eager"
        class="h-32 sm:h-40 w-auto rounded-lg ring-1 ring-slate-700/70 shadow-lg shadow-black/40"></div>`
    } else if (q.flag_thumb) {
      m.hidden = false
      m.innerHTML = `<img src="${q.flag_thumb}" alt="" class="h-6 w-auto rounded-sm ring-1 ring-slate-700/70">`
    } else {
      m.hidden = true
      m.innerHTML = ""
    }
  }

  choose(picked, btn) {
    if (this.locked) return
    this.locked = true

    const q = this.question
    const right = picked === q.answer_index
    const labels = q.option_labels || q.options
    this.log.push({ prompt: q.prompt, answer: labels[q.answer_index], right })

    const [okClass, badClass, dimClass] = this.imageMode
      ? [IMG_CORRECT, IMG_WRONG, IMG_DIM]
      : [CORRECT, WRONG, DIM]
    const badge = (svg, tone) => this.imageMode
      ? `<span class="flex items-center justify-center w-6 h-6 rounded-full ${tone} text-white shadow">${svg}</span>`
      : svg

    const buttons = Array.from(this.optionsTarget.children)
    buttons.forEach((b, i) => {
      b.disabled = true
      const mark = b.querySelector("[data-mark]")
      if (i === q.answer_index) {
        b.className = okClass
        if (mark) mark.innerHTML = badge(CHECK, "bg-emerald-500")
      } else if (i === picked) {
        b.className = badClass
        if (mark) mark.innerHTML = badge(CROSS, "bg-rose-500")
      } else {
        b.className = dimClass
      }
    })

    if (right) {
      this.correct++
      this.streak++
    } else {
      this.streak = 0
    }
    this.scoreTarget.textContent = this.correct
    this.streakTarget.textContent = this.streak

    this.nextLabelTarget.textContent = this.index + 1 >= this.total ? "See results" : "Next question"
    this.nextWrapTarget.hidden = false
  }

  next() {
    if (this.index + 1 >= this.total) return this.finish()
    this.index++
    this.renderQuestion()
  }

  finish() {
    const pct = Math.round((this.correct / this.total) * 100)
    this.progressBarTarget.style.width = "100%"
    this.questionTarget.hidden = true
    this.resultsTarget.hidden = false

    // Colour the ring + headline by tier.
    const tier = pct >= 90 ? "rgb(52 211 153)" : pct >= 60 ? "rgb(251 191 36)" : "rgb(244 63 94)"
    this.ringTarget.style.stroke = tier
    requestAnimationFrame(() => { this.ringTarget.style.strokeDashoffset = CIRC * (1 - pct / 100) })

    this.finalHeadlineTarget.textContent = headline(pct)
    this.finalMessageTarget.textContent = `You scored ${this.correct} of ${this.total}.`
    this.animateScore(pct)
    this.renderRecap()
    if (pct >= 80) this.celebrate()

    this.record()
    this.resultsTarget.scrollIntoView({ behavior: "smooth", block: "center" })
  }

  renderRecap() {
    this.recapTarget.innerHTML = this.log.map((r) => `
      <div class="flex items-start gap-2 text-sm">
        <span class="mt-0.5 shrink-0 ${r.right ? "text-emerald-400" : "text-rose-400"}">${r.right ? CHECK : CROSS}</span>
        <span class="text-slate-300">${escapeHtml(r.prompt)}
          ${r.right ? "" : `<span class="text-slate-400">→ ${escapeHtml(r.answer)}</span>`}</span>
      </div>`).join("")
  }

  animateScore(target) {
    const el = this.finalScoreTarget
    const start = performance.now()
    const tick = (now) => {
      const p = Math.min((now - start) / 900, 1)
      el.textContent = Math.round(target * (0.5 - Math.cos(Math.PI * p) / 2))
      if (p < 1) requestAnimationFrame(tick)
    }
    requestAnimationFrame(tick)
  }

  celebrate() {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return
    const colors = ["#f0b870", "#fbbf24", "#34d399", "#38bdf8", "#fb7185", "#a78bfa"]
    for (let i = 0; i < 44; i++) {
      const bit = document.createElement("div")
      bit.className = "confetti-bit"
      bit.style.left = `${Math.random() * 100}vw`
      bit.style.background = colors[i % colors.length]
      bit.style.animationDuration = `${2 + Math.random() * 1.5}s`
      bit.style.animationDelay = `${Math.random() * 0.3}s`
      bit.style.transform = `rotate(${Math.random() * 360}deg)`
      document.body.appendChild(bit)
      setTimeout(() => bit.remove(), 4200)
    }
  }

  static QUEUE_KEY = "pmt:pendingQuizAttempts"

  record() {
    this.saveAttempt({ url: this.recordUrlValue, score: this.correct, total: this.total }, 2, true)
  }

  // POST a score with bounded retries. On terminal failure the attempt is
  // queued in localStorage and flushed on the next quiz load, and the player
  // is told (toast) instead of losing the score silently.
  saveAttempt(attempt, retries, surfaceBest) {
    const token = document.querySelector('meta[name="csrf-token"]')?.content
    fetch(attempt.url, {
      method: "POST",
      headers: { "Content-Type": "application/json", "Accept": "application/json", "X-CSRF-Token": token },
      body: JSON.stringify({ score: attempt.score, total: attempt.total })
    })
      .then((r) => {
        if (!r.ok) throw new Error(`HTTP ${r.status}`)
        return r.json()
      })
      .then((data) => {
        // Guests can play, but scores need an account. That's not a failure —
        // don't queue it (there's no one to save it to) and don't toast an
        // error; offer the sign-up instead, right at peak engagement.
        if (data && data.guest) return surfaceBest && this.showGuestCta()
        if (surfaceBest) this.showBest(data)
      })
      .catch(() => {
        if (retries > 0) {
          setTimeout(() => this.saveAttempt(attempt, retries - 1, surfaceBest), 1500)
        } else {
          this.queueAttempt(attempt)
          window.dispatchEvent(new CustomEvent("toast", {
            detail: { type: "alert", message: "Couldn't save your score — we'll save it next time you're online." }
          }))
        }
      })
  }

  showGuestCta() {
    if (this.hasGuestCtaTarget) this.guestCtaTarget.hidden = false
  }

  showBest(data) {
    if (!data || !this.hasBestBadgeTarget) return
    this.bestBadgeTarget.classList.remove("hidden")
    this.bestBadgeTarget.innerHTML =
      `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" class="w-3.5 h-3.5"><path d="m15.477 12.89 1.515 8.526a.5.5 0 0 1-.81.47l-3.58-2.687a1 1 0 0 0-1.197 0l-3.586 2.686a.5.5 0 0 1-.81-.469l1.514-8.526"/><circle cx="12" cy="8" r="6"/></svg> Best ${data.best}%`
  }

  queueAttempt(attempt) {
    try {
      const q = JSON.parse(localStorage.getItem(this.constructor.QUEUE_KEY) || "[]")
      q.push(attempt)
      localStorage.setItem(this.constructor.QUEUE_KEY, JSON.stringify(q.slice(-50)))
    } catch (_) { /* storage unavailable — nothing more we can do */ }
  }

  flushQueuedAttempts() {
    let q
    try { q = JSON.parse(localStorage.getItem(this.constructor.QUEUE_KEY) || "[]") } catch (_) { return }
    if (!Array.isArray(q) || !q.length) return
    localStorage.removeItem(this.constructor.QUEUE_KEY)
    q.forEach((attempt) => { if (attempt && attempt.url) this.saveAttempt(attempt, 1, false) })
  }

  playAgain() {
    window.location.reload()
  }
}

function escapeHtml(str) {
  const div = document.createElement("div")
  div.textContent = str
  return div.innerHTML
}

function headline(pct) {
  if (pct === 100) return "Flawless! 🏆"
  if (pct >= 90) return "Globetrotter status"
  if (pct >= 70) return "Strong run"
  if (pct >= 50) return "Not bad — keep going"
  return "Room to explore"
}
