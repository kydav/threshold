import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:threshold/features/templates/data/form_capture_service.dart';
import 'package:threshold/features/templates/data/form_template.dart';
import 'package:uuid/uuid.dart';

/// Stores templates on the device: `templates/<id>/template.json` plus one
/// cleaned JPEG per page. Agreements already live on-device, so templates do
/// too for the proof of concept; cloud sync can come later.
class TemplateRepository {
  Future<Directory> _root() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/templates');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<Directory> folder(String templateId) async =>
      Directory('${(await _root()).path}/$templateId');

  Future<File> pageFile(FormTemplate t, int pageIndex) async =>
      File('${(await folder(t.id)).path}/${t.pages[pageIndex].file}');

  /// Builds a template from captured pages and the model's field map. Pages
  /// are cleaned first: anything the source copy already had written in is
  /// erased, so a filled-in copy works as a blank form.
  Future<FormTemplate> create({
    required List<CapturedPage> pages,
    required FieldMap map,
  }) async {
    final id = const Uuid().v4();
    final dir = await folder(id);
    dir.createSync(recursive: true);

    final fields = [for (final f in map.fields) TemplateField.fromMap(f)];
    final stored = <TemplatePage>[];
    for (var i = 0; i < pages.length; i++) {
      final page = pages[i];
      final clean = cleanPage(
        page.jpeg,
        fields.where((f) => f.page == i + 1 && f.currentlyFilled),
      );
      final name = 'page_${i + 1}.jpg';
      await File('${dir.path}/$name').writeAsBytes(clean);
      stored.add(
        TemplatePage(file: name, width: page.width, height: page.height),
      );
    }

    final template = FormTemplate(
      id: id,
      title: map.title,
      formId: map.formId,
      pages: stored,
      fields: fields,
      createdAt: DateTime.now(),
    );
    await save(template);
    return template;
  }

  Future<void> save(FormTemplate t) async {
    final dir = await folder(t.id);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    await File(
      '${dir.path}/template.json',
    ).writeAsString(jsonEncode(t.toMap()));
  }

  Future<List<FormTemplate>> all() async {
    final root = await _root();
    final out = <FormTemplate>[];
    for (final entry in root.listSync().whereType<Directory>()) {
      final file = File('${entry.path}/template.json');
      if (!file.existsSync()) continue;
      try {
        out.add(
          FormTemplate.fromMap(
            jsonDecode(await file.readAsString()) as Map<String, dynamic>,
          ),
        );
      } catch (_) {
        // A half-written template from an interrupted save: skip it.
      }
    }
    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }

  Future<void> delete(String templateId) async {
    final dir = await folder(templateId);
    if (dir.existsSync()) await dir.delete(recursive: true);
  }
}

/// Erases what a filled-in copy already had written on it:
///  1. pen ink: blue-dominant pixels turn white (print is black, pens are
///     usually blue), which catches signatures that stray outside their box;
///  2. each previously filled field's box is painted white, which catches
///     black ink and typed entries. The bottom few pixels are kept so the
///     printed underline survives; checkboxes keep their outline.
Uint8List cleanPage(Uint8List jpeg, Iterable<TemplateField> filled) {
  final page = img.decodeJpg(jpeg);
  if (page == null) return jpeg;

  // Pen ink: blue-leaning pixels (print is neutral grey/black), grown by two
  // pixels so the anti-aliased edges of each stroke go too.
  final w = page.width;
  final h = page.height;
  final ink = List<bool>.filled(w * h, false);
  for (final p in page) {
    final maxRg = p.r > p.g ? p.r : p.g;
    if (p.b > 60 && p.b - maxRg > 18) ink[p.y * w + p.x] = true;
  }
  const grow = 2;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (!ink[y * w + x]) continue;
      for (var dy = -grow; dy <= grow; dy++) {
        final yy = y + dy;
        if (yy < 0 || yy >= h) continue;
        for (var dx = -grow; dx <= grow; dx++) {
          final xx = x + dx;
          if (xx < 0 || xx >= w) continue;
          page.setPixelRgb(xx, yy, 255, 255, 255);
        }
      }
    }
  }

  final white = img.ColorRgb8(255, 255, 255);
  for (final f in filled) {
    final box = f.box;
    if (f.kind == FieldKind.checkbox) {
      final inset = box.deflate(box.shortestSide * 0.22);
      img.fillRect(
        page,
        x1: inset.left.round(),
        y1: inset.top.round(),
        x2: inset.right.round(),
        y2: inset.bottom.round(),
        color: white,
      );
    } else {
      img.fillRect(
        page,
        x1: box.left.round(),
        y1: box.top.round(),
        x2: box.right.round(),
        y2: (box.bottom - 4).round(),
        color: white,
      );
    }
  }
  return Uint8List.fromList(img.encodeJpg(page, quality: 90));
}

final templateRepositoryProvider = Provider((_) => TemplateRepository());

final templatesProvider = FutureProvider<List<FormTemplate>>(
  (ref) => ref.watch(templateRepositoryProvider).all(),
);
