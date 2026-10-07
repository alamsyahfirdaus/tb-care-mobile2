import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:apk_tb_care/connection.dart';
import 'package:apk_tb_care/models/patient_home_model.dart';

enum HomeErrorType {
  timeout,
  offline,
  unauthorized,
  server,
  general,
}

class HomeServiceException implements Exception {
  final String title;
  final String message;
  final HomeErrorType type;

  HomeServiceException({
    required this.title,
    required this.message,
    this.type = HomeErrorType.general,
  });

  @override
  String toString() => message;
}

class PatientHomeService {
  static const String _cachePrefix = 'cached_patient_home_';

  /// Membaca data beranda dari cache lokal jika tersedia
  static Future<PatientHomeData?> getCachedHomeData(int? patientId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_cachePrefix${patientId ?? 'me'}';
      final cachedJsonStr = prefs.getString(key);
      if (cachedJsonStr != null && cachedJsonStr.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(cachedJsonStr);
        return PatientHomeData.fromJson(decoded);
      }
    } catch (e) {
      log('[PatientHomeService] Gagal membaca cache: $e');
    }
    return null;
  }

  /// Menyimpan data beranda ke cache lokal
  static Future<void> _saveToCache(int? patientId, PatientHomeData data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_cachePrefix${patientId ?? 'me'}';
      final jsonStr = jsonEncode(data.toJson());
      await prefs.setString(key, jsonStr);
    } catch (e) {
      log('[PatientHomeService] Gagal menyimpan cache: $e');
    }
  }

  /// Menghapus cache saat logout
  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith(_cachePrefix));
      for (var k in keys) {
        await prefs.remove(k);
      }
    } catch (_) {}
  }

  /// Mengambil data Beranda Pasien secara terpadu dari backend
  static Future<PatientHomeData> getPatientHome({int? patientId}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null || token.isEmpty) {
      throw HomeServiceException(
        title: 'Sesi telah berakhir',
        message: 'Silakan masuk kembali untuk melanjutkan.',
        type: HomeErrorType.unauthorized,
      );
    }

    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    // 1. Coba panggil unified endpoint `/patient/home`
    try {
      final uri = patientId != null
          ? Uri.parse('${Connection.BASE_URL}/patient/home?patient_id=$patientId')
          : Uri.parse('${Connection.BASE_URL}/patient/home');

      log('[TB CARE] GET ${uri.path}');
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 15));

      log('[TB CARE] Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body != null && body['data'] != null) {
          final homeData =
              PatientHomeData.fromJson(Map<String, dynamic>.from(body['data']));
          await _saveToCache(patientId, homeData);
          return homeData;
        }
      } else if (response.statusCode == 401) {
        throw HomeServiceException(
          title: 'Sesi telah berakhir',
          message: 'Silakan masuk kembali untuk melanjutkan.',
          type: HomeErrorType.unauthorized,
        );
      } else if (response.statusCode == 403) {
        throw HomeServiceException(
          title: 'Akses Ditolak',
          message: 'Anda tidak memiliki wewenang untuk melihat data ini.',
          type: HomeErrorType.general,
        );
      } else if (response.statusCode >= 500) {
        throw HomeServiceException(
          title: 'Layanan sedang mengalami gangguan',
          message: 'Data belum dapat ditampilkan. Silakan coba beberapa saat lagi.',
          type: HomeErrorType.server,
        );
      } else if (response.statusCode == 404) {
        // Jika endpoint /patient/home belum tersedia di server, fallback ke legacy /patients/{id}/show
        if (patientId != null) {
          return await _fetchFromLegacyEndpoint(patientId, headers);
        }
        throw HomeServiceException(
          title: 'Data tidak ditemukan',
          message: 'Data profil pasien tidak ditemukan pada sistem.',
          type: HomeErrorType.general,
        );
      }
    } on SocketException {
      throw HomeServiceException(
        title: 'Tidak ada koneksi internet',
        message: 'Periksa koneksi internet Anda kemudian coba kembali.',
        type: HomeErrorType.offline,
      );
    } on TimeoutException {
      throw HomeServiceException(
        title: 'Data belum dapat dimuat',
        message:
            'Koneksi ke server membutuhkan waktu lebih lama. Silakan periksa koneksi internet Anda dan coba kembali.',
        type: HomeErrorType.timeout,
      );
    } on HomeServiceException {
      rethrow;
    } catch (e) {
      log('[PatientHomeService] Unexpected error: $e');
      // Jika terjadi error parsing atau lainnya, coba fallback jika patientId ada
      if (patientId != null) {
        try {
          return await _fetchFromLegacyEndpoint(patientId, headers);
        } catch (_) {}
      }
      throw HomeServiceException(
        title: 'Layanan sedang mengalami gangguan',
        message: 'Data belum dapat ditampilkan. Silakan coba beberapa saat lagi.',
        type: HomeErrorType.server,
      );
    }

    // Default fallback
    if (patientId != null) {
      return await _fetchFromLegacyEndpoint(patientId, headers);
    }

    throw HomeServiceException(
      title: 'Data belum dapat dimuat',
      message: 'Silakan periksa koneksi Anda dan coba kembali.',
      type: HomeErrorType.general,
    );
  }

  /// Fallback untuk kompatibilitas jika server belum memperbarui endpoint
  static Future<PatientHomeData> _fetchFromLegacyEndpoint(
    int patientId,
    Map<String, String> headers,
  ) async {
    try {
      final uri = Uri.parse('${Connection.BASE_URL}/patients/$patientId/show');
      log('[TB CARE FALLBACK] GET ${uri.path}');
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body != null && body['data'] != null) {
          final legacyData = Map<String, dynamic>.from(body['data']);
          final homeData = PatientHomeData.fromLegacyPatientShow(legacyData);
          await _saveToCache(patientId, homeData);
          return homeData;
        }
      } else if (response.statusCode == 401) {
        throw HomeServiceException(
          title: 'Sesi telah berakhir',
          message: 'Silakan masuk kembali untuk melanjutkan.',
          type: HomeErrorType.unauthorized,
        );
      } else if (response.statusCode >= 500) {
        throw HomeServiceException(
          title: 'Layanan sedang mengalami gangguan',
          message: 'Data belum dapat ditampilkan. Silakan coba beberapa saat lagi.',
          type: HomeErrorType.server,
        );
      }
    } on SocketException {
      throw HomeServiceException(
        title: 'Tidak ada koneksi internet',
        message: 'Periksa koneksi internet Anda kemudian coba kembali.',
        type: HomeErrorType.offline,
      );
    } on TimeoutException {
      throw HomeServiceException(
        title: 'Data belum dapat dimuat',
        message:
            'Koneksi ke server membutuhkan waktu lebih lama. Silakan periksa koneksi internet Anda dan coba kembali.',
        type: HomeErrorType.timeout,
      );
    } on HomeServiceException {
      rethrow;
    } catch (_) {}

    throw HomeServiceException(
      title: 'Data belum dapat dimuat',
      message: 'Silakan periksa koneksi internet Anda dan coba kembali.',
      type: HomeErrorType.general,
    );
  }
}
