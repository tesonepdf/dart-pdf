# Da fare e da valutare

Unico file `.md` di lavoro del progetto (11/11/2026). Per l'assistente che riprende il lavoro: leggere prima `CONFLITTI-FUSIONE.md` (i paletti dell'utente, da non cambiare senza una sua richiesta esplicita). Le regole di lavoro stanno nel file dei riferimenti che l'utente allega a ogni chat.

Tre parti: **1. Da fare**, **2. Da valutare** (file di Ben da decidere uno alla volta) e **3. Da valutare: riferimenti allo sviluppatore** (inventario dei nomi da decidere).

## 1. DA FARE

Per l'assistente che riprende il lavoro. Leggere prima `CONFLITTI-FUSIONE.md` (regole dell'utente e stato dei conflitti). Aggiornato il 2026-11-06.

#### Aggiornamento 2026-11-06

- **Menu dell'app (da sistemare più avanti):** l'utente ha notato che il menu appare diverso quando non c'è un PDF aperto rispetto a quando il PDF è aperto. Non vuole che il menu cambi in base al documento aperto; per ora non modificare il comportamento, da riprendere su sua richiesta.
- **Novità di Ben sul ramo `prova-sviluppatore`:** confrontate con la base comune `f5efa6e5` e importate dal commit Ben `66601339`. I 288 cambiamenti non sovrapposti sono nel repository; le 78 versioni di Ben dei file sovrapposti sono in `DA-VALUTARE` e si esaminano una alla volta. Altri 5 percorsi avevano lo stesso esito da entrambe le parti. Non modificare `main`.

#### Aggiornamento 2026-11-05 (da #224)

**Fatto su `main`:**
- #220: Leggi ad alta voce (voce nel menu di selezione del testo, "Leggi la pagina", voce di sistema).
- #221: Impostazioni > Informazioni: esito dei test automatici (CI) della build installata.
- #222: OCR memorizzato per impronta del file (riapertura senza rifare la scansione), OCR in background su Android (servizio con notifica), voce "Apri originale senza OCR", riquadro dello stato della build nelle Informazioni.
- #223: test dell'OCR automatico corretti (la CI #222 era fallita per 3 test: la memoria OCR usava file veri nel finto servizio). Build e CI #223 riuscite.
- Rendering in background: funziona con un'altra app davanti. Con lo schermo spento non è stato provato: l'utente avvisa se vede il problema.

**Da fare (nuove richieste dell'utente):**
1. **Riassunto del documento**: voce nel menu "Riassumi documento". Serve un modello AI online (offline non verrebbe un buon riassunto). Da progettare con l'utente; serve il suo ok per partire.
2. **Foto incollate dalla galleria dentro il foglio PDF**: poter incollare/inserire una foto dalla galleria direttamente sulla pagina del PDF, come elemento sulla pagina.
3. **Foto incollate ridimensionabili**: selezionare la foto con lo strumento Seleziona e cambiarne la dimensione a piacere (maniglie o misura), senza che occupi tutta la pagina. Si collega a "Foto a grandezza reale" qui sotto.

**Limiti noti dell'OCR (da decidere se sistemarli):**
- la memoria OCR non è attiva nel browser (web): il codice c'è, nessuno la riempie;
- il testo OCR applicato conta come modifica non salvata;
- "Apri originale senza OCR" esiste solo per le schede dove l'OCR è stato applicato in questa sessione;
- il riquadro build usa l'API pubblica di GitHub (circa 60 richieste all'ora): con il limite raggiunto mostra "non disponibile";
- Android 15 limita i servizi `dataSync` a circa 6 ore.

Il resto della lista (conflitti con la versione di Ben, web app, foto a grandezza reale, apertura delle foto, casella di testo) è qui sotto e non è cambiato.

#### Dove siamo

Piano a 4 punti (repo `tesonepdf/dart-pdf`, due rami paralleli):

| Punto | Stato |
|---|---|
| 1. Una sola release normale per canale, niente pre-release né build numerate | **Fatto** e pubblicato su `main` e `prova-sviluppatore` |
| 2. Canale prova separato, con numeri build propri (da 10001) | **Fatto nel workflow** (vedi sotto). Build prova però **rotta** |
| 3. Flusso: l'ufficiale di Ben si unisce nel ramo prova, l'utente prova, poi merge in `main` | Concordato, in corso |
| 4. Contatore aggiornamenti legge la release ufficiale | Il codice lo fa già e funziona anche con release normale. **Non provato su un telefono** |

Conflitti di codice (14): chiusi 1, 2, 3 (`update.dart`, `update_distribution_io.dart`, `update_distribution_stub.dart`, tutti "tuo") 4 e 5 (`update_test.dart`, `update_settings_test.dart`: restano i test dell'utente) 6 (`editor_screen.dart`: restano le funzioni dell'utente), 7 e 8 (`file_io.dart`, `web_file_picker.dart`: restano le tue) e 9 (`editing_overlay.dart`: restano le tue funzioni, frecce da tastiera tolte); **12 applicato** (menu dell'utente ripristinato, voci di Ben in "Da organizzare"), build da verificare. **Il prossimo è il 10: `app/lib/l10n/app_it.arb`** (testi italiani), solo se l'utente lo conferma. Stato dettagliato di ognuno in `CONFLITTI-FUSIONE.md`. Dal 4 al 14 vanno letti uno per uno prima di parlarne. Dettagli in `CONFLITTI-FUSIONE.md`.

#### Ordine di lavoro

1. **Build prova rotta, causa trovata (log incollato dall'utente, build #80):** in `app/lib/app_menu_sheet.dart` righe 202 e 204 il codice usa `appItemCount`, che nel file della fusione non è definito (errore `The getter 'appItemCount' isn't defined for the type '_AppMenuSheetState'`). Nella versione dell'utente (`ebdf12bc`, riga 128) era una variabile locale di `_buildMain`: `final appItemCount = widget.app.length + (widget.readOnly == null ? 0 : 1);`. La fusione ha tenuto i due usi e perso la definizione (è il conflitto 12, file "misto"). Da sistemare con l'ok dell'utente, rileggendo il file con lui; possibili altri errori dopo questo, il log incollato mostrava solo la fine.
2. Riprendere i conflitti dal numero 4, confrontando con Ben solo ciò che serve, in italiano semplice e senza numeri di righe.
3. Quando la prova è senza conflitti e compila: l'utente la prova sul telefono, poi (solo con il suo ok) merge in `main`.
4. Web app: l'utente la vuole, ma **dopo** conflitti e build prova, così in caso di problemi si sa dove cercare. Niente è stato fatto.
5. Le novità di Ben arrivate dopo `f5efa6e5` (es. scorciatoia Ctrl/Cmd+Shift+X) si lasciano stare finché l'utente non dice altrimenti.

#### Numeri build separati: cosa c'è nel workflow (`.github/workflows/build.yml`)

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

#### Come rivedere un conflitto (solo lettura)

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

#### Controlli rapidi sulle build (senza `gh`)

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

#### Portare le modifiche tra i rami

```bash
# struttura (workflow, release, canali): si modifica su main, poi si porta nella prova
git checkout main && git push origin main
git checkout prova-sviluppatore && git merge --no-edit main && git push origin prova-sviluppatore

# a conflitti risolti e con l'ok dell'utente: prova -> main (merge vero, mai copia di file)
git checkout main && git merge prova-sviluppatore && git push origin main
```

Dopo il merge in `main`, `prova-sviluppatore` non si usa più: alla fusione dopo si riparte da `main` unendo `upstream/main`.

#### Da non fare

- Non cancellare le release vecchie (`build-N`, `prova-N`) senza che l'utente lo chieda.
- Non scrivere il token in file, commit o risposte.
- Non usare popup con bottoni, non agire senza "ok", non fare resoconti lunghi.

#### Funzioni nuove (non sono conflitti: da progettare con l'utente, si fanno direttamente su `main`)

##### Foto a grandezza reale, e fronte/retro sullo stesso foglio (idea dell'utente, 2026-10-30)
Scopo: scansionare o fotografare documenti (carta d'identità fronte e retro) e averli in **un unico PDF a grandezza reale**, ritagliabili, copiabili e incollabili tra PDF o foto.
- Oggi (verificato nel codice): una foto aperta diventa un PDF di una pagina con larghezza A4 (`app/lib/image_to_pdf.dart`, `dpi = larghezza * 72 / 595,28`), quindi riempie il foglio. L'utente **non la vuole a tutta pagina**: deve essere sempre una porzione, a misura reale. Ritaglio immagini, inserimento da file o fotocamera e incolla dagli appunti esistono già; la scansione documenti dà PDF a 300 dpi (`doc_scan_io.dart`).
- Scansioni da stampante (foglio A4 intero con una o più foto): si può ricavare la misura dal ritaglio, perché il foglio ha dimensione nota.
- Foto del telefono: la misura reale non è nel file. Idea dell'utente: **misure standard già nel lettore** (carta di credito, carta d'identità, passaporto e altri documenti standard), poi misure personalizzate. Da decidere: elenco dei documenti, come si sceglie la misura, come si affiancano due foto sullo stesso foglio.
- Non fatto: niente codice. Da affrontare dopo i conflitti.

##### Da controllare: apertura delle foto (promessa all'utente, 2026-10-30)
L'utente vuole pensarci con calma e, al limite, fare qualche prova **direttamente su `main`**. Per ora resta tutto com'è: la foto si apre come PDF (`image_to_pdf.dart`), la finestra Apri accetta PDF e foto (`file_io.dart`, `web_file_picker.dart`), il titolo prende ".pdf" (`editor_screen.dart`). Da rivedere insieme: se conviene aprirla come PDF di una pagina, a che misura, e come si collega alla funzione "foto a grandezza reale" qui sopra. Non farlo in autonomia: serve il suo ok.

##### Casella di testo che si adatta da sola al testo (idea dell'utente, 2026-10-30; al posto di Alt+Z)
**Stato (2026-10-30): applicato su `main`, da provare sul telefono.** `_growBoxForNewLines` in `editing_overlay.dart` ora allarga la casella a destra (fino al bordo pagina) per la riga più lunga e la allunga per tutte le righe, comprese quelle che vanno a capo; cresce anche cambiando carattere o dimensione. Dopo la prova dell'utente (23:14): ora **segue il testo anche in riduzione**, senza scendere sotto la misura che aveva quando si è aperto l'editor (`_textEditBaseWidth`, `_textEditBaseHeight`). La riapertura con lo strumento Testo è stata **tolta su richiesta dell'utente**: lo strumento Testo (Inserisci) apre solo caselle nuove (`_openFreeTextAt` com'era). Con lo strumento Seleziona il secondo tocco sulla casella selezionata la riapriva già (`_tapEditsSelectedFreeText`), ma l'utente dice di non riuscirci: da verificare quale strumento usava. Alt+Z di Ben resta, perché restringe anche. Non verificato in compilazione né sul telefono; i test dell'editor non sono stati eseguiti.
Scopo: la casella si adatta **in automatico** al testo e alla grandezza del carattere, **senza Alt+Z**, su Windows e su Android. Se il carattere passa da 10 a 30 la casella cresce da sola; premendo Invio il testo va a capo e la casella si allarga.
- Base già scritta da Ben (commit `7025e617 2026-10-28 Make Alt+Z autosize a text box while its editor has focus (#1188)`): `PdfEditingController.autosizeSelectedTextBox` in `packages/dart_pdf_editor/lib/src/editing/editing_controller.dart` calcola la misura giusta. Alt+Z, in `editing_overlay.dart` (`_autosizeTextEdit`, flag `_textEditReopening`), salva il testo, chiama quella funzione e riapre l'editor sulla casella adattata.
- Idea: richiamare la stessa misura a ogni modifica (testo, Invio, cambio carattere) **senza chiudere e riaprire** l'editor. Poi togliere la scorciatoia Alt+Z. Il cambio carattere passa dal menu delle impostazioni carattere dell'utente: va collegato lì.
- Non verificato: se nella versione Android dell'utente la casella si allarga già con Invio (nel codice non ho trovato un ingrandimento automatico, ma non l'ho provato sul telefono).
- Da fare **dopo i conflitti**, direttamente su `main`, con prova sul telefono. Fino ad allora Alt+Z resta (non si toglie prima che l'automatico funzioni). Serve il suo ok per partire.

#### Modifiche del 30/10 sera (richieste dall'utente)

- **Due workflow separati:** `build.yml` = build UFFICIALE, parte solo dai push su `main` ed e' anche richiamabile (`workflow_call`). `build-prova.yml` = build PROVA, parte solo dai push su `prova-sviluppatore` e richiama `build.yml` (`secrets: inherit`). Cosi' su GitHub gli elenchi e il contatore "#N" delle run sono separati. Il numero dell'app resta quello della release (`app-build`): ufficiale continua (#87...), prova da 10001. **Mai mettere `concurrency` con lo stesso gruppo nel workflow chiamante** (blocca la build).
- **Un solo numero:** titolo release `DartPDF #N` / `DartPDF Prova #N`; nell'app l'aggiornamento e le Informazioni mostrano solo `#N` (`ReleaseInfo.displayVersion`, `AppInfo.displayVersion`). Il numero di versione calcolato (6.303.xxxx) esiste ancora nell'APK e nel marcatore `app-version`, ma non si mostra piu'.
- **"Piu' tardi" e "Salta" valgono per quella versione** e restano memorizzati sul telefono anche dopo gli aggiornamenti dell'app. "Piu' tardi": niente piu' popup di quella versione, resta il banner. "Salta": niente popup e niente banner di quella versione. Una versione (build) successiva chiede di nuovo. (Una modifica del 30/10 sera li aveva resi validi per tutto il canale: **annullata** su richiesta dell'utente.)
- **Versione ufficiale di Ben gia' integrata:** in `official_update.dart` la versione di partenza e' ora **13.0.0+50** (commit `f5efa6e5`), cosi' l'app non la propone piu' come novita'. **Ad ogni nuova fusione con Ben aggiornare le tre costanti `upstreamBase*`.**
- **Riapertura dopo l'aggiornamento:** `UpdateRelaunchReceiver` (Kotlin + manifest) prova a riaprire l'app dopo la sostituzione. **Non verificato su telefono**: Android recente puo' bloccare l'avvio dall'background e in quel caso l'app va riaperta a mano.
- I test (`update_test.dart`, `update_settings_test.dart`) sono stati adeguati a mano, non eseguiti. Non c'e' un test per la nuova scelta valida su tutte le build.
- "Apri in Word": lavoro **interrotto** dall'utente prima di scrivere codice; da riprendere solo se lo richiede.

##### Marcatore e ricerca (richiesta dell'utente, 2026-10-31)
- **Fatto su `main`, da provare sul telefono:** nel pannello dei risultati della ricerca c'è un nuovo pulsante (icona dell'evidenziatore) che apre la barra **Marca / Marca tutti**. Applica il marcatore armato (evidenzia, sottolinea, barrato, ondulato; evidenzia se nessuno è armato) al risultato corrente o a tutti i risultati, con colore e opacità del marcatore, in un solo passo di annullamento. Codice: `PdfEditingController.markMatchesWithMarkup` (`editing_controller.dart`) e `_MarkBar` (`search_panel.dart`). Testi in italiano e inglese scritti nel codice, senza chiavi di traduzione. I risultati dentro le annotazioni vengono saltati.
- **Marcatore sul telefono (2026-10-31, dopo la prova dell'utente):** il marcatore sul testo non funzionava col dito perché il tocco scorre sempre il foglio, il doppio tocco fa zoom e la pressione lunga apre il menu della pagina. Con un marcatore armato: (1) un **trascinamento col dito che parte da una parola** segna il testo sotto il dito e **non scorre più** il foglio (`_TouchMarkupDragRecognizer` in `pdf_viewer.dart`, attivo solo se la pressione cade su testo; fuori dal testo il foglio scorre come prima); (2) un **doppio tocco su una parola** la marca (`_markWordOnDoubleTap`, dai tempi dei puntatori, come il doppio clic del mouse). Compromesso: finché il marcatore è armato, il dito su una parola non scorre il foglio; si scorre dai margini, con due dita o disarmando il marcatore. Da provare sul telefono. **Se il PDF è una scansione senza livello di testo non c'è niente da selezionare e tutto resta come prima**: serve prima l'OCR.
- **Non risolto: "il marcatore non funziona più" come regressione.** Il codice del marcatore (`addMarkup`, `_applyArmedMarkup`, `_selectionLongPressEnabledAt`) non è cambiato con la fusione; nessuna riga relativa è stata toccata. La causa non è stata trovata: serve sapere quale marcatore (pennarello a mano libera o evidenzia testo), su che PDF (scansione senza testo o con testo) e cosa succede.
- Selezione dei risultati uno per uno (spunte): non c'è; oggi si marca il corrente o tutti.

- **Marcatore col dito rifatto (2026-10-31, richiesta dell'utente):** con un marcatore armato, il dito che striscia colora sempre sotto il dito (`_TouchMarkupDragRecognizer`, si prende il gesto dopo 5 pixel): se parte da una parola si aggancia alle parole, altrimenti (scansioni, margini) disegna un tratto libero (`PdfEditingController.addMarkupStroke`, un'annotazione a mano libera, un solo annulla). Due dita allargano e stringono (zoom); se la seconda dita arriva a tratto iniziato, il tratto viene scartato. Il doppio tocco su una parola marca solo quella parola. Stesso comportamento prima e dopo lo zoom. Non compilato qui (Flutter assente), da provare sul telefono.

- **Marcatore col dito semplificato (2026-10-31):** tolto l'aggancio alle parole nella striscia: il dito colora sempre sotto il dito (tratto libero). Il doppio tocco su una parola marca la parola.
- **Marcatore, secondo giro (2026-10-31):** la striscia segue sempre il dito; sopra una parola si raddrizza sulla riga del testo (`_snapMarkPoint`); se non trova testo e il tratto è quasi orizzontale, si raddrizza alla fine. Con un marcatore armato il doppio tocco non fa più zoom (`_onDoubleTap`) e marca tutta la parola. Non compilato qui, da provare.
- **Marcatore, terzo giro (2026-10-31):** lo spessore del tratto si sceglie dal cursore "spessore" nel menu del marcatore (fino a 40 pt, parte da 12, ricordato insieme a colore e opacità: scope `markup`, `strokeWidth`). Ogni tratto diventa una linea dritta (orizzontale sulla riga del testo se passa su parole, verticale se il dito va in verticale): `_straightMark` in `pdf_viewer.dart`, anche nell'anteprima. `beginStyleScope` ora aggiunge i valori di partenza mancanti anche a una scope già esistente. Non compilato qui, da provare.
- **Marcatore: memoria dell'ultima scelta (2026-10-31):** colore, trasparenza e spessore del marcatore si salvano appena cambiano (chiavi `markerColor`, `markerOpacity`, `markerStrokeWidth` in `editing_preferences.dart`) e si rimettono ogni volta che il marcatore viene armato, anche dopo aver riaperto l'app. Non compilato qui, da provare.
- **Strumento Selezione non sposta la pagina (2026-10-31):** in `editing_overlay.dart` (`_panStart`) un trascinamento col dito su pagina vuota con Selezione disegna il rettangolo di selezione invece di scorrere il foglio; per muovere il foglio c'è lo strumento Mano (e le due dita). Non compilato qui, da provare.
- **Marcatore sotto il dito (2026-10-31, dopo prova con zoom forte):** i tratti finivano più in basso del dito perché si agganciavano alla riga del testo nascosto (OCR), che nella scansione è spostato rispetto alle lettere. Tolto l'aggancio (`_snapMarkPoint` ora restituisce il punto del dito): il tratto sta dove tocchi, dritto. Il doppio tocco marca la parola per tutta la sua lunghezza (larghezza dal testo) all'altezza del dito. Non compilato qui, da provare.
- **Controllo aggiornamenti: "Impossibile verificare" (2026-10-31):** causa probabile = limite di richieste dell'API GitHub senza accesso (HTTP 403). La build ora carica nella release il file `release-info.json` (copia delle informazioni della release); l'app lo scarica per primo (`_fetchFromGitHub` in `app/lib/update.dart`, nessun limite) e usa l'API solo se manca. L'elenco di tutte le release non blocca più il controllo su Android. Il file esiste dalla prima build dopo questa modifica: quella va installata una volta a mano. Non verificato su telefono (causa non confermata dal log).


## 2. DA VALUTARE

- Base del confronto: `f5efa6e5` (`f5efa6e525494b24c0ab2049916d1dbe8546a94c`).
- Ramo `prova-sviluppatore` prima dell'import: `60f12a79b4c98c0e4957a4139f9f1406cf215bf7`.
- `ben-milanko/dart-pdf` (`main`): `666013391e8d640c2d7be410eb1e6e861d5ed70d`.
- La classificazione confronta i cambiamenti rispetto alla base storica. Il ramo prova attuale non condivide direttamente la cronologia Git con il ramo Ben; i file qui copiati sono copie di confronto, non versioni attive.
- Il codice attivo nel repository non e' stato cambiato per questi file. Le versioni proposte da Ben sono sotto `DA-VALUTARE/ben/`, mantenendo il percorso originale.

Importati direttamente nel repository: 288 cambiamenti non sovrapposti. Altri 5 percorsi avevano gia' lo stesso esito da entrambe le parti.
File da decidere: 72. (Le 6 copie `.md` di Ben sono state tolte l'11/11 su richiesta dell'utente: erano solo documentazione.)

| Da valutare | Stato su prova rispetto alla base | Stato Ben rispetto alla base | Copia Ben |
|---|---|---|---|
| `.github/workflows/android-incoming.yml` | eliminato | modificato | [`ben/.github/workflows/android-incoming.yml`](<DA-VALUTARE/ben/.github/workflows/android-incoming.yml>) |
| `.github/workflows/nightly-desktop.yml` | eliminato | modificato | [`ben/.github/workflows/nightly-desktop.yml`](<DA-VALUTARE/ben/.github/workflows/nightly-desktop.yml>) |
| `.github/workflows/storeflight.yml` | eliminato | modificato | [`ben/.github/workflows/storeflight.yml`](<DA-VALUTARE/ben/.github/workflows/storeflight.yml>) |
| `.gitignore` | modificato | modificato | [`ben/.gitignore`](<DA-VALUTARE/ben/.gitignore>) |
| `.vscode/settings.json` | eliminato | modificato | [`ben/.vscode/settings.json`](<DA-VALUTARE/ben/.vscode/settings.json>) |
| `app/lib/document_tab.dart` | modificato | modificato | [`ben/app/lib/document_tab.dart`](<DA-VALUTARE/ben/app/lib/document_tab.dart>) |
| `app/lib/editor_screen.dart` | modificato | modificato | [`ben/app/lib/editor_screen.dart`](<DA-VALUTARE/ben/app/lib/editor_screen.dart>) |
| `app/lib/file_io.dart` | modificato | modificato | [`ben/app/lib/file_io.dart`](<DA-VALUTARE/ben/app/lib/file_io.dart>) |
| `app/lib/l10n/app_it.arb` | modificato | modificato | [`ben/app/lib/l10n/app_it.arb`](<DA-VALUTARE/ben/app/lib/l10n/app_it.arb>) |
| `app/lib/l10n/app_localizations_it.dart` | modificato | modificato | [`ben/app/lib/l10n/app_localizations_it.dart`](<DA-VALUTARE/ben/app/lib/l10n/app_localizations_it.dart>) |
| `app/lib/ocr_native.dart` | modificato | modificato | [`ben/app/lib/ocr_native.dart`](<DA-VALUTARE/ben/app/lib/ocr_native.dart>) |
| `app/lib/ocr_stub.dart` | modificato | modificato | [`ben/app/lib/ocr_stub.dart`](<DA-VALUTARE/ben/app/lib/ocr_stub.dart>) |
| `app/lib/ocr_web.dart` | modificato | modificato | [`ben/app/lib/ocr_web.dart`](<DA-VALUTARE/ben/app/lib/ocr_web.dart>) |
| `app/lib/recents.dart` | modificato | modificato | [`ben/app/lib/recents.dart`](<DA-VALUTARE/ben/app/lib/recents.dart>) |
| `app/lib/session_store.dart` | modificato | modificato | [`ben/app/lib/session_store.dart`](<DA-VALUTARE/ben/app/lib/session_store.dart>) |
| `app/lib/welcome_screen.dart` | modificato | modificato | [`ben/app/lib/welcome_screen.dart`](<DA-VALUTARE/ben/app/lib/welcome_screen.dart>) |
| `app/pubspec.yaml` | modificato | modificato | [`ben/app/pubspec.yaml`](<DA-VALUTARE/ben/app/pubspec.yaml>) |
| `app/test/form_data_exchange_menu_test.dart` | modificato | modificato | [`ben/app/test/form_data_exchange_menu_test.dart`](<DA-VALUTARE/ben/app/test/form_data_exchange_menu_test.dart>) |
| `app/test/keyboard_availability_test.dart` | modificato | modificato | [`ben/app/test/keyboard_availability_test.dart`](<DA-VALUTARE/ben/app/test/keyboard_availability_test.dart>) |
| `app/test/ocr_auto_test.dart` | modificato | modificato | [`ben/app/test/ocr_auto_test.dart`](<DA-VALUTARE/ben/app/test/ocr_auto_test.dart>) |
| `app/test/progressive_open_test.dart` | modificato | modificato | [`ben/app/test/progressive_open_test.dart`](<DA-VALUTARE/ben/app/test/progressive_open_test.dart>) |
| `app/test/settings_menu_test.dart` | modificato | modificato | [`ben/app/test/settings_menu_test.dart`](<DA-VALUTARE/ben/app/test/settings_menu_test.dart>) |
| `packages/dart_pdf_cli/pubspec.yaml` | modificato | modificato | [`ben/packages/dart_pdf_cli/pubspec.yaml`](<DA-VALUTARE/ben/packages/dart_pdf_cli/pubspec.yaml>) |
| `packages/dart_pdf_editor/lib/l10n/dart_pdf_editor_it.arb` | modificato | modificato | [`ben/packages/dart_pdf_editor/lib/l10n/dart_pdf_editor_it.arb`](<DA-VALUTARE/ben/packages/dart_pdf_editor/lib/l10n/dart_pdf_editor_it.arb>) |
| `packages/dart_pdf_editor/lib/l10n/dart_pdf_editor_localizations_it.dart` | modificato | modificato | [`ben/packages/dart_pdf_editor/lib/l10n/dart_pdf_editor_localizations_it.dart`](<DA-VALUTARE/ben/packages/dart_pdf_editor/lib/l10n/dart_pdf_editor_localizations_it.dart>) |
| `packages/dart_pdf_editor/lib/src/design/editor_presenter.dart` | modificato | modificato | [`ben/packages/dart_pdf_editor/lib/src/design/editor_presenter.dart`](<DA-VALUTARE/ben/packages/dart_pdf_editor/lib/src/design/editor_presenter.dart>) |
| `packages/dart_pdf_editor/lib/src/design/material_host.dart` | modificato | modificato | [`ben/packages/dart_pdf_editor/lib/src/design/material_host.dart`](<DA-VALUTARE/ben/packages/dart_pdf_editor/lib/src/design/material_host.dart>) |
| `packages/dart_pdf_editor/lib/src/design/material_presenter.dart` | modificato | modificato | [`ben/packages/dart_pdf_editor/lib/src/design/material_presenter.dart`](<DA-VALUTARE/ben/packages/dart_pdf_editor/lib/src/design/material_presenter.dart>) |
| `packages/dart_pdf_editor/lib/src/editing/editing_controller.dart` | modificato | modificato | [`ben/packages/dart_pdf_editor/lib/src/editing/editing_controller.dart`](<DA-VALUTARE/ben/packages/dart_pdf_editor/lib/src/editing/editing_controller.dart>) |
| `packages/dart_pdf_editor/lib/src/editing/editing_overlay.dart` | modificato | modificato | [`ben/packages/dart_pdf_editor/lib/src/editing/editing_overlay.dart`](<DA-VALUTARE/ben/packages/dart_pdf_editor/lib/src/editing/editing_overlay.dart>) |
| `packages/dart_pdf_editor/lib/src/editing/editing_preferences.dart` | modificato | modificato | [`ben/packages/dart_pdf_editor/lib/src/editing/editing_preferences.dart`](<DA-VALUTARE/ben/packages/dart_pdf_editor/lib/src/editing/editing_preferences.dart>) |
| `packages/dart_pdf_editor/lib/src/editing/editing_thumbnails.dart` | modificato | modificato | [`ben/packages/dart_pdf_editor/lib/src/editing/editing_thumbnails.dart`](<DA-VALUTARE/ben/packages/dart_pdf_editor/lib/src/editing/editing_thumbnails.dart>) |
| `packages/dart_pdf_editor/lib/src/editing/editing_toolbar.dart` | modificato | modificato | [`ben/packages/dart_pdf_editor/lib/src/editing/editing_toolbar.dart`](<DA-VALUTARE/ben/packages/dart_pdf_editor/lib/src/editing/editing_toolbar.dart>) |
| `packages/dart_pdf_editor/lib/src/editing/editor_commands.dart` | modificato | modificato | [`ben/packages/dart_pdf_editor/lib/src/editing/editor_commands.dart`](<DA-VALUTARE/ben/packages/dart_pdf_editor/lib/src/editing/editor_commands.dart>) |
| `packages/dart_pdf_editor/lib/src/pdf_editor_view.dart` | modificato | modificato | [`ben/packages/dart_pdf_editor/lib/src/pdf_editor_view.dart`](<DA-VALUTARE/ben/packages/dart_pdf_editor/lib/src/pdf_editor_view.dart>) |
| `packages/dart_pdf_editor/lib/src/pdf_reader.dart` | modificato | modificato | [`ben/packages/dart_pdf_editor/lib/src/pdf_reader.dart`](<DA-VALUTARE/ben/packages/dart_pdf_editor/lib/src/pdf_reader.dart>) |
| `packages/dart_pdf_editor/lib/src/pdf_viewer.dart` | modificato | modificato | [`ben/packages/dart_pdf_editor/lib/src/pdf_viewer.dart`](<DA-VALUTARE/ben/packages/dart_pdf_editor/lib/src/pdf_viewer.dart>) |
| `packages/dart_pdf_editor/lib/src/shell_chrome.dart` | modificato | modificato | [`ben/packages/dart_pdf_editor/lib/src/shell_chrome.dart`](<DA-VALUTARE/ben/packages/dart_pdf_editor/lib/src/shell_chrome.dart>) |
| `packages/dart_pdf_editor/pubspec.yaml` | modificato | modificato | [`ben/packages/dart_pdf_editor/pubspec.yaml`](<DA-VALUTARE/ben/packages/dart_pdf_editor/pubspec.yaml>) |
| `packages/dart_pdf_editor_assets/pubspec.yaml` | modificato | modificato | [`ben/packages/dart_pdf_editor_assets/pubspec.yaml`](<DA-VALUTARE/ben/packages/dart_pdf_editor_assets/pubspec.yaml>) |
| `packages/dart_pdf_editor_flutter_gpu/pubspec.yaml` | modificato | modificato | [`ben/packages/dart_pdf_editor_flutter_gpu/pubspec.yaml`](<DA-VALUTARE/ben/packages/dart_pdf_editor_flutter_gpu/pubspec.yaml>) |
| `packages/dart_pdf_printing/pubspec.yaml` | modificato | modificato | [`ben/packages/dart_pdf_printing/pubspec.yaml`](<DA-VALUTARE/ben/packages/dart_pdf_printing/pubspec.yaml>) |
| `packages/pdf_cos/pubspec.yaml` | modificato | modificato | [`ben/packages/pdf_cos/pubspec.yaml`](<DA-VALUTARE/ben/packages/pdf_cos/pubspec.yaml>) |
| `packages/pdf_document/lib/src/editor.dart` | modificato | modificato | [`ben/packages/pdf_document/lib/src/editor.dart`](<DA-VALUTARE/ben/packages/pdf_document/lib/src/editor.dart>) |
| `packages/pdf_document/pubspec.yaml` | modificato | modificato | [`ben/packages/pdf_document/pubspec.yaml`](<DA-VALUTARE/ben/packages/pdf_document/pubspec.yaml>) |
| `packages/pdf_graphics/pubspec.yaml` | modificato | modificato | [`ben/packages/pdf_graphics/pubspec.yaml`](<DA-VALUTARE/ben/packages/pdf_graphics/pubspec.yaml>) |
| `packages/pdf_ocr_ondevice/pubspec.yaml` | modificato | modificato | [`ben/packages/pdf_ocr_ondevice/pubspec.yaml`](<DA-VALUTARE/ben/packages/pdf_ocr_ondevice/pubspec.yaml>) |
| `packages/pdf_ocr_vlm/pubspec.yaml` | modificato | modificato | [`ben/packages/pdf_ocr_vlm/pubspec.yaml`](<DA-VALUTARE/ben/packages/pdf_ocr_vlm/pubspec.yaml>) |
| `packages/pdf_test_fixtures/pubspec.yaml` | modificato | modificato | [`ben/packages/pdf_test_fixtures/pubspec.yaml`](<DA-VALUTARE/ben/packages/pdf_test_fixtures/pubspec.yaml>) |
| `site/guides/pdf-forms-and-signatures.html` | eliminato | modificato | [`ben/site/guides/pdf-forms-and-signatures.html`](<DA-VALUTARE/ben/site/guides/pdf-forms-and-signatures.html>) |
| `site/i18n/ar.json` | eliminato | modificato | [`ben/site/i18n/ar.json`](<DA-VALUTARE/ben/site/i18n/ar.json>) |
| `site/i18n/de.json` | eliminato | modificato | [`ben/site/i18n/de.json`](<DA-VALUTARE/ben/site/i18n/de.json>) |
| `site/i18n/en.json` | eliminato | modificato | [`ben/site/i18n/en.json`](<DA-VALUTARE/ben/site/i18n/en.json>) |
| `site/i18n/es.json` | eliminato | modificato | [`ben/site/i18n/es.json`](<DA-VALUTARE/ben/site/i18n/es.json>) |
| `site/i18n/fr.json` | eliminato | modificato | [`ben/site/i18n/fr.json`](<DA-VALUTARE/ben/site/i18n/fr.json>) |
| `site/i18n/hi.json` | eliminato | modificato | [`ben/site/i18n/hi.json`](<DA-VALUTARE/ben/site/i18n/hi.json>) |
| `site/i18n/id.json` | eliminato | modificato | [`ben/site/i18n/id.json`](<DA-VALUTARE/ben/site/i18n/id.json>) |
| `site/i18n/it.json` | eliminato | modificato | [`ben/site/i18n/it.json`](<DA-VALUTARE/ben/site/i18n/it.json>) |
| `site/i18n/ja.json` | eliminato | modificato | [`ben/site/i18n/ja.json`](<DA-VALUTARE/ben/site/i18n/ja.json>) |
| `site/i18n/ko.json` | eliminato | modificato | [`ben/site/i18n/ko.json`](<DA-VALUTARE/ben/site/i18n/ko.json>) |
| `site/i18n/nl.json` | eliminato | modificato | [`ben/site/i18n/nl.json`](<DA-VALUTARE/ben/site/i18n/nl.json>) |
| `site/i18n/pl.json` | eliminato | modificato | [`ben/site/i18n/pl.json`](<DA-VALUTARE/ben/site/i18n/pl.json>) |
| `site/i18n/pt.json` | eliminato | modificato | [`ben/site/i18n/pt.json`](<DA-VALUTARE/ben/site/i18n/pt.json>) |
| `site/i18n/ru.json` | eliminato | modificato | [`ben/site/i18n/ru.json`](<DA-VALUTARE/ben/site/i18n/ru.json>) |
| `site/i18n/th.json` | eliminato | modificato | [`ben/site/i18n/th.json`](<DA-VALUTARE/ben/site/i18n/th.json>) |
| `site/i18n/tr.json` | eliminato | modificato | [`ben/site/i18n/tr.json`](<DA-VALUTARE/ben/site/i18n/tr.json>) |
| `site/i18n/uk.json` | eliminato | modificato | [`ben/site/i18n/uk.json`](<DA-VALUTARE/ben/site/i18n/uk.json>) |
| `site/i18n/vi.json` | eliminato | modificato | [`ben/site/i18n/vi.json`](<DA-VALUTARE/ben/site/i18n/vi.json>) |
| `site/i18n/zh-Hant.json` | eliminato | modificato | [`ben/site/i18n/zh-Hant.json`](<DA-VALUTARE/ben/site/i18n/zh-Hant.json>) |
| `site/i18n/zh.json` | eliminato | modificato | [`ben/site/i18n/zh.json`](<DA-VALUTARE/ben/site/i18n/zh.json>) |
| `site/index.html` | eliminato | modificato | [`ben/site/index.html`](<DA-VALUTARE/ben/site/index.html>) |
| `site/sitemap.xml` | eliminato | modificato | [`ben/site/sitemap.xml`](<DA-VALUTARE/ben/site/sitemap.xml>) |


## 3. DA VALUTARE: riferimenti allo sviluppatore

Inventario delle occorrenze di `milanko` e `ocr-models` nel progetto copiato. I percorsi sono relativi alla radice.

#### Occorrenze
README.md:1:Copia modificata di dart-pdf (https://github.com/ben-milanko/dart-pdf), licenza Apache 2.0.
UPSTREAM.md:3:- Progetto originale: https://github.com/ben-milanko/dart-pdf
UPSTREAM.md:7:Base della copia. Per vedere le novità: https://github.com/ben-milanko/dart-pdf/compare/3e0bd1b0c0e5b4ab336a8d584510a3a0e43e607a...main
packages\pdf_test_fixtures\README.md:5:[![CI](https://github.com/ben-milanko/dart-pdf/actions/workflows/ci.yml/badge.svg)](https://github.com/ben-milanko/dart-pdf/actions/workflows/ci.yml)
packages\pdf_test_fixtures\README.md:6:[![License: Apache-2.0](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](https://github.com/ben-milanko/dart-pdf/blob/main/LICENSE)
packages\pdf_test_fixtures\README.md:9:the [dart-pdf suite](https://github.com/ben-milanko/dart-pdf)'s test
app\windows\runner\windows_drop.cpp:19:    "dev.milanko.dartpdf/windows_drop";
tool\test_print_plugin.sh:16:  --org dev.milanko --platforms "$print_platform" --no-pub "$print_host_dir"
app\windows\runner\Runner.rc:95:            VALUE "CompanyName", "dev.milanko" "\0"
app\windows\runner\Runner.rc:99:            VALUE "LegalCopyright", "Copyright (C) 2026 dev.milanko. All rights reserved." "\0"
packages\pdf_ocr_vlm\README.md:3:[![License: Apache-2.0](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](https://github.com/ben-milanko/dart-pdf/blob/main/LICENSE)
packages\pdf_ocr_vlm\README.md:6:[dart-pdf suite](https://github.com/ben-milanko/dart-pdf). It adds an
app\windows\runner\platform_channels.cpp:20:constexpr char kIncomingChannelName[] = "dev.milanko.dartpdf/incoming";
app\windows\runner\platform_channels.cpp:22:    "dev.milanko.dartpdf/image_clipboard";
app\windows\runner\platform_channels.cpp:23:constexpr char kMemoryChannelName[] = "dev.milanko.dartpdf/memory";
app\windows\runner\platform_channels.cpp:28:    "dev.milanko.dartpdf/window_geometry";
app\windows\runner\platform_channels.cpp:30:    "dev.milanko.dartpdf/file_dialogs";
app\windows\runner\platform_channels.cpp:32:    "dev.milanko.dartpdf/file_access";
app\windows\runner\platform_channels.cpp:34:    "dev.milanko.dartpdf/trackpad_signature";
app\windows\runner\platform_channels.cpp:36:    "dev.milanko.dartpdf/trackpad_signature_support";
app\windows\runner\main.cpp:25:    L"dev.milanko.dartpdf.SingleInstance";
tool\storeflight\verify-flatpak-install.sh:14:flatpak_id="${FLATPAK_ID:-dev.milanko.dartpdf}"
app\windows\runner\image_clipboard.h:10:// Native side of the `dev.milanko.dartpdf/image_clipboard` method channel.
tool\stage_linux_appdir.py:18:APP_ID = "dev.milanko.dartpdf"
packages\pdf_ocr_ondevice\test\accuracy\ocr_accuracy_test.dart:4:// directory holding the ocr-models-v1 files (PP-OCRv5_mobile_det.onnx,
tool\smoke_test_linux_gui.sh:11:2. A GTK window titled "DartPDF" or matching class "dev.milanko.dartpdf" is mapped and created.
tool\smoke_test_linux_gui.sh:67:    if xwininfo -display "$DISPLAY" -root -tree 2>/dev/null | grep -iE "DartPDF|dev\.milanko\.dartpdf" >/dev/null 2>&1; then
packages\pdf_ocr_ondevice\README.md:156:`ocr-models-v1` release carried the full `LICENSE.txt` and `NOTICE.txt`; both
tool\site\test_download_links.py:44:            "android": "https://play.google.com/store/apps/details?id=dev.milanko.dartpdf",
tool\site\test_download_links.py:74:                            "https://github.com/ben-milanko/dart-pdf/releases/latest"
packages\pdf_ocr_ondevice\assets\ocr\NOTICE.txt:1:DartPDF on-device OCR model bundle (ocr-models-v1)
packages\pdf_ocr_ondevice\assets\ocr\NOTICE.txt:5:package (https://github.com/ben-milanko/dart-pdf). They are DERIVED WORKS of
tool\run_ios_patrol_ci.sh:23:bundle_id=dev.milanko.pdfViewerExample
packages\pdf_document\test\content_edit_spacing_test.dart:22:            'BT /F1 12 Tf 2 Tc 5 Tw 75 Tz 72 700 Td [(Ben ) -25 (Milanko)] TJ ET'));
packages\pdf_document\test\content_edit_spacing_test.dart:43:          buildType0Pdf('Ben Milanko', bytes, textState: '2 Tc 5 Tw 75 Tz'));
packages\pdf_document\test\content_edit_spacing_test.dart:58:        'BT /F1 12 Tf 2 Tc 5 Tw 72 700 Td q /F1 30 Tf -1 Tc 0 Tw Q (Ben Milanko) Tj ET'));
packages\pdf_document\README.md:5:[![CI](https://github.com/ben-milanko/dart-pdf/actions/workflows/ci.yml/badge.svg)](https://github.com/ben-milanko/dart-pdf/actions/workflows/ci.yml)
packages\pdf_document\README.md:6:[![codecov](https://codecov.io/gh/ben-milanko/dart-pdf/branch/main/graph/badge.svg?flag=pdf_document)](https://codecov.io/gh/ben-milanko/dart-pdf)
packages\pdf_document\README.md:7:[![License: Apache-2.0](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](https://github.com/ben-milanko/dart-pdf/blob/main/LICENSE)
packages\pdf_document\README.md:10:[dart-pdf suite](https://github.com/ben-milanko/dart-pdf): pages,
app\tool\preview\record_ios.py:64:    ap.add_argument("--bundle", default="dev.milanko.dartpdf",
packages\pdf_graphics\README.md:5:[![CI](https://github.com/ben-milanko/dart-pdf/actions/workflows/ci.yml/badge.svg)](https://github.com/ben-milanko/dart-pdf/actions/workflows/ci.yml)
packages\pdf_graphics\README.md:6:[![codecov](https://codecov.io/gh/ben-milanko/dart-pdf/branch/main/graph/badge.svg?flag=pdf_graphics)](https://codecov.io/gh/ben-milanko/dart-pdf)
packages\pdf_graphics\README.md:7:[![License: Apache-2.0](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](https://github.com/ben-milanko/dart-pdf/blob/main/LICENSE)
packages\pdf_graphics\README.md:10:[dart-pdf suite](https://github.com/ben-milanko/dart-pdf): a
tool\patrol_attempt_triage_test.dart:5:  '\t    t =     0.38s         Terminate dev.milanko.pdfViewerExample:37785',
tool\patrol_attempt_triage_test.dart:9:      'dev.milanko.pdfViewerExample:37785: Failed to terminate '
tool\patrol_attempt_triage_test.dart:10:      'dev.milanko.pdfViewerExample:0',
tool\patrol_attempt_triage_test.dart:25:      'dev.milanko.pdfViewerExample.RunnerUITests.xctrunner and options: {',
tool\patrol_attempt_triage_test.dart:28:      '"dev.milanko.pdfViewerExample.RunnerUITests.xctrunner" is unknown to '
tool\patrol_attempt_triage_test.dart:32:      'dev.milanko.pdfViewerExample.RunnerUITests.xctrunner.',
app\integration_test\ocr_e2e_test.dart:2:// the published `ocr-models-v1` bundle - the one path the unit tests can't
app\fastlane\metadata\README.md:67:<https://www.youtube.com/watch?v=jKLzTw32Jd4>. It is unlisted on the Ben Milanko
packages\pdf_cos\README.md:5:[![CI](https://github.com/ben-milanko/dart-pdf/actions/workflows/ci.yml/badge.svg)](https://github.com/ben-milanko/dart-pdf/actions/workflows/ci.yml)
packages\pdf_cos\README.md:6:[![codecov](https://codecov.io/gh/ben-milanko/dart-pdf/branch/main/graph/badge.svg?flag=pdf_cos)](https://codecov.io/gh/ben-milanko/dart-pdf)
packages\pdf_cos\README.md:7:[![License: Apache-2.0](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](https://github.com/ben-milanko/dart-pdf/blob/main/LICENSE)
packages\pdf_cos\README.md:10:[dart-pdf suite](https://github.com/ben-milanko/dart-pdf): everything a
app\macos\Runner.xcodeproj\project.pbxproj:561:				PRODUCT_BUNDLE_IDENTIFIER = dev.milanko.dartPdfEditorApp.RunnerTests;
app\macos\Runner.xcodeproj\project.pbxproj:576:				PRODUCT_BUNDLE_IDENTIFIER = dev.milanko.dartPdfEditorApp.RunnerTests;
app\macos\Runner.xcodeproj\project.pbxproj:591:				PRODUCT_BUNDLE_IDENTIFIER = dev.milanko.dartPdfEditorApp.RunnerTests;
app\macos\Runner\WindowDropService.swift:21:      name: "dev.milanko.dartpdf/windows_drop",
app\macos\Runner\MainFlutterWindow.swift:24:      label: "dev.milanko.dartpdf.file-access",
app\macos\Runner\MainFlutterWindow.swift:104:      name: "dev.milanko.dartpdf/incoming",
app\macos\Runner\MainFlutterWindow.swift:118:      name: "dev.milanko.dartpdf/memory",
app\macos\Runner\MainFlutterWindow.swift:139:      name: "dev.milanko.dartpdf/window_geometry",
app\macos\Runner\MainFlutterWindow.swift:180:      name: "dev.milanko.dartpdf/file_access",
app\macos\Runner\MainFlutterWindow.swift:255:      name: "dev.milanko.dartpdf/image_clipboard",
app\macos\Runner\MainFlutterWindow.swift:307:      name: "dev.milanko.dartpdf/trackpad_signature",
app\macos\Runner\MainFlutterWindow.swift:311:      name: "dev.milanko.dartpdf/trackpad_signature_support",
app\macos\Runner\Configs\AppInfo.xcconfig:11:PRODUCT_BUNDLE_IDENTIFIER = dev.milanko.dartpdf
app\macos\Runner\Configs\AppInfo.xcconfig:14:PRODUCT_COPYRIGHT = Copyright © 2026 dev.milanko. All rights reserved.
app\linux\runner\my_application.cc:59:  // dev.milanko.dartpdf.combine.desktop and my_application_local_command_line).
app\linux\runner\my_application.cc:72:// Handles the dev.milanko.dartpdf/incoming channel. On Linux the cold-start
app\linux\runner\my_application.cc:409:      messenger, "dev.milanko.dartpdf/image_clipboard", FL_METHOD_CODEC(codec));
app\linux\runner\my_application.cc:413:      messenger, "dev.milanko.dartpdf/incoming", FL_METHOD_CODEC(codec));
app\linux\runner\my_application.cc:418:      messenger, "dev.milanko.dartpdf/memory", FL_METHOD_CODEC(codec));
app\linux\runner\my_application.cc:423:      messenger, "dev.milanko.dartpdf/window_geometry",
app\test\tab_drag_test.dart:106:    const channel = MethodChannel('dev.milanko.dartpdf/window_geometry');
app\test\tabs_menu_test.dart:608:    const fileAccess = MethodChannel('dev.milanko.dartpdf/file_access');
app\test\snapshot_clipboard_test.dart:107:    const channel = MethodChannel('dev.milanko.dartpdf/image_clipboard');
app\test\snapshot_clipboard_test.dart:151:    const channel = MethodChannel('dev.milanko.dartpdf/image_clipboard');
app\test\snapshot_clipboard_test.dart:168:    const channel = MethodChannel('dev.milanko.dartpdf/image_clipboard');
app\test\snapshot_clipboard_test.dart:185:    const channel = MethodChannel('dev.milanko.dartpdf/image_clipboard');
app\test\snapshot_clipboard_test.dart:234:    const channel = MethodChannel('dev.milanko.dartpdf/image_clipboard');
app\test\progressive_open_test.dart:136:    const channel = MethodChannel('dev.milanko.dartpdf/file_access');
app\test\print_preview_test.dart:22:              const MethodChannel('dev.milanko.dart_pdf_printing'),
app\test\print_preview_test.dart:39:              const MethodChannel('dev.milanko.dart_pdf_printing'), null);
app\test\print_menu_test.dart:22:  const printChannel = MethodChannel('dev.milanko.dart_pdf_printing');
app\linux\dev.milanko.dartpdf.metainfo.xml:6:  <id>dev.milanko.dartpdf</id>
app\linux\dev.milanko.dartpdf.metainfo.xml:14:  <developer id="dev.milanko">
app\linux\dev.milanko.dartpdf.metainfo.xml:15:    <name>Ben Milanko</name>
app\linux\dev.milanko.dartpdf.metainfo.xml:18:  <launchable type="desktop-id">dev.milanko.dartpdf.desktop</launchable>
app\linux\dev.milanko.dartpdf.metainfo.xml:57:  <url type="bugtracker">https://github.com/ben-milanko/dart-pdf/issues</url>
app\linux\dev.milanko.dartpdf.metainfo.xml:58:  <url type="vcs-browser">https://github.com/ben-milanko/dart-pdf</url>
app\linux\dev.milanko.dartpdf.metainfo.xml:70:      <image>https://raw.githubusercontent.com/ben-milanko/dart-pdf/main/doc/marketing/app/macos/01-welcome.png</image>
app\linux\dev.milanko.dartpdf.metainfo.xml:74:      <image>https://raw.githubusercontent.com/ben-milanko/dart-pdf/main/doc/marketing/app/macos/02-editor.png</image>
app\linux\dev.milanko.dartpdf.metainfo.xml:78:      <image>https://raw.githubusercontent.com/ben-milanko/dart-pdf/main/doc/marketing/app/macos/03-dark.png</image>
app\linux\dev.milanko.dartpdf.desktop:28:Icon=dev.milanko.dartpdf
app\linux\dev.milanko.dartpdf.desktop:34:StartupWMClass=dev.milanko.dartpdf
app\linux\dev.milanko.dartpdf.combine.servicemenu.desktop:2:# Installed to share/kio/servicemenus/ as dev.milanko.dartpdf.combine.desktop.
app\linux\dev.milanko.dartpdf.combine.servicemenu.desktop:30:Icon=dev.milanko.dartpdf
app\linux\dev.milanko.dartpdf.combine.desktop:27:Icon=dev.milanko.dartpdf
app\linux\dev.milanko.dartpdf.combine.desktop:32:StartupWMClass=dev.milanko.dartpdf
app\linux\CMakeLists.txt:10:set(APPLICATION_ID "dev.milanko.dartpdf")
app\linux\CMakeLists.txt:148:install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/dev.milanko.dartpdf.desktop"
app\linux\CMakeLists.txt:155:install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/dev.milanko.dartpdf.combine.desktop"
app\linux\CMakeLists.txt:159:  "${CMAKE_CURRENT_SOURCE_DIR}/dev.milanko.dartpdf.combine.servicemenu.desktop"
app\linux\CMakeLists.txt:161:  RENAME dev.milanko.dartpdf.combine.desktop
app\linux\CMakeLists.txt:166:install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/dev.milanko.dartpdf.metainfo.xml"
app\linux\CMakeLists.txt:172:    "${CMAKE_CURRENT_SOURCE_DIR}/icons/hicolor/${icon_size}x${icon_size}/apps/dev.milanko.dartpdf.png"
app\test\native_window_drop_target_test.dart:9:  const channel = MethodChannel('dev.milanko.dartpdf/windows_drop');
app\test\keyboard_availability_test.dart:13:  const channel = MethodChannel('dev.milanko.dartpdf/keyboard');
app\test\file_io_folder_test.dart:65:      const channel = MethodChannel('dev.milanko.dartpdf/file_access');
app\test\file_io_folder_test.dart:181:  const channel = MethodChannel('dev.milanko.dartpdf/file_access');
app\test\desktop_direct_open_test.dart:87:  const fileAccess = MethodChannel('dev.milanko.dartpdf/file_access');
app\store-listing.md:148:in `linux/dev.milanko.dartpdf.metainfo.xml`. Update all of these sources when
packages\dart_pdf_printing\windows\dart_pdf_printing_plugin.cpp:186:          registrar->messenger(), "dev.milanko.dart_pdf_printing",
app\lib\windows_file_dialogs.dart:17:    MethodChannel('dev.milanko.dartpdf/file_dialogs');
app\RELEASING.md:47:   `linux/dev.milanko.dartpdf.metainfo.xml`, run
app\RELEASING.md:224:  id `dev.milanko.dartpdf` as an explicit App ID under the RES team. Apple does
app\lib\trackpad_signature.dart:21:  static const _events = EventChannel('dev.milanko.dartpdf/trackpad_signature');
app\lib\trackpad_signature.dart:23:      MethodChannel('dev.milanko.dartpdf/trackpad_signature_support');
app\lib\tab_drag.dart:10:    MethodChannel('dev.milanko.dartpdf/window_geometry');
packages\dart_pdf_printing\test\print_printer_test.dart:7:  const channel = MethodChannel('dev.milanko.dart_pdf_printing');
packages\dart_pdf_printing\test\print_preferences_ui_test.dart:12:const _channel = MethodChannel('dev.milanko.dart_pdf_printing');
packages\dart_pdf_printing\test\print_flow_test.dart:15:  const channel = MethodChannel('dev.milanko.dart_pdf_printing');
packages\dart_pdf_printing\test\printing_test.dart:35:    const channel = MethodChannel('dev.milanko.dart_pdf_printing');
packages\dart_pdf_printing\test\printing_test.dart:59:    const channel = MethodChannel('dev.milanko.dart_pdf_printing');
packages\dart_pdf_printing\test\printing_test.dart:82:    const channel = MethodChannel('dev.milanko.dart_pdf_printing');
packages\dart_pdf_printing\test\printing_test.dart:97:    const channel = MethodChannel('dev.milanko.dart_pdf_printing');
packages\dart_pdf_printing\test\native_print_io_test.dart:17:  const channel = MethodChannel('dev.milanko.dart_pdf_printing');
packages\dart_pdf_printing\README.md:161:The backend uses channel `dev.milanko.dart_pdf_printing`. Native registration
app\lib\pdf_mobile_source.dart:10:const mobileFileChannel = MethodChannel('dev.milanko.dartpdf/mobile_file');
packages\dart_pdf_printing\pubspec.yaml:45:        package: dev.milanko.dart_pdf_printing
app\lib\pdf_bookmark_source.dart:8:const _fileAccessChannel = MethodChannel('dev.milanko.dartpdf/file_access');
packages\dart_pdf_printing\macos\dart_pdf_printing.podspec:6:  s.homepage = 'https://github.com/ben-milanko/dart-pdf'
packages\dart_pdf_printing\macos\dart_pdf_printing.podspec:8:  s.author = 'Ben Milanko'
app\lib\native_window_drop_target.dart:7:const _channel = MethodChannel('dev.milanko.dartpdf/windows_drop');
app\lib\memory_probe_io.dart:7:const _memoryChannel = MethodChannel('dev.milanko.dartpdf/memory');
packages\dart_pdf_printing\macos\dart_pdf_printing\Sources\dart_pdf_printing\DartPdfPrintingPlugin.swift:8:      name: "dev.milanko.dart_pdf_printing", binaryMessenger: registrar.messenger)
app\lib\keyboard_availability.dart:20:  static const _channel = MethodChannel('dev.milanko.dartpdf/keyboard');
app\lib\incoming_file.dart:59:  static const channelName = 'dev.milanko.dartpdf/incoming';
app\lib\image_clipboard_io.dart:14:const _channel = MethodChannel('dev.milanko.dartpdf/image_clipboard');
app\lib\file_io.dart:21:const _fileAccessChannel = MethodChannel('dev.milanko.dartpdf/file_access');
app\lib\file_io.dart:54:const _stampBundleFormat = 'dev.milanko.dartpdf.custom-stamps';
packages\dart_pdf_printing\linux\dart_pdf_printing_plugin.cc:506:// Handles the dev.milanko.dart_pdf_printing channel: beginJob / printPage /
packages\dart_pdf_printing\linux\dart_pdf_printing_plugin.cc:605:      fl_plugin_registrar_get_messenger(registrar), "dev.milanko.dart_pdf_printing",
app\ios\Runner.xcodeproj\project.pbxproj:477:				PRODUCT_BUNDLE_IDENTIFIER = dev.milanko.dartpdf;
app\ios\Runner.xcodeproj\project.pbxproj:495:				PRODUCT_BUNDLE_IDENTIFIER = dev.milanko.dartpdf.RunnerTests;
app\ios\Runner.xcodeproj\project.pbxproj:513:				PRODUCT_BUNDLE_IDENTIFIER = dev.milanko.dartpdf.RunnerTests;
app\ios\Runner.xcodeproj\project.pbxproj:529:				PRODUCT_BUNDLE_IDENTIFIER = dev.milanko.dartpdf.RunnerTests;
app\ios\Runner.xcodeproj\project.pbxproj:661:				PRODUCT_BUNDLE_IDENTIFIER = dev.milanko.dartpdf;
app\ios\Runner.xcodeproj\project.pbxproj:684:				PRODUCT_BUNDLE_IDENTIFIER = dev.milanko.dartpdf;
packages\dart_pdf_printing\lib\src\print_printer.dart:3:const _channel = MethodChannel('dev.milanko.dart_pdf_printing');
app\ios\Runner\SceneDelegate.swift:27:  private let fileIoQueue = DispatchQueue(label: "dev.milanko.dartpdf.mobilefile")
app\ios\Runner\SceneDelegate.swift:48:      name: "dev.milanko.dartpdf/memory",
app\ios\Runner\SceneDelegate.swift:75:      name: "dev.milanko.dartpdf/incoming",
app\ios\Runner\SceneDelegate.swift:97:      name: "dev.milanko.dartpdf/image_clipboard",
app\ios\Runner\SceneDelegate.swift:127:      name: "dev.milanko.dartpdf/mobile_file",
packages\dart_pdf_printing\lib\src\native_print_io.dart:8:const MethodChannel _channel = MethodChannel('dev.milanko.dart_pdf_printing');
app\ios\Runner\AppDelegate.swift:26:        name: "dev.milanko.dartpdf/keyboard", binaryMessenger: registrar.messenger())
packages\dart_pdf_printing\ios\dart_pdf_printing.podspec:6:  s.homepage = 'https://github.com/ben-milanko/dart-pdf'
packages\dart_pdf_printing\ios\dart_pdf_printing.podspec:8:  s.author = 'Ben Milanko'
packages\dart_pdf_printing\ios\dart_pdf_printing\Sources\dart_pdf_printing\DartPdfPrintingPlugin.swift:12:      name: "dev.milanko.dart_pdf_printing", binaryMessenger: registrar.messenger())
packages\dart_pdf_printing\example\integration_test\native_registration_test.dart:13:    const channel = MethodChannel('dev.milanko.dart_pdf_printing');
packages\dart_pdf_printing\android\src\main\kotlin\dev\milanko\dart_pdf_printing\DartPdfPrintingPlugin.kt:1:package dev.milanko.dart_pdf_printing
packages\dart_pdf_printing\android\src\main\kotlin\dev\milanko\dart_pdf_printing\DartPdfPrintingPlugin.kt:22:        channel = MethodChannel(binding.binaryMessenger, "dev.milanko.dart_pdf_printing")
packages\dart_pdf_printing\android\src\main\AndroidManifest.xml:2:  package="dev.milanko.dart_pdf_printing">
packages\dart_pdf_printing\android\build.gradle.kts:1:group = "dev.milanko.dart_pdf_printing"
packages\dart_pdf_printing\android\build.gradle.kts:29:    namespace = "dev.milanko.dart_pdf_printing"
app\packaging\snap\snapcraft.yaml:12:# to own the service dev.milanko.dartpdf due to AppArmor policy"). The slot
app\packaging\snap\snapcraft.yaml:13:# generates the AppArmor `dbus (own) bus=session name=dev.milanko.dartpdf`
app\packaging\snap\snapcraft.yaml:63:    common-id: dev.milanko.dartpdf
app\packaging\snap\snapcraft.yaml:123:    name: dev.milanko.dartpdf
app\packaging\snap\snap\snapcraft.yaml:10:contact: https://github.com/ben-milanko/dart-pdf/issues
app\packaging\snap\snap\snapcraft.yaml:27:    common-id: dev.milanko.dartpdf
app\packaging\snap\snap\snapcraft.yaml:53:    name: dev.milanko.dartpdf
app\packaging\snap\snap\snapcraft.yaml:58:    source: https://github.com/ben-milanko/dart-pdf/releases/download/app-v3.7.0/dartpdf-linux-x64.tar.gz
app\packaging\snap\snap\snapcraft.yaml:62:      - share/metainfo/dev.milanko.dartpdf.metainfo.xml
app\packaging\snap\build-release-snap.sh:61:metainfo="$script_dir/../../linux/dev.milanko.dartpdf.metainfo.xml"
app\packaging\snap\build-release-snap.sh:89:  "$work_dir/release-payload/share/metainfo/dev.milanko.dartpdf.metainfo.xml"
app\packaging\msstore\build-msix.ps1:30:  $env:MSSTORE_PUBLISHER_DISPLAY_NAME = 'Ben Milanko'
app\packaging\flatpak\sync-desktop-assets.sh:16:cp "$linux/dev.milanko.dartpdf.desktop"      "$out/"
app\packaging\flatpak\sync-desktop-assets.sh:17:cp "$linux/dev.milanko.dartpdf.combine.desktop" "$out/"
app\packaging\flatpak\sync-desktop-assets.sh:18:cp "$linux/dev.milanko.dartpdf.metainfo.xml" "$out/"
app\packaging\flatpak\sync-desktop-assets.sh:20:  cp "$linux/icons/hicolor/${sz}x${sz}/apps/dev.milanko.dartpdf.png" "$out/icons/dartpdf-${sz}.png"
app\packaging\flatpak\README.md:16:`dev.milanko.dartpdf`. Subsequent releases arrive through normal Flatpak
app\packaging\flatpak\README.md:21:- `dev.milanko.dartpdf.yml` — binary Flatpak manifest.
app\packaging\flatpak\README.md:66:  build-dir dev.milanko.dartpdf.yml
app\packaging\flatpak\README.md:67:flatpak run dev.milanko.dartpdf
app\packaging\flatpak\README.md:78:  dev.milanko.dartpdf inspect "$PWD/document.pdf" --json
app\packaging\flatpak\dev.milanko.dartpdf.yml:17:app-id: dev.milanko.dartpdf
app\packaging\flatpak\dev.milanko.dartpdf.yml:63:      - install -Dm644 dev.milanko.dartpdf.desktop
app\packaging\flatpak\dev.milanko.dartpdf.yml:64:        /app/share/applications/dev.milanko.dartpdf.desktop
app\packaging\flatpak\dev.milanko.dartpdf.yml:67:      - install -Dm644 dev.milanko.dartpdf.combine.desktop
app\packaging\flatpak\dev.milanko.dartpdf.yml:68:        /app/share/applications/dev.milanko.dartpdf.combine.desktop
app\packaging\flatpak\dev.milanko.dartpdf.yml:69:      - install -Dm644 dev.milanko.dartpdf.metainfo.xml
app\packaging\flatpak\dev.milanko.dartpdf.yml:70:        /app/share/metainfo/dev.milanko.dartpdf.metainfo.xml
app\packaging\flatpak\dev.milanko.dartpdf.yml:71:      - install -Dm644 dartpdf-64.png  /app/share/icons/hicolor/64x64/apps/dev.milanko.dartpdf.png
app\packaging\flatpak\dev.milanko.dartpdf.yml:72:      - install -Dm644 dartpdf-128.png /app/share/icons/hicolor/128x128/apps/dev.milanko.dartpdf.png
app\packaging\flatpak\dev.milanko.dartpdf.yml:73:      - install -Dm644 dartpdf-256.png /app/share/icons/hicolor/256x256/apps/dev.milanko.dartpdf.png
app\packaging\flatpak\dev.milanko.dartpdf.yml:74:      - install -Dm644 dartpdf-512.png /app/share/icons/hicolor/512x512/apps/dev.milanko.dartpdf.png
app\packaging\flatpak\dev.milanko.dartpdf.yml:78:        url: https://github.com/ben-milanko/dart-pdf/releases/download/app-v3.7.0/dartpdf-linux-x64.tar.gz
app\packaging\flatpak\dev.milanko.dartpdf.yml:85:          url: https://api.github.com/repos/ben-milanko/dart-pdf/releases/latest
app\packaging\flatpak\dev.milanko.dartpdf.yml:94:        path: desktop-assets/dev.milanko.dartpdf.desktop
app\packaging\flatpak\dev.milanko.dartpdf.yml:96:        path: desktop-assets/dev.milanko.dartpdf.combine.desktop
app\packaging\flatpak\dev.milanko.dartpdf.yml:98:        path: desktop-assets/dev.milanko.dartpdf.metainfo.xml
app\packaging\flatpak\desktop-assets\dev.milanko.dartpdf.metainfo.xml:6:  <id>dev.milanko.dartpdf</id>
app\packaging\flatpak\desktop-assets\dev.milanko.dartpdf.metainfo.xml:14:  <developer id="dev.milanko">
app\packaging\flatpak\desktop-assets\dev.milanko.dartpdf.metainfo.xml:15:    <name>Ben Milanko</name>
app\packaging\flatpak\desktop-assets\dev.milanko.dartpdf.metainfo.xml:18:  <launchable type="desktop-id">dev.milanko.dartpdf.desktop</launchable>
app\packaging\flatpak\desktop-assets\dev.milanko.dartpdf.metainfo.xml:57:  <url type="bugtracker">https://github.com/ben-milanko/dart-pdf/issues</url>
app\packaging\flatpak\desktop-assets\dev.milanko.dartpdf.metainfo.xml:58:  <url type="vcs-browser">https://github.com/ben-milanko/dart-pdf</url>
app\packaging\flatpak\desktop-assets\dev.milanko.dartpdf.metainfo.xml:70:      <image>https://raw.githubusercontent.com/ben-milanko/dart-pdf/main/doc/marketing/app/macos/01-welcome.png</image>
app\packaging\flatpak\desktop-assets\dev.milanko.dartpdf.metainfo.xml:74:      <image>https://raw.githubusercontent.com/ben-milanko/dart-pdf/main/doc/marketing/app/macos/02-editor.png</image>
app\packaging\flatpak\desktop-assets\dev.milanko.dartpdf.metainfo.xml:78:      <image>https://raw.githubusercontent.com/ben-milanko/dart-pdf/main/doc/marketing/app/macos/03-dark.png</image>
app\packaging\flatpak\desktop-assets\dev.milanko.dartpdf.desktop:28:Icon=dev.milanko.dartpdf
app\packaging\flatpak\desktop-assets\dev.milanko.dartpdf.desktop:34:StartupWMClass=dev.milanko.dartpdf
app\packaging\flatpak\desktop-assets\dev.milanko.dartpdf.combine.desktop:27:Icon=dev.milanko.dartpdf
app\packaging\flatpak\desktop-assets\dev.milanko.dartpdf.combine.desktop:32:StartupWMClass=dev.milanko.dartpdf
app\packaging\flatpak\build-self-hosted-repo.sh:94:cp "$script_dir/dev.milanko.dartpdf.yml" "$work_dir/dev.milanko.dartpdf.yml"
app\packaging\flatpak\build-self-hosted-repo.sh:101:python3 - "$work_dir/dev.milanko.dartpdf.yml" <<'PY'
app\packaging\flatpak\build-self-hosted-repo.sh:120:  "$work_dir/build-dir" "$work_dir/dev.milanko.dartpdf.yml"
app\packaging\flatpak\build-self-hosted-repo.sh:157:    'appId': 'dev.milanko.dartpdf',
app\packaging\aur\README.md:8:[validation repository](https://github.com/ben-milanko/dartpdf-aur) prepares
app\packaging\aur\README.md:25:[Native Arch validation](https://github.com/ben-milanko/dartpdf-aur/actions/runs/37884461790)
app\packaging\aur\README.md:61:[official Linux release](https://github.com/ben-milanko/dart-pdf/releases/tag/app-v8.0.0).
app\packaging\aur\PKGBUILD:1:# Maintainer: Ben Milanko <ben.milanko@protonmail.com>
app\packaging\aur\PKGBUILD:23:source=("dartpdf-${pkgver}.tar.gz::https://github.com/ben-milanko/dart-pdf/releases/download/app-v${pkgver}/dartpdf-linux-x64.tar.gz"
app\packaging\aur\PKGBUILD:24:        "LICENSE::https://raw.githubusercontent.com/ben-milanko/dart-pdf/app-v${pkgver}/LICENSE")
packages\dart_pdf_cli\README.md:4:with the [dart-pdf](https://github.com/ben-milanko/dart-pdf) engine. The
packages\dart_pdf_cli\README.md:37:| Flatpak | `flatpak run --command=dartpdf-cli dev.milanko.dartpdf` |
packages\dart_pdf_cli\README.md:149:renderer work in [#684](https://github.com/ben-milanko/dart-pdf/issues/684)
packages\dart_pdf_cli\README.md:150:lands (the broader conversion roadmap is [#369](https://github.com/ben-milanko/dart-pdf/issues/369)).
packages\dart_pdf_editor\README.md:1:![dart-pdf, an open-source Flutter PDF editor and pure-Dart renderer](https://raw.githubusercontent.com/ben-milanko/dart-pdf/main/doc/banner.png)
packages\dart_pdf_editor\README.md:7:[![CI](https://github.com/ben-milanko/dart-pdf/actions/workflows/ci.yml/badge.svg)](https://github.com/ben-milanko/dart-pdf/actions/workflows/ci.yml)
packages\dart_pdf_editor\README.md:8:[![codecov](https://codecov.io/gh/ben-milanko/dart-pdf/branch/main/graph/badge.svg?flag=dart_pdf_editor)](https://codecov.io/gh/ben-milanko/dart-pdf)
packages\dart_pdf_editor\README.md:9:[![License: Apache-2.0](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](https://github.com/ben-milanko/dart-pdf/blob/main/LICENSE)
packages\dart_pdf_editor\README.md:15:![The example app: PdfEditorView showing the feature showcase document](https://raw.githubusercontent.com/ben-milanko/dart-pdf/main/doc/dart_pdf_editor_example.jpg)
packages\dart_pdf_editor\README.md:105:[dart-pdf suite](https://github.com/ben-milanko/dart-pdf): `pdf_cos`
packages\dart_pdf_editor\README.md:189:[full methodology and historical checkpoints](https://github.com/ben-milanko/dart-pdf/blob/main/doc/benchmarks/pdfium-parity.md).
packages\dart_pdf_editor\README.md:196:[`benchmark/`](https://github.com/ben-milanko/dart-pdf/tree/main/benchmark).
packages\dart_pdf_editor\README.md:347:(since 7.0; see [doc/MIGRATING-7.0.0.md](https://github.com/ben-milanko/dart-pdf/blob/main/doc/MIGRATING-7.0.0.md)).
packages\dart_pdf_editor\README.md:832:[doc/render_worker_web.md](https://github.com/ben-milanko/dart-pdf/blob/main/doc/render_worker_web.md).
packages\dart_pdf_editor\example\windows\runner\Runner.rc:92:            VALUE "CompanyName", "dev.milanko" "\0"
packages\dart_pdf_editor\example\windows\runner\Runner.rc:96:            VALUE "LegalCopyright", "Copyright (C) 2026 dev.milanko. All rights reserved." "\0"
packages\dart_pdf_editor\example\pubspec.yaml:44:    package_name: dev.milanko.pdf_viewer_example
packages\dart_pdf_editor\example\pubspec.yaml:46:    bundle_id: dev.milanko.pdfViewerExample
packages\dart_pdf_editor\example\pubspec.yaml:48:    bundle_id: dev.milanko.pdfViewerExample
packages\dart_pdf_editor\example\macos\Runner.xcodeproj\project.pbxproj:472:				PRODUCT_BUNDLE_IDENTIFIER = dev.milanko.pdfViewerExample.RunnerUITests;
packages\dart_pdf_editor\example\macos\Runner.xcodeproj\project.pbxproj:486:				PRODUCT_BUNDLE_IDENTIFIER = dev.milanko.pdfViewerExample.RunnerTests;
packages\dart_pdf_editor\example\macos\Runner.xcodeproj\project.pbxproj:500:				PRODUCT_BUNDLE_IDENTIFIER = dev.milanko.pdfViewerExample.RunnerTests;
packages\dart_pdf_editor\example\macos\Runner.xcodeproj\project.pbxproj:514:				PRODUCT_BUNDLE_IDENTIFIER = dev.milanko.pdfViewerExample.RunnerTests;
packages\dart_pdf_editor\example\macos\Runner.xcodeproj\project.pbxproj:770:				PRODUCT_BUNDLE_IDENTIFIER = dev.milanko.pdfViewerExample.RunnerUITests;
packages\dart_pdf_editor\example\macos\Runner.xcodeproj\project.pbxproj:789:				PRODUCT_BUNDLE_IDENTIFIER = dev.milanko.pdfViewerExample.RunnerUITests;
packages\dart_pdf_editor\example\macos\Runner\Configs\AppInfo.xcconfig:11:PRODUCT_BUNDLE_IDENTIFIER = dev.milanko.pdfViewerExample
packages\dart_pdf_editor\example\macos\Runner\Configs\AppInfo.xcconfig:14:PRODUCT_COPYRIGHT = Copyright © 2026 dev.milanko. All rights reserved.
packages\dart_pdf_editor\example\linux\CMakeLists.txt:10:set(APPLICATION_ID "dev.milanko.pdf_viewer_example")
packages\dart_pdf_editor\example\ios\Runner.xcodeproj\project.pbxproj:449:				PRODUCT_BUNDLE_IDENTIFIER = dev.milanko.pdfViewerExample.RunnerUITests;
packages\dart_pdf_editor\example\ios\Runner.xcodeproj\project.pbxproj:523:				PRODUCT_BUNDLE_IDENTIFIER = dev.milanko.pdfViewerExample;
packages\dart_pdf_editor\example\ios\Runner.xcodeproj\project.pbxproj:545:				PRODUCT_BUNDLE_IDENTIFIER = dev.milanko.pdfViewerExample.RunnerUITests;
packages\dart_pdf_editor\example\ios\Runner.xcodeproj\project.pbxproj:562:				PRODUCT_BUNDLE_IDENTIFIER = dev.milanko.pdfViewerExample.RunnerTests;
packages\dart_pdf_editor\example\ios\Runner.xcodeproj\project.pbxproj:579:				PRODUCT_BUNDLE_IDENTIFIER = dev.milanko.pdfViewerExample.RunnerTests;
packages\dart_pdf_editor\example\ios\Runner.xcodeproj\project.pbxproj:594:				PRODUCT_BUNDLE_IDENTIFIER = dev.milanko.pdfViewerExample.RunnerTests;
packages\dart_pdf_editor\example\ios\Runner.xcodeproj\project.pbxproj:615:				PRODUCT_BUNDLE_IDENTIFIER = dev.milanko.pdfViewerExample.RunnerUITests;
packages\dart_pdf_editor\example\ios\Runner.xcodeproj\project.pbxproj:749:				PRODUCT_BUNDLE_IDENTIFIER = dev.milanko.pdfViewerExample;
packages\dart_pdf_editor\example\ios\Runner.xcodeproj\project.pbxproj:772:				PRODUCT_BUNDLE_IDENTIFIER = dev.milanko.pdfViewerExample;
packages\dart_pdf_editor\example\android\app\src\main\kotlin\dev\milanko\pdf_viewer_example\MainActivity.kt:1:package dev.milanko.pdf_viewer_example
packages\dart_pdf_editor\example\android\app\src\androidTest\java\dev\milanko\pdf_viewer_example\MainActivityTest.java:1:package dev.milanko.pdf_viewer_example;
packages\dart_pdf_editor\example\android\app\build.gradle.kts:8:    namespace = "dev.milanko.pdf_viewer_example"
packages\dart_pdf_editor\example\android\app\build.gradle.kts:20:        applicationId = "dev.milanko.pdf_viewer_example"
app\CHANGELOG.md:380:  the app to own its `dev.milanko.dartpdf` D-Bus name.
app\android\app\src\main\kotlin\dev\milanko\dart_pdf_editor_app\TrackpadSignatureCapture.kt:1:package dev.milanko.dart_pdf_editor_app
app\android\app\src\main\kotlin\dev\milanko\dart_pdf_editor_app\MainActivity.kt:1:package dev.milanko.dart_pdf_editor_app
app\android\app\src\main\kotlin\dev\milanko\dart_pdf_editor_app\MainActivity.kt:34:    private val channelName = "dev.milanko.dartpdf/incoming"
app\android\app\src\main\kotlin\dev\milanko\dart_pdf_editor_app\MainActivity.kt:35:    private val imageClipboardChannelName = "dev.milanko.dartpdf/image_clipboard"
app\android\app\src\main\kotlin\dev\milanko\dart_pdf_editor_app\MainActivity.kt:36:    private val mobileFileChannelName = "dev.milanko.dartpdf/mobile_file"
app\android\app\src\main\kotlin\dev\milanko\dart_pdf_editor_app\MainActivity.kt:37:    private val memoryChannelName = "dev.milanko.dartpdf/memory"
app\android\app\src\main\kotlin\dev\milanko\dart_pdf_editor_app\MainActivity.kt:58:            flutterEngine.dartExecutor.binaryMessenger, "dev.milanko.dartpdf/keyboard"
app\android\app\src\main\kotlin\dev\milanko\dart_pdf_editor_app\MainActivity.kt:129:            "dev.milanko.dartpdf/trackpad_signature",
app\android\app\src\main\kotlin\dev\milanko\dart_pdf_editor_app\MainActivity.kt:133:            "dev.milanko.dartpdf/trackpad_signature_support",
app\android\app\build.gradle.kts:20:    namespace = "dev.milanko.dart_pdf_editor_app"
app\android\app\src\main\kotlin\dev\milanko\dart_pdf_editor_app\ImageClipboardProvider.kt:1:package dev.milanko.dart_pdf_editor_app

#### File di riferimento

- `app/lib/update.dart`: aggiornamenti dell'app puntati alla repository dell'utente.
- `app/lib/app_info.dart`: sorgente e segnalazione problemi puntate alla repository dell'utente.
- `app/lib/whats_new.dart`: note notturne puntate alla repository dell'utente.
- `packages/pdf_ocr_ondevice/lib/src/ocr_model.dart`: modello ora ospitato nella copia; licenze in `assets/ocr/`.

