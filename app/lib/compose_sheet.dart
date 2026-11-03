import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dart_pdf_editor/dart_pdf_editor.dart' show PdfPageExport;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf_document/pdf_document.dart';

import 'file_io.dart';
import 'l10n/app_l10n.dart';

/// Margine e spazio tra i ritagli sul foglio, in punti (1 pt = 1/72 pollice).
const double kSheetMargin = 20;
const double kSheetGap = 10;

/// Una parte di una pagina di un PDF, scelta per essere messa su un foglio.
class SheetCrop {
  SheetCrop({
    required this.name,
    required this.source,
    required this.page,
    required this.region,
    required this.rotation,
    required this.sourceBytes,
    required this.pageSize,
    required this.fraction,
    this.preview,
  });

  /// Nome del PDF di provenienza.
  final String name;
  final PdfDocument source;

  /// I byte del PDF di provenienza (servono per salvare la composizione).
  final Uint8List sourceBytes;

  /// Immagine della pagina intera, per la miniatura (può mancare).
  final Uint8List? preview;

  /// Misura della pagina come si vede, in punti.
  final ({double width, double height}) pageSize;

  /// La parte scelta in frazioni della pagina vista (0..1, in alto a sinistra).
  final Rect fraction;

  /// Pagina di provenienza, da 0.
  final int page;

  /// La parte scelta, nello spazio della pagina prima della rotazione.
  final PdfRect region;

  /// Rotazione con cui la pagina si vede (0, 90, 180, 270).
  final int rotation;

  ({double width, double height}) get size =>
      pdfRegionDisplaySize(region, rotation);

  String get description {
    String mm(double pt) => (pt * 25.4 / 72).round().toString();
    return 'pag. ${page + 1} · ${mm(size.width)}×${mm(size.height)} mm';
  }
}

/// Dove va un ritaglio: foglio (da 0), angolo in basso a sinistra, scala.
class SheetPlacement {
  const SheetPlacement(this.sheet, this.x, this.y, this.scale);
  final int sheet;
  final double x;
  final double y;
  final double scale;
}

/// Mette i ritagli sui fogli, nell'ordine dato: file dopo file, dall'alto a
/// sinistra, affiancati finché ci stanno, poi una nuova riga, poi un nuovo
/// foglio. Misura vera; solo un ritaglio più grande del foglio si rimpicciolisce.
List<SheetPlacement> layoutSheetCrops(
  List<({double width, double height})> sizes, {
  double pageWidth = 595.28,
  double pageHeight = 841.89,
}) {
  final availW = pageWidth - 2 * kSheetMargin;
  final availH = pageHeight - 2 * kSheetMargin;
  final out = <SheetPlacement>[];
  var sheet = 0;
  var x = kSheetMargin;
  var rowTop = pageHeight - kSheetMargin;
  var rowHeight = 0.0;
  for (final size in sizes) {
    final scale = math.min(
        1.0, math.min(availW / size.width, availH / size.height));
    final w = size.width * scale;
    final h = size.height * scale;
    if (x > kSheetMargin && x + w > pageWidth - kSheetMargin) {
      // non ci sta più in questa riga
      rowTop -= rowHeight + kSheetGap;
      x = kSheetMargin;
      rowHeight = 0;
    }
    if (rowTop - h < kSheetMargin) {
      sheet++;
      x = kSheetMargin;
      rowTop = pageHeight - kSheetMargin;
      rowHeight = 0;
    }
    out.add(SheetPlacement(sheet, x, rowTop - h, scale));
    x += w + kSheetGap;
    rowHeight = math.max(rowHeight, h);
  }
  return out;
}

/// Crea il PDF con tutti i ritagli sui fogli A4.
Uint8List composeSheets(List<SheetCrop> crops,
    {List<SheetPlacement>? placements}) {
  placements ??= layoutSheetCrops([for (final c in crops) c.size]);
  final sheets = placements.fold<int>(1, (m, p) => math.max(m, p.sheet + 1));
  final doc = PdfDocument.open(
      PdfBlankDocument.create(pageSize: PdfPageSize.a4, pageCount: sheets));
  final editor = PdfEditor(doc);
  final imports = PdfSheetImports();
  for (var i = 0; i < crops.length; i++) {
    final c = crops[i];
    final p = placements[i];
    editor.placePageRegion(
      imports,
      sheet: p.sheet,
      source: c.source,
      sourcePage: c.page,
      region: c.region,
      x: p.x,
      y: p.y,
      scale: p.scale,
    );
  }
  return editor.save();
}

/// Dal rettangolo disegnato sull'immagine della pagina (frazioni 0..1, origine
/// in alto a sinistra) alla parte di pagina, nello spazio della pagina prima
/// della rotazione.
PdfRect regionFromSelection(Rect sel, PdfRect box, int rotation) {
  (double, double) toPage(double fx, double fy) => switch (rotation) {
        90 => (fy, fx),
        180 => (1 - fx, fy),
        270 => (1 - fy, 1 - fx),
        _ => (fx, 1 - fy),
      };
  final (u1, v1) = toPage(sel.left, sel.top);
  final (u2, v2) = toPage(sel.right, sel.bottom);
  return PdfRect.normalized(
    box.left + u1 * box.width,
    box.bottom + v1 * box.height,
    box.left + u2 * box.width,
    box.bottom + v2 * box.height,
  );
}

/// Disegna una pagina per l'anteprima e le miniature.
Future<Uint8List> renderPagePreview(PdfPage page) {
  final size = pdfRegionDisplaySize(page.cropBox, page.rotation);
  final scale = 1600 / math.max(size.width, size.height);
  return PdfPageExport.exportPage(page, scale: scale);
}

/// La composizione (PDF di partenza, ritagli e posizioni) come file di testo.
Uint8List encodeComposition(
    List<SheetCrop> crops, List<SheetPlacement>? placements) {
  final sources = <SheetCrop>[];
  int indexOf(SheetCrop c) {
    final i = sources.indexWhere((o) => identical(o.sourceBytes, c.sourceBytes));
    if (i >= 0) return i;
    sources.add(c);
    return sources.length - 1;
  }

  final cropList = <Map<String, Object>>[];
  for (final c in crops) {
    cropList.add({
      'source': indexOf(c),
      'page': c.page,
      'region': [c.region.left, c.region.bottom, c.region.right, c.region.top],
      'rotation': c.rotation,
      'fraction': [
        c.fraction.left,
        c.fraction.top,
        c.fraction.right,
        c.fraction.bottom,
      ],
    });
  }
  final map = <String, Object>{
    'version': 1,
    'sources': [
      for (final c in sources)
        {'name': c.name, 'data': base64Encode(c.sourceBytes)},
    ],
    'crops': cropList,
    if (placements != null)
      'placements': [
        for (final p in placements) [p.sheet, p.x, p.y, p.scale],
      ],
  };
  return Uint8List.fromList(utf8.encode(jsonEncode(map)));
}

/// Il contrario di [encodeComposition].
Future<({List<SheetCrop> crops, List<SheetPlacement>? placements})>
    decodeComposition(Uint8List data) async {
  final map = jsonDecode(utf8.decode(data)) as Map<String, dynamic>;
  final names = <String>[];
  final byteList = <Uint8List>[];
  final docs = <PdfDocument>[];
  for (final item in map['sources'] as List<dynamic>) {
    final m = item as Map<String, dynamic>;
    final bytes = base64Decode(m['data'] as String);
    names.add(m['name'] as String);
    byteList.add(bytes);
    docs.add(PdfDocument.open(bytes));
  }
  final previews = <String, Uint8List>{};
  final crops = <SheetCrop>[];
  for (final item in map['crops'] as List<dynamic>) {
    final m = item as Map<String, dynamic>;
    final si = m['source'] as int;
    final pageIndex = m['page'] as int;
    final page = docs[si].page(pageIndex);
    final key = '$si:$pageIndex';
    Uint8List? preview = previews[key];
    if (preview == null) {
      try {
        preview = await renderPagePreview(page);
        previews[key] = preview;
      } catch (_) {
        preview = null;
      }
    }
    final r = (m['region'] as List<dynamic>).map((v) => (v as num).toDouble());
    final rr = r.toList();
    final f = (m['fraction'] as List<dynamic>)
        .map((v) => (v as num).toDouble())
        .toList();
    crops.add(SheetCrop(
      name: names[si],
      source: docs[si],
      page: pageIndex,
      region: PdfRect(rr[0], rr[1], rr[2], rr[3]),
      rotation: m['rotation'] as int,
      sourceBytes: byteList[si],
      pageSize: pdfRegionDisplaySize(page.cropBox, page.rotation),
      fraction: Rect.fromLTRB(f[0], f[1], f[2], f[3]),
      preview: preview,
    ));
  }
  List<SheetPlacement>? placements;
  final rawPlacements = map['placements'];
  if (rawPlacements is List<dynamic>) {
    placements = [
      for (final item in rawPlacements)
        SheetPlacement(
          (item as List<dynamic>)[0] as int,
          (item[1] as num).toDouble(),
          (item[2] as num).toDouble(),
          (item[3] as num).toDouble(),
        ),
    ];
  }
  return (crops: crops, placements: placements);
}

/// Salva la composizione in un file: si condivide sul telefono, finestra di
/// salvataggio sul computer, scaricamento sul web.
Future<void> saveComposition(BuildContext context, List<SheetCrop> crops,
    List<SheetPlacement>? placements) async {
  const name = 'composizione.json';
  final file = XFile.fromData(encodeComposition(crops, placements),
      mimeType: 'application/json', name: name);
  if (kIsWeb) {
    await file.saveTo(name);
    return;
  }
  switch (defaultTargetPlatform) {
    case TargetPlatform.android || TargetPlatform.iOS:
      await SharePlus.instance.share(ShareParams(
        files: [file],
        fileNameOverrides: [name],
        title: name,
        sharePositionOrigin: const Rect.fromLTWH(0, 0, 1, 1),
      ));
    default:
      final location = await getSaveLocation(
        suggestedName: name,
        acceptedTypeGroups: [_compositionTypeGroup],
      );
      if (location != null) await file.saveTo(location.path);
  }
}

XTypeGroup get _compositionTypeGroup => XTypeGroup(
      label: 'Composizione',
      extensions: const ['json'],
      mimeTypes: const ['application/json'],
      uniformTypeIdentifiers: const ['public.json'],
    );

/// Miniatura della parte scelta.
class _CropThumbnail extends StatelessWidget {
  const _CropThumbnail(this.crop);

  final SheetCrop crop;

  @override
  Widget build(BuildContext context) {
    final png = crop.preview;
    if (png == null) {
      return const SizedBox(width: 56, height: 56, child: Icon(Icons.crop));
    }
    final pw = crop.pageSize.width;
    final ph = crop.pageSize.height;
    final f = crop.fraction;
    return SizedBox(
      width: 56,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0x33000000)),
        ),
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: f.width * pw,
            height: f.height * ph,
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.topLeft,
                minWidth: pw,
                maxWidth: pw,
                minHeight: ph,
                maxHeight: ph,
                child: Transform.translate(
                  offset: Offset(-f.left * pw, -f.top * ph),
                  child: Image.memory(png,
                      width: pw,
                      height: ph,
                      fit: BoxFit.fill,
                      gaplessPlayback: true),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Apre "Componi foglio". Restituisce il PDF creato, o null se si annulla.
Future<Uint8List?> showComposeSheet(BuildContext context) =>
    Navigator.of(context).push<Uint8List>(
      MaterialPageRoute<Uint8List>(
        fullscreenDialog: true,
        builder: (_) => const ComposeSheetScreen(),
      ),
    );

class ComposeSheetScreen extends StatefulWidget {
  const ComposeSheetScreen({super.key});

  @override
  State<ComposeSheetScreen> createState() => _ComposeSheetScreenState();
}

class _ComposeSheetScreenState extends State<ComposeSheetScreen> {
  final List<SheetCrop> _crops = [];
  List<SheetPlacement>? _savedPlacements;
  String? _message;

  Future<void> _pickPdf() async {
    try {
      final files = await pickPdfFiles(appL10n(context).fileTypePdf);
      if (files.isEmpty || !mounted) return;
      final file = files.first;
      final bytes = await file.readAsBytes();
      final document = PdfDocument.open(bytes);
      if (document.pageCount == 0) {
        setState(() => _message = 'Il PDF non ha pagine.');
        return;
      }
      if (!mounted) return;
      await _openPicker(file.name, bytes, document);
    } catch (e) {
      if (mounted) setState(() => _message = 'PDF non aperto: $e');
    }
  }

  Future<void> _openPicker(
      String name, Uint8List bytes, PdfDocument document) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _CropPickerScreen(
          name: name,
          bytes: bytes,
          document: document,
          onAdd: (crop) => setState(() {
            _message = null;
            _savedPlacements = null;
            _crops.add(crop);
          }),
        ),
      ),
    );
  }

  Future<void> _openComposition() async {
    try {
      final file = await openFile(acceptedTypeGroups: [_compositionTypeGroup]);
      if (file == null || !mounted) return;
      final result = await decodeComposition(await file.readAsBytes());
      if (!mounted) return;
      setState(() {
        _message = null;
        _crops
          ..clear()
          ..addAll(result.crops);
        _savedPlacements = result.placements;
      });
    } catch (e) {
      if (mounted) setState(() => _message = 'Composizione non aperta: $e');
    }
  }

  Future<void> _create() async {
    final bytes = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute<Uint8List>(
        builder: (_) => _SheetPreviewScreen(
          crops: List.of(_crops),
          initialPlacements: _savedPlacements,
        ),
      ),
    );
    if (bytes != null && mounted) Navigator.of(context).pop(bytes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Componi foglio'),
        actions: [
          IconButton(
            tooltip: 'Apri composizione…',
            icon: const Icon(Icons.folder_open_outlined),
            onPressed: _openComposition,
          ),
          if (_crops.isNotEmpty)
            IconButton(
              tooltip: 'Salva composizione',
              icon: const Icon(Icons.save_alt),
              onPressed: () =>
                  saveComposition(context, _crops, _savedPlacements),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(_crops.isEmpty
                ? 'Aggiungi i ritagli: scegli un PDF, la pagina e disegna il '
                    'rettangolo sulla parte che ti serve. I ritagli vanno su '
                    'fogli A4, uno dopo l\'altro.'
                : 'Trascina per cambiare l\'ordine sul foglio.'),
          ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(_message!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          Expanded(
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              itemCount: _crops.length,
              onReorderItem: (from, to) => setState(() {
                _savedPlacements = null;
                _crops.insert(to, _crops.removeAt(from));
              }),
              itemBuilder: (context, index) {
                final crop = _crops[index];
                return ListTile(
                  key: ObjectKey(crop),
                  leading: _CropThumbnail(crop),
                  title: Text(crop.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(crop.description),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Altro ritaglio da questo PDF',
                        icon: const Icon(Icons.add_box_outlined),
                        onPressed: () =>
                            _openPicker(crop.name, crop.sourceBytes, crop.source),
                      ),
                      IconButton(
                        tooltip: 'Togli',
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() {
                          _savedPlacements = null;
                          _crops.removeAt(index);
                        }),
                      ),
                      ReorderableDragStartListener(
                        index: index,
                        child: const Icon(Icons.drag_handle),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickPdf,
                      icon: const Icon(Icons.add),
                      label: const Text('Aggiungi da un PDF…'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _crops.isEmpty ? null : _create,
                      child: const Text('Disponi sui fogli'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mostra una pagina del PDF e fa disegnare il rettangolo da ritagliare.
class _CropPickerScreen extends StatefulWidget {
  const _CropPickerScreen({
    required this.name,
    required this.bytes,
    required this.document,
    required this.onAdd,
  });

  final String name;
  final Uint8List bytes;
  final PdfDocument document;
  final void Function(SheetCrop crop) onAdd;

  @override
  State<_CropPickerScreen> createState() => _CropPickerScreenState();
}

class _CropPickerScreenState extends State<_CropPickerScreen> {
  int _page = 0;
  int _token = 0;
  int _added = 0;
  Uint8List? _png;
  String? _error;
  Rect? _sel;
  Offset? _start;

  @override
  void initState() {
    super.initState();
    _load(0);
  }

  Future<void> _load(int index) async {
    final token = ++_token;
    setState(() {
      _page = index;
      _png = null;
      _sel = null;
      _error = null;
    });
    try {
      final png = await renderPagePreview(widget.document.page(index));
      if (!mounted || token != _token) return;
      setState(() => _png = png);
    } catch (e) {
      if (mounted && token == _token) setState(() => _error = '$e');
    }
  }

  double get _aspect {
    final page = widget.document.page(_page);
    final size = pdfRegionDisplaySize(page.cropBox, page.rotation);
    return size.width / size.height;
  }

  Offset _fraction(Offset local, Size size) => Offset(
        (local.dx / size.width).clamp(0.0, 1.0),
        (local.dy / size.height).clamp(0.0, 1.0),
      );

  bool get _selOk =>
      _sel != null && _sel!.width > 0.01 && _sel!.height > 0.01;

  void _add({required bool whole}) {
    final page = widget.document.page(_page);
    final box = page.cropBox;
    final rotation = page.rotation;
    final region = whole ? box : regionFromSelection(_sel!, box, rotation);
    widget.onAdd(SheetCrop(
      name: widget.name,
      source: widget.document,
      page: _page,
      region: region,
      rotation: rotation,
      sourceBytes: widget.bytes,
      pageSize: pdfRegionDisplaySize(box, rotation),
      fraction: whole ? const Rect.fromLTWH(0, 0, 1, 1) : _sel!,
      preview: _png,
    ));
    setState(() {
      _added++;
      _sel = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.document.pageCount;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Center(
                child: _error != null
                    ? Text('Pagina non disegnata: $_error')
                    : _png == null
                        ? const CircularProgressIndicator()
                        : LayoutBuilder(builder: (context, constraints) {
                            var w = constraints.maxWidth;
                            var h = w / _aspect;
                            if (h > constraints.maxHeight) {
                              h = constraints.maxHeight;
                              w = h * _aspect;
                            }
                            final size = Size(w, h);
                            return SizedBox(
                              width: w,
                              height: h,
                              child: GestureDetector(
                                onPanStart: (d) {
                                  _start = _fraction(d.localPosition, size);
                                  setState(() => _sel =
                                      Rect.fromPoints(_start!, _start!));
                                },
                                onPanUpdate: (d) {
                                  final s = _start;
                                  if (s == null) return;
                                  setState(() => _sel = Rect.fromPoints(
                                      s, _fraction(d.localPosition, size)));
                                },
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.memory(_png!,
                                        fit: BoxFit.fill,
                                        gaplessPlayback: true),
                                    if (_sel != null)
                                      CustomPaint(
                                          painter: _SelectionPainter(_sel!)),
                                  ],
                                ),
                              ),
                            );
                          }),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _page > 0 ? () => _load(_page - 1) : null,
              ),
              Text('Pagina ${_page + 1} di $count'),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _page < count - 1 ? () => _load(_page + 1) : null,
              ),
            ],
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_added > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _added == 1
                            ? '1 ritaglio aggiunto. Puoi tornare indietro o '
                                'aggiungerne altri.'
                            : '$_added ritagli aggiunti. Puoi tornare indietro '
                                'o aggiungerne altri.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _png == null
                              ? null
                              : () => _add(whole: true),
                          child: const Text('Pagina intera'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _selOk ? () => _add(whole: false) : null,
                          child: const Text('Aggiungi ritaglio'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectionPainter extends CustomPainter {
  _SelectionPainter(this.selection);

  /// Rettangolo in frazioni della pagina (0..1).
  final Rect selection;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTRB(
      selection.left * size.width,
      selection.top * size.height,
      selection.right * size.width,
      selection.bottom * size.height,
    );
    canvas.drawRect(rect, Paint()..color = const Color(0x332196F3));
    canvas.drawRect(
      rect,
      Paint()
        ..color = const Color(0xFF2196F3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_SelectionPainter old) => old.selection != selection;
}

/// Anteprima dei fogli A4: ogni ritaglio si trascina dove si vuole.
class _SheetPreviewScreen extends StatefulWidget {
  const _SheetPreviewScreen({required this.crops, this.initialPlacements});

  final List<SheetCrop> crops;
  final List<SheetPlacement>? initialPlacements;

  @override
  State<_SheetPreviewScreen> createState() => _SheetPreviewScreenState();
}

class _SheetPreviewScreenState extends State<_SheetPreviewScreen> {
  static const double _pageW = 595.28;
  static const double _pageH = 841.89;

  late List<SheetPlacement> _placements;
  int _sheet = 0;
  int? _selected;
  int _token = 0;
  Uint8List? _png;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final saved = widget.initialPlacements;
    _placements = saved != null && saved.length == widget.crops.length
        ? List.of(saved)
        : layoutSheetCrops([for (final c in widget.crops) c.size]);
    _normalize();
    _render();
  }

  int get _sheets =>
      _placements.fold<int>(1, (m, p) => math.max(m, p.sheet + 1));

  Future<void> _render() async {
    final token = ++_token;
    try {
      final bytes = composeSheets(widget.crops, placements: _placements);
      final doc = PdfDocument.open(bytes);
      final png = await PdfPageExport.exportPage(doc.page(_sheet), scale: 1.6);
      if (!mounted || token != _token) return;
      setState(() {
        _png = png;
        _error = null;
      });
    } catch (e) {
      if (mounted && token == _token) setState(() => _error = '$e');
    }
  }

  /// Toglie i fogli rimasti vuoti e rinumera gli altri.
  void _normalize() {
    final used = {for (final p in _placements) p.sheet}.toList()..sort();
    final map = {for (var i = 0; i < used.length; i++) used[i]: i};
    _placements = [
      for (final p in _placements)
        SheetPlacement(map[p.sheet]!, p.x, p.y, p.scale),
    ];
    final sel = _selected;
    if (sel != null) {
      _sheet = _placements[sel].sheet;
    } else {
      _sheet = math.min(_sheet, _sheets - 1);
    }
  }

  void _moveTo(int index, double x, double y) {
    final c = widget.crops[index];
    final p = _placements[index];
    final w = c.size.width * p.scale;
    final h = c.size.height * p.scale;
    _placements[index] = SheetPlacement(
      p.sheet,
      x.clamp(0.0, math.max(0.0, _pageW - w)),
      y.clamp(0.0, math.max(0.0, _pageH - h)),
      p.scale,
    );
  }

  double _maxScale(int i) {
    final c = widget.crops[i];
    return math.max(
        0.2, math.min(_pageW / c.size.width, _pageH / c.size.height));
  }

  /// Cambia la misura tenendo fermo l'angolo in alto a sinistra.
  void _resize(int i, double scale) {
    final p = _placements[i];
    final c = widget.crops[i];
    final top = p.y + c.size.height * p.scale;
    _placements[i] =
        SheetPlacement(p.sheet, p.x, top - c.size.height * scale, scale);
    _moveTo(i, _placements[i].x, _placements[i].y);
  }

  void _moveSheet(int delta) {
    final i = _selected;
    if (i == null) return;
    final target = _placements[i].sheet + delta;
    if (target < 0) return;
    final p = _placements[i];
    _placements[i] = SheetPlacement(target, p.x, p.y, p.scale);
    _moveTo(i, p.x, p.y);
    setState(_normalize);
    _render();
  }

  Future<void> _create() async {
    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    try {
      final bytes = composeSheets(widget.crops, placements: _placements);
      if (mounted) Navigator.of(context).pop(bytes);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'PDF non creato: $e';
        });
      }
    }
  }

  Widget _sheetView(BoxConstraints constraints) {
    var w = constraints.maxWidth;
    var h = w * _pageH / _pageW;
    if (h > constraints.maxHeight) {
      h = constraints.maxHeight;
      w = h * _pageW / _pageH;
    }
    final k = w / _pageW;
    final children = <Widget>[
      if (_png != null)
        Image.memory(_png!, fit: BoxFit.fill, gaplessPlayback: true)
      else
        const ColoredBox(color: Color(0xFFFFFFFF)),
    ];
    for (var i = 0; i < widget.crops.length; i++) {
      final p = _placements[i];
      if (p.sheet != _sheet) continue;
      final c = widget.crops[i];
      final cw = c.size.width * p.scale;
      final ch = c.size.height * p.scale;
      final selected = _selected == i;
      children.add(Positioned(
        left: p.x * k,
        top: (_pageH - p.y - ch) * k,
        width: cw * k,
        height: ch * k,
        child: GestureDetector(
          onTap: () => setState(() => _selected = i),
          onPanStart: (_) => setState(() => _selected = i),
          onPanUpdate: (d) {
            final q = _placements[i];
            setState(() => _moveTo(i, q.x + d.delta.dx / k, q.y - d.delta.dy / k));
          },
          onPanEnd: (_) => _render(),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: selected ? const Color(0x222196F3) : null,
              border: Border.all(
                color: selected
                    ? const Color(0xFF2196F3)
                    : const Color(0x882196F3),
                width: selected ? 2 : 1,
              ),
            ),
            child: Align(
              alignment: Alignment.topLeft,
              child: Container(
                color: const Color(0xFF2196F3),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text('${i + 1}',
                    style: const TextStyle(
                        color: Color(0xFFFFFFFF), fontSize: 11)),
              ),
            ),
          ),
        ),
      ));
    }
    return SizedBox(
      width: w,
      height: h,
      child: Stack(fit: StackFit.expand, children: children),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sheets = _sheets;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Disponi sui fogli'),
        actions: [
          IconButton(
            tooltip: 'Salva composizione',
            icon: const Icon(Icons.save_alt),
            onPressed: () =>
                saveComposition(context, widget.crops, _placements),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(_error ??
                'Trascina i ritagli dove vuoi. Tocca un ritaglio per '
                    'spostarlo in un altro foglio.',
                style: _error == null
                    ? null
                    : TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Center(child: LayoutBuilder(builder: (context, c) {
                return _sheetView(c);
              })),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _sheet > 0
                    ? () {
                        setState(() {
                          _sheet--;
                          _selected = null;
                        });
                        _render();
                      }
                    : null,
              ),
              Text('Foglio ${_sheet + 1} di $sheets'),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _sheet < sheets - 1
                    ? () {
                        setState(() {
                          _sheet++;
                          _selected = null;
                        });
                        _render();
                      }
                    : null,
              ),
            ],
          ),
          if (_selected != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text('Misura ${(_placements[_selected!].scale * 100).round()}%'),
                  Expanded(
                    child: Slider(
                      value: _placements[_selected!]
                          .scale
                          .clamp(0.1, _maxScale(_selected!)),
                      min: 0.1,
                      max: _maxScale(_selected!),
                      onChanged: (v) =>
                          setState(() => _resize(_selected!, v)),
                      onChangeEnd: (_) => _render(),
                    ),
                  ),
                ],
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _selected == null ? null : () => _moveSheet(-1),
                      child: const Text('Foglio prima'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _selected == null ? null : () => _moveSheet(1),
                      child: const Text('Foglio dopo'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy ? null : _create,
                      child: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Crea PDF'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
