import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

// Maintains the realtime "viewing now" list for a shared trip. Pings the
// server every 25s so the 60s TTL on the server keeps us in the live set,
// and rerenders the avatar pills whenever the server broadcasts an update.
export default class extends Controller {
  static values  = { tripId: String }
  static targets = ["list", "empty"]

  connect() {
    this.consumer = createConsumer()
    this.subscription = this.consumer.subscriptions.create(
      { channel: "TripPresenceChannel", trip_id: this.tripIdValue },
      { received: (data) => this.render(data.viewers || []) }
    )
    this.pingHandle = setInterval(() => this.subscription?.perform("ping"), 25000)
  }

  disconnect() {
    clearInterval(this.pingHandle)
    this.subscription?.unsubscribe()
    this.consumer?.disconnect()
  }

  render(viewers) {
    if (!this.hasListTarget) return
    if (viewers.length === 0) {
      this.listTarget.innerHTML = ""
      if (this.hasEmptyTarget) this.emptyTarget.classList.remove("hidden")
      return
    }
    if (this.hasEmptyTarget) this.emptyTarget.classList.add("hidden")
    this.listTarget.innerHTML = viewers.map(v => `
      <span class="inline-flex items-center gap-1.5 pl-1 pr-2 py-0.5 rounded-full bg-emerald-500/15 border border-emerald-500/30 text-emerald-200 text-xs"
            title="${this.escape(v.name)} is here">
        <span class="inline-flex items-center justify-center w-5 h-5 rounded-full bg-emerald-500/30 text-[10px] font-bold">${this.escape(v.initials || "?")}</span>
        <span class="max-w-[10ch] truncate">${this.escape(v.name)}</span>
      </span>
    `).join("")
  }

  escape(s) { return String(s).replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c])) }
}
