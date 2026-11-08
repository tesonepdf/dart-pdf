# Conflitti della fusione con l'ufficiale: appunti per chi riprende il lavoro

File per l'utente **e** per l'assistente che apre una nuova chat. Ogni conflitto è scritto due volte: in linguaggio tecnico (per l'assistente) e in italiano semplice (per l'utente).
Aggiornato il 2026-10-30; ultime modifiche il 2026-11-07. Cosa fare dopo e il codice: vedi `DA-FARE.md`. Quello che qui è "verificato" l'ho controllato con git; il resto è dichiarato come non verificato.

## NUOVO FLUSSO (07/11): un solo ramo, `main`. Il ramo `prova-sviluppatore` non esiste più.

Deciso dall'utente il 07/11: tutto quello che era su `prova-sviluppatore` è stato portato in `main` (avanzamento senza conflitti, `main` era già un antenato di `prova`, quindi non si è perso niente) e poi il ramo `prova-sviluppatore` è stato cancellato. Le parti di questo file che parlano del "ramo prova" restano come storia: da ora i commit, le build e la CI sono tutti su `main`.
- Il push su `main` pubblica la release Android ufficiale (`app-android-latest`) con la CI; `build-prova.yml` resta nel repo ma non parte più (era legato al ramo cancellato). La release `app-android-prova` e l'app "DartPDF Prova" non vengono più aggiornate: se non servono, si tolgono con un ok dell'utente.
- **Per le novità di Ben non si rifà più l'elenco dei file.** Si usa `tools/confronta-ben.sh`: legge in `tools/fusione-ben.stato` l'ultimo commit di Ben già letto (oggi `66601339`), dice i titoli dei commit nuovi, quali file si fondono da soli e quali hanno conflitti veri. Non modifica il progetto. `--copia-puliti` copia i file puliti (senza commit), `--segna` aggiorna lo stato dopo la decisione. Le cose che per decisione dell'utente non si guardano (sito, flussi di Ben, versioni, documenti) sono ignorate. Provato il 07/11: Ben non ha pubblicato niente dopo `66601339`.

## Modifiche richieste dall'utente dopo la fusione (sempre su `main`)

| Data | Richiesta | Commit | Stato |
|---|---|---|---|
| 08/11 | La barra in alto con il numero di pagina deve essere **sempre visibile**, non sparire scorrendo (`editor_screen.dart`: `autoHideChrome: false`). | `#10036` | applicato, da provare sul telefono |

## Aggiornamento 2026-11-06

Sul ramo `prova-sviluppatore` sono stati importati dal `main` di Ben (`66601339`) i 288 cambiamenti non sovrapposti rispetto alla base `f5efa6e5`. Le versioni di Ben per i 78 file sovrapposti sono state copiate in `DA-VALUTARE/ben/`; i file attivi non sono stati sostituiti. Altri 5 percorsi avevano lo stesso esito da entrambe le parti. Esaminare i file in `DA-VALUTARE/README.md` uno alla volta. Questo aggiornamento riguarda la nuova importazione; i 14 conflitti storici qui sotto erano stati chiusi nella precedente versione del ramo.

## Aggiornamento 2026-11-07 (novità grafiche di Ben, le tue funzioni restano)

Regola data dall'utente: tenere le sue funzioni, applicare le novità **grafiche** di Ben, il resto si vede dopo; **un punto alla volta**, a ogni modifica si aggiorna `DA-FARE.md`. Per ognuno dei 46 file modificati da tutti e due ho provato la fusione automatica (base `f5efa6e5`, Ben `66601339`) e ho letto cosa ha cambiato Ben prima di prenderlo.

**Registro dei punti (ramo prova)**

| Punto | Cosa | Commit | Stato |
|---|---|---|---|
| prima | dialoghi di conferma con casella, altezza menu a tendina (3 file in `design/`) | `#10027` (`2780f42`) | applicato |
| prima | bacheca: suggerimento col percorso dei recenti dopo una breve attesa | `#10028` (`64aa7b7`) | applicato |
| 1 | vista a due pagine (con copertina, miniature a coppie, voci nel menu Vista) con il visualizzatore di Ben (`pdf_viewer.dart`); tue funzioni rimesse a mano: spazio sopra la prima pagina, `fill`, "niente da incollare", ricerca valida se cambiano solo le annotazioni | `#10029` (`1c5339e`) | applicato; da solo non compilava, serve il 2 |
| 2 | controller: aggiunti `mode`, `selectsAnnotations`, `wantsPageOverlays`, `pageCurrency` (il controller di Ben non è stato preso intero) | `#10030` (`1986af0`) | applicato, CI verde |
| 3 | `editing_overlay.dart` e modifica del testo di Ben contro la tua casella | nessuno | **letto, non preso** (vedi sotto) |
| 3-bis | sottomenu del menu di Windows raggiungibili da tastiera e lettore schermo (`editor_screen.dart`), più 2 test di Ben | `#10031` (`c4dad47`) | applicato, build da verificare |
| 4 | tasto X del pannello strumenti | nessuno | da decidere (griglia 3x3 tua o riga di Ben) |
| 5 | suggerimento annulla/ripeti scelto per sistema: `⌘Z` su Mac e iPhone, `Ctrl+Z` su Windows, Linux e Android, e solo con una tastiera collegata. Prima la tua barra scriveva sempre `⌘Z`, anche su Windows. Corretti anche il test dell'app | `#10033` | applicato, build da verificare |
| 6 | azioni in basso sul telefono: l'utente le vuole nei "paletti" | nessuno | da chiarire cosa sono i "paletti" |

**DECISIONE DEL 07/11: LA FUSIONE GRAFICA È CHIUSA. Non c'è altro da fare con Ben, finché lui non pubblica novità nuove.**
Controllato che le novità di Ben rimaste valgono su Android e Windows, e sono comunque da non prendere:
- **OCR automatico spento che resta spento:** il tuo codice rispetta già l'interruttore per le scansioni nuove (`editor_screen.dart`, riga ~3592) e ha già il salvataggio del risultato OCR. Differenza con Ben: il recupero di lavori OCR automatici *interrotti* non guarda l'interruttore (la chiamata a `_ocr.recover` non passa `automaticEnabled`). Caso raro: **non preso**.
- **Redazione con sostituzione a immagine:** a metà nel ramo (motore e dialogo dentro, casella e comando del controller no). L'utente non la usa: **non presa**.
- **Condividi che segna il documento come salvato:** già a posto (`_saveResultFromShare`).
- **Overlay, tasto X, riordini interni, sito, flussi di Ben, versioni:** non presi (vedi sopra).
Quando Ben pubblica altro: si riparte da qui, si confronta solo il nuovo (`git fetch upstream main`, poi i commit dopo `66601339`), senza rifare i 78 file.

**Cosa si vede oggi nell'app, dalla fusione grafica del 07/11 (onesto: sono poche cose)**
- Opzioni di visualizzazione: "Vista a due pagine" e "Mostra la copertina separatamente" (spenta di base: se non la accendi non cambia niente).
- Messaggi di conferma che possono avere una casella da spuntare, e menu a tendina con l'altezza giusta.
- Bacheca: il suggerimento col percorso dei recenti compare dopo una breve attesa.
- Windows con tastiera: i sottomenu del menu si aprono con Tab e Invio.
- Suggerimento annulla/ripeti: `Ctrl+Z` su Windows e Android, `⌘Z` su Mac e iPhone.
- Da provare sul telefono dopo i punti 1 e 2: spazio sopra la prima pagina, tornare a una pagina salvata, segnare un testo col dito e poi cercare, e aprire un documento modificato, entrare in Impostazioni e tornare (il documento e lo strumento devono esserci ancora).
- Il resto dei cambiamenti di Ben nei 78 file non è grafica: è il riordino interno dell'editor, che vale la pena solo se si decide di riportare la tua casella di testo sul suo sistema (punto 3).

**Perché il 3 (overlay) non è preso.** Ben ha riorganizzato l'overlay: la modifica del testo sul posto passa in una sessione nuova (`PdfTextEditSession`), blocchi di codice sono stati spostati e ci sono "immagini residue" (il risultato resta visibile finché la pagina non si aggiorna). Nel tuo elenco è "riordino interno, senza funzioni nuove". Dentro ci sono le tue frecce, la X e l'adattamento della casella; il controller di Ben non ha più la vecchia API che la tua casella usa. Rischio alto, guadagno visibile piccolo. Se serve, le sole "immagini residue" si possono prendere dopo come sotto-punto.

**Perché il controller (punto 2) è stato solo ampliato.** Stesso motivo: Ben ha tolto dal controller la vecchia modifica del testo (selezione, richieste di stile, blocco della conferma) e la tua barra e il tuo overlay la usano ancora. Prenderlo vuol dire prendere insieme overlay e barra: è il punto 3.

**Non preso, da vedere con te**
- **`pdf_viewer.dart`:** ora preso (punto 1). Restano da vedere `editing_overlay.dart` ed `editing_controller.dart` (punto 3).
- **Impostazioni sul telefono che conservano documento e strumento:** nel test di Ben dipende dal suo riordino delle schede; da verificare sul telefono se da noi si perde il lavoro.
- **Solo funzioni, lasciate:** redazioni come immagini, schede documento e recupero (`document_tab.dart`), elenco recenti (`recents.dart`), esportazione pagine con Ctrl+Maiusc+X.
- **Cancellati da te, modificati da Ben:** sito, flussi di compilazione di Ben, `SECURITY.md`, `.vscode`, documenti: restano cancellati, non aperti uno a uno.

## Elenco da decidere (2026-11-07): i 78 file di Ben che il ramo prova non ha ancora preso

Fonte: `DA-VALUTARE/README.md` (Ben `66601339`, base `f5efa6e5`). Letti i titoli dei commit di Ben e confrontate le righe di ogni file con il ramo prova; il codice non è stato letto riga per riga. Le descrizioni sono quelle dichiarate da Ben. "Già dentro" = le righe nuove di Ben risultano tutte presenti nel file attuale (confronto automatico, non una prova). **L'elenco è per gruppi di funzione: non è uno per uno su ogni singola modifica.**

**Già dentro, niente da decidere (13 file)**
- Vista a due pagine: `pdf_viewer.dart`, `editing_thumbnails.dart`, `shell_chrome.dart`, `editing_preferences.dart`, `editor_commands.dart`, `pdf_reader.dart`. (Dal 07/11 è davvero dentro: punti 1 e 2.)
- Redazione con sostituzione a immagine: `editor_presenter.dart`, `material_presenter.dart`, `pdf_document/lib/src/editor.dart`.
- Dialogo scala e menu a tendina: `material_host.dart`.
- Suggerimento ritardato nei recenti: `welcome_screen.dart`.
- Testi italiani dell'editor: `dart_pdf_editor_it.arb`, `dart_pdf_editor_localizations_it.dart`.

**Restano come deciso dall'utente (44 file)**
- Cancellati da te e modificati da Ben, non riaperti: sito (24 file in `site/`), flussi di compilazione di Ben (3), documenti (3), `SECURITY.md`, `.vscode/settings.json`.
- 12 `pubspec.yaml` (app e pacchetti): solo numeri di versione e dipendenze di Ben (14.0.0, 15.0.0).

**Da decidere (21 file, per funzione)**
1. **Guida ai moduli PDF e salvataggio che non perde le modifiche fatte mentre salva.** `app/lib/document_tab.dart`, `file_io.dart`, `editor_screen.dart`, `l10n/app_it.arb`, `l10n/app_localizations_it.dart`. Una parte è già dentro.
2. **OCR automatico rispettato quando riprende i lavori interrotti.** `app/lib/ocr_native.dart`, `ocr_web.dart`, `ocr_stub.dart`, `editor_screen.dart`, test `ocr_auto_test.dart`. Quasi per niente preso.
3. **Menu e comandi più facili da trovare, anche per chi usa il lettore schermo.** `editing_toolbar.dart`, `editor_screen.dart`, test `form_data_exchange_menu_test.dart`, `keyboard_availability_test.dart`, `settings_menu_test.dart`. Tocca i menu dell'utente (regola: i suoi menu si tengono sempre). **Fatto il 07/11: sottomenu del menu di Windows (#10031) e suggerimento annulla/ripeti per sistema (#10033). Resta da verificare sul telefono Impostazioni (vedi sotto).**
4. **Esporta pagine con Ctrl/Cmd+Maiusc+X.** `pdf_editor_view.dart`.
5. **Redazione, ultime correzioni di revisione.** `editing_controller.dart` e `editing_toolbar.dart`.
6. **Correzione anteprime e annotazioni.** `editor_screen.dart`, test `progressive_open_test.dart`.
7. **Elenco recenti e sessione riorganizzati dentro, senza cambi visibili.** `app/lib/recents.dart`, `session_store.dart`, `document_tab.dart`.
8. **Riordino interno dell'editor di Ben, senza funzioni nuove:** incolla, cronologia, trascinamento selezione, sessione del testo, comportamento degli strumenti. `editing_controller.dart`, `editing_overlay.dart`, `pdf_editor_view.dart`, `editor_screen.dart`. Sono i conflitti pesanti; dentro ci sono le frecce e la casella di testo dell'utente. **Punto 3 del piano: letto, non preso (vedi sopra).**
9. **`.gitignore` e `app/README.md`.** Marginali.

**Corrispondenza tra i punti del piano del 07/11 e i gruppi di questo elenco**

| Punto del piano | Gruppo dell'elenco |
|---|---|
| 1 vista a due pagine | "Già dentro" (vista a due pagine) |
| 2 controller | parte del gruppo 8 |
| 3 overlay e sessione del testo | gruppo 8 (e in parte il 5) |
| 3-bis menu accessibili | gruppo 3 |
| 4 tasto X del pannello strumenti | non nell'elenco (nasce dal conflitto nel pannello strumenti di `editing_toolbar.dart`) |
| 5 annulla/ripeti per sistema | gruppo 3 |
| 6 azioni in basso nei "paletti" | non nell'elenco (richiesta dell'utente del 07/11) |

Ultima build del ramo prova verificata verde: #10030 (`1986af0`). #10031 (`c4dad47`) è in elaborazione. #10029 è fallita perché il visualizzatore nuovo non compilava senza il punto 2: corretta da #10030.

## Regole dell'utente (valgono sempre, le ripete da mesi)

- Nessuna azione senza un suo "ok / sì / vai". Si può proporre, non eseguire.
- Mai popup con bottoni (`ask_user_input_v0`). Le domande, se servono, sono testo normale e una sola.
- Niente resoconti lunghi, niente suggerimenti, nemmeno di sicurezza. A fine lavoro basta "ok".
- Ogni modifica è seguita da commit, push e build Actions. Non si aspetta l'esito della build per ridare la chat.
- Le **sue modifiche restano sempre**. Si prende la versione dello sviluppatore solo se ha fatto la stessa cosa meglio.
- **I menu dell'utente si tengono sempre.** Quello che aggiunge Ben si mette nei menu dell'utente, nella voce a cui si associa meglio; se non c'è, nella sezione provvisoria "Da organizzare". Il riordino dei menu lo farà l'utente più avanti. Mai adottare il menu di Ben.
- **Tutto quello che Ben aggiunge e che entra nel lavoro dell'utente (menu, voci, frasi, messaggi) deve essere sempre tradotto in italiano.** Se Ben lo lascia in inglese o senza traduzione, si traduce prima di chiudere il conflitto. Un testo nuovo in inglese nell'app dell'utente non va mai lasciato.
- **Un conflitto alla volta sul ramo prova**: si risolve, commit, push, build. Poi si aggiorna questo file (stato e commit). `main` non si tocca senza il suo ok.
- Non gli interessano numeri di righe, numeri di file, statistiche. Spiegare in italiano semplice cosa fa ogni cosa.
- **Prima di parlare di un conflitto bisogna averlo letto.** Se non lo si è letto, dirlo subito. Descrivere conflitti mai visti lo ha fatto infuriare.
- Il token GitHub non va mai scritto in file, commit o risposte. Se serve, lo dà lui nella chat.

- **Gli appunti di lavoro si scrivono solo in questo file (`CONFLITTI-FUSIONE.md`), non in `DA-FARE.md`** (deciso dall'utente il 07/11). `DA-FARE.md` è stato riportato com'era prima delle note del 07/11.

## Il progetto

- Repo dell'utente: `tesonepdf/dart-pdf` (**pubblico**, verificato con l'API il 2026-10-30: Ben può vedere i commit). Copia modificata di `ben-milanko/dart-pdf` ("Ben", "Milanko", "lo sviluppatore"), che fa moltissimi commit al giorno.
- Obiettivo: portare nel suo repo tutte le novità di Ben, tenendo le modifiche dell'utente. Le sue modifiche principali: casella di testo con frecce, X e adattamento (`editing_overlay.dart`); sistema aggiornamenti (pre-release Android, architetture); foto come PDF; apertura PDF e immagini; traduzioni italiane.
- Flusso deciso (punti 1 e 2 del piano, chiusi):
  - Due percorsi paralleli che non si incontrano mai, se non nel merge.
  - `main` = app ufficiale "DartPDF" (`it.tesonepdf.pdf`). Una sola release normale, tag `app-android-latest`, marcata "Latest", senza pre-release.
  - `prova-sviluppatore` = app "DartPDF Prova" (`it.tesonepdf.pdf.prova`), si installa accanto all'altra. Una sola release normale, tag `app-android-prova`, mai "Latest".
  - Le novità di Ben si uniscono prima in `prova-sviluppatore`; i conflitti si risolvono lì; l'utente prova l'app Prova; solo dopo il suo ok si fa **merge git** in `main` (niente copia dei file, niente rinomina del ramo). Alla fusione dopo si riparte da `main`.
  - Ogni app ha il proprio controllo aggiornamenti: legge solo la propria release, scarica l'APK da dentro l'app.
  - Le modifiche a workflow, release e canali si fanno su `main` e poi si portano nel ramo prova con un merge.
- Applicato il 2026-10-30: `build.yml` pubblica una sola release normale per canale (commit `2e380312` su main, merge `c7191aa2` su prova). Non crea più `build-N` / `prova-N`.
- **Numeri build separati: applicato il 2026-10-30** nel workflow (ogni ramo continua dal numero della propria release, la prova parte da 10001 (nessuna lettera nel titolo)). Dettagli e codice in `DA-FARE.md`.

## Riferimenti git

| Cosa | Commit |
|---|---|
| Base della copia (ufficiale 11.0.0+48) | `3e0bd1b0c0e5b4ab336a8d584510a3a0e43e607a` |
| `main` prima della fusione | `ebdf12bc` |
| Ufficiale usato nella fusione (13.0.0+50) | `f5efa6e525494b24c0ab2049916d1dbe8546a94c` |
| Commit di fusione (due genitori) | `396573c3` su `prova-sviluppatore` |
| Ufficiale oggi | `c64a54f9` (due commit più nuovi di quello unito; l'utente ha detto di **lasciarli stare** per ora) |

Per rivedere un file: aggiungere il remote `upstream` (https://github.com/ben-milanko/dart-pdf.git, pubblico), `git fetch upstream main`, poi `git diff <base> <tuo>` e `git diff <base> <ufficiale>` sullo stesso file.

## I 14 conflitti di codice

**Stato al 30/10: tutti e 14 i conflitti sono chiusi sul ramo prova.** Restano: provare "DartPDF Prova" sul telefono, e solo con l'ok dell'utente il merge in `main`. I file `CONFLITTI-FUSIONE.md` e `DA-FARE.md` su `main` sono rimasti indietro rispetto a questi del ramo prova (e in parte sbagliati): al merge vanno presi quelli del ramo prova.

Legenda stato: **CHIUSO** = deciso e applicato · **DA FARE** = va letto e deciso con l'utente · **IN CORSO** = applicato, build non ancora verificata.
Percorsi relativi alla radice. Dopo ogni conflitto: commit, push su `prova-sviluppatore`, build.

### 1. `app/lib/update.dart` — CHIUSO (resta il tuo)
- **Tecnico:** logica di controllo aggiornamenti. L'utente ha il riconoscimento della release Android (pre-release prima, ora release normale), i marcatori `app-build`/commit e il controllo delle architetture. Ben ha riscritto le stesse righe (asset compatibili, versioni saltate persistenti). Tenuta la versione dell'utente.
- **In italiano:** il pezzo che decide se c'è una versione nuova dell'app. Hai già il tuo, che funziona con la tua pagina delle release. Quello di Ben fa una cosa simile ma non conosce le tue release.

### 2. `app/lib/update_distribution_io.dart` — CHIUSO (resta il tuo)
- **Tecnico:** rileva su che telefono gira l'app (architettura, canale). Tenuto il file dell'utente.
- **In italiano:** serve a scegliere il file giusto da scaricare per il tuo telefono.

### 3. `app/lib/update_distribution_stub.dart` — CHIUSO (verificato)
- **Tecnico:** collisione solo apparente. Base: `defaultStoreManagedUpdateChannel`. Ben ha aggiunto `defaultUpdateArchitecture`. L'utente ha aggiunto la stessa riga più `defaultAndroidSupportedAbis`. Il file attuale contiene tutto.
- **In italiano:** i due avevano aggiunto la stessa cosa. Non c'era niente da scegliere.

### 4. `app/test/update_test.dart` — CHIUSO (restano i tuoi controlli)
- **Tecnico:** test del servizio di aggiornamento. Il file fuso conteneva i test dell'utente (release Android rolling, scelta ABI, store iOS) mescolati con quelli di Ben (versioni saltate persistenti, asset compatibili, ABI sconosciuta, riscrittura dei test nightly). Scelta dell'utente: **solo i suoi**; il file è tornato alla versione `ebdf12bc`. Nei suoi test la parola "prerelease" compare una sola volta, in un commento sul canale nightly: nessun test controlla il flag pre-release di GitHub. I test non sono eseguiti dalla build dell'APK (`build.yml` non ha `flutter test`) e non sono stati eseguiti in locale (Flutter assente): non è verificato che compilino contro l'`update.dart` fuso.
- **In italiano:** i controlli sull'aggiornamento sono quelli tuoi. Quelli di Ben non ci sono: se li rifarà o li cambierà, se ne parla. Non c'è nessun controllo sulla pre-release.

### 5. `app/test/update_settings_test.dart` — CHIUSO (restano i tuoi controlli, nessuna modifica al file)
- **Tecnico:** utente e Ben hanno aggiunto in modo indipendente lo stesso test, `Settings skips notifications but keeps manual installation`. Ben ha in più `startup banner can skip a version across screen restarts` (banner di avvio con "salta", ricordato al riavvio) e ha cambiato i dati di prova (asset macOS, `architecture: 'x64'`). L'utente ha in più `Android startup check offers the user a new APK`. Il test di Ben non si adatta: nell'app dell'utente l'avviso all'avvio è un popup (Scarica / Dopo / Salta), non più un banner. Scelta dell'utente: lasciare i suoi, come nel conflitto 4. Il file resta com'è (422 righe).
- **In italiano:** tu e Ben avete scritto lo stesso controllo senza saperlo. Quello in più di Ben riguarda un avviso che nella tua app è diventato un popup, quindi non lo aggiungiamo.

### 6. `app/lib/editor_screen.dart` — CHIUSO (restano le tue funzioni)
- **Tecnico:** sei punti di conflitto in tre zone. (a) Avviso aggiornamenti: Ben ha un banner con Dopo/Salta (`update-banner-skip`, commit `a3b2ab74`), l'utente ha il popup Scarica/Dopo/Salta più banner fisso dopo "Dopo": **tuo**. (b) Apertura foto come PDF (4 punti: `looksLikePdf`, `imageBytesToPdfAsync`, `imageTitleAsPdf`, `isImageFileName`; in un punto la differenza è solo il nome della variabile `rawBytes`/`bytes`): **tuo**. La funzione è entrata il 28/10 con il commit `6b19ecd3` (#43), insieme alla casella di testo. (c) Menu: **tuo**, ripristinato col 12. Nessuna modifica al codice in questo passo.
- **In italiano:** la schermata principale. Resta tutto come l'hai voluto tu: popup aggiornamenti, foto aperte come PDF e il tuo menu.
- **Limite noto della parte (b):** la foto aperta diventa un PDF di una pagina con larghezza A4 (`dpi = larghezza * 72 / 595,28`), quindi viene ingrandita a tutto il foglio. Non è la grandezza reale che serve. Vedi "Funzioni nuove" in `DA-FARE.md`.

### 7. `app/lib/file_io.dart` — CHIUSO (resta il tuo, nessuna modifica al codice)
- **Tecnico:** due righe. Il filtro del dialogo Apri usa `documentTypeGroup` (pdf, jpg, jpeg, jpe, png, bmp, gif, webp, tif, tiff, heic, heif) invece di `pdfTypeGroup` di Ben, e il selettore multiplo web usa `pickDocumentFilesWeb` invece di `pickPdfFilesWeb`. Nel file c'è anche la novità di Ben `xdpTypeGroup` / `openableTypeGroups` per aprire i pacchetti XDP: non era un conflitto ed è rimasta.
- **In italiano:** nella finestra "Apri file" puoi scegliere PDF e foto, non solo PDF. Resta così, come per il punto 6.

### 8. `app/lib/web_file_picker.dart` — CHIUSO (resta il tuo, nessuna modifica al codice)
- **Tecnico:** un solo punto: la funzione `pickDocumentFilesWeb` (accept `.pdf,application/pdf,image/*`), che Ben non ha. Resta anche `pickPdfFilesWeb`.
- **In italiano:** lo stesso discorso del 7, ma per l'app che gira nel browser: sceglie anche le foto.

### 9. `packages/dart_pdf_editor/lib/src/editing/editing_overlay.dart` — CHIUSO (restano le tue funzioni; tolte le frecce da tastiera)
- **Tecnico:** collisione tra due aggiunte vicine nel gestore dei tasti dell'editor di testo: (a) dell'utente, le frecce della **tastiera** spostavano la casella a testo vuoto (`_moveTextEditBox(event.logicalKey)`, 13 righe); (b) di Ben, Alt+Z adatta la casella al testo (`_autosizeTextEdit`, commit `7025e617`, #1188). Scelta dell'utente: restano le sue funzioni, **ma le frecce da tastiera devono muovere solo il cursore nel testo**: ho **tolto il blocco (a)** (13 righe). Le frecce a schermo ai lati della casella (`_buildEditArrows`, righe ~4107 e 8559) restano e non hanno condizioni di piattaforma, quindi compaiono anche su Windows (letto nel codice, non provato). `_moveTextEditBox` resta, usato da quelle frecce. Alt+Z di Ben resta finché non c'è l'adattamento automatico (vedi `DA-FARE.md`). Il test `editing_arrow_nudge_test.dart` riguarda le frecce su un'annotazione selezionata, non questa.
- **In italiano:** le frecce della tastiera muovono solo il cursore dentro il testo. Per spostare la casella usi le frecce disegnate ai suoi lati, quelle che hai fatto su Android, che compaiono anche su Windows. L'Alt+Z di Ben resta per ora; poi lo sostituiamo con l'adattamento automatico.
- **Confermato dall'utente (30/10):** le frecce della tastiera muovono solo il cursore, e **anche su Windows le frecce disegnate restano fuori dal riquadro della casella di testo**.

### 10. `app/lib/l10n/app_it.arb` — CHIUSO (resta il tuo, deciso dall'utente il 30/10)
- **Tecnico (verificato chiave per chiave):** Ben aggiunge 31 chiavi italiane e non cambia nessuna esistente. Il file dell'utente ha le stesse 31 chiavi con testo identico a quello di Ben, più 15 chiavi che l'utente ha tradotto in italiano mentre Ben le lascia in inglese (OCR automatico, firme, elenco Adobe). Nessuna chiave è stata cambiata da tutti e due. Il file nel ramo prova è identico a quello dell'utente: non si perde nessuna frase di Ben. **La riga precedente di questo file ("le stringhe nuove di Ben non ci sono") era sbagliata.**
- **In italiano:** i testi italiani dell'app restano i tuoi. Hanno già tutte le frasi nuove di Ben, e in più le tue 15 traduzioni.

### 11. `app/lib/l10n/app_localizations_it.dart` — CHIUSO (resta il tuo, confermato dall'utente il 30/10)
- **Tecnico (verificato):** codice Dart generato dal file del punto 10. In `app/pubspec.yaml` il Dart generato è tenuto nel repo (nessun passo di generazione in build), quindi deve restare coerente con l'`.arb`. Controllato: tutte le 390 chiavi dell'`.arb` hanno il codice corrispondente e, per quelle senza segnaposto, il testo è identico. Nessuna differenza.
- **In italiano:** la parte tecnica dei testi italiani. Va d'accordo con il file delle frasi, quindi non c'è niente da sistemare: segue la scelta del punto 10.

### 12. `app/lib/app_menu_sheet.dart` — CHIUSO (menu dell'utente + sezione "Da organizzare"; confermato dall'utente il 30/10)
- **Tecnico:** ripristinato il file dell'utente (File / Questo documento / App, ricerca, sottomenu recenti). Aggiunto il parametro opzionale `toOrganize` e una sezione "Da organizzare" che contiene le azioni `formData` di Ben (FDF/XFDF/XDP). In `editor_screen.dart` la chiamata a `showAppMenuSheet` usa di nuovo i parametri dell'utente. Corregge l'errore `appItemCount`.
- **In italiano:** il tuo menu del telefono è tornato com'era. Le novità di Ben per importare ed esportare i moduli stanno in una sezione "Da organizzare", finché non decidi dove metterle.
- **Non fatto:** il menu di Windows (popup) mette ancora le voci dei moduli all'inizio del blocco Documento. Da riordinare con te insieme a tutti gli altri menu.

### 13. `packages/dart_pdf_cli/bin/dartpdf.dart` — CHIUSO (resta il numero di Ben, 0.10.0; deciso dall'utente il 30/10: non sono numeri suoi, non c'è motivo di tenerli)
- **Tecnico (verificato):** il conflitto è una sola riga: `const _version`. Base `0.8.0`; nel repo dell'utente `0.9.0`; in Ben `0.10.0`. Entrambi i numeri sono di Ben: `0.9.0` è del suo commit `bf6ba79b` (Release 12.0.0+49), `0.10.0` del suo `f5efa6e5` (13.0.0+50). L'utente non ha fatto nessuna modifica propria a questo file. Nel ramo prova il file è identico a quello di Ben.
- **In italiano:** il numero di versione del programma da riga di comando `dartpdf`, non dell'app Android. Il tuo era solo una versione più vecchia di Ben. Non c'è niente di tuo da proteggere.

### 14. `metainfo.xml` (due copie: `app/linux/` e `app/packaging/flatpak/desktop-assets/`) — CHIUSO (resta la versione di Ben; deciso dall'utente il 30/10)
- **Tecnico:** esistono due copie (`app/linux/dev.milanko.dartpdf.metainfo.xml` e `app/packaging/flatpak/desktop-assets/dev.milanko.dartpdf.metainfo.xml`); quale fosse in conflitto non è verificato. Solo versione e note.
- **In italiano:** la scheda dell'app per Linux. Non ti riguarda.

### Registro dei passi sul ramo prova

| Passo | Commit | Build |
|---|---|---|
| 1, 2, 3 chiusi | già nel ramo | — |
| 12 menu ripristinato + sezione "Da organizzare" | `0e471cf1` | da verificare su GitHub Actions |
| 4 test aggiornamenti: restano i tuoi | `6254b50a` | da verificare su GitHub Actions |
| 5 test schermata aggiornamenti: restano i tuoi | `0a9bf733` | da verificare su GitHub Actions |
| 6 schermata principale: restano le tue funzioni (nessuna modifica al codice) | `93907a7b` | — |
| 7 e 8 apertura file: restano le tue (nessuna modifica al codice) | `06c0ea16` | — |
| 9 casella di testo: restano le tue funzioni, tolte le frecce da tastiera | vedi `git log` del ramo | da verificare su GitHub Actions |
| 10 traduzioni italiane: resta il tuo file (nessuna modifica al codice) | questo commit | da verificare su GitHub Actions |
| 11 file italiano generato: resta il tuo (nessuna modifica al codice) | questo commit | da verificare su GitHub Actions |
| 13 versione del programma da riga di comando: resta quella di Ben (nessuna modifica al codice) | questo commit | da verificare su GitHub Actions |
| 14 note di versione Linux: resta quella di Ben (nessuna modifica al codice) | questo commit | da verificare su GitHub Actions |

Altri conflitti, già risolti senza discussione: 25 file di versioni/changelog dei pacchetti (presi dall'ufficiale con gli indirizzi `tesonepdf` rimessi); 29 file che nel repo dell'utente non esistono (sito, flussi di compilazione di Ben, `CLAUDE.md`, `doc`): esclusi.

## Quattro scelte prese da me, mai approvate dall'utente (da rivedere)

1. Aggiornamenti: tenuta la versione dell'utente senza fonderla con quella ufficiale.
2. Menu del telefono: adottato quello ufficiale (ma `app_menu_sheet.dart` risulta misto, vedi punto 12).
3. Foto come PDF: tenuta, anche se l'utente aveva detto di non averla modificata.
4. Casella di testo: tenuta quella dell'utente.

## Stato delle build (verificato con l'API di GitHub)

**Aggiornamento 07/11:** quanto scritto sotto è del 30/10 ed è superato: l'errore `appItemCount` è chiuso. La CI del ramo prova passa (analyze, test, build APK debug) dal commit #10026; ultima build verificata verde #10030 (`1986af0`).

- `main`: build #73 e #76 riuscite.
- `prova-sviluppatore`: build #74, #75, #77, #80 **tutte fallite** nel passo "Compila l'APK". **Causa (dal log incollato dall'utente):** `app/lib/app_menu_sheet.dart` usa `appItemCount` (righe 202 e 204) ma la fusione ne ha perso la definizione, che nella versione dell'utente era una variabile locale di `_buildMain`. È il conflitto 12. Il log completo non si scarica dall'ambiente della chat (dominio bloccato): se servono altri errori li incolla l'utente. L'app Prova sul telefono non è aggiornata. Compilare in locale non è possibile (Flutter non è installato).

## Altre cose in sospeso

- Web app: l'utente vuole una web app per non dover aggiornare l'app Windows. Se ne è solo parlato; niente è stato fatto né deciso. Vercel (strumenti connessi alla chat) e il target hosting `tesonepdf-dart-pdf` esistono; non verificato che funzionino. Da fare dopo i conflitti, salvo diversa decisione.
- Le vecchie release `build-N` e `prova-N` (tag `prova-59`, `prova-60`, `prova-65`, `prova-67` e le `build-N`) sono rimaste su GitHub: cancellarle solo se lo chiede l'utente.
- Le due build lanciate col cambio di workflow (#76 main riuscita, #77 prova fallita) non hanno ancora convertito il tag della prova da pre-release a release normale, perché la build prova non è arrivata allo step di pubblicazione.
