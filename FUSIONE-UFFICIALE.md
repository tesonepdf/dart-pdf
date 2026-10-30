# Fusione con la versione ufficiale 13.0.0+50

Ramo di prova: `prova-sviluppatore` (commit `396573c3`). `main` **non è stato toccato**.
Progetto ufficiale: https://github.com/ben-milanko/dart-pdf

## Cosa ho trovato

- Il tuo repo e l'ufficiale **non avevano storia in comune**: la copia era partita da zero.
  Per questo un `git merge` normale non funzionava. Ho usato come punto di partenza
  il commit di base indicato in `UPSTREAM.md` (`3e0bd1b`, versione 11.0.0+48).
- Dalla base l'ufficiale ha pubblicato due versioni:
  - **12.0.0+49**: nuvolette con nota, ricerca testo da oscurare, snapshot vettoriali in PNG,
    righelli e guide, barre più compatte, correzioni su oscuramento e anteprima di stampa.
  - **13.0.0+50**: import/export FDF, XFDF e XDP, modifica dei link, commenti accanto alle
    annotazioni, selezione di più schede, nuova schermata iniziale, correzioni Android,
    versioni saltate ricordate, anteprima di stampa sulle pagine scelte, scorciatoie X e Alt+Z.
- File cambiati dall'ufficiale: **345**. Di questi **163 erano già identici** nel tuo repo.
- Conflitti reali: **68**, così divisi:
  - 29 su file che nel tuo repo non esistono (sito, flussi di compilazione, `CLAUDE.md`, `doc`);
  - 25 su numeri di versione e changelog dei pacchetti;
  - 14 su codice dell'app.
- Tutto il resto, circa 250 file, si è unito da solo.

## Cosa ho fatto

Per i 14 conflitti di codice ho scelto così:

| File | Scelta | Motivo |
|---|---|---|
| `update.dart`, `update_distribution_io/stub.dart`, test `update_test.dart` e `update_settings_test.dart` | **tuo** | sistema di aggiornamenti sistemato insieme in chat (pre-release Android, architetture) |
| `editor_screen.dart` (popup aggiornamenti) | **tuo** | popup Scarica / Dopo / Salta e controllo versione ufficiale |
| `editor_screen.dart` (foto come PDF) | **tuo** | funzione già presente nel tuo repo |
| `file_io.dart`, `web_file_picker.dart` | **tuo** | apertura di PDF e immagini |
| `editing_overlay.dart` | **tuo** | frecce per spostare la casella di testo vuota |
| `app_it.arb`, `app_localizations_it.dart` | **tuo** | traduzioni italiane |
| `app_menu_sheet.dart`, `editor_screen.dart` (menu) | **ufficiale** | menu telefono nuovo con voci FDF/XFDF/XDP |
| `dartpdf.dart`, `metainfo.xml` | **ufficiale** | solo numero di versione e note di rilascio |

Altro:

- 25 file di versione e changelog: presi dall'ufficiale, con i tuoi indirizzi `tesonepdf` rimessi.
- 29 file non tuoi (sito, flussi di compilazione dell'ufficiale, `CLAUDE.md`, `doc`): esclusi.
- Il commit di fusione ha **due genitori** (`main` e `upstream/main`): da ora l'ufficiale
  è antenato del tuo repo e i prossimi merge saranno normali.

## Dove ho deciso io senza chiederti

Ho preso la tua frase "ho modificato solo la casella di testo e il menu delle impostazioni
carattere" come risposta alle quattro scelte. Non lo era. In particolare:

1. **Aggiornamenti**: ho tenuto la tua versione senza fonderla con quella ufficiale.
2. **Menu del telefono**: ho adottato quello ufficiale.
3. **Foto come PDF**: l'ho tenuta, anche se hai detto di non averla modificata.
4. **Casella di testo**: tenuta la tua.

## Cosa non è verificato

- Non ho potuto compilare in locale (Flutter non è installato nel mio ambiente):
  la build su GitHub Actions è l'unico controllo.
- I test dell'app non sono stati eseguiti.

## Come tornare indietro o rifare

- Scartare tutto: `git branch -D prova-sviluppatore` (non influisce su `main`).
- Rifare una scelta: riparti da `main`, unisci `upstream/main` e cambia solo il lato
  del file interessato.
- Portare in `main` solo dopo la tua conferma.
