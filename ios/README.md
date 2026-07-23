# Plan My Trip — iOS (Hotwire Native shell)

Thin native iOS wrapper around the Rails app, using
[hotwire-native-ios](https://github.com/hotwired/hotwire-native-ios). All
screens are rendered server-side and loaded into a `WKWebView` driven by
`HotwireNative.Navigator`.

This directory contains only the Swift sources. Building the app requires
**macOS + Xcode 15+** — the Linux dev box can't compile it.

## Quick build (headless, no Xcode GUI)

The Xcode project is *generated* from the checked-in Swift sources by
`generate_xcodeproj.rb` (XcodeGen-style — the `.xcodeproj` is a build artifact
and is gitignored). To build and run on a simulator from a terminal:

```bash
gem install xcodeproj                 # one-time, if missing
ruby ios/generate_xcodeproj.rb        # → ios/PlanMyTrip/PlanMyTrip.xcodeproj

cd ios/PlanMyTrip
xcodebuild build \
  -project PlanMyTrip.xcodeproj -scheme PlanMyTrip \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO

# install + launch on the booted simulator
APP=build/Build/Products/Debug-iphonesimulator/PlanMyTrip.app
xcrun simctl install booted "$APP"
xcrun simctl launch  booted com.wanderply.PlanMyTrip
```

Bundle id is `com.wanderply.PlanMyTrip`, deployment target iOS 16. The generator
links the `hotwire-native-ios` Swift Package automatically (no manual
"Add Package Dependencies" step). Point the app at a running Rails server via
`AppConfig.baseURLString` / the `BASE_URL` build setting (see below) — with no
server it renders Hotwire's "Could not connect" screen.

## One-time setup on a Mac (Xcode GUI — alternative to the generator)

1. **Open Xcode** → File → New → Project → **iOS · App**
   - Product name: `PlanMyTrip`
   - Interface: **Storyboard** (or SwiftUI — both work, this scaffold uses UIKit)
   - Language: **Swift**
   - Save it inside this `ios/` folder, on top of the existing `PlanMyTrip/` directory (let Xcode overwrite the boilerplate `AppDelegate.swift` etc. with the files here).

2. **Add the Hotwire Native dependency**:
   - File → Add Package Dependencies…
   - URL: `https://github.com/hotwired/hotwire-native-ios`
   - Up to next major version, target: `PlanMyTrip`

3. **Drop in the source files** if Xcode didn't already pick them up:
   - `AppDelegate.swift`
   - `SceneDelegate.swift`
   - `AppConfig.swift`
   - `Info.plist` (replace the auto-generated one)

4. **Set the dev server URL**:
   - For **iOS Simulator** on the same Mac as the Rails server: leave `AppConfig.baseURLString` as `http://localhost:3010`.
   - For a **physical device**: change it to your Mac's LAN IP, e.g. `http://192.168.1.42:3010`. Both devices must be on the same Wi-Fi.
   - Or set a `BASE_URL` build setting (Build Settings → User-Defined → `+`) so debug/release can differ.

5. **Build & run** (⌘R). The app opens the Rails app's `/` route as the root,
   honoring path rules from `/configurations/ios.json` (sign-in / new trip /
   edit / share / account → modals; everything else → push).

## How URLs are routed

All routing comes from `public/configurations/ios.json` on the Rails side.
Edit that file to change which screens open as modals vs. pushes — the app
re-fetches it on each launch, so no rebuild is needed for navigation tweaks.

## Speech bridge (`SpeechComponent.swift`)

WKWebView implements `speechSynthesis` but **not** `SpeechRecognition`, so on
iOS the podcast / Read aloud / Drive Co-Pilot already speak through the Web
Speech API, but voice **input** (the concierge and day-trip mic) had nothing to
fall back to. `SpeechComponent` supplies it via `SFSpeechRecognizer` +
`AVAudioEngine`, exposed to the web through the `speech` bridge component
(registered in `AppDelegate`, which is what advertises it in the user agent).
The shared web façade `app/javascript/speech.js` prefers the Web Speech API and
only calls the bridge for what the browser lacks — so `speak` is implemented
for parity but isn't normally exercised on iOS.

Requires the two usage strings in `Info.plist`
(`NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`) — the
app is rejected without them. The Android counterpart is
`android/.../SpeechComponent.kt`.

## Going beyond a pure web wrapper

- **Native bridge components** — register them in `AppDelegate` via
  `Hotwire.registerBridgeComponents([...])` (see `SpeechComponent`). Other
  candidates: a native share sheet for "Open in AllTrails", a native
  date-picker for trip dates, haptic feedback on form submit.
- **Push notifications** — wire up APNs in `AppDelegate` and POST the device
  token to a `/devices` endpoint on the Rails app.
- **Offline auth** — Hotwire Native shares cookies with the underlying
  WKWebView, so Devise sign-in just works. Use the iOS Keychain if you want
  biometric re-auth on launch.

## Debugging

- Safari on Mac → Develop → Simulator/Device → `localhost:3010` lets you inspect
  the WKWebView with the same dev tools as a desktop browser.
- Rails logs will show the `User-Agent: Hotwire Native iOS` from this app —
  the `hotwire_native_app?` helper in the Rails app uses this to hide the
  web header (the native nav bar takes over).
