import 'package:intl/intl.dart';

class PatientHomeData {
  final PatientInfo? patient;
  final TreatmentInfo? treatment;
  final VisitInfo? nextVisit;
  final List<VisitInfo> upcomingVisits;
  final MedicationInfo? medication;
  final ConsultationSummary? consultation;
  final List<NotificationItem> notifications;
  final int unreadNotificationsCount;
  final List<EducationItem> education;

  PatientHomeData({
    this.patient,
    this.treatment,
    this.nextVisit,
    this.upcomingVisits = const [],
    this.medication,
    this.consultation,
    this.notifications = const [],
    this.unreadNotificationsCount = 0,
    this.education = const [],
  });

  factory PatientHomeData.fromJson(Map<String, dynamic> json) {
    return PatientHomeData(
      patient: json['patient'] != null
          ? PatientInfo.fromJson(Map<String, dynamic>.from(json['patient']))
          : null,
      treatment: json['treatment'] != null
          ? TreatmentInfo.fromJson(Map<String, dynamic>.from(json['treatment']))
          : null,
      nextVisit: json['next_visit'] != null
          ? VisitInfo.fromJson(Map<String, dynamic>.from(json['next_visit']))
          : null,
      upcomingVisits: (json['upcoming_visits'] as List<dynamic>?)
              ?.map((e) => VisitInfo.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
      medication: json['medication'] != null
          ? MedicationInfo.fromJson(Map<String, dynamic>.from(json['medication']))
          : null,
      consultation: json['consultation'] != null
          ? ConsultationSummary.fromJson(
              Map<String, dynamic>.from(json['consultation']))
          : null,
      notifications: (json['notifications'] as List<dynamic>?)
              ?.map((e) => NotificationItem.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
      unreadNotificationsCount:
          (json['unread_notifications_count'] as num?)?.toInt() ?? 0,
      education: (json['education'] as List<dynamic>?)
              ?.map((e) => EducationItem.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'patient': patient?.toJson(),
      'treatment': treatment?.toJson(),
      'next_visit': nextVisit?.toJson(),
      'upcoming_visits': upcomingVisits.map((e) => e.toJson()).toList(),
      'medication': medication?.toJson(),
      'consultation': consultation?.toJson(),
      'notifications': notifications.map((e) => e.toJson()).toList(),
      'unread_notifications_count': unreadNotificationsCount,
      'education': education.map((e) => e.toJson()).toList(),
    };
  }

  /// Adaptasi dari response legacy `/patients/{id}/show`
  factory PatientHomeData.fromLegacyPatientShow(
      Map<String, dynamic> data, {
      bool uploadedToday = false,
      Map<String, dynamic>? todayRecord,
  }) {
    final treatments = (data['treatments'] as List<dynamic>?) ?? [];
    final currentTreatment = treatments.isNotEmpty ? treatments[0] : null;

    final visits = (currentTreatment?['visits'] as List<dynamic>?) ?? [];
    final puskesmasName = data['puskesmas']?.toString() ?? 'Puskesmas';

    // Parse upcoming visits
    final now = DateTime.now();
    final todayOnly = DateTime(now.year, now.month, now.day);
    final List<VisitInfo> upcoming = [];

    for (var v in visits) {
      if (v == null) continue;
      final vMap = Map<String, dynamic>.from(v);
      final dateStr = vMap['visit_date']?.toString();
      if (dateStr == null) continue;
      final parsedDate = DateTime.tryParse(dateStr);
      if (parsedDate != null) {
        final parsedOnly = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
        if (parsedOnly.isAfter(todayOnly) || parsedOnly.isAtSameMomentAs(todayOnly)) {
          upcoming.add(VisitInfo.fromJson({
            'id': vMap['id'],
            'visit_date': dateStr,
            'visit_time': vMap['visit_time'],
            'visit_status': vMap['visit_status'] ?? 'Terjadwal',
            'notes': vMap['notes'],
            'puskesmas_name': vMap['puskesmas_name'] ?? puskesmasName,
          }));
        }
      }
    }

    upcoming.sort((a, b) {
      final da = DateTime.tryParse(a.visitDate ?? '') ?? DateTime(3000);
      final db = DateTime.tryParse(b.visitDate ?? '') ?? DateTime(3000);
      return da.compareTo(db);
    });

    final nextVisit = upcoming.isNotEmpty ? upcoming.first : null;

    // Treatment calculations
    TreatmentInfo? treatmentInfo;
    if (currentTreatment != null) {
      final rawStart = data['treatment_start_date']?.toString() ??
          currentTreatment['start_date']?.toString();
      final rawEnd = currentTreatment['end_date']?.toString();

      int currentDay = 0;
      int totalDays = 180;

      if (rawStart != null && rawStart.trim().isNotEmpty) {
        final start = DateTime.tryParse(rawStart);
        if (start != null) {
          final startOnly = DateTime(start.year, start.month, start.day);
          if (!todayOnly.isBefore(startOnly)) {
            currentDay = todayOnly.difference(startOnly).inDays + 1;
          }
          if (rawEnd != null && rawEnd.trim().isNotEmpty) {
            final end = DateTime.tryParse(rawEnd);
            if (end != null) {
              final endOnly = DateTime(end.year, end.month, end.day);
              totalDays = endOnly.difference(startOnly).inDays + 1;
              if (currentDay > totalDays) currentDay = totalDays;
            }
          }
        }
      }

      int progress = totalDays > 0 ? ((currentDay / totalDays) * 100).round() : 0;
      if (progress > 100) progress = 100;

      String? medTime;
      final schedule = data['medication_schedule'];
      if (schedule != null && schedule['reminder_time'] != null) {
        medTime = schedule['reminder_time'].toString();
      } else if (currentTreatment['medication_time'] != null) {
        medTime = currentTreatment['medication_time'].toString();
      }
      if (medTime != null && medTime.length >= 5) {
        medTime = medTime.substring(0, 5);
      }

      treatmentInfo = TreatmentInfo(
        id: currentTreatment['id'] is int
            ? currentTreatment['id']
            : int.tryParse(currentTreatment['id']?.toString() ?? '') ?? 0,
        treatmentTypeId: currentTreatment['treatment_type_id'],
        treatmentTypeName: currentTreatment['treatment_type_id'] == 1
            ? 'TB Aktif'
            : currentTreatment['treatment_type_id'] == 2
                ? 'TB Laten'
                : 'TB MDR',
        treatmentStatus: currentTreatment['treatment_status']?.toString() ?? 'Berjalan',
        startDate: rawStart,
        endDate: rawEnd,
        treatmentDays: currentTreatment['treatment_days'],
        currentDay: currentDay,
        totalDays: totalDays > 0 ? totalDays : 180,
        progressPercent: progress,
        medicationTime: medTime,
      );
    }

    return PatientHomeData(
      patient: PatientInfo(
        id: data['id'] is int ? data['id'] : int.tryParse(data['id']?.toString() ?? '') ?? 0,
        userId: data['user_id'] is int ? data['user_id'] : int.tryParse(data['user_id']?.toString() ?? ''),
        name: data['name']?.toString() ?? 'Pasien TB',
        nik: data['nik']?.toString(),
        phone: data['phone']?.toString(),
        gender: data['gender']?.toString(),
        photo: null,
        puskesmasName: puskesmasName,
        treatmentStartDate: data['treatment_start_date']?.toString(),
      ),
      treatment: treatmentInfo,
      nextVisit: nextVisit,
      upcomingVisits: upcoming.take(3).toList(),
      medication: MedicationInfo(
        reminderTime: treatmentInfo?.medicationTime,
        isTakenToday: uploadedToday,
        todayRecord: todayRecord,
      ),
      consultation: null,
      notifications: [],
      unreadNotificationsCount: 0,
      education: [],
    );
  }
}

class PatientInfo {
  final int id;
  final int? userId;
  final String name;
  final String? nik;
  final String? phone;
  final String? gender;
  final String? photo;
  final String puskesmasName;
  final String? treatmentStartDate;

  PatientInfo({
    required this.id,
    this.userId,
    required this.name,
    this.nik,
    this.phone,
    this.gender,
    this.photo,
    required this.puskesmasName,
    this.treatmentStartDate,
  });

  factory PatientInfo.fromJson(Map<String, dynamic> json) {
    return PatientInfo(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      userId: json['user_id'] is int ? json['user_id'] : int.tryParse(json['user_id']?.toString() ?? ''),
      name: json['name']?.toString() ?? 'Pasien TB',
      nik: json['nik']?.toString(),
      phone: json['phone']?.toString(),
      gender: json['gender']?.toString(),
      photo: json['photo']?.toString(),
      puskesmasName: json['puskesmas_name']?.toString() ?? json['puskesmas']?.toString() ?? 'Puskesmas',
      treatmentStartDate: json['treatment_start_date']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'nik': nik,
        'phone': phone,
        'gender': gender,
        'photo': photo,
        'puskesmas_name': puskesmasName,
        'treatment_start_date': treatmentStartDate,
      };
}

class TreatmentInfo {
  final int id;
  final int? treatmentTypeId;
  final String treatmentTypeName;
  final String treatmentStatus;
  final String? startDate;
  final String? endDate;
  final int? treatmentDays;
  final int currentDay;
  final int totalDays;
  final int progressPercent;
  final String? medicationTime;

  TreatmentInfo({
    required this.id,
    this.treatmentTypeId,
    required this.treatmentTypeName,
    required this.treatmentStatus,
    this.startDate,
    this.endDate,
    this.treatmentDays,
    this.currentDay = 0,
    this.totalDays = 180,
    this.progressPercent = 0,
    this.medicationTime,
  });

  factory TreatmentInfo.fromJson(Map<String, dynamic> json) {
    return TreatmentInfo(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      treatmentTypeId: json['treatment_type_id'] is int
          ? json['treatment_type_id']
          : int.tryParse(json['treatment_type_id']?.toString() ?? ''),
      treatmentTypeName: json['treatment_type_name']?.toString() ?? 'Program Pengobatan TB',
      treatmentStatus: json['treatment_status']?.toString() ?? 'Berjalan',
      startDate: json['start_date']?.toString(),
      endDate: json['end_date']?.toString(),
      treatmentDays: (json['treatment_days'] as num?)?.toInt(),
      currentDay: (json['current_day'] as num?)?.toInt() ?? 0,
      totalDays: (json['total_days'] as num?)?.toInt() ?? 180,
      progressPercent: (json['progress_percent'] as num?)?.toInt() ?? 0,
      medicationTime: json['medication_time']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'treatment_type_id': treatmentTypeId,
        'treatment_type_name': treatmentTypeName,
        'treatment_status': treatmentStatus,
        'start_date': startDate,
        'end_date': endDate,
        'treatment_days': treatmentDays,
        'current_day': currentDay,
        'total_days': totalDays,
        'progress_percent': progressPercent,
        'medication_time': medicationTime,
      };
}

class VisitInfo {
  final int id;
  final String? visitDate;
  final String? visitTime;
  final String visitStatus;
  final String? notes;
  final String puskesmasName;

  VisitInfo({
    required this.id,
    this.visitDate,
    this.visitTime,
    required this.visitStatus,
    this.notes,
    required this.puskesmasName,
  });

  factory VisitInfo.fromJson(Map<String, dynamic> json) {
    return VisitInfo(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      visitDate: json['visit_date']?.toString() ?? json['date']?.toString(),
      visitTime: json['visit_time']?.toString() ?? json['time']?.toString(),
      visitStatus: json['visit_status']?.toString() ?? json['status']?.toString() ?? 'Terjadwal',
      notes: json['notes']?.toString(),
      puskesmasName: json['puskesmas_name']?.toString() ?? 'Puskesmas',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'visit_date': visitDate,
        'visit_time': visitTime,
        'visit_status': visitStatus,
        'notes': notes,
        'puskesmas_name': puskesmasName,
      };

  String get formattedDate {
    if (visitDate == null) return 'Tanggal belum ditentukan';
    try {
      final dt = DateTime.parse(visitDate!);
      return DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(dt);
    } catch (_) {
      return visitDate!;
    }
  }

  String get formattedShortDate {
    if (visitDate == null) return '-';
    try {
      final dt = DateTime.parse(visitDate!);
      return DateFormat('d MMMM yyyy', 'id_ID').format(dt);
    } catch (_) {
      return visitDate!;
    }
  }

  String get formattedTime {
    if (visitTime == null || visitTime!.isEmpty) return '--:--';
    if (visitTime!.length >= 5) return visitTime!.substring(0, 5);
    return visitTime!;
  }
}

class MedicationInfo {
  final String? reminderTime;
  final bool isTakenToday;
  final Map<String, dynamic>? todayRecord;

  MedicationInfo({
    this.reminderTime,
    this.isTakenToday = false,
    this.todayRecord,
  });

  factory MedicationInfo.fromJson(Map<String, dynamic> json) {
    return MedicationInfo(
      reminderTime: json['reminder_time']?.toString(),
      isTakenToday: json['is_taken_today'] == true,
      todayRecord: json['today_record'] != null
          ? Map<String, dynamic>.from(json['today_record'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'reminder_time': reminderTime,
        'is_taken_today': isTakenToday,
        'today_record': todayRecord,
      };
}

class ConsultationSummary {
  final int id;
  final String title;
  final String latestMessage;
  final String doctorOrOfficerName;
  final String? updatedAt;
  final bool isAnswered;
  final int unreadRepliesCount;

  ConsultationSummary({
    required this.id,
    required this.title,
    required this.latestMessage,
    required this.doctorOrOfficerName,
    this.updatedAt,
    this.isAnswered = false,
    this.unreadRepliesCount = 0,
  });

  factory ConsultationSummary.fromJson(Map<String, dynamic> json) {
    return ConsultationSummary(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      title: json['title']?.toString() ?? 'Konsultasi',
      latestMessage: json['latest_message']?.toString() ?? '',
      doctorOrOfficerName: json['doctor_or_officer_name']?.toString() ?? 'Petugas TB Care',
      updatedAt: json['updated_at']?.toString(),
      isAnswered: json['is_answered'] == true,
      unreadRepliesCount: (json['unread_replies_count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'latest_message': latestMessage,
        'doctor_or_officer_name': doctorOrOfficerName,
        'updated_at': updatedAt,
        'is_answered': isAnswered,
        'unread_replies_count': unreadRepliesCount,
      };
}

class NotificationItem {
  final int id;
  final String title;
  final String message;
  final String type;
  final String? createdAt;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      title: json['title']?.toString() ?? 'Notifikasi',
      message: json['message']?.toString() ?? '',
      type: json['type']?.toString() ?? 'Info',
      createdAt: json['created_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'message': message,
        'type': type,
        'created_at': createdAt,
      };
}

class EducationItem {
  final int id;
  final String title;
  final String? description;
  final String materialType;
  final String? photo;
  final String? videoUrl;
  final String? createdAt;

  EducationItem({
    required this.id,
    required this.title,
    this.description,
    required this.materialType,
    this.photo,
    this.videoUrl,
    this.createdAt,
  });

  factory EducationItem.fromJson(Map<String, dynamic> json) {
    return EducationItem(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      title: json['title_material']?.toString() ?? json['title']?.toString() ?? 'Edukasi TB',
      description: json['description']?.toString(),
      materialType: json['material_type']?.toString() ?? 'image',
      photo: json['photo']?.toString(),
      videoUrl: json['video_url']?.toString(),
      createdAt: json['created_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title_material': title,
        'description': description,
        'material_type': materialType,
        'photo': photo,
        'video_url': videoUrl,
        'created_at': createdAt,
      };
}
