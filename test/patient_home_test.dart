import 'package:flutter_test/flutter_test.dart';
import 'package:apk_tb_care/models/patient_home_model.dart';

void main() {
  group('PatientHomeModel Tests', () {
    test('Parses unified JSON response correctly', () {
      final json = {
        'patient': {
          'id': 1,
          'user_id': 2,
          'name': 'Pasien TB Care',
          'nik': '3278012345678901',
          'phone': '081234567890',
          'gender': 'L',
          'photo': null,
          'puskesmas_name': 'Puskesmas Cihideung',
          'treatment_start_date': '2026-01-17',
        },
        'treatment': {
          'id': 10,
          'treatment_type_id': 1,
          'treatment_type_name': 'Kategori 1 (Pasien Baru)',
          'treatment_status': 'Berjalan',
          'start_date': '2026-01-17',
          'end_date': '2026-07-17',
          'treatment_days': 180,
          'current_day': 45,
          'total_days': 180,
          'progress_percent': 25,
          'medication_time': '20:00',
        },
        'next_visit': {
          'id': 5,
          'visit_date': '2026-10-12',
          'visit_time': '08:00',
          'visit_status': 'Terjadwal',
          'notes': 'Kontrol rutin',
          'puskesmas_name': 'Puskesmas Cihideung',
        },
        'upcoming_visits': [
          {
            'id': 5,
            'visit_date': '2026-10-12',
            'visit_time': '08:00',
            'visit_status': 'Terjadwal',
            'notes': 'Kontrol rutin',
            'puskesmas_name': 'Puskesmas Cihideung',
          }
        ],
        'medication': {
          'reminder_time': '20:00',
          'is_taken_today': false,
          'today_record': null,
        },
        'consultation': {
          'id': 1,
          'title': 'Konsultasi Efek Samping',
          'latest_message': 'Silakan diminum setelah makan malam.',
          'doctor_or_officer_name': 'dr. Budi Santoso',
          'updated_at': '2026-10-02 14:00',
          'is_answered': true,
          'unread_replies_count': 0,
        },
        'notifications': [
          {
            'id': 1,
            'title': 'Pengingat Minum Obat',
            'message': 'Jangan lupa minum obat hari ini.',
            'type': 'Pengingat Minum Obat',
            'created_at': '2026-09-05 15:20',
          }
        ],
        'unread_notifications_count': 1,
        'education': [
          {
            'id': 49,
            'title_material': 'Etika Batuk',
            'description': 'Panduan etika batuk yang benar.',
            'material_type': 'image',
            'photo': 'https://example.com/img.jpg',
            'video_url': null,
            'created_at': '2026-04-21 10:16',
          }
        ],
      };

      final homeData = PatientHomeData.fromJson(json);

      expect(homeData.patient?.name, 'Pasien TB Care');
      expect(homeData.patient?.puskesmasName, 'Puskesmas Cihideung');
      expect(homeData.treatment?.currentDay, 45);
      expect(homeData.treatment?.totalDays, 180);
      expect(homeData.treatment?.progressPercent, 25);
      expect(homeData.nextVisit?.formattedTime, '08:00');
      expect(homeData.medication?.isTakenToday, false);
      expect(homeData.consultation?.doctorOrOfficerName, 'dr. Budi Santoso');
      expect(homeData.notifications.length, 1);
      expect(homeData.education.length, 1);
      expect(homeData.unreadNotificationsCount, 1);
    });

    test('toJson and fromJson preserves data for local caching', () {
      final initial = PatientHomeData(
        patient: PatientInfo(
          id: 1,
          userId: 2,
          name: 'Pasien Uji',
          puskesmasName: 'Puskesmas Kawalu',
        ),
        treatment: TreatmentInfo(
          id: 5,
          treatmentTypeName: 'TB Aktif',
          treatmentStatus: 'Berjalan',
          currentDay: 20,
          totalDays: 180,
          progressPercent: 11,
          medicationTime: '19:00',
        ),
        medication: MedicationInfo(
          reminderTime: '19:00',
          isTakenToday: true,
        ),
      );

      final map = initial.toJson();
      final restored = PatientHomeData.fromJson(map);

      expect(restored.patient?.name, 'Pasien Uji');
      expect(restored.treatment?.progressPercent, 11);
      expect(restored.medication?.isTakenToday, true);
    });

    test('Adapts legacy patient show response seamlessly', () {
      final legacy = {
        'id': 1,
        'user_id': 2,
        'name': 'Pasien Legacy',
        'puskesmas': 'Puskesmas Kawalu',
        'treatment_start_date': '2026-10-01',
        'treatments': [
          {
            'id': 10,
            'treatment_type_id': 1,
            'treatment_status': 'Berjalan',
            'start_date': '2026-10-01',
            'end_date': '2027-04-01',
            'treatment_days': 180,
            'medication_time': '08:00',
            'visits': [
              {
                'id': 1,
                'visit_date': '2026-10-15',
                'visit_time': '09:00:00',
                'visit_status': 'Terjadwal',
                'notes': 'Kontrol 2 mingguan',
              }
            ],
          }
        ],
      };

      final homeData = PatientHomeData.fromLegacyPatientShow(legacy, uploadedToday: true);

      expect(homeData.patient?.name, 'Pasien Legacy');
      expect(homeData.treatment?.treatmentTypeName, 'TB Aktif');
      expect(homeData.medication?.isTakenToday, true);
      expect(homeData.nextVisit?.id, 1);
      expect(homeData.nextVisit?.formattedTime, '09:00');
    });
  });
}
