# Wanderply brand assets (for the brand reel)

| File | What it is |
|---|---|
| `BRAND_KIT.html` | One-page visual brand kit — colors, fonts, logo, components, motion + export specs. Open in a browser. |
| `phone-frame-9x16.png` | 1080×1920 transparent-screen phone frame — **vertical cut** (Reels / TikTok / Shorts). |
| `phone-frame-1x1.png` | 1080×1080 — **feed** crop (phone centered). |
| `phone-frame-16x9.png` | 1920×1080 — **YouTube / site hero** (phone centered, room for text beside it). |
| `phone-frame-9x16.svg` | Editable vector source of the frame (tweak colors/bezel, re-export). |

## Using the phone frame in your editor (DaVinci Resolve / CapCut / After Effects)

1. Add the matching `phone-frame-*.png` on a video track **above** your screen recording.
2. Scale/position the recording to **fill the transparent screen window** for that crop:

   | Frame | Canvas | Screen window (x · y · w · h) |
   |---|---|---|
   | `9x16` | 1080×1920 | **150 · 74 · 780 · 1736** |
   | `1x1`  | 1080×1080 | **321 · 42 · 439 · 976** |
   | `16x9` | 1920×1080 | **741 · 42 · 439 · 976** |

   (screen aspect ≈ 9:20 — record the app tall, or pan a wider capture)
3. Optional: put a background behind both — brand dark `#0a0e1a`, or a soft-blurred
   red-rock/landscape photo for depth. Add a subtle amber glow behind the phone.
4. The bezel already carries the amber accent edge + Wanderply pin in the chin, so
   exports stay on-brand with no extra work.

## Re-rasterizing the frame after an SVG edit

```bash
# wrap + shoot with headless Chrome (faithful gradients + mask)
printf '<!doctype html><style>html,body{margin:0;background:transparent}svg{display:block}</style>' > /tmp/frame.html
cat phone-frame-9x16.svg >> /tmp/frame.html
google-chrome --headless=new --disable-gpu --window-size=1080,1920 --hide-scrollbars \
  --default-background-color=00000000 --screenshot="$PWD/phone-frame-9x16.png" /tmp/frame.html
```

Colors/fonts are pulled from the live app (`public/icon.svg`, the layout head, and
`docs/DESIGN_SYSTEM.md`). If the app's tokens change, update `BRAND_KIT.html` to match.
