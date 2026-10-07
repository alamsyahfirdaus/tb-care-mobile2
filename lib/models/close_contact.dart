import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ContactScreening {
  final int id;
  final String code;
  final String riskLevel;
  final String status;
  final int totalScore;
  final int symptomsCount;
  final bool hasCriticalSymptom;
  final String recommendation;
  final String? notes;
  final String? screenedAt;
  final String? screenedAtFormatted;

  ContactScreening({
    required this.id,
    required this.code,
    required this.riskLevel,
    required this.status,
    required this.totalScore,
    required this.symptomsCount,
    this.hasCriticalSymptom = false,
    required this.recommendation,
    this.notes,
    this.screenedAt,
    this.screenedAtFormatted,
  });

  factory ContactScreening.fromJson(Map<String, dynamic> json) {
    return ContactScreening(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      code: json['code']?.toString() ?? '',
      riskLevel: json['risk_level']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      totalScore: json['total_score'] is int
          ? json['total_score'] as int
          : int.tryParse(json['total_score']?.toString() ?? '0') ?? 0,
      symptomsCount: json['symptoms_count'] is int
          ? json['symptoms_count'] as int
          : int.tryParse(json['symptoms_count']?.toString() ?? '0') ?? 0,
      hasCriticalSymptom: json['has_critical_symptom'] == true,
      recommendation: json['recommendation']?.toString() ?? '',
      notes: json['notes']?.toString(),
      screenedAt: json['screened_at']?.toString(),
      screenedAtFormatted: json['screened_at_formatted']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'risk_level': riskLevel,
      'status': status,
      'total_score': totalScore,
      'symptoms_count': symptomsCount,
      'has_critical_symptom': hasCriticalSymptom,
      'recommendation': recommendation,
      'notes': notes,
      'screened_at': screenedAt,
      'screened_at_formatted': screenedAtFormatted,
    };
  }
}

class CloseContact {
  final int id;
  final String contactCode;
  final int patientId;
  final String name;
  final String relationship;
  final String gender;
  final String genderLabel;
  final String? dateOfBirth;
  final int age;
  final String? nik;
  final String? phone;
  final String? address;
  final String? screeningDate;
  final String screeningResult;
  final String tptStatus;
  final String? notes;
  final ContactScreening? latestScreening;
  final List<ContactScreening> screenings;

  CloseContact({
    required this.id,
    required this.contactCode,
    required this.patientId,
    required this.name,
    required this.relationship,
    required this.gender,
    required this.genderLabel,
    this.dateOfBirth,
    required this.age,
    this.nik,
    this.phone,
    this.address,
    this.screeningDate,
    required this.screeningResult,
    required this.tptStatus,
    this.notes,
    this.latestScreening,
    this.screenings = const [],
  });

  factory CloseContact.fromJson(Map<String, dynamic> json) {
    final rawGender = json['gender']?.toString().toUpperCase() ?? 'L';
    final parsedAge = json['age'] is int
        ? json['age'] as int
        : int.tryParse(json['age']?.toString() ?? '0') ?? 0;

    ContactScreening? parsedLatest;
    if (json['latest_screening'] is Map) {
      parsedLatest = ContactScreening.fromJson(
        Map<String, dynamic>.from(json['latest_screening']),
      );
    }

    List<ContactScreening> parsedScreenings = [];
    if (json['screenings'] is List) {
      parsedScreenings = (json['screenings'] as List)
          .whereType<Map>()
          .map((m) => ContactScreening.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    }

    return CloseContact(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      contactCode: json['contact_code']?.toString() ?? '',
      patientId: json['patient_id'] is int
          ? json['patient_id'] as int
          : int.tryParse(json['patient_id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      relationship: json['relationship']?.toString() ?? 'Keluarga Serumah',
      gender: rawGender,
      genderLabel: json['gender_label']?.toString() ??
          (rawGender == 'P' ? 'Perempuan' : 'Laki-laki'),
      dateOfBirth: json['date_of_birth']?.toString(),
      age: parsedAge,
      nik: json['nik']?.toString(),
      phone: json['phone']?.toString(),
      address: json['address']?.toString(),
      screeningDate: json['screening_date']?.toString(),
      screeningResult:
          json['screening_result']?.toString() ?? 'Belum Skrining',
      tptStatus: json['tpt_status']?.toString() ?? 'Tidak Perlu',
      notes: json['notes']?.toString(),
      latestScreening: parsedLatest,
      screenings: parsedScreenings,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'contact_code': contactCode,
      'patient_id': patientId,
      'name': name,
      'relationship': relationship,
      'gender': gender,
      'gender_label': genderLabel,
      'date_of_birth': dateOfBirth,
      'age': age,
      'nik': nik,
      'phone': phone,
      'address': address,
      'screening_date': screeningDate,
      'screening_result': screeningResult,
      'tpt_status': tptStatus,
      'notes': notes,
      'latest_screening': latestScreening?.toJson(),
      'screenings': screenings.map((s) => s.toJson()).toList(),
    };
  }

  /// Format tanggal lahir ke bahasa Indonesia (contoh: 12 Mei 2010)
  String? get formattedDateOfBirth {
    if (dateOfBirth == null || dateOfBirth!.isEmpty) return null;
    try {
      final parsed = DateTime.parse(dateOfBirth!);
      return DateFormat('d MMMM y', 'id_ID').format(parsed);
    } catch (_) {
      return dateOfBirth;
    }
  }

  /// Format tanggal skrining ke bahasa Indonesia
  String? get formattedScreeningDate {
    if (screeningDate == null || screeningDate!.isEmpty) return null;
    try {
      final parsed = DateTime.parse(screeningDate!);
      return DateFormat('d MMMM y', 'id_ID').format(parsed);
    } catch (_) {
      return screeningDate;
    }
  }

  /// Menentukan apakah anggota ini sudah pernah diskrining
  bool get isScreened {
    if (latestScreening != null) return true;
    final lower = screeningResult.toLowerCase().trim();
    return lower.isNotEmpty &&
        lower != 'belum' &&
        lower != 'belum skrining' &&
        lower != 'tidak ada' &&
        lower != '-';
  }

  /// Ringkasan status skrining untuk badge
  String get screeningStatusShort {
    if (!isScreened) return 'Belum Skrining';
    if (screeningResult.contains('Tinggi')) return 'Risiko Tinggi';
    if (screeningResult.contains('Sedang')) return 'Risiko Sedang';
    if (screeningResult.contains('Rendah')) return 'Risiko Rendah';
    if (screeningResult.contains('Sehat')) return 'Sehat';
    if (screeningResult.contains('Gejala')) return 'Bergejala';
    if (screeningResult.contains('Dirujuk')) return 'Dirujuk';
    if (screeningResult.contains('TPT')) return 'Mulai TPT';
    if (screeningResult.contains('Positif')) return 'Positif TB';
    return screeningResult;
  }

  /// Warna tema status skrining
  Color get screeningColor {
    if (!isScreened) return const Color(0xFFF59E0B); // Amber / Kuning
    if (screeningResult.contains('Rendah') ||
        screeningResult.contains('Sehat')) {
      return const Color(0xFF10B981); // Emerald Green
    }
    if (screeningResult.contains('Sedang')) {
      return const Color(0xFFF59E0B); // Amber / Orange
    }
    if (screeningResult.contains('Tinggi') ||
        screeningResult.contains('Gejala') ||
        screeningResult.contains('Positif')) {
      return const Color(0xFFEF4444); // Red
    }
    if (screeningResult.contains('Dirujuk')) {
      return const Color(0xFF3B82F6); // Blue
    }
    return const Color(0xFF8B5CF6); // Purple
  }
}
