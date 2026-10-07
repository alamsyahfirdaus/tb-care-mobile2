import 'package:apk_tb_care/edit_profile.dart';
import 'package:apk_tb_care/services/address_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final Map<String, dynamic> samplePatientData = {
    'id': 10,
    'user_type_id': 2,
    'name': 'Budi Santoso',
    'username': 'budisantoso',
    'email': 'budi@example.com',
    'phone': '081234567890',
    'gender': 'L',
    'date_of_birth': '1995-05-15',
    'place_of_birth': 'Tasikmalaya',
    'nik': '3278011505950001',
    'puskesmas_id': '1',
    'puskesmas_name': 'Puskesmas Kawalu (Kawalu, Kota Tasikmalaya)',
    'village_id': '101',
    'village_name': 'Talagasari',
    'subdistrict_id': '201',
    'subdistrict_name': 'Kawalu',
    'district_id': '301',
    'district_name': 'Kota Tasikmalaya',
    'province_id': '401',
    'province_name': 'Jawa Barat',
    'rt': '001',
    'rw': '005',
    'address': 'Kp. Sukamaju No. 12',
  };

  testWidgets('EditProfilePage renders initial patient data immediately without delay',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileEditPage(userData: samplePatientData),
      ),
    );

    // Initial values should be immediately visible
    expect(find.text('Budi Santoso'), findsOneWidget);
    expect(find.text('3278011505950001'), findsOneWidget);
    // Puskesmas tampil sebagai kartu terpilih yang rapi tanpa error / dropdown paksaan
    expect(find.text('Puskesmas Kawalu'), findsOneWidget);
    expect(find.text('Kawalu - Kota Tasikmalaya'), findsOneWidget);
    expect(find.text('Ubah Puskesmas'), findsOneWidget);
    expect(find.text('Pilih puskesmas dari daftar'), findsNothing);
    expect(find.text('Talagasari'), findsOneWidget);
    expect(find.text('Kawalu'), findsOneWidget);
    expect(find.text('Kota Tasikmalaya'), findsOneWidget);
    expect(find.text('Jawa Barat'), findsOneWidget);
    expect(find.text('001'), findsOneWidget);
    expect(find.text('005'), findsOneWidget);
    expect(find.text('Kp. Sukamaju No. 12'), findsOneWidget);
  });

  testWidgets('Patient with existing Puskesmas can tap "Ubah Puskesmas" to search and tap "Batal" to cancel',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileEditPage(userData: samplePatientData),
      ),
    );

    // Initial state: Card view is shown
    expect(find.text('Puskesmas Kawalu'), findsOneWidget);
    expect(find.text('Ubah Puskesmas'), findsOneWidget);

    // Tap "Ubah Puskesmas"
    final ubahFinder = find.text('Ubah Puskesmas');
    await tester.ensureVisible(ubahFinder);
    await tester.tap(ubahFinder);
    await tester.pumpAndSettle();

    // Now search field and "Batal" button are visible
    final batalFinder = find.text('Batal');
    expect(batalFinder, findsOneWidget);
    expect(find.text('Puskesmas Pendamping *'), findsOneWidget);

    // Tap "Batal" to revert to card view
    await tester.ensureVisible(batalFinder);
    await tester.tap(batalFinder);
    await tester.pumpAndSettle();

    expect(find.text('Puskesmas Kawalu'), findsOneWidget);
    expect(find.text('Ubah Puskesmas'), findsOneWidget);
    expect(find.text('Batal'), findsNothing);
  });

  testWidgets('Patient without Puskesmas directly sees search field on EditProfilePage',
      (WidgetTester tester) async {
    final noPuskesmasData = Map<String, dynamic>.from(samplePatientData);
    noPuskesmasData['puskesmas_id'] = null;
    noPuskesmasData['puskesmas_name'] = null;

    await tester.pumpWidget(
      MaterialApp(
        home: ProfileEditPage(userData: noPuskesmasData),
      ),
    );

    expect(find.text('Puskesmas Pendamping *'), findsOneWidget);
    expect(find.text('Ubah Puskesmas'), findsNothing);
  });

  testWidgets('RT and RW are required and show validation error if empty',
      (WidgetTester tester) async {
    final emptyRtRwData = Map<String, dynamic>.from(samplePatientData);
    emptyRtRwData['rt'] = '';
    emptyRtRwData['rw'] = '';

    await tester.pumpWidget(
      MaterialApp(
        home: ProfileEditPage(userData: emptyRtRwData),
      ),
    );

    // Scroll to the save button
    final saveButtonFinder = find.text('Simpan Perubahan');
    await tester.ensureVisible(saveButtonFinder);
    await tester.tap(saveButtonFinder);
    await tester.pumpAndSettle();

    // Verify validation errors appear
    expect(find.text('RT wajib diisi'), findsOneWidget);
    expect(find.text('RW wajib diisi'), findsOneWidget);
  });

  testWidgets('Email is optional on EditProfilePage and can be empty',
      (WidgetTester tester) async {
    final noEmailData = Map<String, dynamic>.from(samplePatientData);
    noEmailData['email'] = '';

    await tester.pumpWidget(
      MaterialApp(
        home: ProfileEditPage(userData: noEmailData),
      ),
    );

    // Form should not show email error when empty
    expect(find.text('Harap isi alamat email'), findsNothing);
  });

  testWidgets('EditProfilePage displays "Alamat Jalan / Detail Rumah" label and helper',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileEditPage(userData: samplePatientData),
      ),
    );

    expect(find.text('Alamat Jalan / Detail Rumah'), findsOneWidget);
    expect(find.text('Contoh: Jl. Cikadu No. 25 atau Kp. Sukamaju'), findsOneWidget);
  });

  group('formatFullAddress tests', () {
    test('formats complete patient address into a cohesive sentence', () {
      final formatted = formatFullAddress(
        address: 'Jl. Cikadu',
        rt: '003',
        rw: '003',
        village: 'Talagasari',
        subdistrict: 'Kawalu',
        district: 'Kota Tasikmalaya',
        province: 'Jawa Barat',
      );
      expect(
        formatted,
        'Jl. Cikadu, RT 003, RW 003, Talagasari, Kawalu, Kota Tasikmalaya, Jawa Barat',
      );
    });

    test('avoids duplicate RT / RW prefix if already provided', () {
      final formatted = formatFullAddress(
        address: 'Kp. Sukamaju No. 10',
        rt: 'RT 01',
        rw: 'RW 05',
        village: 'Talagasari',
        subdistrict: 'Kawalu',
        district: 'Kota Tasikmalaya',
        province: 'Jawa Barat',
      );
      expect(
        formatted,
        'Kp. Sukamaju No. 10, RT 01, RW 05, Talagasari, Kawalu, Kota Tasikmalaya, Jawa Barat',
      );
    });

    test('gracefully omits missing or null fields without stray commas or null text', () {
      final formatted = formatFullAddress(
        address: 'Jl. Ahmad Yani No. 5',
        rt: null,
        rw: '',
        village: 'Sukamaju',
        subdistrict: null,
        district: 'Kota Tasikmalaya',
        province: 'Jawa Barat',
      );
      expect(
        formatted,
        'Jl. Ahmad Yani No. 5, Sukamaju, Kota Tasikmalaya, Jawa Barat',
      );
    });

    test('returns empty string when all fields are empty or null', () {
      final formatted = formatFullAddress(
        address: null,
        rt: '',
        rw: null,
        village: '-',
        subdistrict: null,
        district: '',
        province: null,
      );
      expect(formatted, '');
    });
  });

  group('formatPuskesmasDisplay tests', () {
    test('formats structured puskesmas data into name and location', () {
      final info = formatPuskesmasDisplay(
        rawName: 'Kawalu',
        subdistrictName: 'Kawalu',
        districtName: 'Kota Tasikmalaya',
      );
      expect(info.name, 'Kawalu');
      expect(info.location, 'Kawalu - Kota Tasikmalaya');
    });

    test('parses name and location from combined string with parentheses', () {
      final info = formatPuskesmasDisplay(
        formattedName: 'Puskesmas Kawalu (Kawalu, Kota Tasikmalaya)',
      );
      expect(info.name, 'Puskesmas Kawalu');
      expect(info.location, 'Kawalu - Kota Tasikmalaya');
    });

    test('handles Puskesmas map with nested subdistrict and district', () {
      final info = formatPuskesmasDisplay(
        puskesmasMap: {
          'name': 'Puskesmas Tamansari',
          'subdistrict': {
            'name': 'Tamansari',
            'district': {
              'name': 'Kota Tasikmalaya',
            },
          },
        },
      );
      expect(info.name, 'Puskesmas Tamansari');
      expect(info.location, 'Tamansari - Kota Tasikmalaya');
    });
  });
}
