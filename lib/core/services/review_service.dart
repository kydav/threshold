import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:path_provider/path_provider.dart';

/// Asks for a store rating once the agent has finished a couple of signings.
///
/// Call [recordSigning] right after an agreement is signed. The second
/// signing triggers the OS review sheet, once per install. The OS also
/// throttles the sheet (iOS shows it at most 3 times a year) and may skip it.
class ReviewService {
  static const _askAfter = 2;

  Future<File> get _file async =>
      File('${(await getApplicationDocumentsDirectory()).path}/review_state');

  /// Signings counted so far, or -1 once we've asked.
  Future<int> _read() async {
    try {
      final f = await _file;
      if (!f.existsSync()) return 0;
      return int.tryParse((await f.readAsString()).trim()) ?? 0;
    } on FileSystemException {
      return 0;
    }
  }

  Future<void> recordSigning() async {
    try {
      final count = await _read();
      if (count < 0) return;
      final next = count + 1;
      final f = await _file;
      if (next < _askAfter) {
        await f.writeAsString('$next');
        return;
      }
      final review = InAppReview.instance;
      if (!await review.isAvailable()) {
        await f.writeAsString('$next');
        return;
      }
      await f.writeAsString('-1');
      // Let the success screen settle before the sheet appears.
      await Future<void>.delayed(const Duration(milliseconds: 800));
      await review.requestReview();
    } on Exception catch (e) {
      // A rating prompt must never break signing.
      debugPrint('Review prompt skipped: $e');
    }
  }
}

final reviewServiceProvider = Provider((_) => ReviewService());
