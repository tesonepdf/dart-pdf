# Provenienza

- Progetto originale: https://github.com/ben-milanko/dart-pdf
- Commit di base: `3e0bd1b0c0e5b4ab336a8d584510a3a0e43e607a`
- Data del commit: `2026-10-26T07:34:08+11:00`

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
