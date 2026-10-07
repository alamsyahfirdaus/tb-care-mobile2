import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:apk_tb_care/models/patient_medication.dart';
import 'package:apk_tb_care/main/pasien/patient_medications_page.dart';

void main() {
  group('PatientMedication Model Tests', () {
    test('parses pure string items gracefully', () {
      final med = PatientMedication.fromDynamic('Rifampisin', defaultScheduleTime: '07:00:00');
      expect(med.name, 'Rifampisin');
      expect(med.scheduleTime, '07:00:00');
      expect(med.dosage, isNull);
      expect(med.frequency, isNull);
    });

    test('parses map items with complete details', () {
      final med = PatientMedication.fromDynamic({
        'name': 'Isoniazid',
        'dosage': '300 mg',
        'frequency': '1 kali sehari',
        'rules': 'Sebelum makan',
        'schedule_time': '08:00',
      });
      expect(med.name, 'Isoniazid');
      expect(med.dosage, '300 mg');
      expect(med.frequency, '1 kali sehari');
      expect(med.rules, 'Sebelum makan');
      expect(med.scheduleTime, '08:00');
    });

    test('parses PatientMedicationResponse from API json', () {
      final json = {
        'success': true,
        'data': {
          'treatment_id': 12,
          'treatment_type': 'Kategori 1',
          'treatment_status': 'Berjalan',
          'medication_time': '07:00',
          'count': 3,
          'medications': [
            {'name': 'Rifampisin', 'dosage': '450 mg'},
            {'name': 'Isoniazid', 'dosage': '300 mg'},
            {'name': 'Pirazinamid', 'dosage': '500 mg'},
          ],
        }
      };

      final response = PatientMedicationResponse.fromJson(json);
      expect(response.treatmentId, 12);
      expect(response.treatmentType, 'Kategori 1');
      expect(response.treatmentStatus, 'Berjalan');
      expect(response.medicationTime, '07:00');
      expect(response.count, 3);
      expect(response.medications.length, 3);
      expect(response.medications[0].name, 'Rifampisin');
      expect(response.medications[0].dosage, '450 mg');
    });

    test('parses legacy prescription list of strings', () {
      final json = {
        'id': 5,
        'prescription': ['Rifampisin', 'Isoniazid'],
        'medication_time': '07:00:00',
      };

      final response = PatientMedicationResponse.fromJson(json);
      expect(response.count, 2);
      expect(response.medications.length, 2);
      expect(response.medications[0].name, 'Rifampisin');
      expect(response.medications[1].name, 'Isoniazid');
    });

    test('parseList splits newline delimited strings correctly', () {
      final raw = [
        "Isoniazid\nripamfisine\npirazinamid\nethambutol"
      ];
      final meds = PatientMedication.parseList(raw, defaultScheduleTime: '07:30');
      expect(meds.length, 4);
      expect(meds[0].name, 'Isoniazid');
      expect(meds[0].scheduleTime, '07:30');
      expect(meds[1].name, 'ripamfisine');
      expect(meds[2].name, 'pirazinamid');
      expect(meds[3].name, 'ethambutol');
    });

    test('parseList splits comma separated strings correctly', () {
      final raw = [
        "Rifampisin,Isoniazid,Pyrazinamide,Ethambutol"
      ];
      final meds = PatientMedication.parseList(raw);
      expect(meds.length, 4);
      expect(meds[0].name, 'Rifampisin');
      expect(meds[1].name, 'Isoniazid');
      expect(meds[2].name, 'Pyrazinamide');
      expect(meds[3].name, 'Ethambutol');
    });

    test('parseList handles empty, null, and placeholder values cleanly', () {
      expect(PatientMedication.parseList(null), isEmpty);
      expect(PatientMedication.parseList([]), isEmpty);
      expect(PatientMedication.parseList(['-']), isEmpty);
      expect(PatientMedication.parseList(['Tidak ada']), isEmpty);
      expect(PatientMedication.parseList(['Tidak ada informasi obat.']), isEmpty);
    });

    test('parseList parses maps with extra details correctly', () {
      final raw = [
        {
          'name': 'Rifampisin',
          'dosage': '450 mg',
          'frequency': '1x sehari',
          'rules': 'Sebelum makan',
          'schedule_time': '07:00'
        },
        {
          'name': 'Isoniazid',
          'dosage': '300 mg',
          'frequency': '1x sehari',
          'rules': 'Sesudah makan',
        }
      ];
      final meds = PatientMedication.parseList(raw, defaultScheduleTime: '08:00');
      expect(meds.length, 2);
      expect(meds[0].name, 'Rifampisin');
      expect(meds[0].dosage, '450 mg');
      expect(meds[0].scheduleTime, '07:00');
      expect(meds[1].name, 'Isoniazid');
      expect(meds[1].dosage, '300 mg');
      expect(meds[1].scheduleTime, '08:00');
    });
  });

  group('PatientMedicationsPage Widget Tests', () {
    testWidgets('renders AppBar and populated medication list with initial data', (tester) async {
      final initialTreatment = {
        'id': 101,
        'treatment_type': 'Kategori 1',
        'treatment_status': 'Berjalan',
        'medication_time': '07:00:00',
        'prescription': ['Rifampisin', 'Isoniazid', 'Pirazinamid'],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: PatientMedicationsPage(
            patientId: 1,
            initialTreatment: initialTreatment,
          ),
        ),
      );

      // Verify AppBar
      expect(find.text('Daftar Obat'), findsOneWidget);

      // Verify Header Banner
      expect(find.text('Program Pengobatan TB'), findsOneWidget);
      expect(find.text('Kategori 1'), findsOneWidget);
      expect(find.text('Berjalan'), findsOneWidget);
      expect(find.text('Jadwal Minum Harian: '), findsOneWidget);
      expect(find.text('07:00 WIB'), findsOneWidget);

      // Verify Section Header
      expect(find.text('Obat yang Sedang Dikonsumsi'), findsOneWidget);
      expect(find.text('3 Obat'), findsOneWidget);

      // Verify Medication items
      expect(find.text('Rifampisin'), findsOneWidget);
      expect(find.text('Isoniazid'), findsOneWidget);
      expect(find.text('Pirazinamid'), findsOneWidget);

      // Verify Info Banner
      expect(find.textContaining('Konsumsi obat secara teratur'), findsOneWidget);
    });

    testWidgets('renders empty state when prescription list is empty', (tester) async {
      final emptyTreatment = {
        'id': 102,
        'treatment_type': 'Kategori 1',
        'treatment_status': 'Berjalan',
        'medication_time': '07:00:00',
        'prescription': <dynamic>[],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: PatientMedicationsPage(
            patientId: 1,
            initialTreatment: emptyTreatment,
          ),
        ),
      );

      expect(find.text('Daftar Obat'), findsOneWidget);
      expect(find.text('Belum Ada Data Obat'), findsOneWidget);
      expect(find.textContaining('Informasi obat belum tersedia pada pengobatan Anda'), findsOneWidget);
      expect(find.text('Perbarui Data'), findsOneWidget);
    });
  });
}
