#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Build, sign, package, and optionally notarize FeedBacks.app.

Usage:
  scripts/release-mac.sh [options]

Options:
  --configuration <name>    Xcode configuration (default: Release)
  --no-build                Reuse the existing built app
  --no-sign                 Skip Developer ID signing
  --no-notarize             Skip notarization and stapling
  --help                    Show this help

Signing:
  Export SIGN_IDENTITY to override the Developer ID certificate.
  If unset, the first "Developer ID Application:" identity is used.

Notarization:
  Preferred:
    export NOTARYTOOL_PROFILE="your-keychain-profile"

  Or:
    export APPLE_ID="name@domain.com"
    export TEAM_ID="XXXXXXXXXX"
    export APPLE_APP_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx"
EOF
}

log() {
  printf '==> %s\n' "$*"
}

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

resolve_sign_identity() {
  if [[ -n "${SIGN_IDENTITY:-}" ]]; then
    printf '%s\n' "$SIGN_IDENTITY"
    return 0
  fi

  local detected
  detected="$(security find-identity -v -p codesigning 2>/dev/null | sed -n 's/.*"\(Developer ID Application:.*\)"/\1/p' | head -n 1 || true)"
  if [[ -z "$detected" ]]; then
    fail "No Developer ID Application identity found. Export SIGN_IDENTITY or install the certificate."
  fi

  printf '%s\n' "$detected"
}

submit_for_notarization() {
  local zip_path="$1"

  if [[ -n "${NOTARYTOOL_PROFILE:-}" ]]; then
    xcrun notarytool submit "$zip_path" --keychain-profile "$NOTARYTOOL_PROFILE" --wait
    return 0
  fi

  if [[ -n "${APPLE_ID:-}" && -n "${TEAM_ID:-}" && -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" ]]; then
    xcrun notarytool submit "$zip_path" \
      --apple-id "$APPLE_ID" \
      --team-id "$TEAM_ID" \
      --password "$APPLE_APP_SPECIFIC_PASSWORD" \
      --wait
    return 0
  fi

  fail "Notarization requested but credentials are missing."
}

sign_embedded_python() {
  local app_path="$1"
  local identity="$2"
  local runtime_dir="${app_path}/Contents/Resources/python-minimal"

  [[ -d "$runtime_dir" ]] || fail "Embedded runtime missing: ${runtime_dir}"

  log "Signing embedded python runtime"
  while IFS= read -r path; do
    codesign --force --sign "$identity" --options runtime --timestamp "$path"
  done < <(
    find "$runtime_dir" \
      \( -path '*/bin/python3' -o -path '*/bin/python3.10' -o -name '*.dylib' -o -name '*.so' \) \
      -type f | sort
  )
}

CONFIGURATION="Release"
DO_BUILD=1
DO_SIGN=1
DO_NOTARIZE=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --configuration)
      CONFIGURATION="${2:-}"; shift 2 ;;
    --no-build)
      DO_BUILD=0; shift ;;
    --no-sign)
      DO_SIGN=0; DO_NOTARIZE=0; shift ;;
    --no-notarize)
      DO_NOTARIZE=0; shift ;;
    --help|-h)
      usage; exit 0 ;;
    *)
      fail "Unknown option: $1" ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
XCODE_PROJECT="${PROJECT_DIR}/FeedBacks.xcodeproj"
XCODE_SCHEME="FeedBacks"
DERIVED_DIR="${PROJECT_DIR}/.derived-release"
DIST_DIR="${PROJECT_DIR}/dist/release"
APP_NAME="FeedBacks"
BUILT_APP="${DERIVED_DIR}/Build/Products/${CONFIGURATION}/${APP_NAME}.app"
RELEASE_APP="${DIST_DIR}/${APP_NAME}.app"
ZIP_PATH="${DIST_DIR}/${APP_NAME}.zip"

mkdir -p "$DIST_DIR"

if [[ $DO_BUILD -eq 1 ]]; then
  log "Building ${APP_NAME} (${CONFIGURATION})"
  xcodebuild \
    -project "$XCODE_PROJECT" \
    -scheme "$XCODE_SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination 'platform=macOS' \
    -derivedDataPath "$DERIVED_DIR" \
    CODE_SIGNING_ALLOWED=NO \
    build
fi

[[ -d "$BUILT_APP" ]] || fail "Built app not found at ${BUILT_APP}"

log "Staging release bundle"
rm -rf "$RELEASE_APP" "$ZIP_PATH"
ditto "$BUILT_APP" "$RELEASE_APP"

if [[ $DO_SIGN -eq 1 ]]; then
  SIGN_IDENTITY="$(resolve_sign_identity)"
  log "Signing with ${SIGN_IDENTITY}"
  sign_embedded_python "$RELEASE_APP" "$SIGN_IDENTITY"
  codesign --force --sign "$SIGN_IDENTITY" --options runtime --entitlements "${PROJECT_DIR}/FeedBacksApp/FeedBacks.entitlements" --timestamp "$RELEASE_APP"
  codesign --verify --deep --strict --verbose=2 "$RELEASE_APP"
else
  log "Skipping signing"
fi

if [[ $DO_NOTARIZE -eq 1 ]]; then
  [[ $DO_SIGN -eq 1 ]] || fail "Notarization requires signing."
  log "Creating notarization zip"
  ditto -c -k --keepParent "$RELEASE_APP" "$ZIP_PATH"
  log "Submitting for notarization"
  submit_for_notarization "$ZIP_PATH"
  log "Stapling ticket"
  xcrun stapler staple "$RELEASE_APP"
  xcrun stapler validate "$RELEASE_APP"
  spctl --assess --ignore-cache -t execute -vv "$RELEASE_APP"
else
  log "Skipping notarization"
fi

log "Release app: ${RELEASE_APP}"
if [[ -f "$ZIP_PATH" ]]; then
  log "Release zip: ${ZIP_PATH}"
fi
