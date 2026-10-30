# Da fare e codice: consegna alla prossima chat

Per l'assistente che riprende il lavoro. Leggere prima `CONFLITTI-FUSIONE.md` (regole dell'utente e stato dei conflitti). Aggiornato il 2026-10-30.

## Dove siamo

Piano a 4 punti (repo `tesonepdf/dart-pdf`, due rami paralleli):

| Punto | Stato |
|---|---|
| 1. Una sola release normale per canale, niente pre-release né build numerate | **Fatto** e pubblicato su `main` e `prova-sviluppatore` |
| 2. Canale prova separato, con numeri build propri (`#Np`) | **Fatto nel workflow** (vedi sotto). Build prova però **rotta** |
| 3. Flusso: l'ufficiale di Ben si unisce nel ramo prova, l'utente prova, poi merge in `main` | Concordato, in corso |
| 4. Contatore aggiornamenti legge la release ufficiale | Il codice lo fa già e funziona anche con release normale. **Non provato su un telefono** |

Conflitti di codice (14): chiusi 1, 2, 3 (`update.dart`, `update_distribution_io.dart`, `update_distribution_stub.dart`, tutti "tuo"). **Il prossimo è il 4: `app/test/update_test.dart`.** Dal 4 al 14 vanno letti uno per uno prima di parlarne. Dettagli in `CONFLITTI-FUSIONE.md`.

## Ordine di lavoro

1. Scoprire perché la build del ramo prova non compila (errore nel passo "Compila l'APK"). Il log non si scarica dall'ambiente della chat: `productionresultssa13.blob.core.windows.net` è bloccato. Serve che l'utente incolli le righe rosse della build, oppure che consenta il dominio nelle impostazioni di rete.
2. Riprendere i conflitti dal numero 4, confrontando con Ben solo ciò che serve, in italiano semplice e senza numeri di righe.
3. Quando la prova è senza conflitti e compila: l'utente la prova sul telefono, poi (solo con il suo ok) merge in `main`.
4. Web app: l'utente la vuole, ma **dopo** conflitti e build prova, così in caso di problemi si sa dove cercare. Niente è stato fatto.
5. Le novità di Ben arrivate dopo `f5efa6e5` (es. scorciatoia Ctrl/Cmd+Shift+X) si lasciano stare finché l'utente non dice altrimenti.

## Numeri build separati: cosa c'è nel workflow (`.github/workflows/build.yml`)

Ogni ramo conta da solo. Il numero è quello scritto nelle note della **propria** release (`<!-- app-build: N -->`) più 1. Non guarda mai l'altra release.

- `main`: tag `app-android-latest`, titolo `DartPDF #N - versione V`, marcata "Latest".
- `prova-sviluppatore`: tag `app-android-prova`, titolo `DartPDF Prova #Np - versione V`, mai "Latest".
- La "p" compare solo nel titolo e nelle note. Nell'APK il numero build è un intero (Android non accetta lettere), e il marcatore `app-build` resta intero.
- Se la release non ha il marcatore, si usa `github.run_number` come ripiego, così il numero non scende mai sotto lo storico.
- Una build fallita non consuma il numero: la successiva riprende lo stesso.
- Una build alla volta per ramo (`concurrency`), così due build non prendono lo stesso numero. Se arrivano più push mentre una build gira, GitHub tiene in coda solo l'ultimo: i commit intermedi possono non essere compilati.
- L'input `solo_contatore` ("build fittizia") non ha più effetto sul numero: il numero ora viene dalla release, non dal contatore di GitHub.

Valori al 2026-10-30: `app-android-latest` era a #78; `app-android-prova` a #67 (vecchia, ancora pre-release e con titolo vecchio). Alla prima build riuscita la prova diventa release normale `#68p`.

Codice applicato (estratti):

```yaml
# in testa al file
concurrency:
  group: build-${{ github.ref_name }}
  cancel-in-progress: false

env:
  ANDROID_TAG: ${{ github.ref_name == 'prova-sviluppatore' && 'app-android-prova' || 'app-android-latest' }}
  NUM_SUFFIX: ${{ github.ref_name == 'prova-sviluppatore' && 'p' || '' }}

# job "version", passo "Calcola versione e numero build" (env: GH_TOKEN: ${{ github.token }})
ultimo="$(gh api "repos/$GITHUB_REPOSITORY/releases/tags/$ANDROID_TAG" --jq '.body' 2>/dev/null | sed -n 's/.*<!-- app-build: \([0-9][0-9]*\) -->.*/\1/p' | head -n1 || true)"
if [[ -n "$ultimo" ]]; then number="$((ultimo + 1))"; else number="${{ github.run_number }}"; fi

# job "release": una sola release normale per canale
latest_flag="$([[ "$RELEASE_PREFIX" == build ]] && echo true || echo false)"
android_title="$APP_LABEL #${NUMERO}${NUM_SUFFIX} - versione ${VERSIONE}"
gh release edit "$android_tag" --repo "$GITHUB_REPOSITORY" --title "$android_title" \
  --notes "$android_notes" --prerelease=false --latest="$latest_flag"
```

## Come rivedere un conflitto (solo lettura)

```bash
git clone https://x-access-token:<TOKEN_DATO_DALL_UTENTE>@github.com/tesonepdf/dart-pdf.git
cd dart-pdf
git remote add upstream https://github.com/ben-milanko/dart-pdf.git   # pubblico
git fetch upstream main

B=3e0bd1b0c0e5b4ab336a8d584510a3a0e43e607a   # base della copia (11.0.0+48)
M=ebdf12bc                                    # main prima della fusione
U=f5efa6e5                                    # ufficiale unito (13.0.0+50)
F=app/test/update_test.dart                   # il file da guardare

git diff $B $M -- $F        # cosa ha cambiato l'utente
git diff $B $U -- $F        # cosa ha cambiato Ben
git show 396573c3:$F        # com'e' ora nella fusione (ramo prova-sviluppatore)
```

Per sapere se un file nella fusione è "tuo" o "ufficiale": confrontare `git rev-parse 396573c3:$F` con quello di `$M` e `$U`.

## Controlli rapidi sulle build (senza `gh`)

```bash
# ultime build e loro esito
curl -s -H "Authorization: Bearer <TOKEN>" \
  "https://api.github.com/repos/tesonepdf/dart-pdf/actions/runs?per_page=6" | python3 -c "
import sys,json
for r in json.load(sys.stdin)['workflow_runs']: print(r['run_number'],r['head_branch'],r['status'],r['conclusion'],r['head_sha'][:8])"

# quale passo e' fallito (annotazioni: il log completo e' bloccato dalla rete della chat)
curl -s -H "Authorization: Bearer <TOKEN>" \
  "https://api.github.com/repos/tesonepdf/dart-pdf/actions/runs/<RUN_ID>/jobs"
```

## Portare le modifiche tra i rami

```bash
# struttura (workflow, release, canali): si modifica su main, poi si porta nella prova
git checkout main && git push origin main
git checkout prova-sviluppatore && git merge --no-edit main && git push origin prova-sviluppatore

# a conflitti risolti e con l'ok dell'utente: prova -> main (merge vero, mai copia di file)
git checkout main && git merge prova-sviluppatore && git push origin main
```

Dopo il merge in `main`, `prova-sviluppatore` non si usa più: alla fusione dopo si riparte da `main` unendo `upstream/main`.

## Da non fare

- Non cancellare le release vecchie (`build-N`, `prova-N`) senza che l'utente lo chieda.
- Non scrivere il token in file, commit o risposte.
- Non usare popup con bottoni, non agire senza "ok", non fare resoconti lunghi.
