import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:apk_tb_care/connection.dart';
import 'package:apk_tb_care/models/patient_medication.dart';

class PatientMedicationException implements Exception {
  final String message;
  final int? statusCode;

  PatientMedicationException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class PatientMedicationService {
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

  /// Mengambil daftar obat pengobatan aktif milik pasien terautentikasi
  static Future<PatientMedicationResponse> getMedications({int? patientId}) async {
    final headers = await _getHeaders();

    // 1. Coba panggil endpoint khusus /treatments/medications
    try {
      final uri = Uri.parse('${Connection.BASE_URL}/treatments/medications').replace(
        queryParameters: patientId != null ? {'patient_id': '$patientId'} : null,
      );

      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return PatientMedicationResponse.fromJson(decoded);
        }
        return PatientMedicationResponse.empty();
      } else if (response.statusCode == 401) {
        throw PatientMedicationException(
          'Sesi Anda telah berakhir. Silakan login kembali.',
          statusCode: 401,
        );
      } else if (response.statusCode == 403) {
        throw PatientMedicationException(
          'Anda tidak memiliki wewenang untuk melihat data obat ini.',
          statusCode: 403,
        );
      } else if (response.statusCode == 404) {
        // Fallback jika endpoint belum dikenali, panggil patient show
        if (patientId != null) {
          return await _fetchFromPatientShow(patientId, headers);
        }
        return PatientMedicationResponse.empty();
      } else {
        final decoded = _tryDecode(response.body);
        final msg = decoded?['message'] ?? 'Gagal memuat daftar obat (${response.statusCode})';
        throw PatientMedicationException(msg, statusCode: response.statusCode);
      }
    } on SocketException {
      throw PatientMedicationException('Tidak dapat terhubung ke server. Periksa koneksi internet Anda.');
    } on TimeoutException {
      throw PatientMedicationException('Koneksi terputus (waktu habis). Silakan coba lagi.');
    } catch (e) {
      if (e is PatientMedicationException) rethrow;

      // Fallback ke patient show jika memungkinkan
      if (patientId != null) {
        try {
          return await _fetchFromPatientShow(patientId, headers);
        } catch (_) {}
      }

      debugPrint('[PatientMedicationService] Error: $e');
      throw PatientMedicationException('Gagal memuat daftar obat: $e');
    }
  }

  /// Fallback untuk mengambil prescription dari GET /api/patients/{id}/show
  static Future<PatientMedicationResponse> _fetchFromPatientShow(
    int patientId,
    Map<String, String> headers,
  ) async {
    final uri = Uri.parse('${Connection.BASE_URL}/patients/$patientId/show');
    final response = await http
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final data = decoded['data'];
      if (data is Map) {
        final treatments = data['treatments'];
        if (treatments is List && treatments.isNotEmpty) {
          final firstTreatment = Map<String, dynamic>.from(treatments.first);
          final rawPrescription = firstTreatment['prescription'];
          final medTime = firstTreatment['medication_time']?.toString() ??
              data['medication_schedule']?['reminder_time']?.toString();

          final List<PatientMedication> list = [];
          if (rawPrescription is List) {
            for (final p in rawPrescription) {
              if (p != null) {
                list.add(PatientMedication.fromDynamic(p, defaultScheduleTime: medTime));
              }
            }
          }

          return PatientMedicationResponse(
            treatmentId: firstTreatment['id'] is int ? firstTreatment['id'] as int : null,
            treatmentStatus: firstTreatment['treatment_status']?.toString(),
            medicationTime: medTime,
            count: list.length,
            medications: list,
          );
        }
      }
      return PatientMedicationResponse.empty();
    } else {
      throw PatientMedicationException(
        'Gagal memuat data pengobatan pasien (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }
  }

  static Map<String, dynamic>? _tryDecode(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }
}
