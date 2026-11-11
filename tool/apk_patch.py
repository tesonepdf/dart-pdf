#!/usr/bin/env python3
"""Patch tra due APK (formato DPAT1) e piano di pubblicazione della release.

Comandi:
  apk_patch.py make  VECCHIO NUOVO PATCH      crea la patch
  apk_patch.py apply VECCHIO PATCH NUOVO      applica la patch (verifica le impronte)
  apk_patch.py sha   FILE                     stampa lo SHA-256
  apk_patch.py plan  ...                      usato dalla build (vedi sotto)

Formato DPAT1 (tutto compresso con gzip, numeri little-endian):
  intestazione: "DPAT1\\0", u64 dimensione vecchio, 32 byte SHA-256 vecchio,
                u64 dimensione nuovo, 32 byte SHA-256 nuovo
  operazioni:   0x01 COPIA  u64 posizione-nel-vecchio, u64 lunghezza
                0x02 INSERISCI u64 lunghezza, byte
                0x00 FINE

La patch si trova con il metodo di rsync: il vecchio APK si divide in blocchi da
1 KB, il nuovo si scorre byte per byte con un checksum rotante e ogni pezzo
uguale a un blocco del vecchio diventa una COPIA, il resto un INSERISCI.
Il risultato e' controllato con lo SHA-256: se non coincide, l'app scarica
l'APK completo.

Piano di pubblicazione (comando plan): vedi la funzione plan().
"""
import argparse
import gzip
import hashlib
import json
import os
import struct
import subprocess
import sys
import tempfile
import time
from operator import mul

MAGIC = b"DPAT1\0"
BLOCK = 1024
OP_END, OP_COPY, OP_INSERT = 0, 1, 2
MAX_PER_KEY = 8          # candidati per checksum (evita le liste lunghe di blocchi a zero)
MAX_EDGES = 30           # quante patch tenere nell'elenco
MAX_RATIO = 0.5          # una patch piu' grande della meta' dell'APK non conviene
BASE_ASSET = "DartPDF-Android.apk"
MANIFEST = "patches.json"


class PatchError(Exception):
    pass


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while True:
            chunk = f.read(1 << 20)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest()


# ---------------------------------------------------------------- creare

def _weak(block):
    return sum(block), sum(map(mul, range(len(block), 0, -1), block))


def _table(old):
    table = {}
    for o in range(0, len(old) - BLOCK + 1, BLOCK):
        a, b = _weak(old[o:o + BLOCK])
        lst = table.setdefault(((b & 0xFFFF) << 16) | (a & 0xFFFF), [])
        if len(lst) < MAX_PER_KEY:
            lst.append(o)
    return table


def make_patch(old_path, new_path, out_path):
    with open(old_path, "rb") as f:
        old = f.read()
    with open(new_path, "rb") as f:
        new = f.read()
    n = len(new)
    table = _table(old)
    ops = []  # ('c', pos_vecchio, lunghezza) oppure ('i', inizio_nuovo, fine_nuovo)
    lit = 0
    i = 0
    if n >= BLOCK and table:
        a, b = _weak(new[0:BLOCK])
        while True:
            hit = None
            offs = table.get(((b & 0xFFFF) << 16) | (a & 0xFFFF))
            if offs:
                blk = new[i:i + BLOCK]
                for o in offs:
                    if old[o:o + BLOCK] == blk:
                        hit = o
                        break
            if hit is not None:
                o = hit
                back = 0
                limit = min(i - lit, o)
                while back < limit and old[o - 1 - back] == new[i - 1 - back]:
                    back += 1
                fwd = BLOCK
                while i + fwd < n and o + fwd < len(old):
                    step = min(65536, n - i - fwd, len(old) - o - fwd)
                    if old[o + fwd:o + fwd + step] == new[i + fwd:i + fwd + step]:
                        fwd += step
                    else:
                        k = 0
                        while old[o + fwd + k] == new[i + fwd + k]:
                            k += 1
                        fwd += k
                        break
                if i - back > lit:
                    ops.append(("i", lit, i - back))
                ops.append(("c", o - back, back + fwd))
                i += fwd
                lit = i
                if i + BLOCK > n:
                    break
                a, b = _weak(new[i:i + BLOCK])
                continue
            if i + BLOCK >= n:
                break
            x = new[i]
            y = new[i + BLOCK]
            a = (a - x + y) & 0xFFFF
            b = (b - BLOCK * x + a) & 0xFFFF
            i += 1
    if lit < n:
        ops.append(("i", lit, n))

    with open(out_path, "wb") as raw:
        with gzip.GzipFile(filename="", mode="wb", compresslevel=9,
                           fileobj=raw, mtime=0) as g:
            g.write(MAGIC + struct.pack("<Q", len(old))
                    + hashlib.sha256(old).digest()
                    + struct.pack("<Q", n) + hashlib.sha256(new).digest())
            for kind, x, y in ops:
                if kind == "c":
                    g.write(bytes([OP_COPY]) + struct.pack("<QQ", x, y))
                else:
                    g.write(bytes([OP_INSERT]) + struct.pack("<Q", y - x))
                    g.write(new[x:y])
            g.write(bytes([OP_END]))
    return os.path.getsize(out_path)


# --------------------------------------------------------------- applicare

def _read(stream, n):
    data = stream.read(n)
    if len(data) != n:
        raise PatchError("patch troncata")
    return data


def apply_patch(old_path, patch_path, out_path):
    with open(old_path, "rb") as old, gzip.open(patch_path, "rb") as p, \
            open(out_path, "wb") as out:
        head = _read(p, 6 + 8 + 32 + 8 + 32)
        if head[:6] != MAGIC:
            raise PatchError("non e' una patch DPAT1")
        (old_size,) = struct.unpack("<Q", head[6:14])
        old_sha = head[14:46]
        (new_size,) = struct.unpack("<Q", head[46:54])
        new_sha = head[54:86]
        if os.path.getsize(old_path) != old_size or \
                bytes.fromhex(sha256_file(old_path)) != old_sha:
            raise PatchError("la patch non e' per questo APK")
        h = hashlib.sha256()
        written = 0
        while True:
            op = _read(p, 1)[0]
            if op == OP_END:
                break
            if op == OP_COPY:
                o, length = struct.unpack("<QQ", _read(p, 16))
                if o + length > old_size:
                    raise PatchError("copia fuori dall'APK vecchio")
                old.seek(o)
                while length:
                    chunk = old.read(min(length, 1 << 20))
                    if not chunk:
                        raise PatchError("APK vecchio troncato")
                    out.write(chunk)
                    h.update(chunk)
                    written += len(chunk)
                    length -= len(chunk)
            elif op == OP_INSERT:
                (length,) = struct.unpack("<Q", _read(p, 8))
                while length:
                    chunk = p.read(min(length, 1 << 20))
                    if not chunk:
                        raise PatchError("patch troncata")
                    out.write(chunk)
                    h.update(chunk)
                    written += len(chunk)
                    length -= len(chunk)
            else:
                raise PatchError("operazione sconosciuta %d" % op)
        if written != new_size or h.digest() != new_sha:
            raise PatchError("l'APK ricostruito non coincide")


# ------------------------------------------------------ piano di pubblicazione

def gh_download(repo, tag, name, dest_dir):
    """Scarica un file dalla release; None se non c'e'."""
    path = os.path.join(dest_dir, name)
    for attempt in range(3):
        r = subprocess.run(
            ["gh", "release", "download", tag, "--repo", repo, "--pattern", name,
             "--dir", dest_dir, "--clobber"], capture_output=True, text=True)
        if r.returncode == 0 and os.path.exists(path):
            return path
        err = (r.stderr or "").lower()
        if "not found" in err or "no assets match" in err:
            return None
        time.sleep(5)
    return None


def _reconstruct(manifest, download, work):
    """Ricostruisce l'APK della build 'current' del manifest: base + catena."""
    base = manifest["base"]
    cur = manifest["current"]
    path = download(base["asset"], work)
    if not path or sha256_file(path) != base["sha256"]:
        return None
    b = base["build"]
    step = 0
    while b != cur["build"]:
        edge = next((e for e in manifest["patches"] if e["from"] == b), None)
        if edge is None:
            return None
        pp = download(edge["asset"], work)
        if not pp:
            return None
        step += 1
        out = os.path.join(work, "chain-%d.apk" % step)
        try:
            apply_patch(path, pp, out)
        except PatchError:
            return None
        if sha256_file(out) != edge["to_sha"]:
            return None
        path = out
        b = edge["to"]
    return path if sha256_file(path) == cur["sha256"] else None


def plan(new_apk, build, out_dir, download, slim, force_full, log=print):
    """Decide cosa pubblicare per la build 'build'.

    download(nome, cartella) -> percorso o None: scarica un file della release.
    slim: se False l'APK completo si pubblica sempre (le patch si aggiungono
          soltanto); se True l'APK completo si pubblica solo come nuova base.
    Scrive in out_dir: patches.json (nuovo elenco), decision.json e, se serve,
    il file della patch. Restituisce la decisione.
    """
    os.makedirs(out_dir, exist_ok=True)
    work = tempfile.mkdtemp(prefix="apkplan-")
    new_sha = sha256_file(new_apk)
    new_size = os.path.getsize(new_apk)

    manifest = None
    mpath = download(MANIFEST, work)
    if mpath:
        try:
            with open(mpath) as f:
                manifest = json.load(f)
            if manifest.get("current", {}).get("build", 0) >= build:
                log("elenco gia' alla build %s: riparto da zero"
                    % manifest["current"]["build"])
                manifest = None
        except (ValueError, KeyError, TypeError):
            manifest = None

    edges = list(manifest["patches"]) if manifest else []
    prev = _reconstruct(manifest, download, work) if manifest else None
    if manifest and not prev:
        log("APK precedente non ricostruibile: pubblico l'APK completo")
        edges = []

    reasons = []
    new_edge = None
    patch_name = None
    if prev:
        cur = manifest["current"]
        patch_name = "patch-%d-%d.dpat" % (cur["build"], build)
        patch_path = os.path.join(out_dir, patch_name)
        psize = make_patch(prev, new_apk, patch_path)
        log("patch %s: %d byte (APK %d byte)" % (patch_name, psize, new_size))
        if psize > MAX_RATIO * new_size:
            reasons.append("patch troppo grande")
            os.remove(patch_path)
            patch_name = None
        elif force_full:
            os.remove(patch_path)
            patch_name = None
        else:
            new_edge = {"from": cur["build"], "to": build, "asset": patch_name,
                        "size": psize, "from_sha": cur["sha256"],
                        "to_sha": new_sha}
    else:
        reasons.append("nessuna base precedente")
    if force_full:
        reasons.append("richiesto con [completo]")
    if not slim:
        reasons.append("modalita' con APK sempre completo")
    if manifest and slim:
        chain = [e for e in edges if e["from"] >= manifest["base"]["build"]]
        if len(chain) + 1 >= MAX_EDGES:
            reasons.append("catena di patch troppo lunga")

    full = bool(reasons)
    if new_edge:
        edges.append(new_edge)
    elif full:
        edges = []  # niente strada per arrivarci con le patch: elenco da rifare

    delete = []
    while len(edges) > MAX_EDGES:
        delete.append(edges.pop(0)["asset"])
    if manifest and not new_edge and full:
        delete += [e["asset"] for e in manifest["patches"]]

    base = (manifest or {}).get("base")
    if full or not base:
        base = {"build": build, "asset": BASE_ASSET, "sha256": new_sha,
                "size": new_size}
    new_manifest = {"version": 1, "base": base,
                    "current": {"build": build, "sha256": new_sha,
                                "size": new_size},
                    "patches": edges}
    with open(os.path.join(out_dir, MANIFEST), "w") as f:
        json.dump(new_manifest, f, indent=1)
    keep = {e["asset"] for e in edges}
    decision = {"full": full, "patch": patch_name if new_edge else None,
                "delete": sorted(set(delete) - keep),
                "reason": "; ".join(reasons) or "solo patch"}
    with open(os.path.join(out_dir, "decision.json"), "w") as f:
        json.dump(decision, f, indent=1)
    log("decisione: %s" % json.dumps(decision))
    return decision


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawTextHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    for name in ("make", "apply"):
        p = sub.add_parser(name)
        p.add_argument("a")
        p.add_argument("b")
        p.add_argument("c")
    p = sub.add_parser("sha")
    p.add_argument("file")
    p = sub.add_parser("plan")
    p.add_argument("--repo", required=True)
    p.add_argument("--tag", required=True)
    p.add_argument("--new", required=True)
    p.add_argument("--build", type=int, required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--slim", default="false")
    p.add_argument("--force-full", default="false")
    args = ap.parse_args(argv)
    if args.cmd == "make":
        print(make_patch(args.a, args.b, args.c))
    elif args.cmd == "apply":
        apply_patch(args.a, args.b, args.c)
    elif args.cmd == "sha":
        print(sha256_file(args.file))
    else:
        truthy = lambda s: str(s).strip().lower() in ("1", "true", "yes", "si")
        plan(args.new, args.build, args.out,
             lambda name, d: gh_download(args.repo, args.tag, name, d),
             slim=truthy(args.slim), force_full=truthy(args.force_full))


if __name__ == "__main__":
    try:
        main()
    except PatchError as e:
        print("errore: %s" % e, file=sys.stderr)
        sys.exit(1)
