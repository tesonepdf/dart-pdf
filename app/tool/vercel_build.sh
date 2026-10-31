#!/usr/bin/env bash
# Vercel: compila la web app. Il numero build e' quello scritto in testa al
# messaggio del commit ("#132 ..."), lo stesso di Actions.
set -euo pipefail
APP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$HOME/flutter/bin:$PATH"
export CI=true
export DART="dart" FLUTTER="flutter"
message="${VERCEL_GIT_COMMIT_MESSAGE:-}"
number="${message%% *}"
number="${number#\#}"
if ! [[ "$number" =~ ^[0-9]+$ ]]; then number="1"; fi
export PDF_BUILD_NUMBER="$number"
read -r year day hour minute < <(TZ=Europe/Rome date '+%Y %j %H %M')
export PDF_BUILD_VERSION="$((year - 2020)).${day}.${hour}${minute}"
cd "$APP_DIR"
bash tool/build_web.sh
