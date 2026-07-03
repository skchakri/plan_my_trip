#!/usr/bin/env bash
# One-command App Store pipeline for Wanderply iOS.
# Everything from a clean checkout to a TestFlight upload — no manual Xcode steps.
#
# Prereqs you must supply (the only things not automatable):
#   ASC_ISSUER_ID      App Store Connect → Users and Access → Integrations (UUID)
#   ASC_KEY_ID         the API key's Key ID (a .p8 named AuthKey_<KEY_ID>.p8 must be
#                      in ~/.appstoreconnect/private_keys/ or ./private_keys/)
#   DEVELOPMENT_TEAM   the 10-char Apple Team ID that owns the app
#
# Usage:
#   ASC_ISSUER_ID=... ASC_KEY_ID=... DEVELOPMENT_TEAM=... ./push.sh [--upload]
#
# Without --upload it stops after producing the signed .ipa (per "prep, stop
# before upload"). With --upload it also ships the build to TestFlight.
set -euo pipefail

cd "$(dirname "$0")"
BASE_URL="${BASE_URL:-https://wanderply.com}"
UPLOAD="no"; [ "${1:-}" = "--upload" ] && UPLOAD="yes"

# --- validate inputs --------------------------------------------------------
missing=()
[ -n "${ASC_ISSUER_ID:-}" ]    || missing+=("ASC_ISSUER_ID")
[ -n "${ASC_KEY_ID:-}" ]       || missing+=("ASC_KEY_ID")
[ -n "${DEVELOPMENT_TEAM:-}" ] || missing+=("DEVELOPMENT_TEAM")
if [ "${#missing[@]}" -gt 0 ]; then
  echo "✗ missing required env: ${missing[*]}" >&2
  echo "  see the header of this script for where to get each." >&2
  exit 2
fi
KEY_PATH=""
for d in "$HOME/.appstoreconnect/private_keys" "./private_keys"; do
  [ -f "$d/AuthKey_${ASC_KEY_ID}.p8" ] && KEY_PATH="$d/AuthKey_${ASC_KEY_ID}.p8"
done
[ -n "$KEY_PATH" ] || { echo "✗ AuthKey_${ASC_KEY_ID}.p8 not found in key dirs" >&2; exit 2; }
echo "→ team=$DEVELOPMENT_TEAM key=$ASC_KEY_ID base=$BASE_URL upload=$UPLOAD"

# --- generate project with signing enabled ----------------------------------
export DEVELOPMENT_TEAM
ruby generate_xcodeproj.rb

cd PlanMyTrip
AUTH=(-authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID" -authenticationKeyPath "$KEY_PATH")

# --- archive (auto-registers App ID + mints distribution profile) -----------
echo "→ archiving…"
xcodebuild archive \
  -project PlanMyTrip.xcodeproj -scheme PlanMyTrip \
  -destination 'generic/platform=iOS' \
  -archivePath build/PlanMyTrip.xcarchive \
  BASE_URL="$BASE_URL" \
  -allowProvisioningUpdates "${AUTH[@]}"

# --- export the signed .ipa -------------------------------------------------
echo "→ exporting .ipa…"
# Fill teamID into a throwaway copy of the export options.
sed "s/REPLACE_WITH_TEAM_ID/$DEVELOPMENT_TEAM/" ../ExportOptions.plist > build/ExportOptions.plist
xcodebuild -exportArchive \
  -archivePath build/PlanMyTrip.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist build/ExportOptions.plist \
  -allowProvisioningUpdates "${AUTH[@]}"
IPA="build/export/PlanMyTrip.ipa"
echo "✓ built $IPA"

# --- upload -----------------------------------------------------------------
if [ "$UPLOAD" = "yes" ]; then
  echo "→ uploading to App Store Connect…"
  xcrun altool --upload-app -f "$IPA" -t ios \
    --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
  echo "✓ uploaded — check TestFlight in App Store Connect"
else
  echo "· skipping upload (pass --upload to ship to TestFlight)"
fi
