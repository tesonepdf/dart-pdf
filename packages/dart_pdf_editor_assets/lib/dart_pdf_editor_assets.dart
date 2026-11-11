/// Optional bundled assets for `dart_pdf_editor`: the six editor fonts offered
/// by the font menu (and used as composite-text fallbacks), the families the
/// renderer substitutes into unembedded text - TeX Gyre Heros for
/// Helvetica/Arial, Termes for Times, Cursor for Courier, Adventor for Century
/// Gothic / Avant Garde, and Carlito for Calibri - and the prebuilt web
/// worker.
///
/// The substitute faces are metric-compatible clones: they carry the very
/// advances the fonts they stand in for do - the AFM tables for the standard
/// 14, and Calibri's own /Widths for Carlito - which is what makes them safe to
/// draw a page with. A face with different advances leaves white space *inside*
/// words - or, where it is the wider face, crowds the glyphs into each other -
/// because the renderer places every character at the PDF's own pen offset.
/// They need no registration call - being declared font families, they are
/// registered with the engine from the first paint.
///
/// These assets are declared in *this* package rather than in `dart_pdf_editor`
/// so a viewer-only application never bundles them - Flutter includes a
/// package's declared assets on every build target, so the only way to make the
/// ~6 MB of fonts + worker (~4.4 MB compressed) opt-in is to keep them out of
/// the package every consumer depends on.
///
/// Depend on this package and call [registerBundledEditorAssets] once at startup
/// (before opening a viewer) to get the historical full-featured behaviour:
///
/// ```dart
/// import 'package:dart_pdf_editor_assets/dart_pdf_editor_assets.dart';
///
/// void main() {
///   registerBundledEditorAssets();
///   runApp(const MyApp());
/// }
/// ```
library;

import 'package:dart_pdf_editor/dart_pdf_editor.dart';

/// The asset-bundle package name Flutter serves this package's assets under.
const String _package = 'dart_pdf_editor_assets';

/// The editor fonts bundled with this package - ten free stand-ins for the most
/// used document fonts (the imitated font is named in brackets), the DejaVu
/// serif and monospace faces, Fira Sans, Spectral and Lobster.
///
/// Assigned to [pdfBundledFonts] by [registerBundledEditorAssets] so they show
/// up in every [showPdfFontMenu]; the DejaVu trio also backs [loadFallbackFonts]
/// for composite (/Type0) text editing.
const List<PdfBundledFont> bundledEditorFonts = <PdfBundledFont>[
  // I dieci font piu' usati nei documenti: sostituti liberi, solo versione
  // normale (il grassetto e' simulato). Tra parentesi il font che imitano.
  // Calibri, Arial, Times New Roman, Courier New, Cambria e Georgia hanno le
  // stesse larghezze dell'originale; gli altri sono simili.
  PdfBundledFont('Carlito (Calibri)',
      'packages/$_package/assets/fonts/Carlito-Regular.ttf',
      package: _package),
  PdfBundledFont(
      'Arimo (Arial)', 'packages/$_package/assets/fonts/Arimo-Regular.ttf',
      package: _package),
  PdfBundledFont('Tinos (Times New Roman)',
      'packages/$_package/assets/fonts/Tinos-Regular.ttf',
      package: _package),
  PdfBundledFont('Cousine (Courier New)',
      'packages/$_package/assets/fonts/Cousine-Regular.ttf',
      package: _package),
  PdfBundledFont('Caladea (Cambria)',
      'packages/$_package/assets/fonts/Caladea-Regular.ttf',
      package: _package),
  PdfBundledFont('Gelasio (Georgia)',
      'packages/$_package/assets/fonts/Gelasio-Regular.ttf',
      package: _package),
  PdfBundledFont('DejaVu Sans (Verdana)',
      'packages/$_package/assets/fonts/DejaVuSans.ttf',
      package: _package),
  PdfBundledFont('Open Sans (Segoe UI)',
      'packages/$_package/assets/fonts/OpenSans-Regular.ttf',
      package: _package),
  PdfBundledFont('Comic Neue (Comic Sans)',
      'packages/$_package/assets/fonts/ComicNeue-Regular.ttf',
      package: _package),
  PdfBundledFont('EB Garamond (Garamond)',
      'packages/$_package/assets/fonts/EBGaramond-Regular.ttf',
      package: _package),
  PdfBundledFont(
      'DejaVu Serif', 'packages/$_package/assets/fonts/DejaVuSerif.ttf',
      package: _package),
  PdfBundledFont(
      'DejaVu Sans Mono', 'packages/$_package/assets/fonts/DejaVuSansMono.ttf',
      package: _package),
  PdfBundledFont(
      'Fira Sans', 'packages/$_package/assets/fonts/FiraSans-Regular.ttf',
      package: _package),
  PdfBundledFont(
      'Spectral', 'packages/$_package/assets/fonts/Spectral-Regular.ttf',
      package: _package),
  PdfBundledFont(
      'Lobster', 'packages/$_package/assets/fonts/Lobster-Regular.ttf',
      package: _package),
  // I quaranta font gratuiti piu' comuni (licenza OFL, solo versione normale;
  // il grassetto e' simulato). Sans, serif, a spaziatura fissa e da titolo.
  PdfBundledFont(
      'Roboto', 'packages/$_package/assets/fonts/Roboto-Regular.ttf',
      package: _package),
  PdfBundledFont(
      'Lato', 'packages/$_package/assets/fonts/Lato-Regular.ttf',
      package: _package),
  PdfBundledFont(
      'Montserrat', 'packages/$_package/assets/fonts/Montserrat-Regular.ttf',
      package: _package),
  PdfBundledFont(
      'Poppins', 'packages/$_package/assets/fonts/Poppins-Regular.ttf',
      package: _package),
  PdfBundledFont(
      'Noto Sans', 'packages/$_package/assets/fonts/NotoSans-Regular.ttf',
      package: _package),
  PdfBundledFont(
      'Source Sans 3', 'packages/$_package/assets/fonts/SourceSans3-Regular.ttf',
      package: _package),
  PdfBundledFont(
      'Nunito', 'packages/$_package/assets/fonts/Nunito-Regular.ttf',
      package: _package),
  PdfBundledFont(
      'Ubuntu', 'packages/$_package/assets/fonts/Ubuntu-Regular.ttf',
      package: _package),
  PdfBundledFont(
      'Inter', 'packages/$_package/assets/fonts/Inter-Regular.ttf',
      package: _package),
  PdfBundledFont(
      'Work Sans', 'packages/$_package/assets/fonts/WorkSans-Regular.ttf',
      package: _package),
  PdfBundledFont(
      'Raleway', 'packages/$_package/assets/fonts/Raleway-Regular.ttf',
      package: _package),
  PdfBundledFont(
      'Oswald', 'packages/$_package/assets/fonts/Oswald-Regular.ttf',
      package: _package),
  PdfBundledFont(
      'PT Sans', 'packages/$_package/assets/fonts/PTSans-Regular.ttf',
      package: _package),
  PdfBundledFont(
      'Rubik', 'packages/$_package/assets/fonts/Rubik-Regular.ttf',
      package: _package),
  PdfBundledFont(
      'Quicksand', 'packages/$_package/assets/fonts/Quicksand-Regular.ttf',
      package: _package),
  PdfBundledFont(
      'Mulish', 'packages/$_package/assets/fonts/Mulish-Regular.ttf',
      package: _package),
  PdfBundledFont(
      'Karla', 'packages/$_package/assets/fonts/Karla-Regular.ttf',
      package: _package),
  PdfBundledFont(
      'Cabin', 'packages/$_package/assets/fonts/Cabin-Regular.ttf',
      package: _package),
  PdfBundledFont(
      'Titillium Web', 'packages/$_package/assets/fonts/TitilliumWeb-Regular.ttf',
      package: _package),
  PdfBundledFont(
      'Josefin Sans', 'packages/$_package/assets/fonts/JosefinSans-Regular.ttf',
      package: _package),
  PdfBundledFont(
      'Barlow', 'packages/$_package/assets/fonts/Barlow-Regular.ttf',
      package: _package),
  PdfBundledFont(
      'IBM Plex Sans', 'packages/$_package/assets/fonts/IBMPlexSans-Regular.ttf',
      package: _package),
  PdfBundledFont(
      'DM Sans', 'packages/$_package/assets/fonts/DMSans-Regular.ttf',
      package: _package),
  PdfBundledFont(
      'Roboto Condensed', 'packages/$_package/assets/fonts/RobotoCondensed-Regular.ttf',
      package: _package),
  PdfBundledFont(
      'Merriweather', 'packages/$_package/assets/fonts/Merriweather-Regular.ttf',
      package: _package),
  PdfBundledFont(
      'Playfair Display', 'packages/$_package/assets/fonts/PlayfairDisplay-Regular.ttf',
      package: _package),
  PdfBundledFont(
      'Lora', 'packages/$_package/assets/fonts/Lora-Regular.ttf',
      package: _package),
  PdfBundledFont(
      'PT Serif', 'packages/$_package/assets/fonts/PTSerif-Regular.ttf',
      package: _package),
  PdfBundledFont(
      'Noto Serif', 'packages/$_package/assets/fonts/NotoSerif-Regular.ttf',
      package: _package),
  PdfBundledFont(
      'Source Serif 4', 'packages/$_package/assets/fonts/SourceSerif4-Regular.ttf',
      package: _package),
  PdfBundledFont(
      'Libre Baskerville', 'packages/$_package/assets/fonts/LibreBaskerville-Regular.ttf',
      package: _package),
  PdfBundledFont(
      'Crimson Text', 'packages/$_package/assets/fonts/CrimsonText-Regular.ttf',
      package: _package),
  PdfBundledFont(
      'Roboto Slab', 'packages/$_package/assets/fonts/RobotoSlab-Regular.ttf',
      package: _package),
  PdfBundledFont(
      'Cormorant Garamond', 'packages/$_package/assets/fonts/CormorantGaramond-Regular.ttf',
      package: _package),
  PdfBundledFont(
      'Bitter', 'packages/$_package/assets/fonts/Bitter-Regular.ttf',
      package: _package),
  PdfBundledFont(
      'Source Code Pro', 'packages/$_package/assets/fonts/SourceCodePro-Regular.ttf',
      package: _package),
  PdfBundledFont(
      'Roboto Mono', 'packages/$_package/assets/fonts/RobotoMono-Regular.ttf',
      package: _package),
  PdfBundledFont(
      'IBM Plex Mono', 'packages/$_package/assets/fonts/IBMPlexMono-Regular.ttf',
      package: _package),
  PdfBundledFont(
      'Bebas Neue', 'packages/$_package/assets/fonts/BebasNeue-Regular.ttf',
      package: _package),
  PdfBundledFont(
      'Dancing Script', 'packages/$_package/assets/fonts/DancingScript-Regular.ttf',
      package: _package),
];

/// The package-asset URL of the prebuilt web render worker shipped here.
///
/// Assigned to [pdfRenderWorkerScriptUrl] by [registerBundledEditorAssets] so a
/// Flutter web app gets off-main-thread page rendering without build steps.
/// Ignored on native platforms, where the worker is an isolate that needs no
/// script.
const String bundledEditorWorkerScriptUrl =
    'assets/packages/$_package/assets/web/pdf_render_worker.dart.js';

/// Registers this package's bundled assets with `dart_pdf_editor`, restoring the
/// historical full-featured defaults an app got before the assets were split
/// out.
///
/// Call once at startup, before opening a viewer:
///
/// - [fonts] (default true) sets [pdfBundledFonts] to [bundledEditorFonts], so
///   the font menu offers them and composite-text editing has fallback faces.
/// - [webWorker] (default true) points [pdfRenderWorkerScriptUrl] at this
///   package's [bundledEditorWorkerScriptUrl]. Harmless on native.
///
/// Pass `fonts: false` or `webWorker: false` to register only one group - e.g.
/// a web app that wants the worker but supplies its own font catalogue, or a
/// native app that wants the fonts but no worker asset.
void registerBundledEditorAssets({bool fonts = true, bool webWorker = true}) {
  if (fonts) {
    pdfBundledFonts = bundledEditorFonts;
  }
  if (webWorker) {
    pdfRenderWorkerScriptUrl = bundledEditorWorkerScriptUrl;
  }
}
