import 'dart:typed_data';

import 'package:dart_pdf_editor/dart_pdf_editor.dart'
    show PdfDialogSubmit, showPdfDialog;
import 'package:material_ui/material_ui.dart';

import 'l10n/app_l10n.dart';
import 'pdf_conversions.dart';

/// Una foto scelta: il nome del file e i suoi byte.
class PhotoItem {
  const PhotoItem(this.name, this.bytes);

  final String name;
  final Uint8List bytes;
}

/// Il testo che spiega come sarà la pagina di ogni foto.
String photoPdfPageHint(PhotoPdfPage page) => switch (page) {
      PhotoPdfPage.a4 =>
        'Foglio A4, in piedi o per traverso secondo la foto. La foto ci sta tutta.',
      PhotoPdfPage.photoSize =>
        'La pagina ha la forma della foto, senza bordi bianchi.',
    };

/// Chiede l'ordine delle [photos] (si trascinano) e come deve essere la
/// pagina di ognuna. Ogni foto diventa una pagina. Si possono anche togliere
/// foto dall'elenco. Restituisce null se si annulla.
Future<({List<PhotoItem> photos, PhotoPdfPage page})?> showPhotosToPdfDialog(
    BuildContext context, List<PhotoItem> photos) {
  final order = [...photos];
  var page = PhotoPdfPage.a4;
  return showPdfDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        void confirm() {
          if (order.isEmpty) return;
          Navigator.of(context).pop((photos: order, page: page));
        }

        return AlertDialog(
          key: const ValueKey('photos-pdf-dialog'),
          title: Text('Foto in PDF (${order.length})'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                    'Ogni foto diventa una pagina. Trascina le foto per '
                    'cambiare l\'ordine.'),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: ReorderableListView.builder(
                    key: const ValueKey('photos-pdf-order'),
                    shrinkWrap: true,
                    buildDefaultDragHandles: false,
                    itemCount: order.length,
                    onReorderItem: (from, to) =>
                        setState(() => order.insert(to, order.removeAt(from))),
                    itemBuilder: (context, index) => ListTile(
                      key: ObjectKey(order[index]),
                      dense: true,
                      leading: SizedBox(
                        width: 44,
                        height: 44,
                        child: Image.memory(
                          order[index].bytes,
                          fit: BoxFit.cover,
                          cacheWidth: 96,
                          gaplessPlayback: true,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.image_outlined),
                        ),
                      ),
                      title: Text(
                        order[index].name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text('Pagina ${index + 1}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            key: ValueKey('photos-pdf-remove-$index'),
                            tooltip: 'Togli dall\'elenco',
                            icon: const Icon(Icons.close),
                            onPressed: () =>
                                setState(() => order.removeAt(index)),
                          ),
                          ReorderableDragStartListener(
                            index: index,
                            child: const Icon(Icons.drag_handle),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Pagina'),
                const SizedBox(height: 8),
                SegmentedButton<PhotoPdfPage>(
                  key: const ValueKey('photos-pdf-page'),
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                        value: PhotoPdfPage.a4, label: Text('A4')),
                    ButtonSegment(
                        value: PhotoPdfPage.photoSize,
                        label: Text('Misura della foto')),
                  ],
                  selected: {page},
                  onSelectionChanged: (s) => setState(() => page = s.first),
                ),
                const SizedBox(height: 8),
                Text(photoPdfPageHint(page)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(appL10n(context).cancel),
            ),
            PdfDialogSubmit.action(
              onSubmit: confirm,
              child: FilledButton(
                key: const ValueKey('photos-pdf-confirm'),
                onPressed: order.isEmpty ? null : confirm,
                child: const Text('Crea PDF'),
              ),
            ),
          ],
        );
      },
    ),
  );
}
