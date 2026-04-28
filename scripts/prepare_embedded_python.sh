#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_RUNTIME="${SOURCE_RUNTIME:-/Users/gautier/GogoLabs/Coupez/Resources/python-minimal}"
DEST_RUNTIME="${DEST_RUNTIME:-$ROOT_DIR/FeedBacksApp/Resources/python-minimal}"
PYTHON_BIN="${PYTHON_BIN:-/usr/local/bin/python3.10}"
SITE_PACKAGES="$DEST_RUNTIME/lib/python3.10/site-packages"
DONOR_RUNTIME="${DONOR_RUNTIME:-/Users/gautier/GogoLabs/GogoProtoolsArchiver/Resources/python-minimal}"

if [[ ! -d "$SOURCE_RUNTIME" ]]; then
  echo "Missing source runtime: $SOURCE_RUNTIME" >&2
  exit 1
fi

if [[ ! -x "$PYTHON_BIN" ]]; then
  echo "Missing Python 3.10 executable: $PYTHON_BIN" >&2
  exit 1
fi

echo "Syncing bundled runtime from $SOURCE_RUNTIME"
/bin/rm -rf "$DEST_RUNTIME"
/usr/bin/rsync -a "$SOURCE_RUNTIME/" "$DEST_RUNTIME/"
mkdir -p "$SITE_PACKAGES"

echo "Installing grpcio into bundled runtime"
"$PYTHON_BIN" -m pip install --upgrade --only-binary=:all: --target "$SITE_PACKAGES" grpcio

echo "Pruning caches"
/usr/bin/find "$DEST_RUNTIME" -type d -name '__pycache__' -prune -exec /bin/rm -rf {} + 2>/dev/null || true
/usr/bin/find "$DEST_RUNTIME" -type f \( -name '*.pyc' -o -name '*.pyo' \) -delete 2>/dev/null || true
/bin/rm -rf "$DEST_RUNTIME/lib/Resources/Python.app"

for ext in _socket.cpython-310-darwin.so _scproxy.cpython-310-darwin.so; do
  target="$DEST_RUNTIME/lib/python3.10/lib-dynload/$ext"
  donor="$DONOR_RUNTIME/lib/python3.10/lib-dynload/$ext"
  if [[ ! -f "$target" && -f "$donor" ]]; then
    echo "Restoring missing extension $ext from donor runtime"
    /bin/cp "$donor" "$target"
    /bin/chmod 755 "$target"
  fi
done

echo "Embedded runtime ready at $DEST_RUNTIME"
