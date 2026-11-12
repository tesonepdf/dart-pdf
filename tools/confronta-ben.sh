#!/usr/bin/env bash
# Confronta SOLO le novita' pubblicate da Ben dopo l'ultimo commit gia' letto.
# Non modifica i file del progetto (salvo con --copia-puliti / --segna).
#
#   tools/confronta-ben.sh                 mostra novita', file puliti e file con conflitti veri
#   tools/confronta-ben.sh --copia-puliti  copia nel progetto i file che si fondono da soli (senza commit)
#   tools/confronta-ben.sh --segna         scrive in tools/fusione-ben.stato l'ultimo commit di Ben letto
#
# Risultati (file fusi, con marcatori dove ci sono conflitti): /tmp/confronta-ben/
set -u
cd "$(git rev-parse --show-toplevel)" || exit 2
STATO=tools/fusione-ben.stato
URL=https://github.com/ben-milanko/dart-pdf.git
OUT=/tmp/confronta-ben
# Cose di Ben che per decisione dell'utente non si guardano: sito, flussi di compilazione,
# documenti, versioni (pubspec/changelog), impostazioni dell'editor.
IGNORA='^(site/|\.github/|\.vscode/|doc/|SECURITY\.md$|CLAUDE\.md$|README\.md$|\.gitignore$)|(^|/)pubspec\.yaml$|(^|/)CHANGELOG\.md$'

[ -f "$STATO" ] || { echo "Manca $STATO"; exit 2; }
# shellcheck disable=SC1090
. "$STATO"
git remote get-url upstream >/dev/null 2>&1 || git remote add upstream "$URL"
NUOVO=$(git ls-remote upstream refs/heads/main | cut -f1)
[ -n "$NUOVO" ] || { echo "Non riesco a leggere il repo di Ben (rete?)"; exit 2; }

if [ "${1:-}" = "--segna" ]; then
  sed -i "s/^ULTIMO_LETTO=.*/ULTIMO_LETTO=$NUOVO/" "$STATO"
  echo "Segnato: Ben letto fino a ${NUOVO:0:8}. Ricordati il commit di $STATO."; exit 0
fi
if [ "$NUOVO" = "$ULTIMO_LETTO" ]; then
  echo "Nessuna novita' di Ben dopo ${ULTIMO_LETTO:0:8}."; exit 0
fi

git fetch -q --depth=1 upstream "$ULTIMO_LETTO" "$NUOVO" 2>/dev/null || { echo "Fetch fallito"; exit 2; }
echo "Ben: ${ULTIMO_LETTO:0:8} -> ${NUOVO:0:8}"
echo
echo "== Novita' dichiarate da Ben (titoli dei commit) =="
# Con GITHUB_TOKEN (variabile d'ambiente, mai scritta in un file) il limite di richieste e' piu' alto.
curl -s ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} "https://api.github.com/repos/ben-milanko/dart-pdf/compare/$ULTIMO_LETTO...$NUOVO" | python3 -c '
import sys,json
try: d=json.load(sys.stdin)
except Exception: print("  (elenco non disponibile)"); raise SystemExit
if "message" in d and "commits" not in d:
    print("  (elenco non disponibile: "+d["message"][:70]+")"); raise SystemExit
cs=d.get("commits",[])
print("  commit nuovi:",d.get("ahead_by","?"))
for c in cs[-60:]: print("  -",c["commit"]["message"].splitlines()[0][:110])
' 2>/dev/null || echo "  (elenco non disponibile)"

rm -rf "$OUT"; mkdir -p "$OUT"
puliti=(); conflitti=(); nuovi=(); cancellati=(); binari=(); ignorati=0
while IFS=$'\t' read -r st f; do
  if [[ "$f" =~ $IGNORA ]]; then ignorati=$((ignorati+1)); continue; fi
  case "$st" in
    D) [ -e "$f" ] && cancellati+=("$f"); continue;;
  esac
  if ! git cat-file -e "HEAD:$f" 2>/dev/null; then nuovi+=("$f"); mkdir -p "$OUT/$(dirname "$f")"; git show "$NUOVO:$f" > "$OUT/$f"; continue; fi
  if git diff --numstat "$ULTIMO_LETTO" "$NUOVO" -- "$f" | grep -q '^-'; then binari+=("$f"); continue; fi
  mkdir -p "$OUT/$(dirname "$f")"
  git show "$ULTIMO_LETTO:$f" > "$OUT/.base" 2>/dev/null || : > "$OUT/.base"
  git show "$NUOVO:$f" > "$OUT/.theirs"
  git show "HEAD:$f" > "$OUT/.ours"
  git merge-file -p "$OUT/.ours" "$OUT/.base" "$OUT/.theirs" > "$OUT/$f"; c=$?
  if [ "$c" -eq 0 ]; then puliti+=("$f"); else conflitti+=("$c  $f"); fi
done < <(git diff --name-status "$ULTIMO_LETTO" "$NUOVO" | awk -F'\t' '{print $1"\t"$NF}')
rm -f "$OUT/.base" "$OUT/.theirs" "$OUT/.ours"

echo
echo "== Risultato =="
echo "  ignorati (sito, flussi di Ben, versioni, documenti): $ignorati"
echo "  file NUOVI di Ben (non esistono qui): ${#nuovi[@]}"
echo "  file che si fondono DA SOLI: ${#puliti[@]}"
echo "  file con CONFLITTI VERI: ${#conflitti[@]}"
echo "  binari da guardare a mano: ${#binari[@]}"
echo "  cancellati da Ben ma presenti qui: ${#cancellati[@]}"
if [ "${#conflitti[@]}" -gt 0 ]; then echo; echo "== Conflitti veri (numero  file) =="; printf '  %s\n' "${conflitti[@]}"; fi
if [ "${#puliti[@]}" -gt 0 ]; then echo; echo "== Si fondono da soli =="; printf '  %s\n' "${puliti[@]}"; fi
if [ "${#nuovi[@]}" -gt 0 ]; then echo; echo "== Nuovi =="; printf '  %s\n' "${nuovi[@]}"; fi
if [ "${#binari[@]}" -gt 0 ]; then echo; echo "== Binari =="; printf '  %s\n' "${binari[@]}"; fi
echo; echo "File fusi in $OUT (nei conflitti ci sono i marcatori <<<<<<<)."
echo
echo "== PALETTI: funzioni dell'utente da non toccare (da conflittiFusione.md) =="
awk '/^## PALETTI/{f=1;next} /^## /{f=0} f' conflittiFusione.md 2>/dev/null
echo "Se una novita' di Ben cambia una di queste descrizioni: ALLARME, ci si ferma e si chiede all'utente."

if [ "${1:-}" = "--copia-puliti" ]; then
  for f in "${puliti[@]}" "${nuovi[@]}"; do mkdir -p "$(dirname "$f")"; cp "$OUT/$f" "$f"; done
  echo "Copiati ${#puliti[@]} file puliti e ${#nuovi[@]} nuovi nel progetto. Niente commit fatto."
fi
