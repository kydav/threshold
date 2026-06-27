import 'package:flutter_test/flutter_test.dart';

// The _lines and _initials helpers are private to OklahomaPdfService.
// We replicate them here as pure functions to test the logic in isolation
// without needing to instantiate the full service (which requires Firebase).
//
// If the implementation ever changes, these tests serve as a contract to
// keep the new implementation behaviorally equivalent.

List<String> _lines(String text, int count) {
  final parts = text.split('\n');
  return List.generate(
    count,
    (i) => i < parts.length ? parts[i].trim() : '',
  );
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

void main() {
  group('_lines helper (Oklahoma additional provisions split)', () {
    test('splits a multi-line string into exactly count elements', () {
      const text = 'Line 1\nLine 2\nLine 3';
      final result = _lines(text, 4);
      expect(result.length, 4);
      expect(result[0], 'Line 1');
      expect(result[1], 'Line 2');
      expect(result[2], 'Line 3');
      expect(result[3], '');
    });

    test('pads with empty strings when input has fewer lines than count', () {
      final result = _lines('Only one line', 4);
      expect(result.length, 4);
      expect(result[0], 'Only one line');
      expect(result[1], '');
      expect(result[2], '');
      expect(result[3], '');
    });

    test('trims whitespace from each line', () {
      final result = _lines('  trimmed  \n  also trimmed  ', 2);
      expect(result[0], 'trimmed');
      expect(result[1], 'also trimmed');
    });

    test('handles empty string input', () {
      final result = _lines('', 4);
      expect(result.length, 4);
      expect(result[0], '');
    });

    test('handles count = 0', () {
      final result = _lines('some text', 0);
      expect(result, isEmpty);
    });

    test('truncates to count when input has more lines', () {
      final text = List.generate(10, (i) => 'Line $i').join('\n');
      final result = _lines(text, 4);
      expect(result.length, 4);
      expect(result[3], 'Line 3');
    });
  });

  group('_initials helper (Oklahoma buyer initials)', () {
    test('returns first letter of each of first and last name, uppercased', () {
      expect(_initials('John Doe'), 'JD');
    });

    test('returns only first letter for single-word name', () {
      expect(_initials('Cher'), 'C');
    });

    test('uses first and last parts for multi-word names (e.g. "Mary Jane Watson")', () {
      // Parts: ['Mary', 'Jane', 'Watson'] → first='M', last='W'
      expect(_initials('Mary Jane Watson'), 'MW');
    });

    test('uppercases both initials', () {
      expect(_initials('john doe'), 'JD');
    });

    test('returns empty string for empty input', () {
      expect(_initials(''), '');
    });

    test('returns empty string for whitespace-only input', () {
      expect(_initials('   '), '');
    });

    test('trims leading/trailing whitespace before extracting initials', () {
      expect(_initials('  John Doe  '), 'JD');
    });
  });
}
