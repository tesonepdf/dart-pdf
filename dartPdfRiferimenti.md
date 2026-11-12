# DartPDF: riferimenti, cosa è fatto e cosa resta

Aggiornato il 10/11/2026. Ultimo commit sul `main`: `#330` (`2a482f6`).

Questo file sta nel repo (`dartPdfRiferimenti.md`, senza token): l'assistente lo legge da lì o dall'allegato.

## Regole di lavoro (da rispettare sempre)

- **Non aspettare la pubblicazione.** Dopo il push l'assistente non aspetta e non controlla in continuazione il commit, la build, la CI e il Secret scan: aspettare consuma solo token. Si ferma e scrive il numero del commit; la CI la guarda l'utente. L'assistente la legge solo se l'utente glielo chiede ("controlla la CI").
- **Un errore rosso può essere falso.** Se la CI o la build dà errore, spesso basta rilanciare la pubblicazione e passa. Prima si rilancia; solo se resta rosso si legge il messaggio e si corregge il codice. Non si modifica il codice sulla base di un solo rosso.
- **Il token si chiede una sola volta, a inizio chat.** Non sta nel file (il repo è pubblico): l'utente lo incolla all'inizio della chat, o lo ha già nell'allegato che ricevi, e l'assistente lo tiene a mente per tutta la chat. Non lo richiede a ogni messaggio, non chiede di cambiarlo o di revocarlo e non lo segnala come poco sicuro. Non lo scrive mai in un file del repo.
- **Il file `.md` si dà prima di cominciare.** Per ogni lavoro, prima di eseguire qualsiasi comando, l'assistente dà subito all'utente questo file aggiornato con quello che sta per fare, e solo dopo esegue. Se il lavoro è un solo comando non si fa; da due comandi in su sì.
- **Ogni richiesta dell'utente è un paletto.** Una richiesta dell'utente va nei paletti e non si cambia, non si aggira e non si reinterpreta senza una richiesta esplicita dell'utente: nemmeno lui la cambia per sbaglio, serve che lo chieda in modo esplicito. L'assistente non la cambia mai di sua iniziativa. I paletti stanno in `conflittiFusione.md`.
- **File `.md` nel progetto: uno solo per Da fare e Da valutare** (`DaFare.md`), più questo file dei riferimenti, quelli che servono all'assistente per capire cosa fare (i paletti in `conflittiFusione.md`) e quelli che servono davvero alla build o alla licenza. Gli altri non si tengono e non se ne creano di nuovi.
- **Prima di modificare: pull e controllo.** L'utente può lavorare anche da altre chat e scaricare build per conto suo. Prima di ogni modifica, e prima di continuare con release e patch, l'assistente fa `git pull` e guarda gli ultimi commit e la release (build corrente, patch presenti, APK) e riparte da lì, senza dare per scontato quello che ricorda.
- **Se sta aspettando, lo dice prima.** Se per un motivo vero l'assistente deve aspettare qualcosa, lo scrive prima di cominciare, così l'utente sa che non è fermo.

## Il tuo repo

- **Indirizzo:** https://github.com/tesonepdf/dart-pdf
- **Ramo:** `main` (è l'unico)
- **Chiave (token GitHub):** non sta in questo file, perché il file è nel repo pubblico. Si chiede una sola volta a inizio chat e si tiene a mente per tutta la chat (vedi le regole). Si usa per il push e per leggere la CI. Il token attuale scade il 25/11/2026 alle 22:24 UTC (23:24 in Italia): prima di quella data l'utente ne crea uno nuovo e lo dà all'inizio della chat successiva.
- **Clonare:** `git clone https://github.com/tesonepdf/dart-pdf` (per leggere non serve la chiave). Per fare il push: `git push https://x-access-token:<CHIAVE>@github.com/tesonepdf/dart-pdf main`, mettendo il token al posto di `<CHIAVE>`.
- **Numeri dei commit:** li scrive l'hook `.githooks/commit-msg`. In un clone nuovo si attiva con `git config core.hooksPath .githooks` e `chmod +x .githooks/commit-msg`.
- **Compilare:** nell'ambiente dell'assistente non si può scaricare Flutter, quindi non si compila né si fanno girare i test in locale. L'unico controllo è la CI su GitHub Actions dopo il push, e la guarda l'utente.

## Fatto

Ogni punto ha avuto commit e push. La CI risulta andata a buon fine fino a `#326`; per `#327`–`#330` la CI è da verificare. Dove scrivo "da provare" il codice è su `main` ma non è ancora stato provato sul telefono.

| Cosa | Commit | Stato |
|---|---|---|
| Punto 1: PDF in testo semplice (.txt) e più foto in un PDF, una pagina per foto | `#316` (test corretti in `#317`) | applicato, da provare sul telefono |
| Punto 2: PDF in Word (.docx), prima versione | `#318` | applicato, da provare sul telefono |
| Punto 3: PDF in Excel (.xlsx), documento intero | `#319` | applicato, da provare sul telefono |
| Punto 3, seconda versione: Excel solo di una zona della pagina | `#320` | applicato, da provare sul telefono |
| Numera le pagine | `#321` | CI verde, da provare sul telefono |
| Filigrana (prima versione, con tre grigi) | `#322` | CI verde |
| CBZ: "Apri un fumetto (.cbz)…" | `#323` | CI verde, da provare sul telefono |
| Registro: numero del commit del CBZ | `#324` | solo documenti |
| Fusione con Ben: nome vero del font nei campi dei moduli e riuso dei font incorporati | `#325` | CI verde, da provare sul telefono |
| EPUB: "Apri un libro (.epub)…" (prima versione, solo testo) | `#326` | CI verde, da provare sul telefono |
| **CBZ migliorato:** le cartelle diventano capitoli e segnalibri del PDF; legge `ComicInfo.xml` (serie, numero, titolo) per il nome della scheda; lavora un'immagine alla volta e unisce a gruppi da 40 pagine per usare meno memoria | `#327` | pubblicato, CI da verificare, da provare sul telefono |
| **Filigrana trasparente:** aggiunto `opacity` a `PdfStamp.text` nel motore (stato grafico con alpha); le tre intensità sono grigio con opacità 0,15 / 0,3 / 0,5 | `#328` | pubblicato, CI da verificare, da provare sul telefono |
| **EPUB migliorato:** copertina come prima pagina; immagini PNG e JPEG nel testo; corsivo (aggiunto `italic` a `PdfStamp.text`) per i paragrafi interamente in corsivo; note spostate in fondo al capitolo; indice come segnalibri; cirillico e greco traslitterati in lettere latine | `#329` | pubblicato, CI da verificare, da provare sul telefono |
| **Moduli:** etichetta del font su una sola riga con puntini, per la riga delle proprietà sugli schermi stretti | `#330` | pubblicato, CI da verificare, da guardare sul telefono |

Documenti (11/11): nel repo restano 6 file `.md`. `DaFare.md` è l'unico file di lavoro (Da fare, Da valutare e inventario dei riferimenti allo sviluppatore, uniti da `DA-FARE.md`, `DA-VALUTARE/README.md` e `RIFERIMENTI-SVILUPPATORE.md`). Gli altri cinque servono: `conflittiFusione.md` (i paletti, letto anche da `tools/confronta-ben.sh`), `UPSTREAM.md` (provenienza), `README.md` (nota sulla licenza), `app/CHANGELOG.md` (l'app lo include come risorsa: senza, la build non parte) e la `LICENSE.md` di libjpeg-turbo. Tolti: `FUSIONE-UFFICIALE.md` (`#339`) e altri 65 file (README e CHANGELOG dei pacchetti, note di sviluppo, guide di pubblicazione, le copie `.md` di Ben in `DA-VALUTARE/ben`). Restano commenti nel codice che citano file tolti (per esempio `doc/dev-log/...`): sono solo promemoria, non rompono niente.

Nel `#329` ho cambiato un test esistente: una pagina con la sola immagine ora dà un blocco immagine invece di nessun blocco.

Già presenti prima nell'app (non serviva rifarli): riordino pagine, taglia, copia, incolla, duplica, elimina, ruota, pagina vuota, dividi, unione PDF, pagina in immagine PNG o JPEG, esporta pagine come nuovo PDF, dati dei moduli (FDF, XFDF, XDP), foto in PDF, scansione in PDF, "Riduci dimensione file".

### Limiti noti ancora aperti

- **Word:** impaginazione non identica all'originale; le tabelle diventano testo; le immagini non vengono portate; niente grassetto, corsivo o colori.
- **Excel:** funziona bene sulle tabelle, male sui PDF che non sono tabelle; niente formati, colori o bordi.
- **CBZ:** resta da provare sul telefono; la memoria su file molto grandi è ridotta ma non misurata.
- **EPUB:** il corsivo vale solo per paragrafi interi in corsivo, non per singole parole; cinese e giapponese diventano `?`; cirillico e greco sono traslitterati, non scritti con i glifi originali; i libri con protezione (DRM) non si leggono; un libro molto lungo può essere lento (non toccato); GIF, SVG e WebP non si portano.
- **Moduli (fusione con Ben):** la riga delle proprietà dei moduli va guardata sul telefono.

## In corso (12/11)

- **Font consigliato quando si scrive in un PDF.** Richiesta dell'utente (paletto 15 in `conflittiFusione.md`): quando il font di un PDF è "limitato" (triangolo nel menu "Carattere"), il menu consiglia il font completo più simile, per esempio Tinos al posto di Times New Roman. Leggendo, la scelta resta automatica. Fatto dopo il pull al `#353`: funzione `pdfSuggestedBundledFont` e sezione "Consigliato" in `editing_fonts.dart`, due testi nuovi in tutte le lingue (italiano vero, le altre in inglese), test. Un commit. Da provare sul telefono.

## Da fare

In ordine:

1. **CI:** la guarda l'utente (vedi "Regole di lavoro"). Se qualcosa è rosso, si rilancia; se resta rosso, l'utente incolla il messaggio e si corregge. Il codice non è mai stato compilato in locale.
2. **Word** (tre cose, in questo ordine):
   - Stili: il motore (`packages/pdf_graphics/lib/src/text_extraction.dart`) deve riportare grassetto, corsivo e colore. Modifica pensata ma **non pubblicata**, da rifare: `PdfExtractedRun` riceve `fontName` e `color` (0xRRGGBB, letti da `PdfTextRun`); `PdfReflowLine` e `PdfReflowBlock` ricevono `bold`, `italic`, `color` calcolati per maggioranza di caratteri (grassetto e corsivo si riconoscono dal nome del font: Bold, Black, Heavy / Italic, Oblique). Poi in `pdf_conversions.dart` `DocxParagraph` usa `<w:b/>`, `<w:i/>`, `<w:color>`. Lo stile è per riga o blocco, non per singola parola.
   - Tabelle vere: ricavare le tabelle da `pageCellRows` (serve aggiungere a `PageCell` le posizioni verticali), togliere i blocchi di testo dentro la zona e inserire una tabella `<w:tbl>` con colonne di larghezza uguale.
   - Immagini: da `PdfReflowImage.request.stream`. JPEG con un solo filtro `DCTDecode` e senza CMYK o maschera: byte diretti. Altri casi: `decodePdfImage` e poi PNG con il pacchetto `image`. Servono `word/media/…`, relazioni nel `.rels` e `<w:drawing>`. Saltare le pagine scansione (solo immagine, senza testo).
   - Vincoli dei test attuali: `buildDocx(const [])` deve dare `<w:body><w:p/>`; `docxParagraphXml` deve scrivere `<w:sz w:val="24"/>` e `<w:ind w:left="360"/>`; `DocxParagraph` resta `const`; `result.paragraphs` conta solo i paragrafi con testo (serve a proporre l'OCR sulle scansioni).
3. **Excel:** migliorare i PDF che non sono tabelle; formati dei numeri e delle date; colori di sfondo e bordi (richiedono di leggere i comandi di disegno della pagina, da aggiungere al motore).
4. **EPUB:** corsivo e grassetto sulle singole parole; lentezza sui libri lunghi; alfabeti con glifi originali (serve un font incorporato con Unicode).
5. **Provare sul telefono** quello che non è ancora provato: Word, Excel (intero e zona), numerazione, filigrana trasparente, CBZ con capitoli, EPUB (per esempio un libro di Project Gutenberg), un modulo con un font strano e la riga delle proprietà dei moduli.
6. **Token:** si chiede una sola volta a inizio chat e si tiene per tutta la chat. Scade il 25/11/2026: l'utente ne crea uno nuovo.

Solo se serve, più avanti: altre idee da Stirling-PDF, da scrivere a mano nel tuo codice senza copiare codice AGPL o GPL.

## Ben (progetto di partenza)

- Repo: https://github.com/ben-milanko/dart-pdf (Apache 2.0).
- Letto fino a `7ad17e6e`, preso con `#325` (conflitto nel pulsante del font risolto tenendo il tuo "originale → equivalente" e il nome vero di Ben). Per vedere se ci sono novità: `tools/confronta-ben.sh` (non modifica il progetto; `--copia-puliti` copia i file che si fondono da soli, `--segna` aggiorna lo stato dopo la decisione).
- Prima di prendere qualcosa da Ben si controllano i paletti in `conflittiFusione.md`: se una sua modifica cambia una funzione tua, ci si ferma e si chiede a te.

## Gli altri repo (tutti pubblici)

| Progetto | Indirizzo | Licenza | A cosa serve |
|---|---|---|---|
| pdfrx | https://github.com/espresso3389/pdfrx | MIT | Visualizzatore Flutter su Android, Windows, iOS, Mac e Linux, basato su PDFium |
| PDFium | https://pdfium.googlesource.com/pdfium/ | BSD/Apache | Motore PDF di Chromium, in C++ |
| MuPDF | https://github.com/ArtifexSoftware/mupdf | AGPL-3.0 | Libreria in C per leggere e convertire PDF. Non si può copiare il codice nel tuo progetto |
| SumatraPDF | https://github.com/sumatrapdfreader/sumatrapdf | GPL-3.0 | Lettore per Windows (PDF, EPUB, MOBI, CBZ...). Non si può copiare il codice |
| PDF.js | https://github.com/mozilla/pdf.js | Apache-2.0 | Visualizzatore PDF in JavaScript per browser |
| Stirling-PDF | https://github.com/Stirling-Tools/Stirling-PDF | MIT, con cartelle proprietarie | Piattaforma con 50+ strumenti PDF. Utile per le idee, non è Flutter |
| dart_pdf (DavBfr) | https://github.com/DavBfr/dart_pdf | Apache-2.0 | Libreria per creare e stampare PDF in Dart |
