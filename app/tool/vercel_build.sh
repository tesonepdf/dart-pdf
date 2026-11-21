#!/usr/bin/env bash
# Vercel: compila la web app. Versione e numero build sono l'identificativo
# scritto in testa al messaggio del commit ("6.325.1049#487 — ..."), lo stesso
# di Actions.
set -euo pipefail
APP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$HOME/flutter/bin:$PATH"
export CI=true
export DART="dart" FLUTTER="flutter"
message="${VERCEL_GIT_COMMIT_MESSAGE:-}"
first="${message%%$'\n'*}"
version=""
number=""
# Identificativo scritto in testa al messaggio: VERSIONE#BUILD (6.325.1049#487).
# Vecchio formato: solo "#N".
if [[ "$first" =~ ^([0-9]+\.[0-9]+\.[0-9]+)#([0-9]+) ]]; then
  version="${BASH_REMATCH[1]}"
  number="${BASH_REMATCH[2]}"
else
  number="${first%% *}"
  number="${number#\#}"
fi
if ! [[ "$number" =~ ^[0-9]+$ ]]; then number="1"; fi
if [ -z "$version" ]; then
  read -r year day hour minute < <(TZ=Europe/Rome date '+%Y %j %H %M')
  version="$((year % 10)).${day}.${hour}${minute}"
fi
export PDF_BUILD_NUMBER="$number"
export PDF_BUILD_VERSION="$version"
cd "$APP_DIR"
bash tool/build_web.sh
