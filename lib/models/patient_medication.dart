class PatientMedication {
  final String name;
  final String? dosage;
  final String? frequency;
  final String? rules;
  final String? scheduleTime;

  const PatientMedication({
    required this.name,
    this.dosage,
    this.frequency,
    this.rules,
    this.scheduleTime,
  });

  factory PatientMedication.fromDynamic(
    dynamic item, {
    String? defaultScheduleTime,
  }) {
    if (item == null) {
      return const PatientMedication(name: '-');
    }

    if (item is String) {
      final trimmed = item.trim();
      return PatientMedication(
        name: trimmed.isNotEmpty ? trimmed : '-',
        scheduleTime: defaultScheduleTime,
      );
    }

    if (item is Map) {
      final map = Map<String, dynamic>.from(item);
      final rawName =
          map['name'] ??
          map['nama_obat'] ??
          map['nama'] ??
          map['drug_name'] ??
          map['medicine_name'] ??
          '-';
      return PatientMedication(
        name: rawName.toString().trim(),
        dosage: map['dosage']?.toString() ?? map['dosis']?.toString(),
        frequency: map['frequency']?.toString() ?? map['frekuensi']?.toString(),
        rules:
            map['rules']?.toString() ??
            map['instruksi']?.toString() ??
            map['aturan']?.toString() ??
            map['catatan']?.toString(),
        scheduleTime:
            map['schedule_time']?.toString() ??
            map['time']?.toString() ??
            map['jadwal']?.toString() ??
            defaultScheduleTime,
      );
    }

    return PatientMedication(
      name: item.toString().trim(),
      scheduleTime: defaultScheduleTime,
    );
  }

  /// Mem-parsing raw data obat (List of strings, List of maps, delimited string, dll.)
  /// secara aman dan memecah nama obat yang tergabung oleh newline atau koma.
  static List<PatientMedication> parseList(
    dynamic raw, {
    String? defaultScheduleTime,
  }) {
    if (raw == null) return [];
    final List<PatientMedication> result = [];

    void addSingle(
      String name, {
      String? dosage,
      String? frequency,
      String? rules,
      String? time,
    }) {
      final trimmed = name.trim();
      if (trimmed.isNotEmpty &&
          trimmed != '-' &&
          trimmed.toLowerCase() != 'tidak ada' &&
          trimmed.toLowerCase() != 'tidak ada informasi obat.') {
        result.add(
          PatientMedication(
            name: trimmed,
            dosage: dosage,
            frequency: frequency,
            rules: rules,
            scheduleTime: time ?? defaultScheduleTime,
          ),
        );
      }
    }

    void parseString(String str) {
      final lines = str.split(RegExp(r'[\r\n]+'));
      for (final line in lines) {
        final parts = line.split(',');
        for (final part in parts) {
          addSingle(part);
        }
      }
    }

    if (raw is List) {
      for (final item in raw) {
        if (item == null) continue;
        if (item is String) {
          parseString(item);
        } else if (item is Map) {
          final med = PatientMedication.fromDynamic(
            item,
            defaultScheduleTime: defaultScheduleTime,
          );
          if (med.name.contains('\n') ||
              med.name.contains('\r') ||
              med.name.contains(',')) {
            final parts = med.name.split(RegExp(r'[\r\n,]+'));
            for (final p in parts) {
              addSingle(
                p,
                dosage: med.dosage,
                frequency: med.frequency,
                rules: med.rules,
                time: med.scheduleTime,
              );
            }
          } else {
            if (med.name.trim().isNotEmpty && med.name != '-') {
              result.add(med);
            }
          }
        } else {
          parseString(item.toString());
        }
      }
    } else if (raw is String) {
      parseString(raw);
    }

    return result;
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    if (dosage != null) 'dosage': dosage,
    if (frequency != null) 'frequency': frequency,
    if (rules != null) 'rules': rules,
    if (scheduleTime != null) 'schedule_time': scheduleTime,
  };
}

class PatientMedicationResponse {
  final int? treatmentId;
  final String? treatmentType;
  final String? treatmentStatus;
  final String? startDate;
  final String? endDate;
  final String? medicationTime;
  final int count;
  final List<PatientMedication> medications;

  const PatientMedicationResponse({
    this.treatmentId,
    this.treatmentType,
    this.treatmentStatus,
    this.startDate,
    this.endDate,
    this.medicationTime,
    required this.count,
    required this.medications,
  });

  factory PatientMedicationResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map ? Map<String, dynamic>.from(json['data']) : json;

    final medListRaw = data['medications'] ?? data['prescription'] ?? [];
    final String? medTime = data['medication_time']?.toString();
    final List<PatientMedication> meds = PatientMedication.parseList(
      medListRaw,
      defaultScheduleTime: medTime,
    );

    final int count = data['count'] is int ? data['count'] as int : meds.length;

    return PatientMedicationResponse(
      treatmentId: data['treatment_id'] is int
          ? data['treatment_id'] as int
          : (data['id'] is int ? data['id'] as int : null),
      treatmentType: data['treatment_type']?.toString(),
      treatmentStatus: data['treatment_status']?.toString(),
      startDate: data['start_date']?.toString(),
      endDate: data['end_date']?.toString(),
      medicationTime: medTime,
      count: count,
      medications: meds,
    );
  }

  factory PatientMedicationResponse.empty() {
    return const PatientMedicationResponse(
      count: 0,
      medications: [],
    );
  }
}
