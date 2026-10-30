# Provenienza

- Progetto originale: https://github.com/ben-milanko/dart-pdf
- Commit di base: `3e0bd1b0c0e5b4ab336a8d584510a3a0e43e607a`
- Data del commit: `2026-10-26T07:34:08+11:00`

Versione dell'app all'origine: `11.0.0+48` (`app/pubspec.yaml` del commit di base). L'app la usa come punto di partenza per il controllo della versione ufficiale (Impostazioni > Aggiornamenti > Repo ufficiale).

Base della copia. Per vedere le novità: https://github.com/ben-milanko/dart-pdf/compare/3e0bd1b0c0e5b4ab336a8d584510a3a0e43e607a...main

## Modifiche rispetto all'originale

- `app/android/app/build.gradle.kts`: `applicationId` impostato a `it.tesonepdf.pdf`; il `namespace` è rimasto invariato.
- Aggiunto un workflow GitHub Actions per compilare APK Android separati per architettura e app Windows, pubblicandoli come Release.
- Gli endpoint app per release, sorgente e segnalazione problemi puntano alla repository `tesonepdf/dart-pdf`.
- I modelli OCR e le relative licenze sono inclusi in `packages/pdf_ocr_ondevice/assets/ocr/`; app e build web li servono dalla repository dell'utente.
- Rimossa la selezione Firebase demo; il target di hosting è stato rinominato `tesonepdf-dart-pdf`.
- Il solo collegamento previsto all'originale è il controllo pubblico in sola lettura delle nuove release, da implementare nella Fase 2.
- `NOTICE` e `analysis_options.yaml` non erano presenti nel commit di origine.
- Nessuna cartella del workspace Dart è stata rimossa: tutte le cartelle dichiarate in `pubspec.yaml` sono incluse.

## Flusso di lavoro

- **Modifiche normali**: solo su `main`, seguite da commit, push e build Actions.
- **Release**: una sola release per canale, sempre normale (mai pre-release). `main` → tag `app-android-latest` (marcata "Latest"); `prova-sviluppatore` → tag `app-android-prova` (mai "Latest"). Nessuna release numerata a parte: a ogni build l'APK viene sostituito e il numero build è nel titolo (`#N`) e nelle note, dove l'app lo legge per il controllo aggiornamenti.
- **Numero build**: il numero dopo il `#` è quello della run di GitHub Actions (`github.run_number`), non il conteggio dei commit.
- **Aggiornamento dall'originale** (remote `upstream` = `ben-milanko/dart-pdf`): `upstream/main` si unisce in `prova-sviluppatore`, dove si risolvono i conflitti e si verifica che la fusione sia di gradimento. `prova-sviluppatore` è solo un banco di prova: non ha release, pre-release o canale proprio.
- **Portare in `main`**: merge di `prova-sviluppatore` in `main`, mai rinomina del ramo né copia manuale dei file. Dopo il merge `prova-sviluppatore` non si considera più; alla fusione successiva si riparte da `main`.
- Le modifiche alla struttura (workflow, release, canali) si fanno solo su `main`, mai da `prova-sviluppatore`.
