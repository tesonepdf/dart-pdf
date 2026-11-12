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
- **Release**: una sola release, sempre normale (mai pre-release), marcata "Latest" su `main`, tag `app-android-latest`. Nessuna release numerata a parte: a ogni build l'APK viene sostituito e il numero build è nel titolo (`#N`) e nelle note, dove l'app lo legge per il controllo aggiornamenti.
- **Numero build**: il numero dopo il `#` non è il conteggio dei commit. È il numero della run di GitHub Actions (run #105 → app #105).
- **Aggiornamento dall'originale** (`ben-milanko/dart-pdf`): si cercano solo le novità di Ben e si avvisa l'utente, senza unire, importare o modificare niente. Le novità si guardano in sola lettura (confronto con la base `3e0bd1b`) e si decide insieme cosa portare.
- **Prima di ogni modifica**: si valutano i branch (`git fetch --all`, confronto con `main`) per vedere se ci sono modifiche parallele.
- Le modifiche alla struttura (workflow, release, canali) si fanno solo su `main`.
