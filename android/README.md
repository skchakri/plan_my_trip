# Plan My Trip — Android (Hotwire Native shell)

Thin native Android wrapper around the Rails app, using
[hotwire-native-android](https://github.com/hotwired/hotwire-native-android).
All screens are rendered by the Rails server and loaded into a `WebView`
driven by the Hotwire `Navigator`.

This directory contains the Gradle config, manifest, and Kotlin sources.
Building requires **Android Studio (Hedgehog or newer) + JDK 17 + Android SDK
34**. Gradle wrapper jar isn't checked in — Android Studio adds it on first
sync.

## One-time setup

1. **Open Android Studio** → File → Open → select the `android/` folder.
2. Let Gradle sync. It will:
   - Download `dev.hotwire:core` + `dev.hotwire:navigation-fragments`
   - Generate `gradlew` / `gradlew.bat` / `gradle-wrapper.jar`
3. Set the dev server URL in `app/src/main/java/com/skchakri/planmytrip/AppConfig.kt`:
   - **Emulator on the same Linux host** as Rails: leave as `http://10.0.2.2:3010`
     (Android emulator's special alias for the host's localhost).
   - **Physical device on Wi-Fi**: change to your machine's LAN IP, e.g. `http://192.168.1.42:3010`.
4. Plug in a device or start an emulator → Run (Shift+F10).

## How URLs are routed

`Hotwire.loadPathConfiguration` in `MainApplication.onCreate()` fetches
`/configurations/android.json` from the Rails server on every launch, so
navigation tweaks (modal vs push, titles, pull-to-refresh) are made on the
Rails side without rebuilding the APK.

## Going beyond the pure web wrapper

- **Bridge components** — register Kotlin bridge components in `MainApplication`
  to add native UI on top of web pages (date picker, share sheet, haptics).
- **FCM push** — wire Firebase in `MainApplication` and POST tokens to a
  `/devices` endpoint on the Rails app.
- **Cookie-based auth** — Hotwire Native shares cookies with the underlying
  WebView, so Devise sign-in just works once.

## Debugging

- Chrome → `chrome://inspect/#devices` lets you inspect the WebView with
  full DevTools.
- Rails logs will show `User-Agent: Hotwire Native Android` from this app —
  the `hotwire_native_app?` helper on the Rails side uses this to hide the
  web header (the native nav takes over).

## Cleartext HTTP in debug

`network_security_config.xml` allows plain HTTP only to `localhost`,
`10.0.2.2`, and private LAN ranges. Production traffic should be HTTPS-only;
flip `usesCleartextTraffic="false"` in the manifest before shipping.
