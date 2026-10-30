# Conflitti della fusione con l'ufficiale: appunti per chi riprende il lavoro

File scritto per l'assistente che apre una nuova chat. L'utente non lo deve leggere.
Aggiornato il 2026-10-30. Cosa fare dopo e il codice: vedi `DA-FARE.md`. Quello che qui è "verificato" l'ho controllato con git; il resto è dichiarato come non verificato.

## Regole dell'utente (valgono sempre, le ripete da mesi)

- Nessuna azione senza un suo "ok / sì / vai". Si può proporre, non eseguire.
- Mai popup con bottoni (`ask_user_input_v0`). Le domande, se servono, sono testo normale e una sola.
- Niente resoconti lunghi, niente suggerimenti, nemmeno di sicurezza. A fine lavoro basta "ok".
- Ogni modifica è seguita da commit, push e build Actions. Non si aspetta l'esito della build per ridare la chat.
- Le **sue modifiche restano sempre**. Si prende la versione dello sviluppatore solo se ha fatto la stessa cosa meglio.
- Non gli interessano numeri di righe, numeri di file, statistiche. Spiegare in italiano semplice cosa fa ogni cosa.
- **Prima di parlare di un conflitto bisogna averlo letto.** Se non lo si è letto, dirlo subito. Descrivere conflitti mai visti lo ha fatto infuriare.
- Il token GitHub non va mai scritto in file, commit o risposte. Se serve, lo dà lui nella chat.

## Il progetto

- Repo dell'utente: `tesonepdf/dart-pdf` (privato). Copia modificata di `ben-milanko/dart-pdf` ("Ben", "Milanko", "lo sviluppatore"), che fa moltissimi commit al giorno.
- Obiettivo: portare nel suo repo tutte le novità di Ben, tenendo le modifiche dell'utente. Le sue modifiche principali: casella di testo con frecce, X e adattamento (`editing_overlay.dart`); sistema aggiornamenti (pre-release Android, architetture); foto come PDF; apertura PDF e immagini; traduzioni italiane.
- Flusso deciso (punti 1 e 2 del piano, chiusi):
  - Due percorsi paralleli che non si incontrano mai, se non nel merge.
  - `main` = app ufficiale "DartPDF" (`it.tesonepdf.pdf`). Una sola release normale, tag `app-android-latest`, marcata "Latest", senza pre-release.
  - `prova-sviluppatore` = app "DartPDF Prova" (`it.tesonepdf.pdf.prova`), si installa accanto all'altra. Una sola release normale, tag `app-android-prova`, mai "Latest".
  - Le novità di Ben si uniscono prima in `prova-sviluppatore`; i conflitti si risolvono lì; l'utente prova l'app Prova; solo dopo il suo ok si fa **merge git** in `main` (niente copia dei file, niente rinomina del ramo). Alla fusione dopo si riparte da `main`.
  - Ogni app ha il proprio controllo aggiornamenti: legge solo la propria release, scarica l'APK da dentro l'app.
  - Le modifiche a workflow, release e canali si fanno su `main` e poi si portano nel ramo prova con un merge.
- Applicato il 2026-10-30: `build.yml` pubblica una sola release normale per canale (commit `2e380312` su main, merge `c7191aa2` su prova). Non crea più `build-N` / `prova-N`.
- **Numeri build separati: applicato il 2026-10-30** nel workflow (ogni ramo continua dal numero della propria release, la prova scrive `#Np` solo nel titolo). Dettagli e codice in `DA-FARE.md`.

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

Numerazione usata con l'utente. Percorsi relativi alla radice.

Stato deciso dall'utente in chat:

1. `app/lib/update.dart`: **chiuso, resta il tuo.**
2. `app/lib/update_distribution_io.dart`: **chiuso, resta il tuo.**
3. `app/lib/update_distribution_stub.dart`: **chiuso, verificato.** Base: solo `defaultStoreManagedUpdateChannel`. Ben ha aggiunto `defaultUpdateArchitecture`. L'utente ha aggiunto la stessa riga più `defaultAndroidSupportedAbis`. Collisione finta: il file attuale ha tutto.

Da discutere uno per uno, **con lettura del contenuto prima**. Per ciascuno è verificato solo a cosa assomiglia il file dopo la fusione (commit `396573c3`):

| # | File | Dopo la fusione |
|---|---|---|
| 4 | `app/test/update_test.dart` | **misto**, né tuo né ufficiale puro. Il riepilogo iniziale diceva "tuo": non corrisponde. Da controllare |
| 5 | `app/test/update_settings_test.dart` | identico al tuo |
| 6 | `app/lib/editor_screen.dart` | misto (ha tre punti: popup aggiornamenti = tuo, foto come PDF = tuo, menu = ufficiale) |
| 7 | `app/lib/file_io.dart` | identico al tuo |
| 8 | `app/lib/web_file_picker.dart` | identico al tuo |
| 9 | `packages/dart_pdf_editor/lib/src/editing/editing_overlay.dart` | identico al tuo (casella di testo, frecce, X) |
| 10 | `app/lib/l10n/app_it.arb` | identico al tuo: le stringhe italiane nuove di Ben **non ci sono** |
| 11 | `app/lib/l10n/app_localizations_it.dart` | identico al tuo, stesso discorso. Verificato che implementa tutte le 390 voci astratte di `app_localizations.dart`, quindi non manca nessun metodo |
| 12 | `app/lib/app_menu_sheet.dart` | **misto**, non "ufficiale puro" come scritto nel riepilogo. Il lavoro dell'utente su questo file è grande (riscrittura): **rischio più alto di aver perso sue modifiche** |
| 13 | `packages/dart_pdf_cli/bin/dartpdf.dart` | identico all'ufficiale (solo numero di versione/note) |
| 14 | `metainfo.xml` | esistono due copie: `app/linux/dev.milanko.dartpdf.metainfo.xml` e `app/packaging/flatpak/desktop-assets/dev.milanko.dartpdf.metainfo.xml`. Quale fosse in conflitto non è verificato. Solo versione e note |

Non verificato per nessuno dei punti 4-14: cosa fa nel dettaglio ogni modifica dell'utente e di Ben, e dove si pestano i piedi davvero. Il riepilogo iniziale (scelte "tuo / ufficiale") l'ho ripetuto senza averlo controllato; la tabella sopra ne corregge solo ciò che ho potuto verificare.

Altri conflitti, già risolti senza discussione: 25 file di versioni/changelog dei pacchetti (presi dall'ufficiale con gli indirizzi `tesonepdf` rimessi); 29 file che nel repo dell'utente non esistono (sito, flussi di compilazione di Ben, `CLAUDE.md`, `doc`): esclusi.

## Quattro scelte prese da me, mai approvate dall'utente (da rivedere)

1. Aggiornamenti: tenuta la versione dell'utente senza fonderla con quella ufficiale.
2. Menu del telefono: adottato quello ufficiale (ma `app_menu_sheet.dart` risulta misto, vedi punto 12).
3. Foto come PDF: tenuta, anche se l'utente aveva detto di non averla modificata.
4. Casella di testo: tenuta quella dell'utente.

## Stato delle build (verificato con l'API di GitHub)

- `main`: build #73 e #76 riuscite.
- `prova-sviluppatore`: build #74, #75, #77 **tutte fallite** nel passo "Compila l'APK" (exit code 1). La causa non è nota: il log completo non si scarica dall'ambiente della chat (l'indirizzo di download è bloccato). L'app Prova sul telefono quindi potrebbe non essere aggiornata. Compilare in locale non è possibile (Flutter non è installato).
- Probabile da guardare per prima: l'errore reale nel log di Actions del run di `prova-sviluppatore`, passo "Compila l'APK".

## Altre cose in sospeso

- Web app: l'utente vuole una web app per non dover aggiornare l'app Windows. Se ne è solo parlato; niente è stato fatto né deciso. Vercel (strumenti connessi alla chat) e il target hosting `tesonepdf-dart-pdf` esistono; non verificato che funzionino. Da fare dopo i conflitti, salvo diversa decisione.
- Le vecchie release `build-N` e `prova-N` (tag `prova-59`, `prova-60`, `prova-65`, `prova-67` e le `build-N`) sono rimaste su GitHub: cancellarle solo se lo chiede l'utente.
- Le due build lanciate col cambio di workflow (#76 main riuscita, #77 prova fallita) non hanno ancora convertito il tag della prova da pre-release a release normale, perché la build prova non è arrivata allo step di pubblicazione.
