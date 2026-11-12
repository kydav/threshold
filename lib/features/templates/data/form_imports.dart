import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:threshold/features/templates/data/form_capture_service.dart';
import 'package:threshold/features/templates/data/form_template.dart';
import 'package:threshold/features/templates/data/template_repository.dart';
import 'package:uuid/uuid.dart';

enum ImportStatus {
  /// Sending the pages to the server.
  uploading,

  /// The server is reading the form.
  reading,

  /// Upload or reading failed; can be retried.
  failed,
}

/// A form being set up in the background. Its pages wait on the phone
/// (`form_imports/<id>/`) until the server's field map comes back.
@immutable
class PendingImport {
  const PendingImport({
    required this.id,
    required this.uid,
    required this.createdAt,
    required this.pageCount,
    required this.status,
    this.jobId,
    this.error,
  });

  factory PendingImport.fromMap(Map<String, dynamic> m) => PendingImport(
    id: m['id'] as String,
    uid: m['uid'] as String? ?? '',
    createdAt: DateTime.parse(m['createdAt'] as String),
    pageCount: (m['pageCount'] as num).toInt(),
    status: ImportStatus.values.byName(m['status'] as String),
    jobId: m['jobId'] as String?,
    error: m['error'] as String?,
  );

  final String id;
  final String uid;
  final DateTime createdAt;
  final int pageCount;
  final ImportStatus status;
  final String? jobId;
  final String? error;

  PendingImport copyWith({
    ImportStatus? status,
    String? jobId,
    String? error,
  }) => PendingImport(
    id: id,
    uid: uid,
    createdAt: createdAt,
    pageCount: pageCount,
    status: status ?? this.status,
    jobId: jobId ?? this.jobId,
    error: status == ImportStatus.failed ? error : null,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'uid': uid,
    'createdAt': createdAt.toIso8601String(),
    'pageCount': pageCount,
    'status': status.name,
    if (jobId != null) 'jobId': jobId,
    if (error != null) 'error': error,
  };
}

/// Form imports in progress for the signed-in agent.
///
/// The server reads each form on its own, so the agent can leave the screen
/// or the app. While the app is open this polls every few seconds; when
/// it's reopened it picks up where it left off. A finished form becomes a
/// template and is announced on [formReadyProvider].
class FormImports extends Notifier<List<PendingImport>>
    with WidgetsBindingObserver {
  final _capture = FormCaptureService();
  Timer? _timer;
  bool _polling = false;

  static const _pollEvery = Duration(seconds: 5);

  @override
  List<PendingImport> build() {
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      _timer?.cancel();
    });
    // Reload when the agent changes; each only sees their own imports.
    ref.listen(_uidProvider, (_, _) => unawaited(_load()));
    unawaited(_load());
    return const [];
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // (Shadows the notifier's state; only the lifecycle is read here.)
    if (state == AppLifecycleState.resumed) {
      _schedule(immediately: true);
    } else if (state == AppLifecycleState.paused) {
      _timer?.cancel();
    }
  }

  /// Starts reading [pages] in the background. Returns the template right
  /// away when the server already knows this form; otherwise null, and the
  /// import shows on My forms until it's done.
  /// [pdf] is the uploaded file, if the form came from one.
  Future<FormTemplate?> start(
    List<CapturedPage> pages, {
    Uint8List? pdf,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    var item = PendingImport(
      id: const Uuid().v4(),
      uid: uid,
      createdAt: DateTime.now(),
      pageCount: pages.length,
      status: ImportStatus.uploading,
    );
    await _savePages(item.id, pages);
    if (pdf != null && pdf.length <= kMaxPdfBytes) {
      await File('${(await _dir(item.id)).path}/source.pdf').writeAsBytes(pdf);
    }
    await _put(item);
    return _upload(item, pages);
  }

  /// Tries a failed import again: polls a job that may have finished after
  /// all, or uploads the pages again.
  Future<FormTemplate?> retry(String id) async {
    final item = state.where((i) => i.id == id).firstOrNull;
    if (item == null) return null;
    if (item.jobId != null && item.error == null) {
      await _put(item.copyWith(status: ImportStatus.reading));
      _schedule(immediately: true);
      return null;
    }
    await _put(item.copyWith(status: ImportStatus.uploading));
    return _upload(item, await _loadPages(item));
  }

  Future<void> remove(String id) async {
    state = [
      for (final i in state)
        if (i.id != id) i,
    ];
    final dir = await _dir(id);
    if (dir.existsSync()) await dir.delete(recursive: true);
  }

  Future<FormTemplate?> _upload(
    PendingImport item,
    List<CapturedPage> pages,
  ) async {
    try {
      final source = File('${(await _dir(item.id)).path}/source.pdf');
      final job = await _capture.startJob(
        pages,
        pdf: source.existsSync() ? await source.readAsBytes() : null,
      );
      if (job.isDone) {
        return _finish(item.copyWith(jobId: job.jobId), job, pages: pages);
      }
      await _put(item.copyWith(status: ImportStatus.reading, jobId: job.jobId));
      _schedule();
      return null;
    } on Exception catch (e) {
      debugPrint('Form upload failed: $e');
      await _put(
        item.copyWith(
          status: ImportStatus.failed,
          error:
              'Could not upload the form. Check your connection and try '
              'again.',
        ),
      );
      return null;
    }
  }

  void _schedule({bool immediately = false}) {
    _timer?.cancel();
    if (!state.any((i) => i.status == ImportStatus.reading)) return;
    if (immediately) unawaited(_pollAll());
    _timer = Timer.periodic(_pollEvery, (_) => unawaited(_pollAll()));
  }

  Future<void> _pollAll() async {
    if (_polling) return;
    _polling = true;
    try {
      for (final item in [...state]) {
        if (item.status != ImportStatus.reading || item.jobId == null) {
          continue;
        }
        final FormJob job;
        try {
          job = await _capture.pollJob(item.jobId!);
        } on Exception catch (e) {
          // Offline or a blip: try again on the next tick.
          debugPrint('Form job poll failed: $e');
          continue;
        }
        if (job.isDone) {
          await _finish(item, job);
        } else if (job.isError) {
          await _put(
            item.copyWith(
              status: ImportStatus.failed,
              error: job.error ?? 'Could not read the form.',
            ),
          );
        }
      }
    } finally {
      _polling = false;
      if (!state.any((i) => i.status == ImportStatus.reading)) {
        _timer?.cancel();
      }
    }
  }

  Future<FormTemplate?> _finish(
    PendingImport item,
    FormJob job, {
    List<CapturedPage>? pages,
  }) async {
    try {
      final template = await ref
          .read(templateRepositoryProvider)
          .create(
            pages: pages ?? await _loadPages(item),
            map: job.map!,
            mapJobId: job.jobId,
            checkInk: job.cached,
          );
      await remove(item.id);
      ref.invalidate(templatesProvider);
      // Announced only when it finished out of sight; the capture screen
      // opens a form that's ready right away itself.
      if (pages == null) {
        ref.read(formReadyProvider.notifier).state = template;
      }
      return template;
    } on Exception catch (e) {
      debugPrint('Could not save the imported form: $e');
      await _put(
        item.copyWith(
          status: ImportStatus.failed,
          error: 'Could not save the form on this phone.',
        ),
      );
      return null;
    }
  }

  // ---- Storage: form_imports/<id>/{import.json, page_<n>.jpg|.json,
  //      source.pdf (uploaded PDFs only)} ----

  Future<Directory> _root() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/form_imports');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<Directory> _dir(String id) async =>
      Directory('${(await _root()).path}/$id');

  Future<void> _put(PendingImport item) async {
    final dir = await _dir(item.id);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    await File(
      '${dir.path}/import.json',
    ).writeAsString(jsonEncode(item.toMap()));
    final exists = state.any((i) => i.id == item.id);
    state =
        exists
            ? [for (final i in state) i.id == item.id ? item : i]
            : [item, ...state];
  }

  Future<void> _savePages(String id, List<CapturedPage> pages) async {
    final dir = await _dir(id);
    dir.createSync(recursive: true);
    for (var i = 0; i < pages.length; i++) {
      final p = pages[i];
      await File('${dir.path}/page_$i.jpg').writeAsBytes(p.jpeg);
      await File('${dir.path}/page_$i.json').writeAsString(
        jsonEncode({
          'width': p.width,
          'height': p.height,
          'ocr': [
            for (final l in p.ocr) {'text': l.text, 'box': l.box},
          ],
        }),
      );
    }
  }

  Future<List<CapturedPage>> _loadPages(PendingImport item) async {
    final dir = await _dir(item.id);
    return [
      for (var i = 0; i < item.pageCount; i++)
        await () async {
          final meta =
              jsonDecode(await File('${dir.path}/page_$i.json').readAsString())
                  as Map<String, dynamic>;
          return CapturedPage(
            jpeg: await File('${dir.path}/page_$i.jpg').readAsBytes(),
            width: (meta['width'] as num).toInt(),
            height: (meta['height'] as num).toInt(),
            ocr: [
              for (final l in meta['ocr'] as List)
                (
                  text: (l as Map)['text'] as String,
                  box: [for (final v in l['box'] as List) (v as num).toInt()],
                ),
            ],
          );
        }(),
    ];
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final out = <PendingImport>[];
    if (uid != null) {
      for (final dir in (await _root()).listSync().whereType<Directory>()) {
        final file = File('${dir.path}/import.json');
        if (!file.existsSync()) continue;
        try {
          var item = PendingImport.fromMap(
            jsonDecode(await file.readAsString()) as Map<String, dynamic>,
          );
          if (item.uid != uid) continue;
          // The app closed mid-upload: the agent retries.
          if (item.status == ImportStatus.uploading) {
            item = item.copyWith(
              status: ImportStatus.failed,
              error: 'The upload was interrupted.',
            );
          }
          out.add(item);
        } catch (_) {
          // A half-written record: skip it.
        }
      }
    }
    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = out;
    _schedule(immediately: true);
  }
}

final _uidProvider = StreamProvider<String?>(
  (_) => FirebaseAuth.instance.authStateChanges().map((u) => u?.uid),
);

final formImportsProvider = NotifierProvider<FormImports, List<PendingImport>>(
  FormImports.new,
);

/// The last form that finished setting up in the background, for the
/// "ready" alert. The app clears it once shown.
final formReadyProvider = StateProvider<FormTemplate?>((_) => null);
