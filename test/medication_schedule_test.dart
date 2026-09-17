import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

String formatMedicationDisplayTime(String? rawTime) {
  if (rawTime == null || rawTime.trim().isEmpty || rawTime == '--:--') {
    return '--:-- WIB';
  }
  final parts = rawTime.trim().split(':');
  if (parts.length >= 2) {
    final hh = parts[0].padLeft(2, '0');
    final mm = parts[1].padLeft(2, '0');
    return '$hh:$mm WIB';
  }
  return '$rawTime WIB';
}

String getEffectiveMedicationTime({
  required Map<String, dynamic> patientData,
  Map<String, dynamic>? currentTreatment,
}) {
  final schedule = patientData['medication_schedule'];
  if (schedule != null &&
      schedule['reminder_time'] != null &&
      schedule['reminder_time'].toString().trim().isNotEmpty) {
    return schedule['reminder_time'].toString().trim();
  }
  if (currentTreatment != null &&
      currentTreatment['medication_time'] != null &&
      currentTreatment['medication_time'].toString().trim().isNotEmpty) {
    return currentTreatment['medication_time'].toString().trim();
  }
  return '';
}

DateTime calculateNextAlarmOccurrence(int hour, int minute, DateTime now) {
  var scheduled = DateTime(now.year, now.month, now.day, hour, minute);
  if (scheduled.isBefore(now)) {
    scheduled = scheduled.add(const Duration(days: 1));
  }
  return scheduled;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', '');
  });

  group('Medication Schedule Formatting & Parsing Tests', () {
    test('Format valid HH:mm:ss to HH:mm WIB', () {
      expect(formatMedicationDisplayTime('08:00:00'), '08:00 WIB');
      expect(formatMedicationDisplayTime('20:30:00'), '20:30 WIB');
      expect(formatMedicationDisplayTime('07:05:00'), '07:05 WIB');
    });

    test('Format single digit hour and minute properly', () {
      expect(formatMedicationDisplayTime('8:5'), '08:05 WIB');
    });

    test('Format null, empty, or placeholder time returns default', () {
      expect(formatMedicationDisplayTime(null), '--:-- WIB');
      expect(formatMedicationDisplayTime(''), '--:-- WIB');
      expect(formatMedicationDisplayTime('   '), '--:-- WIB');
      expect(formatMedicationDisplayTime('--:--'), '--:-- WIB');
    });
  });

  group('Medication Schedule Priority Logic Tests', () {
    test('patient_medication_schedules overrides legacy treatment medication_time', () {
      final patientData = {
        'treatment_start_date': '2026-09-17',
        'medication_schedule': {
          'reminder_time': '07:30:00',
          'is_active': true,
        },
      };
      final currentTreatment = {
        'medication_time': '08:00:00',
      };

      final effectiveTime = getEffectiveMedicationTime(
        patientData: patientData,
        currentTreatment: currentTreatment,
      );

      expect(effectiveTime, '07:30:00');
      expect(formatMedicationDisplayTime(effectiveTime), '07:30 WIB');
    });

    test('Falls back to treatment medication_time when medication_schedule is null', () {
      final patientData = {
        'treatment_start_date': '2026-09-17',
        'medication_schedule': null,
      };
      final currentTreatment = {
        'medication_time': '08:00:00',
      };

      final effectiveTime = getEffectiveMedicationTime(
        patientData: patientData,
        currentTreatment: currentTreatment,
      );

      expect(effectiveTime, '08:00:00');
      expect(formatMedicationDisplayTime(effectiveTime), '08:00 WIB');
    });

    test('Works when treatments list is empty (new patient with treatment_start_date only)', () {
      final patientData = {
        'treatment_start_date': '2026-09-17',
        'treatments': [],
        'medication_schedule': {
          'reminder_time': '09:00:00',
          'is_active': true,
        },
      };

      final effectiveTime = getEffectiveMedicationTime(
        patientData: patientData,
        currentTreatment: null,
      );

      expect(effectiveTime, '09:00:00');
      expect(formatMedicationDisplayTime(effectiveTime), '09:00 WIB');
    });

    test('Returns empty string when neither medication_schedule nor treatment has time', () {
      final patientData = {
        'treatment_start_date': '2026-09-17',
        'treatments': [],
        'medication_schedule': null,
      };

      final effectiveTime = getEffectiveMedicationTime(
        patientData: patientData,
        currentTreatment: null,
      );

      expect(effectiveTime, '');
    });
  });

  group('Alarm Scheduling Time Calculations', () {
    test('Schedules for today if reminder time is in the future', () {
      final now = DateTime(2026, 9, 18, 6, 0); // 06:00
      final scheduled = calculateNextAlarmOccurrence(8, 0, now); // Target 08:00

      expect(scheduled.day, now.day);
      expect(scheduled.hour, 8);
      expect(scheduled.minute, 0);
    });

    test('Schedules for tomorrow if reminder time has already passed today', () {
      final now = DateTime(2026, 9, 18, 10, 0); // 10:00
      final scheduled = calculateNextAlarmOccurrence(8, 0, now); // Target 08:00

      expect(scheduled.day, now.day + 1);
      expect(scheduled.hour, 8);
      expect(scheduled.minute, 0);
    });
  });
}
