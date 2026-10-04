import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apk_tb_care/register.dart';

void main() {
  testWidgets('RegisterPage renders Step 1 with patient fields and no officer tabs', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const MaterialApp(
        home: RegisterPage(
          initialPuskesmasList: [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify AppBar Title
    expect(find.text("Buat Akun Pasien"), findsOneWidget);

    // Verify absence of old role tabs
    expect(find.widgetWithText(Tab, "Petugas"), findsNothing);
    expect(find.widgetWithText(Tab, "Pasien"), findsNothing);

    // Verify Step Indicators
    expect(find.text("Data Pasien"), findsWidgets);
    expect(find.text("Alamat Pasien"), findsWidgets);
    expect(find.text("Langkah 1 dari 2"), findsOneWidget);

    // Verify Step 1 fields
    expect(find.text("Nama Lengkap"), findsOneWidget);
    expect(find.text("NIK"), findsOneWidget);
    expect(find.text("Nomor HP"), findsOneWidget);
    expect(find.text("Puskesmas"), findsOneWidget);
    expect(find.text("Tanggal Mulai Pengobatan"), findsOneWidget);
    expect(find.text("Lanjutkan"), findsOneWidget);

    // Test validation on empty form submission
    await tester.tap(find.text("Lanjutkan"));
    await tester.pumpAndSettle();

    // Verify validation errors appear
    expect(find.text("Nama lengkap wajib diisi"), findsOneWidget);
    expect(find.text("NIK wajib diisi"), findsOneWidget);
    expect(find.text("Nomor HP wajib diisi"), findsOneWidget);
  });

  testWidgets('Validation errors for invalid NIK and phone', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const MaterialApp(
        home: RegisterPage(
          initialPuskesmasList: [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Enter short NIK (< 16 digits)
    final nikField = find.widgetWithText(TextFormField, "NIK");
    await tester.enterText(nikField, "12345");

    // Enter short phone (< 10 digits)
    final phoneField = find.widgetWithText(TextFormField, "Nomor HP");
    await tester.enterText(phoneField, "0812");

    // Trigger validation
    await tester.tap(find.text("Lanjutkan"));
    await tester.pumpAndSettle();

    expect(find.text("NIK harus terdiri dari 16 digit."), findsOneWidget);
    expect(find.text("Nomor HP harus antara 10 - 15 digit"), findsOneWidget);
  });

  testWidgets('Step 2 displays inverted territory flow: Desa/Kelurahan searchable, parent fields readonly', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final mockVillages = [
      {
        "id": 16,
        "name": "Talagasari",
        "subdistrict_id": 41,
        "district_id": 27,
        "province_id": 1,
        "subdistrict": {"id": 41, "name": "Kawalu"},
        "district": {"id": 27, "name": "Kota Tasikmalaya"},
        "province": {"id": 1, "name": "Jawa Barat"},
        "parent_display": "Kawalu • Kota Tasikmalaya",
      },
      {
        "id": 1,
        "name": "Mugarsari",
        "subdistrict_id": 44,
        "district_id": 27,
        "province_id": 1,
        "subdistrict": {"id": 44, "name": "Tamansari"},
        "district": {"id": 27, "name": "Kota Tasikmalaya"},
        "province": {"id": 1, "name": "Jawa Barat"},
        "parent_display": "Tamansari • Kota Tasikmalaya",
      },
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: RegisterPage(
          initialStep: 2,
          initialVillageList: mockVillages,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Step 2 header indicator
    expect(find.text("Langkah 2 dari 2"), findsOneWidget);
    expect(find.text("Alamat Pasien"), findsWidgets);

    // Verify Field 1: Desa/Kelurahan (searchable)
    expect(find.text("Desa/Kelurahan"), findsOneWidget);
    expect(find.text("Cari Desa/Kelurahan..."), findsOneWidget);

    // Verify Field 2: Kecamatan (readonly with lock icon)
    expect(find.text("Kecamatan"), findsOneWidget);
    expect(find.text("Otomatis terisi dari Desa/Kelurahan"), findsNWidgets(3));

    // Verify Field 3: Kabupaten/Kota
    expect(find.text("Kabupaten/Kota"), findsOneWidget);

    // Verify Field 4: Provinsi
    expect(find.text("Provinsi"), findsOneWidget);

    // Verify Lock icons on 3 parent fields
    expect(find.byIcon(Icons.lock_outline_rounded), findsNWidgets(3));

    // Verify Kembali & Daftar buttons
    final kembaliBtn = find.widgetWithText(OutlinedButton, "Kembali");
    final daftarBtn = find.widgetWithText(ElevatedButton, "Daftar");

    expect(kembaliBtn, findsOneWidget);
    expect(daftarBtn, findsOneWidget);
  });

  testWidgets('Selecting Desa/Kelurahan automatically fills Kecamatan, Kabupaten/Kota, and Provinsi', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final mockVillages = [
      {
        "id": 16,
        "name": "Talagasari",
        "subdistrict_id": 41,
        "district_id": 27,
        "province_id": 1,
        "subdistrict": {"id": 41, "name": "Kawalu"},
        "district": {"id": 27, "name": "Kota Tasikmalaya"},
        "province": {"id": 1, "name": "Jawa Barat"},
        "parent_display": "Kawalu • Kota Tasikmalaya",
      },
      {
        "id": 1,
        "name": "Mugarsari",
        "subdistrict_id": 44,
        "district_id": 27,
        "province_id": 1,
        "subdistrict": {"id": 44, "name": "Tamansari"},
        "district": {"id": 27, "name": "Kota Tasikmalaya"},
        "province": {"id": 1, "name": "Jawa Barat"},
        "parent_display": "Tamansari • Kota Tasikmalaya",
      },
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: RegisterPage(
          initialStep: 2,
          initialVillageList: mockVillages,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Type in Desa/Kelurahan field
    final villageField = find.widgetWithText(TextFormField, "Desa/Kelurahan");
    await tester.tap(villageField);
    await tester.enterText(villageField, "Talaga");
    await tester.pumpAndSettle();

    // Verify option is rendered with parent info subtitle
    expect(find.text("Talagasari"), findsWidgets);
    expect(find.text("Kawalu • Kota Tasikmalaya"), findsOneWidget);

    // Tap on option
    await tester.tap(find.text("Kawalu • Kota Tasikmalaya"));
    await tester.pumpAndSettle();

    // Verify Kecamatan, Kabupaten/Kota, Provinsi are automatically filled
    expect(find.text("Kawalu"), findsOneWidget);
    expect(find.text("Kota Tasikmalaya"), findsOneWidget);
    expect(find.text("Jawa Barat"), findsOneWidget);

    // Tap on Kecamatan to verify it is readonly (does not open keyboard/dropdown)
    final kecField = find.widgetWithText(TextFormField, "Kecamatan");
    await tester.tap(kecField);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Switch to Mugarsari
    await tester.tap(villageField);
    await tester.enterText(villageField, "Mugar");
    await tester.pumpAndSettle();

    expect(find.text("Mugarsari"), findsWidgets);
    expect(find.text("Tamansari • Kota Tasikmalaya"), findsOneWidget);

    await tester.tap(find.text("Tamansari • Kota Tasikmalaya"));
    await tester.pumpAndSettle();

    // Verify parents changed automatically
    expect(find.text("Tamansari"), findsOneWidget);
    expect(find.text("Kota Tasikmalaya"), findsOneWidget);
    expect(find.text("Jawa Barat"), findsOneWidget);

    // Clear selection
    final clearBtn = find.byIcon(Icons.close_rounded);
    expect(clearBtn, findsOneWidget);
    await tester.tap(clearBtn);
    await tester.pumpAndSettle();

    // Verify all fields are reset
    expect(find.text("Otomatis terisi dari Desa/Kelurahan"), findsNWidgets(3));
  });

  testWidgets('Step 2 button layout has no overflow on small screen (360x640)', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final mockVillages = [
      {
        "id": 16,
        "name": "Talagasari",
        "subdistrict_id": 41,
        "district_id": 27,
        "province_id": 1,
        "subdistrict": {"id": 41, "name": "Kawalu"},
        "district": {"id": 27, "name": "Kota Tasikmalaya"},
        "province": {"id": 1, "name": "Jawa Barat"},
        "parent_display": "Kawalu • Kota Tasikmalaya",
      },
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: RegisterPage(
          initialStep: 2,
          initialVillageList: mockVillages,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Check that both buttons exist and are laid out without throwing any overflow
    expect(tester.takeException(), isNull);
    expect(find.widgetWithText(OutlinedButton, "Kembali"), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, "Daftar"), findsOneWidget);
  });
}
