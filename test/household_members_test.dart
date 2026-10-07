import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:apk_tb_care/models/close_contact.dart';
import 'package:apk_tb_care/main/pasien/household_members_page.dart';
import 'package:apk_tb_care/main/pasien/household_member_detail_page.dart';
import 'package:apk_tb_care/main/pasien/household_member_form_page.dart';
import 'package:apk_tb_care/values/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  final sampleContactJson = {
    'id': 101,
    'contact_code': 'KONT-202610-0101',
    'patient_id': 5,
    'name': 'Ahmad Fauzi',
    'relationship': 'Anak',
    'gender': 'L',
    'gender_label': 'Laki-laki',
    'date_of_birth': '2010-05-12',
    'age': 16,
    'nik': '3278012345678901',
    'phone': '081234567890',
    'address': 'Jl. Cikadu No. 12',
    'screening_date': '2026-09-10',
    'screening_result': 'Sehat / Tidak Bergejala',
    'tpt_status': 'Tidak Perlu',
    'notes': 'Kontak erat serumah pasien',
  };

  group('CloseContact Model Tests', () {
    test('parses JSON correctly into CloseContact model', () {
      final contact = CloseContact.fromJson(sampleContactJson);

      expect(contact.id, 101);
      expect(contact.contactCode, 'KONT-202610-0101');
      expect(contact.name, 'Ahmad Fauzi');
      expect(contact.relationship, 'Anak');
      expect(contact.gender, 'L');
      expect(contact.genderLabel, 'Laki-laki');
      expect(contact.age, 16);
      expect(contact.isScreened, true);
      expect(contact.screeningStatusShort, 'Sehat');
      expect(contact.formattedDateOfBirth, '12 Mei 2010');
      expect(contact.formattedScreeningDate, '10 September 2026');
    });

    test('handles unscreened contact gracefully', () {
      final unscreenedJson = Map<String, dynamic>.from(sampleContactJson);
      unscreenedJson['screening_result'] = 'Belum Skrining';
      unscreenedJson['screening_date'] = null;

      final contact = CloseContact.fromJson(unscreenedJson);

      expect(contact.isScreened, false);
      expect(contact.screeningStatusShort, 'Belum Skrining');
      expect(contact.formattedScreeningDate, null);
    });

    test('toJson produces expected structure', () {
      final contact = CloseContact.fromJson(sampleContactJson);
      final json = contact.toJson();

      expect(json['id'], 101);
      expect(json['name'], 'Ahmad Fauzi');
      expect(json['relationship'], 'Anak');
      expect(json['gender'], 'L');
      expect(json['age'], 16);
    });
  });

  group('HouseholdMemberDetailPage Widget Tests', () {
    testWidgets('renders detail page with contact information',
        (WidgetTester tester) async {
      final contact = CloseContact.fromJson(sampleContactJson);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: HouseholdMemberDetailPage(
            contactId: contact.id,
            initialContact: contact,
          ),
        ),
      );

      // Verify AppBar title
      expect(find.text('Detail Anggota'), findsOneWidget);

      // Verify Header
      expect(find.text('Ahmad Fauzi'), findsOneWidget);
      expect(find.text('Anak'), findsOneWidget);
      expect(find.text('Kode: KONT-202610-0101'), findsOneWidget);

      // Verify Personal Info Section
      expect(find.text('Informasi Pribadi'), findsOneWidget);
      expect(find.text('Laki-laki'), findsOneWidget);
      expect(find.text('16 tahun'), findsOneWidget);
      expect(find.text('3278012345678901'), findsOneWidget);
      expect(find.text('081234567890'), findsOneWidget);

      // Verify Screening Section
      expect(find.text('Status Skrining & Kesehatan'), findsOneWidget);
      expect(find.text('Sehat / Tidak Bergejala'), findsOneWidget);

      // Verify Action buttons
      expect(find.text('Ubah'), findsOneWidget);
      expect(find.text('Hapus'), findsOneWidget);
    });

    testWidgets('tapping Hapus shows confirmation dialog',
        (WidgetTester tester) async {
      final contact = CloseContact.fromJson(sampleContactJson);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: HouseholdMemberDetailPage(
            contactId: contact.id,
            initialContact: contact,
          ),
        ),
      );

      // Tap "Hapus" button
      final deleteBtn = find.text('Hapus');
      await tester.ensureVisible(deleteBtn);
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      // Dialog confirmation appears
      expect(find.text('Hapus Anggota?'), findsOneWidget);
      expect(
        find.text(
          'Apakah Anda yakin ingin menghapus Ahmad Fauzi dari daftar anggota serumah?',
        ),
        findsOneWidget,
      );
      expect(find.text('Batal'), findsOneWidget);

      // Tap Batal
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();

      // Dialog dismissed
      expect(find.text('Hapus Anggota?'), findsNothing);
    });

    testWidgets('shows "Mulai Skrining Sekarang" when member is not screened',
        (WidgetTester tester) async {
      final unscreenedJson = Map<String, dynamic>.from(sampleContactJson);
      unscreenedJson['screening_result'] = 'Belum Skrining';
      unscreenedJson['screening_date'] = null;
      final contact = CloseContact.fromJson(unscreenedJson);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: HouseholdMemberDetailPage(
            contactId: contact.id,
            initialContact: contact,
          ),
        ),
      );

      expect(find.text('Mulai Skrining Sekarang'), findsOneWidget);
      expect(find.text('Lihat Hasil Skrining'), findsNothing);
    });

    testWidgets(
        'shows "Lihat Hasil Skrining" and opens bottom sheet when member is screened',
        (WidgetTester tester) async {
      final contact = CloseContact.fromJson(sampleContactJson);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: HouseholdMemberDetailPage(
            contactId: contact.id,
            initialContact: contact,
          ),
        ),
      );

      final viewResultBtn = find.text('Lihat Hasil Skrining');
      expect(viewResultBtn, findsOneWidget);
      expect(find.text('Skrining Ulang'), findsOneWidget);

      await tester.ensureVisible(viewResultBtn);
      await tester.tap(viewResultBtn);
      await tester.pumpAndSettle();

      // Modal bottom sheet appears
      expect(find.text('Hasil Skrining TB'), findsOneWidget);
      expect(find.text('Rekomendasi Tindak Lanjut'), findsOneWidget);
      expect(find.text('Tutup'), findsOneWidget);

      await tester.tap(find.text('Tutup'));
      await tester.pumpAndSettle();
      expect(find.text('Hasil Skrining TB'), findsNothing);
    });
  });

  group('HouseholdMemberFormPage Widget Tests', () {
    testWidgets('renders add form with required fields and labels',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: const HouseholdMemberFormPage(),
        ),
      );

      expect(find.text('Tambah Anggota Serumah'), findsOneWidget);
      expect(find.text('NIK'), findsOneWidget);
      expect(find.text('Nama Lengkap'), findsOneWidget);
      expect(find.text('Jenis Kelamin'), findsOneWidget);
      expect(find.text('Tanggal Lahir'), findsOneWidget);
      expect(find.text('Nomor Handphone / WhatsApp'), findsOneWidget);
      expect(find.text('Hubungan dengan Pasien'), findsOneWidget);
      expect(find.text('Catatan Tambahan'), findsOneWidget);
      expect(find.text('Simpan Anggota'), findsOneWidget);

      // Verify removed fields
      expect(find.text('Usia (Tahun)'), findsNothing);
      expect(find.text('Alamat Tempat Tinggal'), findsNothing);
    });

    testWidgets('shows validation errors when submitting empty form',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: const HouseholdMemberFormPage(),
        ),
      );

      // Tap "Simpan Anggota" without filling anything
      final submitBtn = find.text('Simpan Anggota');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('NIK wajib diisi.'), findsOneWidget);
      expect(find.text('Nama lengkap wajib diisi.'), findsOneWidget);
      expect(find.text('Jenis kelamin wajib dipilih.'), findsOneWidget);
    });

    testWidgets('validates NIK format when length is less than 16 digits',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: const HouseholdMemberFormPage(),
        ),
      );

      // Enter incomplete NIK
      await tester.enterText(find.byType(TextFormField).first, '32780123');

      final submitBtn = find.text('Simpan Anggota');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('NIK harus 16 digit.'), findsOneWidget);
    });

    testWidgets('renders edit form populated with existing contact data',
        (WidgetTester tester) async {
      final contact = CloseContact.fromJson(sampleContactJson);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: HouseholdMemberFormPage(existingContact: contact),
        ),
      );

      expect(find.text('Ubah Anggota Serumah'), findsOneWidget);
      expect(find.text('3278012345678901'), findsOneWidget);
      expect(find.text('Ahmad Fauzi'), findsOneWidget);
      expect(find.text('Simpan Perubahan'), findsOneWidget);
    });
  });

  group('HouseholdMembersPage Widget Tests', () {
    testWidgets('renders Appbar with standardized theme',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: const HouseholdMembersPage(patientId: 5),
        ),
      );

      expect(find.text('Anggota Serumah'), findsOneWidget);
    });
  });
}
