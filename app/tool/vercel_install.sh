#!/usr/bin/env bash
# Vercel: installa Flutter (stessa versione della build Android in
# .github/workflows/build.yml) e scarica le dipendenze.
set -euo pipefail
FLUTTER_VERSION="${FLUTTER_VERSION:-3.47.7}"
APP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$APP_DIR/.." && pwd)"
if [ ! -x "$HOME/flutter/bin/flutter" ]; then
  git clone --depth 1 --branch "$FLUTTER_VERSION" https://github.com/flutter/flutter.git "$HOME/flutter"
fi
export PATH="$HOME/flutter/bin:$PATH"
export CI=true
flutter config --no-analytics --enable-web
flutter precache --web
cd "$REPO_ROOT"
flutter pub get
