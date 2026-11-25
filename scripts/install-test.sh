#!/bin/bash
# CI only: installs the built .pkg on the runner and checks that macOS
# registers and enables the keyboard.
set -euo pipefail
cd "$(dirname "$0")/.."

PKG="$(ls build/MyanmarSimpleKeyboard-*.pkg | head -1)"
APP="/Library/Input Methods/MyanmarSimpleKeyboard.app"
EXE="$APP/Contents/MacOS/MyanmarSimpleKeyboard"

echo "==> Installing $PKG"
sudo installer -pkg "$PKG" -target /
test -x "$EXE"
codesign --verify --strict --verbose=2 "$APP"
"$EXE" --version

echo "==> Registering as $(whoami) (the postinstall script also does this)"
"$EXE" --install

echo "==> Status"
for attempt in 1 2 3 4 5; do
  if "$EXE" --status; then
    exit 0
  fi
  echo "not ready yet (attempt $attempt), waiting…"
  sleep 3
done
exit 1
