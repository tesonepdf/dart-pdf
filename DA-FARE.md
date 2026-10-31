# Da fare e codice: consegna alla prossima chat

Per l'assistente che riprende il lavoro. Leggere prima `CONFLITTI-FUSIONE.md` (regole dell'utente e stato dei conflitti). Aggiornato il 2026-10-30.

## Dove siamo

Piano a 4 punti (repo `tesonepdf/dart-pdf`, due rami paralleli):

| Punto | Stato |
|---|---|
| 1. Una sola release normale per canale, niente pre-release né build numerate | **Fatto** e pubblicato su `main` e `prova-sviluppatore` |
| 2. Canale prova separato, con numeri build propri (da 10001) | **Fatto nel workflow** (vedi sotto). Build prova però **rotta** |
| 3. Flusso: l'ufficiale di Ben si unisce nel ramo prova, l'utente prova, poi merge in `main` | Concordato, in corso |
| 4. Contatore aggiornamenti legge la release ufficiale | Il codice lo fa già e funziona anche con release normale. **Non provato su un telefono** |

Conflitti di codice (14): chiusi 1, 2, 3 (`update.dart`, `update_distribution_io.dart`, `update_distribution_stub.dart`, tutti "tuo") 4 e 5 (`update_test.dart`, `update_settings_test.dart`: restano i test dell'utente) 6 (`editor_screen.dart`: restano le funzioni dell'utente), 7 e 8 (`file_io.dart`, `web_file_picker.dart`: restano le tue) e 9 (`editing_overlay.dart`: restano le tue funzioni, frecce da tastiera tolte); **12 applicato** (menu dell'utente ripristinato, voci di Ben in "Da organizzare"), build da verificare. **Il prossimo è il 10: `app/lib/l10n/app_it.arb`** (testi italiani), solo se l'utente lo conferma. Stato dettagliato di ognuno in `CONFLITTI-FUSIONE.md`. Dal 4 al 14 vanno letti uno per uno prima di parlarne. Dettagli in `CONFLITTI-FUSIONE.md`.

## Ordine di lavoro

1. **Build prova rotta, causa trovata (log incollato dall'utente, build #80):** in `app/lib/app_menu_sheet.dart` righe 202 e 204 il codice usa `appItemCount`, che nel file della fusione non è definito (errore `The getter 'appItemCount' isn't defined for the type '_AppMenuSheetState'`). Nella versione dell'utente (`ebdf12bc`, riga 128) era una variabile locale di `_buildMain`: `final appItemCount = widget.app.length + (widget.readOnly == null ? 0 : 1);`. La fusione ha tenuto i due usi e perso la definizione (è il conflitto 12, file "misto"). Da sistemare con l'ok dell'utente, rileggendo il file con lui; possibili altri errori dopo questo, il log incollato mostrava solo la fine.
2. Riprendere i conflitti dal numero 4, confrontando con Ben solo ciò che serve, in italiano semplice e senza numeri di righe.
3. Quando la prova è senza conflitti e compila: l'utente la prova sul telefono, poi (solo con il suo ok) merge in `main`.
4. Web app: l'utente la vuole, ma **dopo** conflitti e build prova, così in caso di problemi si sa dove cercare. Niente è stato fatto.
5. Le novità di Ben arrivate dopo `f5efa6e5` (es. scorciatoia Ctrl/Cmd+Shift+X) si lasciano stare finché l'utente non dice altrimenti.

## Numeri build separati: cosa c'è nel workflow (`.github/workflows/build.yml`)

Ogni ramo conta da solo. Il numero è quello scritto nelle note della **propria** release (`<!-- app-build: N -->`) più 1. Non guarda mai l'altra release.

- `main`: tag `app-android-latest`, titolo `DartPDF #N - versione V`, marcata "Latest".
- `prova-sviluppatore`: tag `app-android-prova`, titolo `DartPDF Prova #N - versione V` (N parte da 10001, nessuna lettera), mai "Latest".
- **Nessuna "p"** (tolta su richiesta dell'utente): la prova si riconosce perché i suoi numeri sono da 10001 in su. Nell'APK il numero build è un intero e il marcatore `app-build` resta intero.
- Se la release non ha il marcatore, si usa `github.run_number` come ripiego, così il numero non scende mai sotto lo storico.
- Una build fallita non consuma il numero: la successiva riprende lo stesso.
- Una build alla volta per ramo (`concurrency`), così due build non prendono lo stesso numero. Se arrivano più push mentre una build gira, GitHub tiene in coda solo l'ultimo: i commit intermedi possono non essere compilati.
- L'input `solo_contatore` ("build fittizia") non ha più effetto sul numero: il numero ora viene dalla release, non dal contatore di GitHub.

Valori al 2026-10-30: `app-android-latest` a #79 (prossima #80). **La prova parte da 10001** (decisione dell'utente, per non confondersi mai con l'ufficiale): `NUM_BASE=10000` nel workflow, titolo `#10001`, poi 10002, 10003... La release `app-android-prova` è ancora la vecchia (#67, pre-release): alla prima build prova riuscita diventa release normale `#10001`.

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

## Funzioni nuove (non sono conflitti: da progettare con l'utente, si fanno direttamente su `main`)

### Foto a grandezza reale, e fronte/retro sullo stesso foglio (idea dell'utente, 2026-10-30)
Scopo: scansionare o fotografare documenti (carta d'identità fronte e retro) e averli in **un unico PDF a grandezza reale**, ritagliabili, copiabili e incollabili tra PDF o foto.
- Oggi (verificato nel codice): una foto aperta diventa un PDF di una pagina con larghezza A4 (`app/lib/image_to_pdf.dart`, `dpi = larghezza * 72 / 595,28`), quindi riempie il foglio. L'utente **non la vuole a tutta pagina**: deve essere sempre una porzione, a misura reale. Ritaglio immagini, inserimento da file o fotocamera e incolla dagli appunti esistono già; la scansione documenti dà PDF a 300 dpi (`doc_scan_io.dart`).
- Scansioni da stampante (foglio A4 intero con una o più foto): si può ricavare la misura dal ritaglio, perché il foglio ha dimensione nota.
- Foto del telefono: la misura reale non è nel file. Idea dell'utente: **misure standard già nel lettore** (carta di credito, carta d'identità, passaporto e altri documenti standard), poi misure personalizzate. Da decidere: elenco dei documenti, come si sceglie la misura, come si affiancano due foto sullo stesso foglio.
- Non fatto: niente codice. Da affrontare dopo i conflitti.

### Da controllare: apertura delle foto (promessa all'utente, 2026-10-30)
L'utente vuole pensarci con calma e, al limite, fare qualche prova **direttamente su `main`**. Per ora resta tutto com'è: la foto si apre come PDF (`image_to_pdf.dart`), la finestra Apri accetta PDF e foto (`file_io.dart`, `web_file_picker.dart`), il titolo prende ".pdf" (`editor_screen.dart`). Da rivedere insieme: se conviene aprirla come PDF di una pagina, a che misura, e come si collega alla funzione "foto a grandezza reale" qui sopra. Non farlo in autonomia: serve il suo ok.

### Casella di testo che si adatta da sola al testo (idea dell'utente, 2026-10-30; al posto di Alt+Z)
**Stato (2026-10-30): applicato su `main`, da provare sul telefono.** `_growBoxForNewLines` in `editing_overlay.dart` ora allarga la casella a destra (fino al bordo pagina) per la riga più lunga e la allunga per tutte le righe, comprese quelle che vanno a capo; cresce anche cambiando carattere o dimensione. Dopo la prova dell'utente (23:14): ora **segue il testo anche in riduzione**, senza scendere sotto la misura che aveva quando si è aperto l'editor (`_textEditBaseWidth`, `_textEditBaseHeight`). La riapertura con lo strumento Testo è stata **tolta su richiesta dell'utente**: lo strumento Testo (Inserisci) apre solo caselle nuove (`_openFreeTextAt` com'era). Con lo strumento Seleziona il secondo tocco sulla casella selezionata la riapriva già (`_tapEditsSelectedFreeText`), ma l'utente dice di non riuscirci: da verificare quale strumento usava. Alt+Z di Ben resta, perché restringe anche. Non verificato in compilazione né sul telefono; i test dell'editor non sono stati eseguiti.
Scopo: la casella si adatta **in automatico** al testo e alla grandezza del carattere, **senza Alt+Z**, su Windows e su Android. Se il carattere passa da 10 a 30 la casella cresce da sola; premendo Invio il testo va a capo e la casella si allarga.
- Base già scritta da Ben (commit `7025e617 2026-10-28 Make Alt+Z autosize a text box while its editor has focus (#1188)`): `PdfEditingController.autosizeSelectedTextBox` in `packages/dart_pdf_editor/lib/src/editing/editing_controller.dart` calcola la misura giusta. Alt+Z, in `editing_overlay.dart` (`_autosizeTextEdit`, flag `_textEditReopening`), salva il testo, chiama quella funzione e riapre l'editor sulla casella adattata.
- Idea: richiamare la stessa misura a ogni modifica (testo, Invio, cambio carattere) **senza chiudere e riaprire** l'editor. Poi togliere la scorciatoia Alt+Z. Il cambio carattere passa dal menu delle impostazioni carattere dell'utente: va collegato lì.
- Non verificato: se nella versione Android dell'utente la casella si allarga già con Invio (nel codice non ho trovato un ingrandimento automatico, ma non l'ho provato sul telefono).
- Da fare **dopo i conflitti**, direttamente su `main`, con prova sul telefono. Fino ad allora Alt+Z resta (non si toglie prima che l'automatico funzioni). Serve il suo ok per partire.

## Modifiche del 30/10 sera (richieste dall'utente)

- **Due workflow separati:** `build.yml` = build UFFICIALE, parte solo dai push su `main` ed e' anche richiamabile (`workflow_call`). `build-prova.yml` = build PROVA, parte solo dai push su `prova-sviluppatore` e richiama `build.yml` (`secrets: inherit`). Cosi' su GitHub gli elenchi e il contatore "#N" delle run sono separati. Il numero dell'app resta quello della release (`app-build`): ufficiale continua (#87...), prova da 10001. **Mai mettere `concurrency` con lo stesso gruppo nel workflow chiamante** (blocca la build).
- **Un solo numero:** titolo release `DartPDF #N` / `DartPDF Prova #N`; nell'app l'aggiornamento e le Informazioni mostrano solo `#N` (`ReleaseInfo.displayVersion`, `AppInfo.displayVersion`). Il numero di versione calcolato (6.303.xxxx) esiste ancora nell'APK e nel marcatore `app-version`, ma non si mostra piu'.
- **"Piu' tardi" e "Salta" valgono per quella versione** e restano memorizzati sul telefono anche dopo gli aggiornamenti dell'app. "Piu' tardi": niente piu' popup di quella versione, resta il banner. "Salta": niente popup e niente banner di quella versione. Una versione (build) successiva chiede di nuovo. (Una modifica del 30/10 sera li aveva resi validi per tutto il canale: **annullata** su richiesta dell'utente.)
- **Versione ufficiale di Ben gia' integrata:** in `official_update.dart` la versione di partenza e' ora **13.0.0+50** (commit `f5efa6e5`), cosi' l'app non la propone piu' come novita'. **Ad ogni nuova fusione con Ben aggiornare le tre costanti `upstreamBase*`.**
- **Riapertura dopo l'aggiornamento:** `UpdateRelaunchReceiver` (Kotlin + manifest) prova a riaprire l'app dopo la sostituzione. **Non verificato su telefono**: Android recente puo' bloccare l'avvio dall'background e in quel caso l'app va riaperta a mano.
- I test (`update_test.dart`, `update_settings_test.dart`) sono stati adeguati a mano, non eseguiti. Non c'e' un test per la nuova scelta valida su tutte le build.
- "Apri in Word": lavoro **interrotto** dall'utente prima di scrivere codice; da riprendere solo se lo richiede.

### Marcatore e ricerca (richiesta dell'utente, 2026-10-31)
- **Fatto su `main`, da provare sul telefono:** nel pannello dei risultati della ricerca c'è un nuovo pulsante (icona dell'evidenziatore) che apre la barra **Marca / Marca tutti**. Applica il marcatore armato (evidenzia, sottolinea, barrato, ondulato; evidenzia se nessuno è armato) al risultato corrente o a tutti i risultati, con colore e opacità del marcatore, in un solo passo di annullamento. Codice: `PdfEditingController.markMatchesWithMarkup` (`editing_controller.dart`) e `_MarkBar` (`search_panel.dart`). Testi in italiano e inglese scritti nel codice, senza chiavi di traduzione. I risultati dentro le annotazioni vengono saltati.
- **Non risolto: "il marcatore non funziona più".** Il codice del marcatore (`addMarkup`, `_applyArmedMarkup`, `_selectionLongPressEnabledAt`) non è cambiato con la fusione; nessuna riga relativa è stata toccata. La causa non è stata trovata: serve sapere quale marcatore (pennarello a mano libera o evidenzia testo), su che PDF (scansione senza testo o con testo) e cosa succede.
- Selezione dei risultati uno per uno (spunte): non c'è; oggi si marca il corrente o tutti.
