import 'dart:developer';
import 'dart:io';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

class AlarmService {
  static const String _lastMedicationTimeKey = 'last_medication_time';

  /// SET TRUE UNTUK TES VISIT 1 MENIT
  // ignore: constant_identifier_names
  static const bool DEBUG_VISIT_1_MINUTE = false;

  /// ================= INIT =================
  static Future<void> initialize() async {
    if (!await _isPatientUser()) {
      log('AlarmService init diblok (bukan pasien)');
      return;
    }

    await _checkPermissions();
    await _initNotificationChannels();
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: true);
  }

  /// ================= PUBLIC API =================
  static Future<void> handleTreatment({
    required String status,
    required String? medicationTime,
    required List<dynamic>? visits,
  }) async {
    if (!await _isPatientUser()) {
      log('⛔ handleTreatment diblok (bukan pasien)');
      return;
    }

    if (status == 'Selesai') {
      await stopAllMedicationAlarm();
      return;
    }

    if (status == 'Berjalan' && medicationTime != null) {
      await _rescheduleMedicationIfNeeded(medicationTime);
    }

    if (visits != null && visits.isNotEmpty) {
      await scheduleVisitNotifications(visits);
    }
  }

  static Future<bool> _isPatientUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userType = prefs.getInt('user_type_id');
    return userType == 2; // 2 = PASIEN
  }

  /// ================= STOP =================
  static Future<void> stopAllMedicationAlarm() async {
    await AndroidAlarmManager.cancel(0);
    await Workmanager().cancelByTag('daily_medication');

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastMedicationTimeKey);

    log('Semua alarm obat dihentikan');
  }

  /// ================= MEDICATION =================
  static Future<void> _rescheduleMedicationIfNeeded(String apiTime) async {
    final prefs = await SharedPreferences.getInstance();
    final lastTime = prefs.getString(_lastMedicationTimeKey);

    if (lastTime == apiTime) {
      log('Alarm obat tidak berubah ($apiTime)');
      return;
    }

    log('Reschedule alarm obat → $apiTime');

    await AndroidAlarmManager.cancel(0);
    await Workmanager().cancelByTag('daily_medication');

    await _scheduleMedicationFromApi(apiTime);
    await prefs.setString(_lastMedicationTimeKey, apiTime);
  }

  static Future<void> _scheduleMedicationFromApi(String time) async {
    final parts = time.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    if (await _canScheduleExactAlarms()) {
      await _scheduleExactDailyMedication(hour, minute);
    }

    await _scheduleMedicationBackup(hour, minute);
  }

  static Future<void> _scheduleExactDailyMedication(
    int hour,
    int minute,
  ) async {
    final now = DateTime.now();
    var scheduled = DateTime(now.year, now.month, now.day, hour, minute);

    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await AndroidAlarmManager.oneShotAt(
      scheduled,
      0,
      medicationAlarmCallback,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
    );

    log('Alarm obat diset: $scheduled');
  }

  static Future<void> _scheduleMedicationBackup(int hour, int minute) async {
    final now = DateTime.now();
    var scheduled = DateTime(now.year, now.month, now.day, hour, minute);

    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await Workmanager().registerOneOffTask(
      'daily_medication_${scheduled.millisecondsSinceEpoch}',
      'daily_medication',
      initialDelay: scheduled.difference(now),
      inputData: {'scheduled_time': scheduled.toString()},
      tag: 'daily_medication',
    );

    log('Backup WorkManager obat: $scheduled');
  }

  /// ================= VISIT =================
  static Future<void> scheduleVisitNotifications(List<dynamic> visits) async {
    if (!await _isPatientUser()) {
      log('Visit alarm diblok (bukan pasien)');
      return;
    }

    for (final visit in visits) {
      try {
        DateTime reminderTime;

        if (DEBUG_VISIT_1_MINUTE) {
          reminderTime = DateTime.now().add(const Duration(minutes: 1));
          log('DEBUG VISIT → 1 menit');
        } else {
          final visitDate = DateTime.parse(visit['visit_date']);
          final timeParts = visit['visit_time'].split(':');

          final scheduled = DateTime(
            visitDate.year,
            visitDate.month,
            visitDate.day,
            int.parse(timeParts[0]),
            int.parse(timeParts[1]),
          );

          reminderTime = scheduled.subtract(const Duration(hours: 1));
        }

        if (reminderTime.isBefore(DateTime.now())) {
          log('Visit dilewati (waktu lewat)');
          continue;
        }

        await AndroidAlarmManager.oneShotAt(
          reminderTime,
          visit['id'],
          visitAlarmCallback,
          exact: true,
          wakeup: true,
          rescheduleOnReboot: true,
        );

        log('Alarm kunjungan diset: $reminderTime');
      } catch (e) {
        log('Error visit alarm: $e');
      }
    }
  }

  /// ================= PERMISSION =================
  static Future<bool> _canScheduleExactAlarms() async {
    if (!Platform.isAndroid) return true;

    final info = await DeviceInfoPlugin().androidInfo;
    if (info.version.sdkInt >= 31) {
      return Permission.scheduleExactAlarm.isGranted;
    }
    return true;
  }

  static Future<void> _checkPermissions() async {
    await Permission.notification.request();
    if (Platform.isAndroid) {
      await Permission.scheduleExactAlarm.request();
    }
  }

  /// ================= CHANNEL =================
  static Future<void> _initNotificationChannels() async {
    final plugin = FlutterLocalNotificationsPlugin();

    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );

    final android =
        plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    const alarmChannel = AndroidNotificationChannel(
      'alarm_channel',
      'Alarm TB Care',
      importance: Importance.max,
      sound: RawResourceAndroidNotificationSound('alarm_tb_care2'),
      playSound: true,
      enableVibration: true,
    );

    await android?.createNotificationChannel(alarmChannel);
  }
}

/// ================= CALLBACK OBAT =================
@pragma('vm:entry-point')
void medicationAlarmCallback() async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getInt('user_type_id') != 2) return;

  final notifications = FlutterLocalNotificationsPlugin();

  await notifications.show(
    0,
    'Reminder Pengobatan',
    'Saatnya minum obat! Jangan lupa ya!',
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'alarm_channel',
        'Alarm TB Care',
        importance: Importance.max,
        priority: Priority.high,
        sound: RawResourceAndroidNotificationSound('alarm_tb_care2'),
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
      ),
    ),
  );
}

/// ================= CALLBACK VISIT =================
@pragma('vm:entry-point')
void visitAlarmCallback() async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getInt('user_type_id') != 2) return;
  
  final notifications = FlutterLocalNotificationsPlugin();

  await notifications.show(
    999,
    'Kunjungan Pengobatan',
    'Anda memiliki jadwal kunjungan pengobatan',
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'alarm_channel',
        'Alarm TB Care',
        importance: Importance.max,
        priority: Priority.high,
        sound: RawResourceAndroidNotificationSound('alarm_tb_care2'),
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
      ),
    ),
  );
}

/// ================= WORKMANAGER BACKUP =================
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == 'daily_medication') {
      medicationAlarmCallback();
    }
    return true;
  });
}
