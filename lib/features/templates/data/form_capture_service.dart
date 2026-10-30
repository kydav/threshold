import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

/// Long edge of a stored page, in pixels. Matches what the vision model reads
/// natively, so field boxes come back in the same pixel space we store.
const kPageMaxEdge = 1568;

/// A page ready for field mapping: a normalised JPEG plus its OCR lines.
class CapturedPage {
  CapturedPage({
    required this.jpeg,
    required this.width,
    required this.height,
    required this.ocr,
  });

  final Uint8List jpeg;
  final int width;
  final int height;
  final List<({String text, List<int> box})> ocr;
}

/// The map Claude returned: form title/id and the raw field list.
typedef FieldMap =
    ({String title, String formId, List<Map<String, dynamic>> fields});

/// Turns a paper or PDF form into pages + a field map.
class FormCaptureService {
  /// Opens the native document scanner (auto edge-detect, flatten, crop).
  /// Returns null if the agent cancels.
  Future<List<Uint8List>?> scan() async {
    final paths = await CunningDocumentScanner.getPictures();
    if (paths == null || paths.isEmpty) return null;
    return [for (final p in paths) await File(p).readAsBytes()];
  }

  /// Lets the agent pick a PDF and renders each page to an image.
  Future<List<Uint8List>?> pickPdf() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (files.isEmpty) return null;
    final bytes = await files.first.readAsBytes();
    final pages = <Uint8List>[];
    // 150 dpi is plenty for an 8.5x11 page at the 1568 px we store.
    await for (final page in Printing.raster(bytes, dpi: 150)) {
      pages.add(await page.toPng());
    }
    return pages;
  }

  /// Resizes a page image to [kPageMaxEdge] as a JPEG and reads its text
  /// on-device. OCR runs on the resized image so its boxes share the pixel
  /// space the model and the stored template use.
  Future<CapturedPage> prepare(Uint8List source) async {
    final decoded = img.decodeImage(source);
    if (decoded == null) throw const FormatException('Unreadable image');
    final oriented = img.bakeOrientation(decoded);
    final longEdge =
        oriented.width > oriented.height ? oriented.width : oriented.height;
    final resized =
        longEdge > kPageMaxEdge
            ? img.copyResize(
              oriented,
              width: oriented.width >= oriented.height ? kPageMaxEdge : null,
              height: oriented.height > oriented.width ? kPageMaxEdge : null,
              interpolation: img.Interpolation.average,
            )
            : oriented;
    final jpeg = Uint8List.fromList(img.encodeJpg(resized, quality: 88));

    // ML Kit reads from a file path most reliably across platforms.
    final tmp = File(
      '${(await getTemporaryDirectory()).path}/ocr_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await tmp.writeAsBytes(jpeg);
    final recognizer = TextRecognizer();
    try {
      final result = await recognizer.processImage(
        InputImage.fromFilePath(tmp.path),
      );
      final ocr = [
        for (final block in result.blocks)
          for (final line in block.lines)
            (
              text: line.text,
              box: [
                line.boundingBox.left.round(),
                line.boundingBox.top.round(),
                line.boundingBox.right.round(),
                line.boundingBox.bottom.round(),
              ],
            ),
      ];
      return CapturedPage(
        jpeg: jpeg,
        width: resized.width,
        height: resized.height,
        ocr: ocr,
      );
    } finally {
      await recognizer.close();
      if (tmp.existsSync()) await tmp.delete();
    }
  }

  /// Sends the pages to the mapFormFields function (Claude, server-side).
  Future<FieldMap> mapFields(List<CapturedPage> pages) async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'mapFormFields',
      options: HttpsCallableOptions(timeout: const Duration(minutes: 5)),
    );
    final result = await callable.call<dynamic>({
      'pages': [
        for (final p in pages)
          {
            'jpegBase64': base64Encode(p.jpeg),
            'width': p.width,
            'height': p.height,
            'ocr': [
              for (final l in p.ocr) {'text': l.text, 'box': l.box},
            ],
          },
      ],
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return (
      title: data['form_title'] as String? ?? 'My form',
      formId: data['form_id'] as String? ?? '',
      fields: [
        for (final f in data['fields'] as List)
          Map<String, dynamic>.from(f as Map),
      ],
    );
  }
}
