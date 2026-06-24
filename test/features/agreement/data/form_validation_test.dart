// Tests for the validation logic that lives in FormScreen._validateStep().
// The widget depends on Flutter UI so we extract the pure logic for unit testing.
import 'package:flutter_test/flutter_test.dart';

// Pure functions that mirror the validation logic in
// lib/features/agreement/presentation/form_screen.dart (_validateStep).
// They are extracted here so they can be unit-tested without a widget tree.

String? validateBuyerName(String value) {
  if (value.trim().isEmpty) return "Buyer's name is required.";
  return null;
}

String? validateBuyerEmail(String value) {
  final email = value.trim();
  if (!email.contains('@') || !email.contains('.')) {
    return 'Enter a valid email address.';
  }
  return null;
}

String? validatePropertyScope(String value) {
  if (value.trim().isEmpty) return 'Property scope is required.';
  return null;
}

String? validateCompensation(String value) {
  if (value.trim().isEmpty) return 'Compensation is required.';
  return null;
}

String? validateDateRange(DateTime startDate, DateTime endDate) {
  if (!endDate.isAfter(startDate)) {
    return 'End date must be after start date.';
  }
  return null;
}

void main() {
  group('validateBuyerName', () {
    test('returns null for non-empty name', () {
      expect(validateBuyerName('John Doe'), isNull);
    });

    test('returns error for empty string', () {
      expect(validateBuyerName(''), isNotNull);
    });

    test('returns error for whitespace-only string', () {
      expect(validateBuyerName('   '), isNotNull);
    });

    test('error message is correct', () {
      expect(validateBuyerName(''), "Buyer's name is required.");
    });

    test('accepts single-word name', () {
      expect(validateBuyerName('Cher'), isNull);
    });
  });

  group('validateBuyerEmail', () {
    test('returns null for valid email', () {
      expect(validateBuyerEmail('buyer@example.com'), isNull);
    });

    test('returns error for email without @', () {
      expect(validateBuyerEmail('invalidemail.com'), isNotNull);
    });

    test('returns error for email without dot', () {
      expect(validateBuyerEmail('invalid@email'), isNotNull);
    });

    test('returns error for empty string', () {
      expect(validateBuyerEmail(''), isNotNull);
    });

    test('returns error for whitespace-only string', () {
      expect(validateBuyerEmail('   '), isNotNull);
    });

    test('error message is correct', () {
      expect(validateBuyerEmail('bad'), 'Enter a valid email address.');
    });

    // Edge-case: this validation is intentionally minimal (no RFC compliance).
    // A string like "@." technically passes the current checks.
    test('accepts minimal "@." pattern (known loose validation)', () {
      expect(validateBuyerEmail('@.'), isNull);
    });
  });

  group('validatePropertyScope', () {
    test('returns null for non-empty scope', () {
      expect(validatePropertyScope('123 Main St'), isNull);
    });

    test('returns error for empty string', () {
      expect(validatePropertyScope(''), isNotNull);
    });

    test('returns error for whitespace only', () {
      expect(validatePropertyScope('  '), isNotNull);
    });
  });

  group('validateCompensation', () {
    test('returns null for percentage string', () {
      expect(validateCompensation('2.5%'), isNull);
    });

    test('returns null for dollar string', () {
      expect(validateCompensation('\$10,000'), isNull);
    });

    test('returns error for empty string', () {
      expect(validateCompensation(''), isNotNull);
    });

    test('returns error for whitespace only', () {
      expect(validateCompensation('   '), isNotNull);
    });
  });

  group('validateDateRange', () {
    final start = DateTime(2025, 1, 1);

    test('returns null when end is strictly after start', () {
      expect(validateDateRange(start, DateTime(2025, 4, 1)), isNull);
    });

    test('returns error when end equals start', () {
      expect(validateDateRange(start, start), isNotNull);
    });

    test('returns error when end is before start', () {
      expect(
        validateDateRange(start, DateTime(2024, 12, 31)),
        isNotNull,
      );
    });

    test('error message is correct', () {
      expect(
        validateDateRange(start, start),
        'End date must be after start date.',
      );
    });

    test('returns null for next-day end date', () {
      expect(
        validateDateRange(start, start.add(const Duration(days: 1))),
        isNull,
      );
    });
  });
}
