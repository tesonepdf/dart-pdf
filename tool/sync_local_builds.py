#!/usr/bin/env python3
"""Scarica in locale l'ultima build di DartPDF dalle Releases di GitHub.

  python tool/sync_local_builds.py             -> solo l'APK Android
  python tool/sync_local_builds.py --windows   -> anche lo zip Windows

L'APK va in apk/android, lo zip in apk/windows. Se l'ultima build e' gia'
presente non scarica nulla. Si tengono le ultime 4 build per cartella: la
quinta piu' vecchia viene cancellata, le altre non vengono toccate.
"""
import json
import re
import sys
import urllib.request
from pathlib import Path

REPO = "tesonepdf/dart-pdf"
TIENI = 4
ROOT = Path(__file__).resolve().parent.parent
HEADERS = {"Accept": "application/vnd.github+json", "User-Agent": "DartPDF-local-build-sync"}


def get(url):
    return urllib.request.urlopen(urllib.request.Request(url, headers=HEADERS), timeout=60)


def scarica(url, dest):
    tmp = dest.with_suffix(dest.suffix + ".part")
    try:
        with get(url) as r, open(tmp, "wb") as f:
            while chunk := r.read(1 << 20):
                f.write(chunk)
        tmp.replace(dest)
    finally:
        tmp.unlink(missing_ok=True)


def pulisci(cartella, pattern):
    trovati = []
    for f in cartella.iterdir():
        m = re.match(pattern, f.name)
        if m:
            trovati.append((int(m.group(1)), f))
    for _, f in sorted(trovati, reverse=True)[TIENI:]:
        f.unlink()


def main():
    con_windows = "--windows" in sys.argv
    with get(f"https://api.github.com/repos/{REPO}/releases?per_page=100") as r:
        releases = json.load(r)
    builds = [(int(m.group(1)), rel) for rel in releases
              if (m := re.fullmatch(r"build-(\d+)", rel["tag_name"]))]
    if not builds:
        sys.exit("Nessuna build pubblicata.")
    numero, rel = max(builds, key=lambda b: b[0])
    assets = {a["name"]: a["browser_download_url"] for a in rel["assets"]}

    android = ROOT / "apk" / "android"
    windows = ROOT / "apk" / "windows"
    android.mkdir(parents=True, exist_ok=True)

    apk_dest = android / f"DartPDF-build-{numero}.apk"
    if apk_dest.exists():
        print(f"APK build {numero} gia' presente.")
    else:
        url = assets.get("DartPDF-Android.apk") or assets.get("app-arm64-v8a.apk")
        if not url:
            sys.exit(f"La build {numero} non ha l'APK.")
        scarica(url, apk_dest)
        print(f"Scaricato APK build {numero}.")
    pulisci(android, r"DartPDF-build-(\d+)\.apk$")

    if con_windows:
        windows.mkdir(parents=True, exist_ok=True)
        zip_dest = windows / f"DartPDF-build-{numero}-windows-x64.zip"
        if zip_dest.exists():
            print(f"Zip Windows build {numero} gia' presente.")
        elif "windows-x64.zip" not in assets:
            print(f"La build {numero} non ha lo zip Windows: avviala da Actions (Run workflow).")
        else:
            scarica(assets["windows-x64.zip"], zip_dest)
            print(f"Scaricato zip Windows build {numero}.")
        pulisci(windows, r"DartPDF-build-(\d+)-windows-x64\.zip$")


if __name__ == "__main__":
    main()
