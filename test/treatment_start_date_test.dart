import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

int calculateCurrentDay(String? startDate, String? endDate, {DateTime? mockToday}) {
  if (startDate == null || startDate.trim().isEmpty) return 0;

  try {
    final start = DateTime.parse(startDate);
    final now = mockToday ?? DateTime.now();

    final startOnly = DateTime(start.year, start.month, start.day);
    final todayOnly = DateTime(now.year, now.month, now.day);

    if (todayOnly.isBefore(startOnly)) return 0;

    if (endDate != null && endDate.trim().isNotEmpty) {
      final end = DateTime.tryParse(endDate);
      if (end != null) {
        final endOnly = DateTime(end.year, end.month, end.day);
        if (todayOnly.isAfter(endOnly)) {
          return endOnly.difference(startOnly).inDays + 1;
        }
      }
    }

    return todayOnly.difference(startOnly).inDays + 1;
  } catch (e) {
    return 0;
  }
}

int calculateTotalDays(String? startDate, String? endDate) {
  if (startDate == null || endDate == null || endDate.trim().isEmpty) {
    return 180;
  }

  try {
    final start = DateTime.parse(startDate);
    final end = DateTime.parse(endDate);

    final startOnly = DateTime(start.year, start.month, start.day);
    final endOnly = DateTime(end.year, end.month, end.day);

    final diff = endOnly.difference(startOnly).inDays + 1;
    return diff > 0 ? diff : 180;
  } catch (e) {
    return 180;
  }
}

String formatTreatmentDates(String? rawStartDate, String? rawEndDate) {
  if (rawStartDate != null && rawStartDate.trim().isNotEmpty) {
    try {
      final start = DateTime.parse(rawStartDate);
      final startStr = DateFormat('d MMMM yyyy', 'id_ID').format(start);
      if (rawEndDate != null && rawEndDate.trim().isNotEmpty) {
        final end = DateTime.tryParse(rawEndDate);
        if (end != null) {
          final endStr = DateFormat('d MMMM yyyy', 'id_ID').format(end);
          return '$startStr s.d. $endStr';
        } else {
          return 'Tanggal Mulai Pengobatan: $startStr';
        }
      } else {
        return 'Tanggal Mulai Pengobatan: $startStr';
      }
    } catch (e) {
      return 'Tanggal Mulai Pengobatan: $rawStartDate';
    }
  } else {
    return 'Tanggal mulai pengobatan belum dicatat.';
  }
}

bool shouldShowTreatmentCard(Map<String, dynamic> patientData) {
  final treatments = patientData['treatments'] as List<dynamic>? ?? [];
  final currentTreatment = treatments.isNotEmpty ? treatments[0] : null;

  final rawTreatmentStartDate = patientData['treatment_start_date'];
  final hasStartDate = rawTreatmentStartDate != null &&
      rawTreatmentStartDate.toString().trim().isNotEmpty;
  return currentTreatment != null || hasStartDate;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', '');
  });

  final mockToday = DateTime(2026, 9, 17);

  group('TEST 1 — Hari Ini (2026-09-17)', () {
    test('Pasien mulai hari ini dihitung sebagai Hari ke-1', () {
      final day = calculateCurrentDay('2026-09-17', null, mockToday: mockToday);
      expect(day, equals(1));
    });
  });

  group('TEST 2 — Tanggal Lampau (2026-08-20)', () {
    test('Pasien mulai 2026-08-20 dihitung durasi dari tanggal mulai', () {
      final day = calculateCurrentDay('2026-08-20', null, mockToday: mockToday);
      // 2026-09-17 - 2026-08-20 = 28 hari berlalu -> Hari ke-29
      expect(day, equals(29));

      final formatted = formatTreatmentDates('2026-08-20', null);
      expect(formatted, contains('20 Agustus 2026'));
    });
  });

  group('TEST 3 — NULL', () {
    test('treatment_start_date NULL aman, tidak crash, dan durasi 0', () {
      final day = calculateCurrentDay(null, null, mockToday: mockToday);
      expect(day, equals(0));

      final formatted = formatTreatmentDates(null, null);
      expect(formatted, equals('Tanggal mulai pengobatan belum dicatat.'));

      final patientData = {
        'id': 1,
        'treatment_start_date': null,
        'treatments': [],
      };
      expect(shouldShowTreatmentCard(patientData), isFalse);
    });
  });

  group('TEST 4 — Treatment Kosong (treatments = [])', () {
    test('Pasien memiliki start_date tapi treatments kosong tetap dikenali', () {
      final patientData = {
        'id': 1,
        'treatment_start_date': '2026-09-17',
        'treatments': [],
      };
      // Tidak boleh dianggap Belum Ada Pengobatan
      expect(shouldShowTreatmentCard(patientData), isTrue);

      final day = calculateCurrentDay(
        patientData['treatment_start_date'] as String,
        null,
        mockToday: mockToday,
      );
      expect(day, equals(1));

      final formatted = formatTreatmentDates(
        patientData['treatment_start_date'] as String,
        null,
      );
      expect(formatted, contains('17 September 2026'));
    });
  });

  group('TEST 5 — Masa Depan (Future Date)', () {
    test('Tanggal masa depan mengembalikan 0 / guard aktif', () {
      final day = calculateCurrentDay('2026-09-18', null, mockToday: mockToday);
      expect(day, equals(0));
    });
  });

  group('TEST 6 — Total Days Standar', () {
    test('Total days tanpa end_date default ke 180 hari (6 bulan)', () {
      final total = calculateTotalDays('2026-09-17', null);
      expect(total, equals(180));
    });
  });
}
