#!/bin/sh
set -eu

APP_PATH="${TARGET_BUILD_DIR}/${WRAPPER_NAME}"
PY_RUNTIME="${APP_PATH}/Contents/Resources/python-minimal"
ENTITLEMENTS_PATH="${SRCROOT}/FeedBacksApp/FeedBacks.entitlements"

if [ -z "${EXPANDED_CODE_SIGN_IDENTITY:-}" ] || [ "${CODE_SIGNING_ALLOWED:-NO}" != "YES" ]; then
  exit 0
fi

if [ ! -d "$PY_RUNTIME" ]; then
  echo "No embedded python runtime at $PY_RUNTIME"
  exit 0
fi

if [ ! -f "$ENTITLEMENTS_PATH" ]; then
  echo "Missing entitlements file at $ENTITLEMENTS_PATH"
  exit 1
fi

echo "Signing embedded python runtime with ${EXPANDED_CODE_SIGN_IDENTITY_NAME:-$EXPANDED_CODE_SIGN_IDENTITY}"
echo "Using entitlements: $ENTITLEMENTS_PATH"

/usr/bin/find "$PY_RUNTIME" \
  \( -path '*/bin/python3' -o -path '*/bin/python3.10' -o -name '*.dylib' -o -name '*.so' \) \
  -exec /usr/bin/codesign --force --sign "$EXPANDED_CODE_SIGN_IDENTITY" --entitlements "$ENTITLEMENTS_PATH" --options runtime --timestamp=none {} \;

/usr/bin/codesign --verify --deep --strict --verbose=2 "$PY_RUNTIME"
/usr/bin/codesign --display --entitlements :- "$PY_RUNTIME/bin/python3" | /usr/bin/grep -q "com.apple.security.app-sandbox"
/usr/bin/codesign --display --entitlements :- "$PY_RUNTIME/bin/python3.10" | /usr/bin/grep -q "com.apple.security.app-sandbox"
