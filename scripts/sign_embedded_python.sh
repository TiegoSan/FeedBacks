#!/bin/sh
set -eu

APP_PATH="${TARGET_BUILD_DIR}/${WRAPPER_NAME}"
PY_RUNTIME="${APP_PATH}/Contents/Resources/python-minimal"

if [ -z "${EXPANDED_CODE_SIGN_IDENTITY:-}" ] || [ "${CODE_SIGNING_ALLOWED:-NO}" != "YES" ]; then
  exit 0
fi

if [ ! -d "$PY_RUNTIME" ]; then
  echo "No embedded python runtime at $PY_RUNTIME"
  exit 0
fi

echo "Signing embedded python runtime with ${EXPANDED_CODE_SIGN_IDENTITY_NAME:-$EXPANDED_CODE_SIGN_IDENTITY}"

/usr/bin/find "$PY_RUNTIME" \
  \( -path '*/bin/python3' -o -path '*/bin/python3.10' -o -name '*.dylib' -o -name '*.so' \) \
  -exec /usr/bin/codesign --force --sign "$EXPANDED_CODE_SIGN_IDENTITY" --timestamp=none {} \;
