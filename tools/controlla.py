#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Controllo statico del codice Dart, senza Flutter e senza rete.

Serve a fermare prima del push gli errori piu' banali che fanno diventare
rossa la CI (`flutter analyze`). NON sostituisce l'analisi vera: prende solo
quello che si vede leggendo i file.

Cosa controlla (errori):
  1. import / export / part che puntano a un file che non esiste
     (percorsi relativi e `package:` dei pacchetti del workspace);
  2. parentesi (), {}, [] non bilanciate; stringhe e commenti /* */ non chiusi
     (anche dentro le interpolazioni ${...});
  3. classi, enum, mixin, typedef, extension del progetto usati in un file
     senza che il file li importi (ne' direttamente ne' con un export);
  3b. nomi rinominati o cancellati nei file toccati (rispetto a HEAD, o a
     `--base=REV`) che altri file usano ancora;
  4. asset e font elencati in un pubspec.yaml che non esistono;
  5. file .arb (testi delle lingue) che non sono un JSON valido.
Cosa segnala come avviso (non blocca):
  6. nomi scritti in un `show` che non si trovano piu' nel file importato.

Uso (dalla radice del repo):
  python3 tools/controlla.py              controlla tutto
  python3 tools/controlla.py --cambiati   mostra solo i file modificati (git)
  python3 tools/controlla.py FILE...      mostra solo quei file
  python3 tools/controlla.py --base=REV   confronta i nomi con REV (di base HEAD)

Codice di uscita: 0 = nessun errore, 1 = almeno un errore.
I casi noti e voluti si scrivono in tools/controlla_noti.txt, una riga per caso:
  percorso|tipo|dettaglio
"""
import json
import os
import re
import subprocess
import sys
import time
from collections import defaultdict

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
SKIP_DIRS = {'.dart_tool', '.git', 'node_modules', 'ephemeral', '.symlinks'}
NOTI = os.path.join(ROOT, 'tools', 'controlla_noti.txt')

# ---------------------------------------------------------------- scanner --

TOKEN = re.compile(
    r"""//|/\*|r'''|r\"\"\"|'''|\"\"\"|r'|r\"|'|\"|[(){}\[\]]""")
BLANK = re.compile(r'[^\n]')
OPEN = {'(': ')', '{': '}', '[': ']'}
CLOSE = {')': '(', '}': '{', ']': '['}
_STRPAT = {}


def _strpat(quote, triple, raw):
    key = (quote, triple, raw)
    p = _STRPAT.get(key)
    if p is None:
        q = re.escape(quote)
        parts = []
        if not raw:
            parts.append(r'\\')
            parts.append(r'\$\{')
        parts.append(q * 3 if triple else q)
        if not triple:
            parts.append(r'\n')
        p = _STRPAT[key] = re.compile('|'.join(parts))
    return p


class Scanner:
    """Toglie stringhe e commenti (tenendo il codice delle interpolazioni) e
    controlla che le parentesi si chiudano."""

    def __init__(self, src):
        self.src = src
        self.n = len(src)
        self.out = []
        self.stack = []
        self.err = None

    def blank(self, a, b):
        if b > a:
            self.out.append(BLANK.sub(' ', self.src[a:b]))

    def fail(self, idx, msg):
        if self.err is None:
            self.err = (idx, msg)

    def run(self):
        self.code(0, False)
        if self.err is None and self.stack:
            ch, idx = self.stack[-1]
            self.fail(idx, "'%s' aperta e mai chiusa" % ch)
        return ''.join(self.out)

    def code(self, i, interp):
        src, n = self.src, self.n
        last = i
        if interp:
            self.stack.append(('$', i))
        while True:
            m = TOKEN.search(src, i)
            if not m:
                self.out.append(src[last:n])
                return n
            t = m.group()
            s = m.start()
            if t == '//':
                self.out.append(src[last:s])
                e = src.find('\n', s)
                e = n if e < 0 else e
                self.blank(s, e)
                i = last = e
                continue
            if t == '/*':
                self.out.append(src[last:s])
                depth, j = 1, s + 2
                while depth and j < n:
                    a = src.find('/*', j)
                    b = src.find('*/', j)
                    if b < 0:
                        j = n
                        break
                    if 0 <= a < b:
                        depth += 1
                        j = a + 2
                    else:
                        depth -= 1
                        j = b + 2
                if depth:
                    self.fail(s, 'commento /* non chiuso')
                self.blank(s, j)
                i = last = j
                continue
            if t[0] in 'r\'"':
                raw = t[0] == 'r'
                if raw and s > 0 and (src[s - 1].isalnum() or src[s - 1] in '_$'):
                    i = s + 1  # una 'r' che chiude un nome, non una stringa raw
                    continue
                body = t[1:] if raw else t
                self.out.append(src[last:s])
                e = self.string(s, m.end(), body[0], len(body) == 3, raw)
                i = last = e
                continue
            if t in OPEN:
                self.stack.append((t, s))
                i = s + 1
                continue
            # parentesi che chiude
            if t == '}' and interp and self.stack and self.stack[-1][0] == '$':
                self.stack.pop()
                self.out.append(src[last:s])
                self.out.append(' ')
                return s + 1
            if self.stack and self.stack[-1][0] == CLOSE[t]:
                self.stack.pop()
            else:
                self.fail(s, "'%s' senza apertura corrispondente" % t)
            i = s + 1

    def string(self, s, j, quote, triple, raw):
        src, n = self.src, self.n
        pat = _strpat(quote, triple, raw)
        start = s
        while True:
            m = pat.search(src, j)
            if not m:
                self.fail(s, 'stringa non chiusa')
                self.blank(start, n)
                return n
            t = m.group()
            if t == '\\':
                j = m.end() + 1
                continue
            if t == '${':
                self.blank(start, m.end())
                j = self.code(m.end(), True)
                start = j
                continue
            if t == '\n':
                self.fail(s, 'stringa non chiusa')
                self.blank(start, m.start())
                return m.start()
            self.blank(start, m.end())
            return m.end()


# ------------------------------------------------------------- repository --

def walk(base, ext):
    for d, dirs, files in os.walk(base):
        dirs[:] = [x for x in dirs if x not in SKIP_DIRS]
        for f in files:
            if f.endswith(ext):
                yield os.path.join(d, f)


def rel(p):
    return os.path.relpath(p, ROOT).replace(os.sep, '/')


def read(p):
    with open(p, encoding='utf-8', errors='replace') as f:
        return f.read()


PKG = {}  # nome pacchetto -> cartella lib


def find_pubspecs():
    out = []
    for base in ('app', 'packages'):
        for d, dirs, files in os.walk(os.path.join(ROOT, base)):
            dirs[:] = [x for x in dirs if x not in SKIP_DIRS]
            if 'pubspec.yaml' in files:
                out.append(os.path.join(d, 'pubspec.yaml'))
    return sorted(out)


PUBSPECS = find_pubspecs()
for _p in PUBSPECS:
    _m = re.search(r'^name:\s*(\S+)', read(_p), re.M)
    if _m:
        PKG[_m.group(1)] = os.path.join(os.path.dirname(_p), 'lib')

DIRECTIVE = re.compile(
    r'^[ \t]*(import|export|part[ \t]+of|part)\b([^;]*);', re.M)
DECL = re.compile(
    r'^\s*(?:(?:abstract|base|final|sealed|interface|mixin|augment)\s+)*'
    r'(?:class|enum|mixin|typedef|extension\s+type)\s+([A-Z_]\w*)')
EXTDECL = re.compile(r'^\s*extension\s+([A-Z_]\w*)(?:<[^>]*>)?\s+on\b')
USED = re.compile(r'(?<![\w$.])[A-Z][A-Za-z0-9_]*')
WORD = re.compile(r'[A-Za-z_$][\w$]*')
URI = re.compile(r"""['"]([^'"\n]+)['"]""")


def resolve(from_file, uri):
    """Percorso del file, oppure None se non e' del progetto (dart:, pub)."""
    if uri.startswith('dart:') or '://' in uri:
        return None
    if uri.startswith('package:'):
        name, _, rest = uri[8:].partition('/')
        if name in PKG:
            return os.path.normpath(os.path.join(PKG[name], rest))
        return None
    return os.path.normpath(os.path.join(os.path.dirname(from_file), uri))


class Info:
    pass


def load_file(path):
    info = Info()
    info.path = path
    info.src = read(path)
    sc = Scanner(info.src)
    info.stripped = sc.run()
    info.scan_err = sc.err
    info.dirs = []  # direttive
    spans = []
    for m in DIRECTIVE.finditer(info.src):
        kw = m.start(1)
        if kw < len(info.stripped) and info.stripped[kw] == ' ':
            continue  # dentro un commento o una stringa
        kind = re.sub(r'\s+', ' ', m.group(1))
        body = re.sub(r'\s+', ' ', m.group(2))
        if kind != 'part of' and not body.lstrip().startswith(("'", '"')):
            continue  # es. il parametro con nome `part: 2`, non una direttiva
        spans.append((m.start(), m.end()))
        uris = URI.findall(body)
        cut = max(body.rfind("'"), body.rfind('"'))
        tail = body[cut + 1:] if cut >= 0 else ''
        alias = re.search(r'\bas\s+(\w+)', tail)
        show = re.search(r'\bshow\s+(.*?)(?=\bhide\b|$)', tail)
        hide = re.search(r'\bhide\s+(.*)$', tail)

        def names(mm):
            return {x.strip() for x in mm.group(1).split(',') if x.strip()} \
                if mm else None
        line = info.src.count('\n', 0, m.start()) + 1
        info.dirs.append({
            'kind': kind, 'uris': uris, 'alias': alias.group(1) if alias else None,
            'show': names(show), 'hide': names(hide), 'line': line,
            'conditional': len(uris) > 1,
        })
    code = info.stripped
    for a, b in reversed(spans):
        code = code[:a] + BLANK.sub(' ', code[a:b]) + code[b:]
    info.code = code
    info.words = set(WORD.findall(code))
    info.decls = find_decls(code)
    return info


def find_decls(code):
    """Nomi di classi, enum, mixin, typedef, extension di primo livello."""
    decls = set()
    depth = 0
    for line in code.split('\n'):
        if depth == 0:
            m = DECL.match(line) or EXTDECL.match(line)
            if m and not m.group(1).startswith('_'):
                decls.add(m.group(1))
        depth += line.count('{') - line.count('}')
        if depth < 0:
            depth = 0
    return decls


def removed_names(files, repo_defs, base):
    """Nomi che c'erano nei file toccati (rispetto a `base`) e ora non ci sono
    piu' in nessun file del progetto: rinominati o cancellati."""
    res = {}
    out = subprocess.run(['git', 'diff', '--name-status', '-M', base], cwd=ROOT,
                         capture_output=True, text=True).stdout
    for line in out.splitlines():
        parts = line.split('\t')
        st = parts[0][:1]
        if st in ('M', 'D') and len(parts) >= 2:
            old = new = parts[1]
        elif st == 'R' and len(parts) >= 3:
            old, new = parts[1], parts[2]
        else:
            continue
        if not old.endswith('.dart'):
            continue
        r = subprocess.run(['git', 'show', '%s:%s' % (base, old)], cwd=ROOT,
                           capture_output=True, text=True)
        if r.returncode != 0:
            continue
        old_decls = find_decls(Scanner(r.stdout).run())
        newp = os.path.normpath(os.path.join(ROOT, new))
        new_decls = files[newp].decls if newp in files else set()
        for n in old_decls - new_decls:
            if n not in repo_defs:
                res[n] = old
    return res


def main(argv):
    t0 = time.time()
    only_changed = '--cambiati' in argv
    only = [a for a in argv if not a.startswith('--')]

    paths = []
    for base in ('app', 'packages'):
        paths.extend(walk(os.path.join(ROOT, base), '.dart'))
    paths = sorted(set(os.path.normpath(p) for p in paths))
    files = {p: load_file(p) for p in paths}
    findings = []  # (percorso, riga, gravita', tipo, dettaglio, messaggio)

    def add(path, line, sev, kind, detail, msg):
        findings.append((rel(path), line, sev, kind, detail, msg))

    # --- parentesi e stringhe
    for p, f in files.items():
        if f.scan_err:
            idx, msg = f.scan_err
            add(p, f.src.count('\n', 0, idx) + 1, 'errore', 'sintassi', msg, msg)

    # --- librerie (file + part)
    part_root = {}
    for p, f in files.items():
        for d in f.dirs:
            if d['kind'] == 'part':
                for u in d['uris']:
                    tp = resolve(p, u)
                    if tp is None:
                        continue
                    if tp not in files:
                        add(p, d['line'], 'errore', 'part mancante', u,
                            "part '%s': il file non esiste" % u)
                    else:
                        part_root[tp] = p
    for p, f in files.items():
        for d in f.dirs:
            if d['kind'] == 'part of' and p not in part_root:
                for u in d['uris']:
                    tp = resolve(p, u)
                    if tp in files:
                        part_root[p] = tp

    def lib_of(p):
        seen = 0
        while p in part_root and seen < 5:
            p = part_root[p]
            seen += 1
        return p

    lib_files = defaultdict(list)
    for p in files:
        lib_files[lib_of(p)].append(p)
    declared = {lib: set().union(*[files[x].decls for x in fl])
                for lib, fl in lib_files.items()}
    repo_defs = defaultdict(set)
    for lib, names in declared.items():
        for n in names:
            repo_defs[n].add(lib)

    # --- import / export che non esistono
    for p, f in files.items():
        for d in f.dirs:
            if d['kind'] not in ('import', 'export'):
                continue
            for u in d['uris']:
                tp = resolve(p, u)
                if tp is None:
                    continue
                if tp in files:
                    continue
                if os.path.exists(tp):
                    continue  # esiste ma non e' Dart (es. .g.dart generato)
                if d['conditional']:
                    continue  # le varianti web/io possono non esserci tutte
                add(p, d['line'], 'errore', 'import mancante', u,
                    "%s '%s': il file non esiste" % (d['kind'], u))

    # --- chiusure degli export
    closure_cache = {}

    def closure(lib):
        if lib in closure_cache:
            return closure_cache[lib]
        res, todo = set(), [lib]
        while todo:
            x = todo.pop()
            if x in res:
                continue
            res.add(x)
            root = files.get(x)
            if not root:
                continue
            for d in root.dirs:
                if d['kind'] == 'export':
                    for u in d['uris']:
                        tp = resolve(x, u)
                        if tp in files:
                            todo.append(lib_of(tp))
        closure_cache[lib] = res
        return res

    def has_external_export(lib):
        for x in closure(lib):
            for d in files[x].dirs:
                if d['kind'] == 'export':
                    for u in d['uris']:
                        if resolve(x, u) is None and not u.startswith('dart:'):
                            return True
        return False

    imports_of = {}
    for lib in lib_files:
        res = []
        for d in files[lib].dirs:
            if d['kind'] != 'import':
                continue
            targets = []
            for u in d['uris']:
                tp = resolve(lib, u)
                if tp in files:
                    targets.append(lib_of(tp))
            res.append((d, targets))
        imports_of[lib] = res

    def visible(lib, name):
        if name in declared[lib]:
            return True
        for d, targets in imports_of[lib]:
            if d['alias']:
                continue
            if d['show'] is not None and name not in d['show']:
                continue
            if d['hide'] is not None and name in d['hide']:
                continue
            for t in targets:
                for x in closure(t):
                    if name in declared[x]:
                        return True
        return False

    # --- classi usate senza import
    for p, f in files.items():
        lib = lib_of(p)
        seen = set()
        for m in USED.finditer(f.code):
            name = m.group()
            if name in seen or name not in repo_defs:
                continue
            seen.add(name)
            if lib in repo_defs[name] or visible(lib, name):
                continue
            defs = sorted(rel(x) for x in repo_defs[name])
            where = defs[0] + (' (e altri %d)' % (len(defs) - 1) if len(defs) > 1 else '')
            add(p, f.code.count('\n', 0, m.start()) + 1, 'errore',
                'import mancante (nome)', name,
                "usa '%s' (definito in %s) ma il file non lo importa" % (name, where))

    # --- nomi rimossi o rinominati ma ancora usati
    base = 'HEAD'
    for a in argv:
        if a.startswith('--base='):
            base = a[7:]
    gone = removed_names(files, repo_defs, base)
    if gone:
        for p, f in files.items():
            seen = set()
            for m in USED.finditer(f.code):
                name = m.group()
                if name in seen or name not in gone:
                    continue
                seen.add(name)
                add(p, f.code.count('\n', 0, m.start()) + 1, 'errore',
                    'nome rimosso', name,
                    "usa '%s', che non e' piu' definito (c'era in %s)"
                    % (name, gone[name]))

    # --- nomi in `show` che non esistono piu'
    for p, f in files.items():
        for d in f.dirs:
            if d['kind'] not in ('import', 'export') or not d['show']:
                continue
            for u in d['uris']:
                tp = resolve(p, u)
                if tp not in files:
                    continue
                tl = lib_of(tp)
                if has_external_export(tl):
                    continue
                allwords = set()
                for x in closure(tl):
                    for y in lib_files[x]:
                        allwords |= files[y].words
                for name in sorted(d['show']):
                    if name not in allwords:
                        add(p, d['line'], 'avviso', 'show senza nome', name,
                            "show '%s' non si trova piu' in %s" % (name, u))

    # --- pubspec: asset e font
    for pub in PUBSPECS:
        base = os.path.dirname(pub)
        in_flutter, in_assets = False, False
        for i, line in enumerate(read(pub).split('\n'), 1):
            if re.match(r'^flutter:\s*$', line):
                in_flutter, in_assets = True, False
                continue
            if in_flutter and re.match(r'^\S', line) and not line.startswith('#'):
                in_flutter = False
            if not in_flutter:
                continue
            if re.match(r'^  assets:\s*$', line):
                in_assets = True
                continue
            if re.match(r'^  \S', line):
                in_assets = False
            entry = None
            if in_assets:
                m = re.match(r'^\s*-\s+([^\s#:][^\s#]*)\s*(?:#.*)?$', line)
                if m:
                    entry = m.group(1)
            m = re.match(r'^\s*-?\s*asset:\s*([^\s#]+)', line)
            if m:
                entry = m.group(1)
            if not entry or entry.startswith('packages/') or '*' in entry:
                continue
            target = os.path.join(base, entry)
            if not os.path.exists(target):
                add(pub, i, 'errore', 'asset mancante', entry,
                    "asset '%s' elencato ma non esiste" % entry)

    # --- file .arb
    arbs = []
    for base in ('app', 'packages'):
        arbs.extend(walk(os.path.join(ROOT, base), '.arb'))
    for p in sorted(arbs):
        try:
            json.loads(read(p))
        except ValueError as e:
            add(p, getattr(e, 'lineno', 1), 'errore', 'arb non valido', 'json',
                'JSON non valido: %s' % e)

    # --- casi noti
    noti = set()
    if os.path.exists(NOTI):
        for line in read(NOTI).split('\n'):
            line = line.strip()
            if line and not line.startswith('#'):
                noti.add(tuple(x.strip() for x in line.split('|')[:3]))
    findings = [x for x in findings if (x[0], x[3], x[4]) not in noti]

    # --- filtro di visualizzazione
    if only_changed:
        out = subprocess.run(['git', 'status', '--porcelain'], cwd=ROOT,
                             capture_output=True, text=True).stdout
        only = [l[3:].strip().split(' -> ')[-1] for l in out.splitlines()]
    if only:
        wanted = {o.replace(os.sep, '/') for o in only}
        findings = [x for x in findings if x[0] in wanted]

    findings.sort(key=lambda x: (x[2] != 'errore', x[0], x[1]))
    errs = [x for x in findings if x[2] == 'errore']
    warns = [x for x in findings if x[2] == 'avviso']
    for title, items in (('ERRORI', errs), ('AVVISI', warns)):
        if items:
            print('%s (%d)' % (title, len(items)))
            for path, line, _, kind, detail, msg in items:
                print('  %s:%s  [%s] %s' % (path, line, kind, msg))
            print()
    print('Controllati %d file Dart, %d pubspec in %.1f s: %d errori, %d avvisi.'
          % (len(files), len(PUBSPECS), time.time() - t0, len(errs), len(warns)))
    return 1 if errs else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
