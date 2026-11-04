part of 'editor.dart';

/// Keeps what [PdfSheetComposition.placePageRegion] has already imported, so
/// several crops of the same source page share one copy of its fonts and
/// images. One cache belongs to one [PdfEditor].
class PdfSheetImports {
  final Map<PdfDocument, _PageImporter> _importers = Map.identity();
  final Map<PdfDocument, Map<int, CosReference>> _forms = Map.identity();

  /// The printable annotations of a source page, as one form (null = none).
  final Map<PdfDocument, Map<int, CosReference?>> _annotationForms =
      Map.identity();
}

/// Size in points of [region] of a page as it looks on screen, for a page
/// displayed with [rotation] (0, 90, 180 or 270 degrees clockwise).
({double width, double height}) pdfRegionDisplaySize(
    PdfRect region, int rotation) {
  final swapped = rotation == 90 || rotation == 270;
  return (
    width: swapped ? region.height : region.width,
    height: swapped ? region.width : region.height,
  );
}

/// Putting parts of other documents' pages on a page of this document.
extension PdfSheetComposition on PdfEditor {
  /// Draws [region] (page user space, before rotation) of page [sourcePage]
  /// of [source] on page [sheet] of this document, upright as the page is
  /// displayed. The bottom-left corner of the drawn part lands at ([x], [y])
  /// and it is scaled by [scale]. The part stays vector: the source page is
  /// copied in as a form XObject and clipped to [region].
  ///
  /// [turns] turns the part by that many extra quarter turns clockwise (0-3)
  /// after it is upright; the corner that lands at ([x], [y]) is then the
  /// bottom-left of the turned part.
  void placePageRegion(
    PdfSheetImports imports, {
    required int sheet,
    required PdfDocument source,
    required int sourcePage,
    required PdfRect region,
    required double x,
    required double y,
    double scale = 1,
    int turns = 0,
  }) {
    final cos = document.cos;
    final formRef = _pageAsForm(imports, source, sourcePage);
    final rotation = source.page(sourcePage).rotation;
    final l = region.left;
    final b = region.bottom;
    final r = region.right;
    final t = region.top;
    // The matrix maps the unrotated page onto the sheet: first the page's
    // own display rotation, then the move to (x, y).
    final (a0, b0, c0, d0, e0, f0) = switch (rotation) {
      90 => (0.0, -1.0, 1.0, 0.0, -b, r),
      180 => (-1.0, 0.0, 0.0, -1.0, r, t),
      270 => (0.0, 1.0, -1.0, 0.0, t, -l),
      _ => (1.0, 0.0, 0.0, 1.0, -l, -b),
    };
    // The extra quarter turns act on the upright part, [width] x [height].
    final size = pdfRegionDisplaySize(region, rotation);
    final width = size.width;
    final height = size.height;
    final (ta, tb, tc, td, te, tf) = switch (turns % 4) {
      1 => (0.0, -1.0, 1.0, 0.0, 0.0, width),
      2 => (-1.0, 0.0, 0.0, -1.0, width, height),
      3 => (0.0, 1.0, -1.0, 0.0, height, 0.0),
      _ => (1.0, 0.0, 0.0, 1.0, 0.0, 0.0),
    };
    final a = ta * a0 + tc * b0;
    final bb = tb * a0 + td * b0;
    final c = ta * c0 + tc * d0;
    final d = tb * c0 + td * d0;
    final e = ta * e0 + tc * f0 + te;
    final f = tb * e0 + td * f0 + tf;
    String n(double v) => ContentWriter.fmt(v);

    final page = document.page(sheet);
    final dict = page.dict;
    final oldRes = cos.resolve(dict['Resources']);
    final res = CosDictionary({
      if (oldRes is CosDictionary) ...oldRes.entries,
    });
    final oldXo = cos.resolve(res['XObject']);
    final xo = CosDictionary({
      if (oldXo is CosDictionary) ...oldXo.entries,
    });
    var index = xo.entries.length + 1;
    while (xo.containsKey('Pg$index')) {
      index++;
    }
    final name = 'Pg$index';
    xo[name] = formRef;
    // What was drawn on the page with annotations (signatures, highlights,
    // filled form fields) travels with the crop, as it does when printing.
    final annotationRef = _annotationsAsForm(imports, source, sourcePage);
    String? annotationName;
    if (annotationRef != null) {
      var next = 1;
      while (xo.containsKey('An$next')) {
        next++;
      }
      annotationName = 'An$next';
      xo[annotationName] = annotationRef;
    }
    res['XObject'] = xo;
    dict['Resources'] = res;

    final text = 'q ${n(scale * a)} ${n(scale * bb)} ${n(scale * c)} '
        '${n(scale * d)} ${n(x + scale * e)} ${n(y + scale * f)} cm '
        '${n(l)} ${n(b)} ${n(r - l)} ${n(t - b)} re W n /$name Do '
        '${annotationName == null ? '' : '/$annotationName Do '}Q\n';
    this._appendContent(
        sheet, page, Uint8List.fromList(latin1.encode(text)));
  }

  /// One form holding the appearances of [source]'s page [index] annotations
  /// that print (not hidden, not a popup, link or reply), each placed where
  /// the annotation sits on the page; null when there is none. Made once per
  /// page and shared by every crop of it.
  CosReference? _annotationsAsForm(
      PdfSheetImports imports, PdfDocument source, int index) {
    final cache = imports._annotationForms.putIfAbsent(source, () => {});
    if (cache.containsKey(index)) return cache[index];
    final importer = imports._importers.putIfAbsent(
        source, () => _PageImporter(source, _updater.addObject));
    final srcCos = source.cos;
    final page = source.page(index);
    final objects = CosDictionary();
    final writer = ContentWriter();
    var count = 0;
    for (final annotation in page.annotations) {
      if (annotation.isHidden ||
          !annotation.isPrint ||
          annotation.subtype == 'Popup' ||
          annotation.subtype == 'Link' ||
          annotation.isReply ||
          annotation.isStateAnnotation) {
        continue;
      }
      final appearance = annotation.normalAppearance;
      if (appearance == null) continue;
      final bbox = pdfRectFrom(srcCos, appearance.dictionary['BBox']);
      final rect = annotation.rect;
      if (bbox == null ||
          bbox.width <= 0 ||
          bbox.height <= 0 ||
          rect.width <= 0 ||
          rect.height <= 0) {
        continue;
      }
      final fit = fitFormToRect(bbox, _sourceFormMatrix(srcCos, appearance), rect);
      final name = 'Ap$count';
      count++;
      final reference = srcCos.referenceTo(appearance);
      objects[name] =
          reference != null ? importer.copyValue(reference) : importer.copyValue(appearance);
      writer
        ..save()
        ..concatMatrix(fit.a, fit.b, fit.c, fit.d, fit.e, fit.f)
        ..drawXObject(name)
        ..restore();
    }
    if (count == 0) {
      cache[index] = null;
      return null;
    }
    final bytes = writer.takeBytes();
    final form = CosStream(
      CosDictionary({
        'Type': const CosName('XObject'),
        'Subtype': const CosName('Form'),
        'FormType': const CosInteger(1),
        'BBox': _rectArray(page.cropBox),
        'Resources': CosDictionary({'XObject': objects}),
        'Length': CosInteger(bytes.length),
      }),
      bytes,
    );
    return cache[index] = _updater.addObject(form);
  }

  /// A form's /Matrix, read from the source document it belongs to.
  PdfMatrix _sourceFormMatrix(CosDocument cos, CosStream form) {
    final raw = cos.resolve(form.dictionary['Matrix']);
    if (raw is CosArray && raw.length >= 6) {
      final values = <double>[];
      for (var i = 0; i < 6; i++) {
        final n = cos.resolve(raw[i]);
        values.add(
          n is CosInteger
              ? n.value.toDouble()
              : n is CosReal
                  ? n.value
                  : (i == 0 || i == 3 ? 1.0 : 0.0),
        );
      }
      return PdfMatrix.row(values);
    }
    return PdfMatrix.identity;
  }

  /// The form XObject for the whole of [source]'s page [index], made once
  /// per page and shared by every crop of it.
  CosReference _pageAsForm(
      PdfSheetImports imports, PdfDocument source, int index) {
    final cached = imports._forms.putIfAbsent(source, () => {})[index];
    if (cached != null) return cached;
    final importer = imports._importers.putIfAbsent(
        source, () => _PageImporter(source, _updater.addObject));
    final leaf = importer.importPages([index]).single;

    // The page's content, as one stream.
    final srcCos = source.cos;
    final srcPage = source.page(index);
    final raw = srcCos.resolve(srcPage.dict['Contents']);
    final streams = <CosStream>[
      if (raw is CosStream) raw,
      if (raw is CosArray)
        for (final item in raw.items)
          if (srcCos.resolve(item) case final CosStream s) s,
    ];
    final out = BytesBuilder();
    for (final s in streams) {
      out.add(srcCos.decodeStreamData(s));
      out.addByte(0x0A);
    }
    final bytes = out.takeBytes();

    final form = CosStream(
      CosDictionary({
        'Type': const CosName('XObject'),
        'Subtype': const CosName('Form'),
        'FormType': const CosInteger(1),
        'BBox': _rectArray(srcPage.cropBox),
        'Resources': leaf.dict['Resources'] ?? CosDictionary(),
        'Length': CosInteger(bytes.length),
      }),
      bytes,
    );
    final ref = _updater.addObject(form);
    imports._forms[source]![index] = ref;
    return ref;
  }
}
