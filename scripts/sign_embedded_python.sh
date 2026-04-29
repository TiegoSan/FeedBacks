#!/bin/sh
set -eu

APP_PATH="${TARGET_BUILD_DIR}/${WRAPPER_NAME}"
PY_RUNTIME="${APP_PATH}/Contents/Resources/python-minimal"
ENTITLEMENTS_PATH="${CODE_SIGN_ENTITLEMENTS:-${PROJECT_DIR}/FeedBacksApp/FeedBacks.entitlements}"

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

for executable in "$PY_RUNTIME/bin/python3" "$PY_RUNTIME/bin/python3.10"; do
  if [ -f "$executable" ]; then
    /usr/bin/codesign \
      --force \
      --sign "$EXPANDED_CODE_SIGN_IDENTITY" \
      --timestamp=none \
      --entitlements "$ENTITLEMENTS_PATH" \
      "$executable"
  fi
done

/usr/bin/find "$PY_RUNTIME" \
  \( -name '*.dylib' -o -name '*.so' \) \
  -exec /usr/bin/codesign --force --sign "$EXPANDED_CODE_SIGN_IDENTITY" --timestamp=none {} \;

/usr/bin/codesign --verify --deep --strict --verbose=2 "$PY_RUNTIME"
/usr/bin/codesign --display --entitlements :- "$PY_RUNTIME/bin/python3" | /usr/bin/grep -q "com.apple.security.app-sandbox"
/usr/bin/codesign --display --entitlements :- "$PY_RUNTIME/bin/python3.10" | /usr/bin/grep -q "com.apple.security.app-sandbox"
