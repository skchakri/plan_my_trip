import { Controller } from "@hotwired/stimulus"

// Trip Concierge chat panel. The server owns the message log (turbo-stream
// appends both the question and the answer), so this controller only handles
// the transient UX: a "thinking…" indicator while the request is in flight,
// clearing the input, and keeping the log scrolled to the latest message.
export default class extends Controller {
  static targets = ["input", "pending", "log", "submit"]

  // turbo:submit-start
  pending(event) {
    if (this.hasInputTarget && !this.inputTarget.value.trim()) {
      event.preventDefault()
      return
    }
    if (this.hasPendingTarget) this.pendingTarget.hidden = false
    if (this.hasSubmitTarget) this.submitTarget.disabled = true
    this.scroll()
  }

  // turbo:submit-end
  done() {
    if (this.hasPendingTarget) this.pendingTarget.hidden = true
    if (this.hasSubmitTarget) this.submitTarget.disabled = false
    if (this.hasInputTarget) {
      this.inputTarget.value = ""
      this.inputTarget.focus()
    }
    // Let the appended turbo-stream paint before scrolling to it.
    requestAnimationFrame(() => this.scroll())
  }

  // Click an example chip → drop it in the box and send.
  suggest(event) {
    const q = event.currentTarget.dataset.question
    if (!q || !this.hasInputTarget) return
    this.inputTarget.value = q
    this.element.querySelector("form")?.requestSubmit()
  }

  // Enter to send, Shift+Enter for a newline.
  keydown(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault()
      event.target.closest("form")?.requestSubmit()
    }
  }

  scroll() {
    if (this.hasLogTarget) this.logTarget.scrollTop = this.logTarget.scrollHeight
  }
}
