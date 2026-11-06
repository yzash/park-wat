#!/usr/bin/env bash
# Vercel install step: fetch the pinned Flutter SDK (cached between builds).
set -euo pipefail
FLUTTER_VERSION="${FLUTTER_VERSION:-3.47.9}"
FLUTTER_DIR="${FLUTTER_DIR:-$HOME/flutter}"
if [ ! -x "$FLUTTER_DIR/bin/flutter" ] || ! "$FLUTTER_DIR/bin/flutter" --version 2>/dev/null | grep -q "Flutter $FLUTTER_VERSION"; then
  rm -rf "$FLUTTER_DIR"
  mkdir -p "$(dirname "$FLUTTER_DIR")"
  curl -sSL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
    | tar -xJ -C "$(dirname "$FLUTTER_DIR")"
fi
git config --global --add safe.directory "$FLUTTER_DIR" || true
"$FLUTTER_DIR/bin/flutter" config --no-analytics >/dev/null
cd app && "$FLUTTER_DIR/bin/flutter" pub get
