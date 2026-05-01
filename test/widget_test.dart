// Smoke / unit tests for Pro-Link that do NOT require Firebase to be
// initialized. We test pure-Dart logic (models, utils, helpers) here
// rather than running the full app, which pulls in Firebase plugins.

import 'package:flutter_test/flutter_test.dart';
import 'package:prolink/core/constants/app_colors.dart';
import 'package:prolink/core/constants/app_constants.dart';
import 'package:prolink/core/utils/app_utils.dart';
import 'package:prolink/models/user_model.dart';

void main() {
  group('AppColors', () {
    test('primary navy is #1a2332', () {
      expect(AppColors.primary.toARGB32(), 0xFF1A2332);
    });
  });

  group('UserRole serialization', () {
    test('round-trips through string', () {
      for (final role in UserRole.values) {
        final encoded = role.value;
        final decoded = UserRoleExtension.fromString(encoded);
        expect(decoded, role);
      }
    });

    test('unknown strings default to intern', () {
      expect(
        UserRoleExtension.fromString('unknown-role'),
        UserRole.intern,
      );
    });
  });

  group('AppUtils status helpers', () {
    test('getStatusLabel returns a non-empty French label', () {
      final statuses = [
        AppConstants.statusActive,
        AppConstants.statusPending,
        AppConstants.statusRejected,
        AppConstants.statusCompleted,
      ];
      for (final s in statuses) {
        expect(AppUtils.getStatusLabel(s).isNotEmpty, isTrue);
      }
    });

    test('getAttendanceLabel returns a label per status', () {
      expect(
        AppUtils.getAttendanceLabel(AppConstants.attendancePresent),
        'Present',
      );
      expect(
        AppUtils.getAttendanceLabel(AppConstants.attendanceAbsent),
        'Absent',
      );
    });
  });
}
