#!/usr/bin/env python3
"""Identificativo unico del prossimo commit: VERSIONE#BUILD (regola presa dal repo turni).

  VERSIONE = ultima cifra dell'anno . giorno dell'anno (3 cifre) . ora e minuti (Roma),
             presa dalla data del commit (GIT_COMMITTER_DATE se impostata, altrimenti adesso);
  BUILD    = numero della prossima build, lo stesso che calcola la CI:
             main               -> commit del ramo + 1 + 25;
             prova-sviluppatore -> 10013 + commit non ancora in main + 1.

Esempio: 6.325.1049#487

Uso (dopo git add):
    eval "$(python3 tool/identificativo.py)"
    GIT_COMMITTER_DATE="$DATA" git commit -m "$ID — descrizione"

    python3 tool/identificativo.py --solo-id    stampa solo l'identificativo (lo usa l'hook)

Cosi' commit, Actions, release, Vercel e app mostrano la stessa stringa.
"""
import os
import subprocess
import sys
from datetime import datetime

try:
    from zoneinfo import ZoneInfo

    ROMA = ZoneInfo("Europe/Rome")
except Exception:  # senza database dei fusi orari si usa l'ora locale
    ROMA = None


def git(*args):
    return subprocess.run(["git", *args], capture_output=True, text=True).stdout.strip()


def quando():
    grezza = os.environ.get("GIT_COMMITTER_DATE", "").strip()
    q = None
    if grezza:
        try:
            q = datetime.fromisoformat(grezza)
        except ValueError:
            q = None
    if q is None:
        q = datetime.now(ROMA) if ROMA else datetime.now().astimezone()
    if q.tzinfo is None:
        q = q.replace(tzinfo=ROMA) if ROMA else q.astimezone()
    if ROMA:
        q = q.astimezone(ROMA)
    return q.replace(microsecond=0)


def versione(q):
    return f"{q.year % 10}.{q.timetuple().tm_yday:03d}.{q.hour:02d}{q.minute:02d}"


def prossimo_numero():
    ramo = git("rev-parse", "--abbrev-ref", "HEAD")
    if ramo == "prova-sviluppatore":
        base = git("rev-parse", "--verify", "-q", "origin/main") or git("rev-parse", "--verify", "-q", "main")
        n = git("rev-list", "--count", f"{base}..HEAD") if base else "0"
        return 10013 + int(n or 0) + 1
    return int(git("rev-list", "--count", "HEAD") or 0) + 1 + 25


def main():
    q = quando()
    ident = f"{versione(q)}#{prossimo_numero()}"
    if "--solo-id" in sys.argv:
        print(ident)
        return
    print(f"ID='{ident}'")
    print(f"DATA='{q.isoformat()}'")


if __name__ == "__main__":
    main()
