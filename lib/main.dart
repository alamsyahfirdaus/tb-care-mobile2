import 'dart:io';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:apk_tb_care/main/pasien/home.dart';
import 'package:apk_tb_care/main/petugas/home.dart';
import 'package:apk_tb_care/main/login.dart';
import 'package:apk_tb_care/connection.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:apk_tb_care/services/notification_service.dart';
import 'package:apk_tb_care/main/pasien/materi_detail.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kReleaseMode) {
    HttpOverrides.global = MyHttpOverrides();
  }

  await Firebase.initializeApp();

  // Inisialisasi Notification Service Global
  final notificationService = NotificationService();
  await notificationService.initialize();

  await AndroidAlarmManager.initialize();

  await initializeDateFormatting('id_ID', '');

  runApp(const MainApp());
}

/// =============================================================
/// ROOT APLIKASI
/// Menentukan halaman awal berdasarkan status session (token)
/// =============================================================
class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  // Halaman awal (Login / Home)
  Widget? _startPage;

  @override
  void initState() {
    super.initState();
    _initSession();
  }

  /// ===========================================================
  /// INISIALISASI SESSION
  /// - Jika token valid → langsung ke Home
  /// - Jika token tidak ada / invalid → Login
  /// ===========================================================
  Future<void> _initSession() async {
    final prefs = await SharedPreferences.getInstance();

    final token = prefs.getString('token');
    final userType = prefs.getInt('user_type_id');

    // Jika tidak ada session → Login
    if (token == null || token.isEmpty || userType == null) {
      _setStartPage(const LoginPage());
      return;
    }

    // Validasi token ke server
    final isValid = await _validateToken(token);
    if (!isValid) {
      await _clearSession(prefs);
      _setStartPage(const LoginPage());
      return;
    }

    // Session valid → arahkan ke Home sesuai role
    final userName = prefs.getString('user_name') ?? '';
    final userId = prefs.getString('user_id');

    // Role: Pasien
    if (userType == 2) {
      final patientId = prefs.getString('patient_id');

      // Data tidak lengkap → reset session
      if (userId == null || patientId == null) {
        await _clearSession(prefs);
        _setStartPage(const LoginPage());
        return;
      }

      _setStartPage(
        HomePage(
          name: userName,
          userId: int.parse(userId),
          patientId: int.parse(patientId),
        ),
      );
    }
    // Role: Petugas
    else {
      _setStartPage(StaffHomePage(name: userName));
    }

    // Daftarkan/upload token FCM saat session dikonfirmasi valid
    NotificationService().getAndUploadToken();

    // Periksa apakah ada pending notifikasi setelah widget terpasang
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (NotificationService.pendingMaterialId != null) {
        final id = NotificationService.pendingMaterialId!;
        NotificationService.pendingMaterialId = null;
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => MateriDetailPage(materialId: id),
          ),
        );
      }
    });
  }

  /// ===========================================================
  /// VALIDASI TOKEN KE SERVER
  /// Endpoint: /me
  /// ===========================================================
  Future<bool> _validateToken(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${Connection.BASE_URL}/me'),
        headers: {'Authorization': 'Bearer $token'},
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// ===========================================================
  /// HAPUS SESSION (LOGOUT / TOKEN INVALID)
  /// ===========================================================
  Future<void> _clearSession(SharedPreferences prefs) async {
    await prefs.clear();
  }

  /// Set halaman awal aplikasi
  void _setStartPage(Widget page) {
    setState(() {
      _startPage = page;
    });
  }

  /// ===========================================================
  /// ROOT UI
  /// ===========================================================
  @override
  Widget build(BuildContext context) {
    // Loading sementara saat cek session
    if (_startPage == null) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp(
      title: 'TB Care',
      navigatorKey: navigatorKey, // Gunakan navigatorKey global untuk routing
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Colors.blue[100],
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue[100]!,
          primary: Colors.blue,
          secondary: Colors.amber,
        ),
      ),
      home: _startPage,
    );
  }
}
