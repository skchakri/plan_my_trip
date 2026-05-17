// Shared TTS settings. Single speed multiplier persisted across the
// reading-mode podcast and the per-section "Read aloud" buttons.

const KEY = "pmt.tts.speed"
export const SPEEDS = [0.75, 1.0, 1.25, 1.5, 2.0]

export function getSpeed() {
  try {
    const v = parseFloat(localStorage.getItem(KEY))
    if (SPEEDS.includes(v)) return v
  } catch (e) { /* ignore */ }
  return 1.0
}

export function setSpeed(v) {
  try { localStorage.setItem(KEY, String(v)) } catch (e) { /* ignore */ }
  window.dispatchEvent(new CustomEvent("pmt:tts-speed", { detail: { speed: v } }))
}

export function nextSpeed(current = getSpeed()) {
  const i = SPEEDS.indexOf(current)
  return SPEEDS[(i + 1) % SPEEDS.length]
}

export function formatSpeed(v = getSpeed()) {
  return v === 1.0 ? "1×" : `${v}×`
}
