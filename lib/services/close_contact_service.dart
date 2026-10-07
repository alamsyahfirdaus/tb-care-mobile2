import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:apk_tb_care/connection.dart';
import 'package:apk_tb_care/models/close_contact.dart';

class CloseContactException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? errors;

  CloseContactException(this.message, {this.statusCode, this.errors});

  @override
  String toString() => message;
}

class CloseContactService {
  static Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') ?? '';
  }

  static Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// Mengambil daftar seluruh anggota serumah milik pasien
  static Future<List<CloseContact>> getContacts({int? patientId}) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('${Connection.BASE_URL}/contacts').replace(
        queryParameters: patientId != null ? {'patient_id': '$patientId'} : null,
      );

      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['data'] is List) {
          final list = decoded['data'] as List<dynamic>;
          return list
              .map((item) =>
                  CloseContact.fromJson(Map<String, dynamic>.from(item)))
              .toList();
        }
        return [];
      } else if (response.statusCode == 401) {
        throw CloseContactException(
          'Sesi Anda telah berakhir. Silakan login kembali.',
          statusCode: 401,
        );
      } else if (response.statusCode == 403) {
        throw CloseContactException(
          'Anda tidak memiliki wewenang untuk melihat data ini.',
          statusCode: 403,
        );
      } else {
        final decoded = _tryDecode(response.body);
        final msg = decoded?['message'] ?? 'Gagal memuat daftar anggota serumah (${response.statusCode})';
        throw CloseContactException(msg, statusCode: response.statusCode);
      }
    } on SocketException {
      throw CloseContactException('Tidak dapat terhubung ke server. Periksa koneksi internet Anda.');
    } on TimeoutException {
      throw CloseContactException('Koneksi terputus (waktu habis). Silakan coba lagi.');
    } catch (e) {
      if (e is CloseContactException) rethrow;
      throw CloseContactException('Terjadi kesalahan: $e');
    }
  }

  /// Mengambil jumlah anggota serumah milik pasien (untuk card ringkasan)
  static Future<int> getContactCount({int? patientId}) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('${Connection.BASE_URL}/contacts/count').replace(
        queryParameters: patientId != null ? {'patient_id': '$patientId'} : null,
      );

      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded['count'] is int
            ? decoded['count'] as int
            : int.tryParse(decoded['count']?.toString() ?? '0') ?? 0;
      }
      return 0;
    } catch (e) {
      debugPrint('[CloseContactService] Error getting contact count: $e');
      return 0;
    }
  }

  /// Mengambil detail satu anggota serumah
  static Future<CloseContact> getContactDetail(int id) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('${Connection.BASE_URL}/contacts/$id');

      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['data'] is Map) {
          return CloseContact.fromJson(Map<String, dynamic>.from(decoded['data']));
        }
        throw CloseContactException('Format data tidak sesuai.');
      } else if (response.statusCode == 404) {
        throw CloseContactException('Data anggota serumah tidak ditemukan.', statusCode: 404);
      } else if (response.statusCode == 403) {
        throw CloseContactException('Anda tidak memiliki wewenang untuk mengakses anggota ini.', statusCode: 403);
      } else {
        final decoded = _tryDecode(response.body);
        final msg = decoded?['message'] ?? 'Gagal memuat detail anggota (${response.statusCode})';
        throw CloseContactException(msg, statusCode: response.statusCode);
      }
    } on SocketException {
      throw CloseContactException('Tidak dapat terhubung ke server. Periksa koneksi internet Anda.');
    } on TimeoutException {
      throw CloseContactException('Koneksi terputus. Silakan coba lagi.');
    } catch (e) {
      if (e is CloseContactException) rethrow;
      throw CloseContactException('Terjadi kesalahan: $e');
    }
  }

  /// Menambahkan anggota serumah baru
  static Future<CloseContact> createContact(Map<String, dynamic> data) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('${Connection.BASE_URL}/contacts');

      final response = await http
          .post(uri, headers: headers, body: jsonEncode(data))
          .timeout(const Duration(seconds: 20));

      final decoded = _tryDecode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (decoded != null && decoded['data'] is Map) {
          return CloseContact.fromJson(Map<String, dynamic>.from(decoded['data']));
        }
        throw CloseContactException('Data berhasil disimpan namun format balasan tidak sesuai.');
      } else if (response.statusCode == 422) {
        final errors = decoded?['errors'] is Map
            ? Map<String, dynamic>.from(decoded!['errors'])
            : null;
        final errorMsg = _extractFirstError(errors) ??
            decoded?['message'] ??
            'Validasi gagal. Periksa kembali isian formulir.';
        throw CloseContactException(errorMsg, statusCode: 422, errors: errors);
      } else if (response.statusCode == 403) {
        throw CloseContactException('Anda tidak memiliki izin untuk menambah data ini.', statusCode: 403);
      } else {
        final msg = decoded?['message'] ?? 'Gagal menambahkan anggota (${response.statusCode})';
        throw CloseContactException(msg, statusCode: response.statusCode);
      }
    } on SocketException {
      throw CloseContactException('Koneksi internet bermasalah. Periksa jaringan Anda.');
    } on TimeoutException {
      throw CloseContactException('Koneksi server habis waktu. Silakan coba lagi.');
    } catch (e) {
      if (e is CloseContactException) rethrow;
      throw CloseContactException('Terjadi kesalahan saat menyimpan: $e');
    }
  }

  /// Memperbarui data anggota serumah
  static Future<CloseContact> updateContact(int id, Map<String, dynamic> data) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('${Connection.BASE_URL}/contacts/$id');

      final response = await http
          .put(uri, headers: headers, body: jsonEncode(data))
          .timeout(const Duration(seconds: 20));

      final decoded = _tryDecode(response.body);

      if (response.statusCode == 200) {
        if (decoded != null && decoded['data'] is Map) {
          return CloseContact.fromJson(Map<String, dynamic>.from(decoded['data']));
        }
        throw CloseContactException('Data berhasil diperbarui namun balasan tidak sesuai.');
      } else if (response.statusCode == 422) {
        final errors = decoded?['errors'] is Map
            ? Map<String, dynamic>.from(decoded!['errors'])
            : null;
        final errorMsg = _extractFirstError(errors) ??
            decoded?['message'] ??
            'Validasi gagal. Periksa isian form.';
        throw CloseContactException(errorMsg, statusCode: 422, errors: errors);
      } else if (response.statusCode == 403) {
        throw CloseContactException('Anda tidak berhak mengubah anggota serumah ini.', statusCode: 403);
      } else if (response.statusCode == 404) {
        throw CloseContactException('Data anggota serumah tidak ditemukan.', statusCode: 404);
      } else {
        final msg = decoded?['message'] ?? 'Gagal memperbarui data (${response.statusCode})';
        throw CloseContactException(msg, statusCode: response.statusCode);
      }
    } on SocketException {
      throw CloseContactException('Koneksi internet bermasalah. Periksa jaringan Anda.');
    } on TimeoutException {
      throw CloseContactException('Waktu koneksi habis. Silakan coba lagi.');
    } catch (e) {
      if (e is CloseContactException) rethrow;
      throw CloseContactException('Terjadi kesalahan: $e');
    }
  }

  /// Menghapus data anggota serumah
  static Future<bool> deleteContact(int id) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('${Connection.BASE_URL}/contacts/$id');

      final response = await http
          .delete(uri, headers: headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 403) {
        throw CloseContactException('Anda tidak berhak menghapus anggota serumah ini.', statusCode: 403);
      } else if (response.statusCode == 404) {
        throw CloseContactException('Data anggota serumah tidak ditemukan.', statusCode: 404);
      } else {
        final decoded = _tryDecode(response.body);
        final msg = decoded?['message'] ?? 'Gagal menghapus anggota (${response.statusCode})';
        throw CloseContactException(msg, statusCode: response.statusCode);
      }
    } on SocketException {
      throw CloseContactException('Koneksi internet bermasalah.');
    } on TimeoutException {
      throw CloseContactException('Waktu koneksi habis.');
    } catch (e) {
      if (e is CloseContactException) rethrow;
      throw CloseContactException('Terjadi kesalahan: $e');
    }
  }

  /// Mengambil detail satu hasil skrining beserta jawaban pertanyaannya
  static Future<Map<String, dynamic>> getScreeningDetail(int screeningId) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('${Connection.BASE_URL}/screening/$screeningId');

      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['data'] is Map) {
          return Map<String, dynamic>.from(decoded['data']);
        }
        return {};
      } else {
        final decoded = _tryDecode(response.body);
        final msg = decoded?['message'] ?? 'Gagal memuat rincian skrining (${response.statusCode})';
        throw CloseContactException(msg, statusCode: response.statusCode);
      }
    } on SocketException {
      throw CloseContactException('Koneksi internet bermasalah.');
    } on TimeoutException {
      throw CloseContactException('Waktu koneksi habis.');
    } catch (e) {
      if (e is CloseContactException) rethrow;
      throw CloseContactException('Terjadi kesalahan: $e');
    }
  }

  static Map<String, dynamic>? _tryDecode(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static String? _extractFirstError(Map<String, dynamic>? errors) {
    if (errors == null || errors.isEmpty) return null;
    final firstVal = errors.values.first;
    if (firstVal is List && firstVal.isNotEmpty) {
      return firstVal.first.toString();
    }
    return firstVal?.toString();
  }
}
