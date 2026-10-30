# Conflitti della fusione con l'ufficiale: appunti per chi riprende il lavoro

File per l'utente **e** per l'assistente che apre una nuova chat. Ogni conflitto è scritto due volte: in linguaggio tecnico (per l'assistente) e in italiano semplice (per l'utente).
Aggiornato il 2026-10-30. Cosa fare dopo e il codice: vedi `DA-FARE.md`. Quello che qui è "verificato" l'ho controllato con git; il resto è dichiarato come non verificato.

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

- `main`: build #73 e #76 riuscite.
- `prova-sviluppatore`: build #74, #75, #77, #80 **tutte fallite** nel passo "Compila l'APK". **Causa (dal log incollato dall'utente):** `app/lib/app_menu_sheet.dart` usa `appItemCount` (righe 202 e 204) ma la fusione ne ha perso la definizione, che nella versione dell'utente era una variabile locale di `_buildMain`. È il conflitto 12. Il log completo non si scarica dall'ambiente della chat (dominio bloccato): se servono altri errori li incolla l'utente. L'app Prova sul telefono non è aggiornata. Compilare in locale non è possibile (Flutter non è installato).

## Altre cose in sospeso

- Web app: l'utente vuole una web app per non dover aggiornare l'app Windows. Se ne è solo parlato; niente è stato fatto né deciso. Vercel (strumenti connessi alla chat) e il target hosting `tesonepdf-dart-pdf` esistono; non verificato che funzionino. Da fare dopo i conflitti, salvo diversa decisione.
- Le vecchie release `build-N` e `prova-N` (tag `prova-59`, `prova-60`, `prova-65`, `prova-67` e le `build-N`) sono rimaste su GitHub: cancellarle solo se lo chiede l'utente.
- Le due build lanciate col cambio di workflow (#76 main riuscita, #77 prova fallita) non hanno ancora convertito il tag della prova da pre-release a release normale, perché la build prova non è arrivata allo step di pubblicazione.
