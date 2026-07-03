# Wanderply iOS — App Store submission

Everything that can be automated headlessly is done and verified. This file is
the exact runbook for the remaining steps, which require an Apple account
identity (a distribution certificate + a registered App ID) that only the
account owner can create.

Bundle id: **`com.wanderply.PlanMyTrip`** · Deployment target: **iOS 16**

## Status — ✅ SHIPPED to App Store Connect (2026-07-03)

Build **1.0 (2)** uploaded successfully (Delivery UUID `fb4e78eb-b751-40a5-b803-a2aeb99515fa`).
App record "Wanderply" (`com.wanderply.PlanMyTrip`, id 6787223924) under the
personal skchakri team. Appears in App Store Connect → TestFlight after Apple
processing (~5–30 min).

> **Credentials are NOT stored in this repo.** The App Store Connect API key
> (Issuer ID / Key ID), Team ID, and the `.p8` live outside version control
> (`~/.appstoreconnect/private_keys/` + the sibling `prof_vault` project). Pass
> them as env vars at run time (below).

| Step | State |
|------|-------|
| Xcode project generated from source (`generate_xcodeproj.rb`) | ✅ done |
| hotwire-native-ios (1.2.2) linked via SPM | ✅ done |
| Native tab bar + native share sheet — clears Guideline 4.2 | ✅ done |
| App icon (1024², amber pin) + asset catalog | ✅ done |
| Simulator build against **https://wanderply.com** | ✅ verified |
| Distribution cert + App ID (auto via API key `-allowProvisioningUpdates`) | ✅ done |
| App record created (web UI — API forbids `apps` CREATE) | ✅ done |
| Distribution `.xcarchive` + `.ipa` | ✅ done |
| **Upload to App Store Connect** | ✅ **done** |

### Reproduce the whole push
```bash
ASC_ISSUER_ID=<issuer-uuid> ASC_KEY_ID=<key-id> DEVELOPMENT_TEAM=<team-id> \
  ./ios/push.sh --upload
```
(bump `CFBundleVersion` in `Info.plist` first — App Store Connect rejects a
duplicate build number.)

### Remaining (human, in App Store Connect UI)
Select the processed build under the version, complete the listing (screenshots
6.7"+6.1", description, keywords, privacy policy URL, age rating), then **Submit
for Review**. TestFlight testing needs no review for internal testers.

### Signing note (why the archive can't run yet)

`security find-identity -v -p codesigning` shows **no Apple Distribution cert on
a personal team** — the only distribution identity is the employer team
"Natures Sunshine Products Inc." (`99F9BS6U68`), which must **not** be used for
this personal app. Pick one of your personal teams and create a distribution
cert there first (below).

## 1. One-time Apple setup (you, in your Apple account)

1. **Choose the team.** Decide which Apple Developer Team owns Wanderply. Note
   its 10-char **Team ID** (Apple Developer → Membership).
2. **Register the App ID**: developer.apple.com → Certificates, IDs & Profiles →
   Identifiers → **+** → App IDs → App → Bundle ID `com.wanderply.PlanMyTrip`.
3. **Create a Distribution certificate**: easiest via Xcode →
   Settings → Accounts → (your team) → Manage Certificates → **+** →
   *Apple Distribution*. (Or Xcode handles it automatically in step 2 below.)
4. **Create the app record** in App Store Connect (appstoreconnect.apple.com →
   Apps → **+**): name, primary language, bundle id `com.wanderply.PlanMyTrip`,
   SKU. Fill listing: description, keywords, support URL, **privacy policy URL**,
   category (Travel), age rating, and screenshots (6.7" + 6.1" required).

## 2. Build the distribution archive (automatable once step 1 is done)

```bash
cd ios
export DEVELOPMENT_TEAM=<YOUR_TEAM_ID>       # e.g. QYLQZTZJ6D
ruby generate_xcodeproj.rb                    # regenerates with signing enabled

cd PlanMyTrip
xcodebuild archive \
  -project PlanMyTrip.xcodeproj -scheme PlanMyTrip \
  -destination 'generic/platform=iOS' \
  -archivePath build/PlanMyTrip.xcarchive \
  BASE_URL='https://wanderply.com' \
  -allowProvisioningUpdates
```

`-allowProvisioningUpdates` lets Xcode register the App ID and mint the
distribution profile automatically (needs you signed into the account in Xcode).

## 3. Export the .ipa

Set `teamID` in `ios/ExportOptions.plist` first, then:

```bash
xcodebuild -exportArchive \
  -archivePath build/PlanMyTrip.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist ../ExportOptions.plist \
  -allowProvisioningUpdates
# → build/export/PlanMyTrip.ipa
```

## 4. Upload (the "after" step — only when you're ready)

Create an **App Store Connect API key** (App Store Connect → Users and Access →
Integrations → App Store Connect API): note the Issuer ID, Key ID, and download
the `AuthKey_<KeyID>.p8`. Then:

```bash
xcrun altool --upload-app -f build/export/PlanMyTrip.ipa -t ios \
  --apiKey <KEY_ID> --apiIssuer <ISSUER_ID>
# (the .p8 must be in ./private_keys/ or ~/.appstoreconnect/private_keys/)
```

Or drag the `.ipa` into **Transporter.app**. After processing, the build appears
in App Store Connect → your app → TestFlight / add to a version → Submit for
Review.

## Guideline 4.2 (Minimum Functionality)

Apple rejects apps that are only a website wrapper. This shell adds a **native
UITabBarController** (`TabBarController.swift`) — real native navigation chrome.
Before submitting, consider adding more native value to strengthen the case:
native share sheet (bridge component), push notifications (APNs), or explicit
offline handling. See `README.md` → "Going beyond a pure web wrapper".
