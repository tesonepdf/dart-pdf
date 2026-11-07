#!/usr/bin/env python3
"""Riassume i test falliti di `flutter test --reporter json` come annotazioni.

Uso: test_summary.py <test.json> [<stderr.txt>]

Per ogni test fallito scrive "file: nome -> prima riga dell'errore", diviso in
piu' annotazioni (GitHub ne mostra poche per passaggio e ognuna e' corta), cosi'
il motivo dei fallimenti si legge dall'API senza scaricare i log.
"""
import json
import re
import sys

LIMIT = 3400  # caratteri per annotazione
MAX_ANNOTATIONS = 8


def escape(text):
    return text.replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A')


def locations(text):
    """Le prime righe dello stack che cadono nei file dell'app o dei test."""
    found = []
    # Solo i file dell'app (app/test, app/lib): i frame interni di flutter_test
    # non dicono dove si rompe il test.
    for match in re.finditer(r'(?:app|packages/[\w-]+)/(?:test|lib)/([\w./-]+\.dart):(\d+)', text):
        loc = match.group(1).rsplit('/', 1)[-1] + ':' + match.group(2)
        if loc not in found:
            found.append(loc)
    return found[:4]


def from_prints(prints):
    """Le prime righe dell'eccezione che il framework ha stampato."""
    text = '\n'.join(prints).replace('\r', '')
    lines = text.split('\n')
    for i, line in enumerate(lines):
        if 'EXCEPTION CAUGHT' in line:
            rest = [l.strip() for l in lines[i + 1:]
                    if l.strip() and not set(l.strip()) <= set('═╞╡ ')]
            where = locations(text)
            suffix = ' @ ' + ', '.join(where) if where else ''
            return (' / '.join(rest[:4])[:300]) + suffix
    return ''


def short(error):
    lines = [l.strip() for l in error.replace('\r', '').split('\n') if l.strip()]
    text = ' / '.join(lines[:3])
    # Le righe di diagnosi (test temporanei "DBG ...") non si accorciano.
    return text[:900] if text.startswith('DBG') else text[:230]


def main():
    tests = {}
    passed = 0
    with open(sys.argv[1], encoding='utf-8', errors='replace') as fh:
        for raw in fh:
            raw = raw.strip()
            if not raw.startswith('{'):
                continue
            try:
                event = json.loads(raw)
            except ValueError:
                continue
            kind = event.get('type')
            if kind == 'testStart':
                test = event['test']
                tests[test['id']] = {
                    'name': test['name'],
                    'url': test.get('url') or '',
                    'errors': [],
                    'prints': [],
                    'result': None,
                    'hidden': False,
                }
            elif kind == 'print':
                entry = tests.get(event.get('testID'))
                if entry is not None:
                    entry['prints'].append(event.get('message', ''))
            elif kind == 'error':
                entry = tests.get(event['testID'])
                if entry is not None:
                    entry['errors'].append(event.get('error', ''))
            elif kind == 'testDone':
                entry = tests.get(event['testID'])
                if entry is not None:
                    entry['result'] = event.get('result')
                    entry['hidden'] = bool(event.get('hidden'))
                    if entry['result'] == 'success' and not entry['hidden']:
                        passed += 1
    failed = [t for t in tests.values()
              if t['result'] in ('failure', 'error') and not t['hidden']]
    lines = []
    for t in failed:
        file = t['url'].rsplit('/', 1)[-1] or '?'
        error = short(t['errors'][0]) if t['errors'] else ''
        if not error or error.startswith('Test failed. See exception logs'):
            error = from_prints(t['prints']) or error or '(nessun messaggio)'
        lines.append(f"{file}: {t['name']} -> {error}")
    if not lines and len(sys.argv) > 2:
        try:
            with open(sys.argv[2], encoding='utf-8', errors='replace') as fh:
                tail = fh.read()[-LIMIT:]
        except OSError:
            tail = ''
        if tail.strip():
            print('::error title=flutter test (stderr)::' + escape(tail))
    chunks, current = [], ''
    for line in lines:
        if current and len(current) + len(line) + 1 > LIMIT:
            chunks.append(current)
            current = ''
        current += line + '\n'
    if current:
        chunks.append(current)
    shown = chunks[:MAX_ANNOTATIONS]
    for i, chunk in enumerate(shown, 1):
        title = f'test falliti {i}/{len(shown)}'
        print(f'::error title={title}::' + escape(chunk))
    if len(chunks) > MAX_ANNOTATIONS:
        print('::error title=test falliti (altri)::'
              + escape(f'{len(chunks) - MAX_ANNOTATIONS} blocchi non mostrati'))
    print(f'::notice title=conteggio test::{passed} passati, {len(failed)} falliti')


main()
