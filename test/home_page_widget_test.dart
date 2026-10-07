import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apk_tb_care/main/pasien/home.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'token': 'test_token',
      'user_name': 'Ahmad Pasien',
      'user_id': '10',
      'user_type_id': 2,
      'patient_id': '5',
    });
  });

  testWidgets('HomePage renders Appbar, Bottom Navigation and initial state', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HomePage(
          name: 'Ahmad Pasien',
          userId: 10,
          patientId: 5,
        ),
      ),
    );

    // Initial loading skeleton or app bar title
    expect(find.text('TB Care'), findsOneWidget);
    expect(find.text('Beranda'), findsOneWidget);
    expect(find.text('Pengobatan'), findsOneWidget);
    expect(find.text('Konsultasi'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);
  });

  testWidgets('HomePage renders refined Beranda sections and excludes Akses Cepat & Edukasi', (WidgetTester tester) async {
    final sampleHomeData = {
      'patient': {
        'id': 5,
        'user_id': 10,
        'name': 'Alamsyah Firdaus',
        'puskesmas_name': 'Puskesmas Kebon Jeruk',
      },
      'treatment': {
        'id': 12,
        'treatment_status': 'Berjalan',
        'treatment_type_name': 'Kategori 1 (Pasien Baru)',
        'current_day': 36,
        'total_days': 181,
        'progress_percent': 20,
        'start_date': '2026-09-01',
        'end_date': '2027-03-01',
        'medication_time': '07:00:00',
      },
      'next_visit': {
        'id': 3,
        'visit_date': '2026-10-15',
        'visit_time': '09:00',
        'puskesmas_name': 'Puskesmas Kebon Jeruk',
      },
      'medication': {
        'is_taken_today': false,
        'reminder_time': '07:00:00',
      },
      'consultation': null,
      'notifications': [],
      'education': [],
    };

    SharedPreferences.setMockInitialValues({
      'token': 'test_token',
      'user_name': 'Alamsyah Firdaus',
      'user_id': '10',
      'user_type_id': 2,
      'patient_id': '5',
      'cached_patient_home_5': jsonEncode(sampleHomeData),
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: HomePage(
          name: 'Alamsyah Firdaus',
          userId: 10,
          patientId: 5,
        ),
      ),
    );
    await tester.pump();

    // 1. Header & Greeting
    expect(find.text('TB Care'), findsOneWidget);
    expect(find.text('Alamsyah Firdaus'), findsOneWidget);
    expect(find.textContaining('Selamat'), findsOneWidget);

    // 2. Status Pengobatan Card
    expect(find.text('Status Pengobatan'), findsOneWidget);
    expect(find.text('KATEGORI 1 (PASIEN BARU)'), findsOneWidget);
    expect(find.text('Hari ke-36'), findsOneWidget);
    expect(find.text('dari 181 hari'), findsOneWidget);
    expect(find.text('(20% selesai)'), findsOneWidget);

    // 3. Pengingat Pengobatan Card
    expect(find.text('Pengingat Pengobatan'), findsOneWidget);
    expect(find.text('Tandai Sudah Minum Obat'), findsOneWidget);

    // 4. Kunjungan Berikutnya Card
    expect(find.text('Kunjungan Berikutnya'), findsOneWidget);
    expect(find.text('Lihat Jadwal'), findsOneWidget);
    expect(find.textContaining('15 Oktober 2026'), findsOneWidget);

    // 5. Materi Edukasi Terbaru Section (Empty State)
    expect(find.text('Materi Edukasi Terbaru'), findsOneWidget);
    expect(find.text('Lihat Semua'), findsOneWidget);
    expect(find.text('Belum ada materi edukasi'), findsOneWidget);

    // 6. Sections that MUST be removed
    expect(find.text('Akses Cepat'), findsNothing);
    expect(find.text('Edukasi untuk Anda'), findsNothing);

    // 7. Bottom Navigation strictly preserved
    expect(find.text('Beranda'), findsOneWidget);
    expect(find.text('Pengobatan'), findsOneWidget);
    expect(find.text('Konsultasi'), findsOneWidget); // Tab item only
    expect(find.text('Profil'), findsOneWidget);
  });

  testWidgets('HomePage renders latest educational materials when present', (WidgetTester tester) async {
    final sampleHomeDataWithEducation = {
      'patient': {
        'id': 5,
        'user_id': 10,
        'name': 'Alamsyah Firdaus',
        'puskesmas_name': 'Puskesmas Kebon Jeruk',
      },
      'treatment': {
        'id': 12,
        'treatment_status': 'Berjalan',
        'treatment_type_name': 'Kategori 1 (Pasien Baru)',
        'current_day': 36,
        'total_days': 181,
        'progress_percent': 20,
        'start_date': '2026-09-01',
        'end_date': '2027-03-01',
        'medication_time': '07:00:00',
      },
      'next_visit': {
        'id': 3,
        'visit_date': '2026-10-15',
        'visit_time': '09:00',
        'puskesmas_name': 'Puskesmas Kebon Jeruk',
      },
      'medication': {
        'is_taken_today': true,
        'reminder_time': '07:00:00',
      },
      'consultation': null,
      'notifications': [],
      'education': [
        {
          'id': 101,
          'title_material': 'Cara Minum Obat TB yang Benar',
          'description': 'Panduan minum obat setiap hari tanpa terlewat.',
          'material_type': 'video',
          'video_url': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
          'created_at': '2026-10-05 10:00',
        },
        {
          'id': 102,
          'title_material': 'Nutrisi Pendukung Pasien TB',
          'description': 'Pola makan sehat untuk pemulihan cepat.',
          'material_type': 'article',
          'created_at': '2026-10-04 09:00',
        },
      ],
    };

    SharedPreferences.setMockInitialValues({
      'token': 'test_token',
      'user_name': 'Alamsyah Firdaus',
      'user_id': '10',
      'user_type_id': 2,
      'patient_id': '5',
      'cached_patient_home_5': jsonEncode(sampleHomeDataWithEducation),
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: HomePage(
          name: 'Alamsyah Firdaus',
          userId: 10,
          patientId: 5,
        ),
      ),
    );
    await tester.pump();

    // Verify Latest Education Section Header & Action
    expect(find.text('Materi Edukasi Terbaru'), findsOneWidget);
    expect(find.text('Lihat Semua'), findsOneWidget);

    // Verify Educational items rendered
    expect(find.text('Cara Minum Obat TB yang Benar'), findsOneWidget);
    expect(find.text('Panduan minum obat setiap hari tanpa terlewat.'), findsOneWidget);
    expect(find.text('Video'), findsOneWidget);

    expect(find.text('Nutrisi Pendukung Pasien TB'), findsOneWidget);
    expect(find.text('Pola makan sehat untuk pemulihan cepat.'), findsOneWidget);
    expect(find.text('Artikel'), findsOneWidget);

    // Verify Sequence: Kunjungan Berikutnya appears before Materi Edukasi Terbaru
    final visitFinder = find.text('Kunjungan Berikutnya');
    final eduFinder = find.text('Materi Edukasi Terbaru');
    expect(visitFinder, findsOneWidget);
    expect(eduFinder, findsOneWidget);

    final visitY = tester.getTopLeft(visitFinder).dy;
    final eduY = tester.getTopLeft(eduFinder).dy;
    expect(visitY < eduY, isTrue, reason: 'Kunjungan Berikutnya must be positioned above Materi Edukasi Terbaru');

    // Bottom Navigation preserved
    expect(find.text('Beranda'), findsOneWidget);
    expect(find.text('Pengobatan'), findsOneWidget);
    expect(find.text('Konsultasi'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);
  });
}

