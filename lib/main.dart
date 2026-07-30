import 'dart:convert';
import 'dart:io';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/foundation.dart';
// ignore: unused_import
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:apk_tb_care/main/pasien/home.dart';
import 'package:apk_tb_care/main/petugas/home.dart';
import 'package:apk_tb_care/main/login.dart';
import 'package:apk_tb_care/connection.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

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
  await AndroidAlarmManager.initialize();

  await AndroidAlarmManager.periodic(
    const Duration(minutes: 30),
    1001,
    checkEducationBackground,
    wakeup: true,
    exact: true,
    rescheduleOnReboot: true,
  );

  await initializeDateFormatting('id_ID', '');

  // REQUEST PERMISSION NOTIFIKASI (ANDROID 13+)
  final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await notificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.requestNotificationsPermission();

  runApp(const MainApp());
}

@pragma('vm:entry-point')
Future<void> checkEducationBackground() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');

  if (token == null) return;

  try {
    final response = await http.get(
      Uri.parse('${Connection.BASE_URL}/education'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) return;

    final data = jsonDecode(response.body);
    final List materials = data['data'];

    if (materials.isEmpty) return;

    // Ambil materi terbaru
    materials.sort(
      (a, b) => DateTime.parse(
        b['created_at'],
      ).compareTo(DateTime.parse(a['created_at'])),
    );

    final newest = materials.first;

    if (newest['is_publish'] != 1) return;

    final lastSeen = prefs.getString('last_education_time');
    final createdAt = DateTime.parse(newest['created_at']);

    if (lastSeen == null || createdAt.isAfter(DateTime.parse(lastSeen))) {
      final FlutterLocalNotificationsPlugin notifications =
          FlutterLocalNotificationsPlugin();

      const AndroidInitializationSettings initSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      await notifications.initialize(
        const InitializationSettings(android: initSettings),
      );

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'education_channel',
            'Edukasi TB Care',
            importance: Importance.max,
            priority: Priority.high,
          );

      await notifications.show(
        0,
        "Materi Edukasi Baru",
        newest['title_material'],
        const NotificationDetails(android: androidDetails),
        payload: newest['id'].toString(),
      );

      await prefs.setString("last_education_time", createdAt.toIso8601String());
    }
  } catch (e) {
    debugPrint("Background check error: $e");
  }
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
