#!/usr/bin/env python3
"""Tiene lo storico delle modifiche di ogni build, per la finestra di
aggiornamento: chi salta qualche build vede cosa e' cambiato in ognuna.

Legge lo storico gia' pubblicato (se c'e'), aggiunge la build nuova in cima e
scrive il file da caricare nella release (build-changes.json).

    storico_build.py --prev prev/build-changes.json --build 312 \
        --version 6.330.0736#312 --changes changes.txt --out build-changes.json

changes.txt: una modifica per riga, con o senza il "- " iniziale.
"""
import argparse
import json
import os
import sys

MAX_BUILD = 25


def carica(path):
    if not path or not os.path.exists(path):
        return []
    try:
        with open(path, encoding="utf-8-sig") as f:
            dati = json.load(f)
    except (OSError, ValueError):
        return []
    return [b for b in dati if isinstance(b, dict) and isinstance(b.get("build"), int)]


def leggi_modifiche(path):
    righe = []
    with open(path, encoding="utf-8") as f:
        for riga in f:
            riga = riga.strip()
            if riga.startswith("- "):
                riga = riga[2:].strip()
            if riga:
                righe.append(riga)
    return righe


def aggiorna(storico, build, version, modifiche, massimo=MAX_BUILD):
    """La build nuova in cima; una build gia' presente si sostituisce."""
    resto = [b for b in storico if b["build"] != build]
    nuova = {"build": build, "version": version, "changes": modifiche}
    return sorted([nuova] + resto, key=lambda b: b["build"], reverse=True)[:massimo]


def main(argv=None):
    p = argparse.ArgumentParser()
    p.add_argument("--prev")
    p.add_argument("--build", type=int, required=True)
    p.add_argument("--version", required=True)
    p.add_argument("--changes", required=True)
    p.add_argument("--out", required=True)
    a = p.parse_args(argv)
    risultato = aggiorna(carica(a.prev), a.build, a.version, leggi_modifiche(a.changes))
    with open(a.out, "w", encoding="utf-8") as f:
        json.dump(risultato, f, ensure_ascii=False, indent=1)
    print(f"storico: {len(risultato)} build, la piu' alta #{risultato[0]['build']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
