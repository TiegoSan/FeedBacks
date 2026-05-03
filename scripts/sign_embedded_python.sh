#!/bin/sh
set -eu

APP_PATH="${TARGET_BUILD_DIR}/${WRAPPER_NAME}"
PY_RUNTIME="${APP_PATH}/Contents/Resources/python-minimal"
ENTITLEMENTS_PATH="${CODE_SIGN_ENTITLEMENTS:-${PROJECT_DIR}/FeedBacksApp/FeedBacks.entitlements}"
HELPER_ENTITLEMENTS_PATH="${PROJECT_DIR}/scripts/FeedBacksPythonHelper.entitlements"
HELPER_SOURCE_PATH="${PROJECT_DIR}/scripts/FeedBacksPythonHelper.c"
HELPER_PATH="${APP_PATH}/Contents/MacOS/FeedBacksPythonHelper"

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

if [ ! -f "$HELPER_ENTITLEMENTS_PATH" ]; then
  echo "Missing helper entitlements file at $HELPER_ENTITLEMENTS_PATH"
  exit 1
fi

if [ ! -f "$HELPER_SOURCE_PATH" ]; then
  echo "Missing helper source file at $HELPER_SOURCE_PATH"
  exit 1
fi

echo "Signing embedded python runtime with ${EXPANDED_CODE_SIGN_IDENTITY_NAME:-$EXPANDED_CODE_SIGN_IDENTITY}"
echo "Using entitlements: $ENTITLEMENTS_PATH"

ARCH_FLAGS=""
for arch in ${ARCHS:-$(uname -m)}; do
  ARCH_FLAGS="$ARCH_FLAGS -arch $arch"
done

mkdir -p "$(dirname "$HELPER_PATH")"
/bin/rm -f "$HELPER_PATH"
/usr/bin/xcrun clang $ARCH_FLAGS -O2 -isysroot "${SDKROOT}" -mmacosx-version-min="${MACOSX_DEPLOYMENT_TARGET}" \
  "$HELPER_SOURCE_PATH" \
  -o "$HELPER_PATH"

/usr/bin/find "$PY_RUNTIME" \
  -type f \
  \( -name 'python3' -o -name 'python3.10' \) \
  -delete

/usr/bin/find "$PY_RUNTIME" \
  \( -name '*.dylib' -o -name '*.so' \) \
  -exec /usr/bin/codesign --force --sign "$EXPANDED_CODE_SIGN_IDENTITY" --timestamp=none {} \;

/usr/bin/codesign \
  --force \
  --sign "$EXPANDED_CODE_SIGN_IDENTITY" \
  --timestamp=none \
  --entitlements "$HELPER_ENTITLEMENTS_PATH" \
  "$HELPER_PATH"

/usr/bin/codesign --verify --deep --strict --verbose=2 "$HELPER_PATH"
/usr/bin/codesign --display --entitlements :- "$HELPER_PATH" | /usr/bin/grep -q "com.apple.security.app-sandbox"
