#!/usr/bin/env python3
"""Tasti a comando di DartPDF (le build vere girano su GitHub Actions).

  python aggiorna_e_pubblica.py apk       commit + push (parte la build APK),
                                           aspetta la fine e scarica l'APK
  python aggiorna_e_pubblica.py windows   avvia la build Windows a comando
                                           (serve GitHub CLI 'gh' gia' loggata),
                                           aspetta la fine e scarica APK + zip
"""
import json
import shutil
import subprocess
import sys
import time
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

REPO = "tesonepdf/dart-pdf"
ROOT = Path(__file__).resolve().parent
HEADERS = {"Accept": "application/vnd.github+json", "User-Agent": "DartPDF-pubblica"}


def pausa_finale():
    try:
        input("\nPremi INVIO per chiudere...")
    except Exception:
        pass


def esci(msg):
    print(f"\nERRORE: {msg}")
    pausa_finale()
    sys.exit(1)


def git(*args, check=True):
    r = subprocess.run(["git", *args], cwd=ROOT, text=True, capture_output=True)
    if check and r.returncode != 0:
        esci(f"git {' '.join(args)}\n{r.stderr.strip()}")
    return r.stdout.strip()


def api(path):
    req = urllib.request.Request(f"https://api.github.com/repos/{REPO}/{path}", headers=HEADERS)
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)


def aspetta_run(trova, timeout_min=60):
    """Aspetta che il run scelto da trova(runs) finisca. Ritorna la conclusione."""
    fine = time.time() + timeout_min * 60
    run = None
    while time.time() < fine:
        try:
            run = trova(api("actions/runs?per_page=15")["workflow_runs"])
        except Exception:
            run = None
        if run and run["status"] == "completed":
            return run["conclusion"]
        print("  build in corso..." if run else "  aspetto che la build parta...")
        time.sleep(30)
    esci("Tempo scaduto in attesa della build.")


def scarica(con_windows):
    cmd = [sys.executable, str(ROOT / "tool" / "sync_local_builds.py")]
    if con_windows:
        cmd.append("--windows")
    subprocess.run(cmd, cwd=ROOT)


def modo_apk():
    if git("status", "--porcelain"):
        git("add", "-A")
        git("commit", "-m", "Aggiornamento " + datetime.now().strftime("%d/%m/%Y %H:%M"))
    git("push")
    sha = git("rev-parse", "HEAD")
    print(f"Pushato {sha[:7]}: attendo la build APK...")
    esito = aspetta_run(lambda runs: next((r for r in runs if r["head_sha"] == sha and r["event"] == "push"), None))
    if esito != "success":
        esci(f"La build e' finita con esito: {esito}. Controlla Actions su GitHub.")
    scarica(False)


def modo_windows():
    if not shutil.which("gh"):
        esci("Serve GitHub CLI (gh). In alternativa: GitHub > Actions > Run workflow.")
    partenza = datetime.now(timezone.utc)
    r = subprocess.run(["gh", "workflow", "run", "build.yml", "--repo", REPO, "--ref", "main"])
    if r.returncode != 0:
        esci("Non sono riuscito ad avviare la build (gh loggata? permessi Actions?).")
    print("Build Windows avviata: attendo...")

    def trova(runs):
        for run in runs:
            creato = datetime.fromisoformat(run["created_at"].replace("Z", "+00:00"))
            if run["event"] == "workflow_dispatch" and creato >= partenza.replace(microsecond=0):
                return run
        return None

    esito = aspetta_run(trova)
    if esito != "success":
        esci(f"La build e' finita con esito: {esito}. Controlla Actions su GitHub.")
    scarica(True)


def main():
    modo = sys.argv[1] if len(sys.argv) > 1 else ""
    if modo == "apk":
        modo_apk()
    elif modo == "windows":
        modo_windows()
    else:
        esci("Uso: python aggiorna_e_pubblica.py apk|windows")
    print("\nFatto.")
    pausa_finale()


if __name__ == "__main__":
    main()
