import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:intl/intl.dart';

class AlarmService {
  static const String _lastMedicationTimeKey = 'last_medication_time';
  static const String _visitReminderEnabledKey = 'visit_reminder_enabled';
  static const String _visitReminderOffsetKey = 'visit_reminder_offset_minutes';
  static const String _nextVisitAlarmInfoKey = 'next_visit_alarm_info';

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
    // ignore: deprecated_member_use
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: true);
  }

  /// ================= PUBLIC API =================
  static Future<void> handleTreatment({
    required String status,
    required String? medicationTime,
    required List<dynamic>? visits,
    String puskesmasName = 'Puskesmas',
  }) async {
    log('[ALARM] User type: Pasien');
    log('[ALARM] Treatment status: $status');
    log('[ALARM] medication_time: $medicationTime');

    if (!await _isPatientUser()) {
      log('handleTreatment diblok (bukan pasien)');
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
      await scheduleVisitNotifications(visits, puskesmasName: puskesmasName);
    }
  }

  static Future<void> setMedicationReminder(
    String time, {
    bool force = false,
  }) async {
    log('[ALARM] setMedicationReminder: $time (force: $force)');
    if (!await _isPatientUser()) {
      log('setMedicationReminder diblok (bukan pasien)');
      return;
    }

    if (force) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastMedicationTimeKey);
    }

    await _rescheduleMedicationIfNeeded(time);
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

    log('[ALARM] Alarm cancelled');
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
    if (parts.length < 2) {
      log('[ALARM] Error splitting time: $time');
      return;
    }
    final hour = int.tryParse(parts[0]) ?? 12;
    final minute = int.tryParse(parts[1]) ?? 0;

    log('[ALARM] Parsed hour: $hour');
    log('[ALARM] Parsed minute: $minute');

    if (await _canScheduleExactAlarms()) {
      await _scheduleExactDailyMedication(hour, minute);
    }

    await _scheduleMedicationBackup(hour, minute);
  }

  static Future<void> _scheduleExactDailyMedication(
    int hour,
    int minute,
  ) async {
    final now = DateTime.now().toLocal();
    var scheduled =
        DateTime(now.year, now.month, now.day, hour, minute).toLocal();

    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    log('[ALARM] Current time: $now');
    log('[ALARM] Scheduled time: $scheduled');

    await AndroidAlarmManager.oneShotAt(
      scheduled,
      0,
      medicationAlarmCallback,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
    );

    log('[ALARM] AndroidAlarmManager scheduled');
  }

  static Future<void> _scheduleMedicationBackup(int hour, int minute) async {
    final now = DateTime.now().toLocal();
    var scheduled =
        DateTime(now.year, now.month, now.day, hour, minute).toLocal();

    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    final initialDelay = scheduled.difference(now);

    await Workmanager().registerOneOffTask(
      'daily_medication_${scheduled.millisecondsSinceEpoch}',
      'daily_medication',
      initialDelay: initialDelay,
      constraints: Constraints(networkType: NetworkType.notRequired),
      inputData: {
        'hour': hour,
        'minute': minute,
        'scheduled_time': scheduled.toString(),
      },
      tag: 'daily_medication',
    );

    log('[ALARM] WorkManager scheduled');
  }

  /// ================= VISIT =================
  static Future<void> scheduleVisitNotifications(
    List<dynamic> visits, {
    String puskesmasName = 'Puskesmas',
    int? reminderOffsetMinutes,
    bool? isEnabled,
  }) async {
    if (!await _isPatientUser()) {
      log('Visit alarm diblok (bukan pasien)');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final enabled =
        isEnabled ?? (prefs.getBool(_visitReminderEnabledKey) ?? true);
    final offsetMinutes =
        reminderOffsetMinutes ?? (prefs.getInt(_visitReminderOffsetKey) ?? 60);

    await prefs.setBool(_visitReminderEnabledKey, enabled);
    await prefs.setInt(_visitReminderOffsetKey, offsetMinutes);

    // Cancel previously registered visit alarms for these visits
    for (final visit in visits) {
      if (visit is Map && visit['id'] != null) {
        final vId =
            visit['id'] is int
                ? visit['id'] as int
                : int.tryParse(visit['id'].toString()) ?? 0;
        if (vId > 0) {
          await AndroidAlarmManager.cancel(vId);
          await Workmanager().cancelByUniqueName('visit_$vId');
        }
      }
    }

    if (!enabled) {
      log('[ALARM] Pengingat kunjungan dinonaktifkan oleh pengguna');
      await prefs.remove(_nextVisitAlarmInfoKey);
      return;
    }

    // Sort visits by date & time ascending
    final sortedVisits = List<dynamic>.from(visits);
    sortedVisits.sort((a, b) {
      final dateA = a['visit_date']?.toString() ?? '';
      final dateB = b['visit_date']?.toString() ?? '';
      final cmp = dateA.compareTo(dateB);
      if (cmp != 0) return cmp;
      final timeA = a['visit_time']?.toString() ?? '';
      final timeB = b['visit_time']?.toString() ?? '';
      return timeA.compareTo(timeB);
    });

    Map<String, dynamic>? nextUpcomingVisit;

    for (final visit in sortedVisits) {
      try {
        if (visit['visit_date'] == null || visit['visit_time'] == null) {
          continue;
        }

        final status = visit['visit_status']?.toString() ?? 'Terjadwal';
        if (status != 'Terjadwal') {
          continue;
        }

        DateTime reminderTime;

        if (DEBUG_VISIT_1_MINUTE) {
          reminderTime = DateTime.now().add(const Duration(minutes: 1));
          log('DEBUG VISIT → 1 menit');
        } else {
          final visitDate = DateTime.parse(visit['visit_date'].toString());
          final timeParts = visit['visit_time'].toString().split(':');
          if (timeParts.length < 2) {
            continue;
          }

          final scheduled =
              DateTime(
                visitDate.year,
                visitDate.month,
                visitDate.day,
                int.parse(timeParts[0]),
                int.parse(timeParts[1]),
              ).toLocal();

          reminderTime = scheduled.subtract(Duration(minutes: offsetMinutes));
        }

        final initialDelay = reminderTime.difference(DateTime.now());

        if (initialDelay.isNegative) {
          log(
            'Visit alarm ${visit['id']} dilewati (waktu lewat: $reminderTime)',
          );
          continue;
        }

        final vId =
            visit['id'] is int
                ? visit['id'] as int
                : int.tryParse(visit['id'].toString()) ?? 100;
        final timeStr = visit['visit_time'].toString();
        final formattedTime =
            timeStr.length >= 5 ? timeStr.substring(0, 5) : timeStr;
        final visitPuskesmas =
            (visit['puskesmas_name'] != null &&
                    visit['puskesmas_name'].toString().isNotEmpty)
                ? visit['puskesmas_name'].toString()
                : puskesmasName;

        final notifMessage =
            'Anda memiliki jadwal kunjungan ke $visitPuskesmas pukul $formattedTime WIB hari ini.';

        if (nextUpcomingVisit == null) {
          nextUpcomingVisit = {
            'id': vId,
            'puskesmas': visitPuskesmas,
            'time': formattedTime,
            'date': visit['visit_date'].toString(),
            'message': notifMessage,
          };
          await prefs.setString(
            _nextVisitAlarmInfoKey,
            jsonEncode(nextUpcomingVisit),
          );
        }

        await AndroidAlarmManager.oneShotAt(
          reminderTime,
          vId,
          visitAlarmCallback,
          exact: true,
          wakeup: true,
          rescheduleOnReboot: true,
        );

        await Workmanager().registerOneOffTask(
          'visit_$vId',
          'visit_reminder',
          initialDelay: initialDelay,
          constraints: Constraints(networkType: NetworkType.notRequired),
          inputData: {
            'visit_id': vId,
            'title': '🏥 Jadwal Kunjungan Puskesmas',
            'message': notifMessage,
          },
          tag: 'visit_reminder',
        );

        log(
          'Alarm kunjungan diset (AlarmManager + WorkManager backup): $reminderTime (ID: $vId)',
        );
      } catch (e) {
        log('Error visit alarm: $e');
      }
    }
  }

  static Future<bool> isVisitReminderEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_visitReminderEnabledKey) ?? true;
  }

  static Future<int> getVisitReminderOffsetMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_visitReminderOffsetKey) ?? 60;
  }

  static Future<void> updateVisitReminderSettings({
    required bool isEnabled,
    required int offsetMinutes,
    required List<dynamic> visits,
    String puskesmasName = 'Puskesmas',
  }) async {
    await scheduleVisitNotifications(
      visits,
      puskesmasName: puskesmasName,
      reminderOffsetMinutes: offsetMinutes,
      isEnabled: isEnabled,
    );
  }

  static Future<void> cancelSpecificVisitAlarm(int visitId) async {
    await AndroidAlarmManager.cancel(visitId);
    await Workmanager().cancelByUniqueName('visit_$visitId');
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.cancel(visitId);
    log('[ALARM] Cancelled specific visit alarm ID: $visitId');
  }

  /// ================= PERMISSION =================
  static Future<bool> _canScheduleExactAlarms() async {
    if (!Platform.isAndroid) return true;

    final info = await DeviceInfoPlugin().androidInfo;
    final granted =
        info.version.sdkInt >= 31
            ? await Permission.scheduleExactAlarm.isGranted
            : true;
    log('[ALARM] Exact alarm permission: $granted');
    return granted;
  }

  static Future<void> _checkPermissions() async {
    final notifStatus = await Permission.notification.status;
    log('[ALARM] Notification permission: ${notifStatus.isGranted}');
    if (!notifStatus.isGranted) {
      await Permission.notification.request();
    }

    if (Platform.isAndroid) {
      final exactStatus = await Permission.scheduleExactAlarm.status;
      if (!exactStatus.isGranted) {
        await Permission.scheduleExactAlarm.request();
      }
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

    const visitChannel = AndroidNotificationChannel(
      'visit_channel',
      'Pengingat Kunjungan',
      importance: Importance.max,
      sound: RawResourceAndroidNotificationSound('alarm_tb_care2'),
      playSound: true,
      enableVibration: true,
    );

    await android?.createNotificationChannel(alarmChannel);
    await android?.createNotificationChannel(visitChannel);
  }
}

/// ================= CALLBACK OBAT =================
@pragma('vm:entry-point')
void medicationAlarmCallback() async {
  log('[ALARM] Alarm callback executed');
  try {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getInt('user_type_id') != 2) {
      log('[ALARM] User is not patient, skipping notification');
      return;
    }

    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);
    final lastShown = prefs.getString('last_shown_date');

    if (lastShown == today) {
      log('[ALARM] Notification already shown today (skipped in AlarmManager)');
      return;
    }

    await prefs.setInt('lastNotificationTime', now.millisecondsSinceEpoch);
    await prefs.setString('last_shown_date', today);

    final notifications = FlutterLocalNotificationsPlugin();
    await notifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );

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
          playSound: true,
          enableVibration: true,
          sound: RawResourceAndroidNotificationSound('alarm_tb_care2'),
          category: AndroidNotificationCategory.alarm,
          visibility: NotificationVisibility.public,
          fullScreenIntent: true,
        ),
      ),
    );

    log('[ALARM] Notification shown');
  } catch (e) {
    log('[ALARM] Error showing medication notification: $e');
  }
}

/// ================= CALLBACK VISIT =================
@pragma('vm:entry-point')
void visitAlarmCallback() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getInt('user_type_id') != 2) return;

    final isEnabled = prefs.getBool('visit_reminder_enabled') ?? true;
    if (!isEnabled) {
      log('[ALARM] Visit reminder is disabled by user preference');
      return;
    }

    String title = '🏥 Jadwal Kunjungan Puskesmas';
    String message = 'Anda memiliki jadwal kunjungan ke Puskesmas hari ini.';
    int notificationId = 100;

    final nextInfoStr = prefs.getString('next_visit_alarm_info');
    if (nextInfoStr != null && nextInfoStr.isNotEmpty) {
      try {
        final info = jsonDecode(nextInfoStr);
        if (info is Map) {
          notificationId =
              info['id'] is int
                  ? info['id'] as int
                  : int.tryParse(info['id'].toString()) ?? 100;
          if (info['message'] != null &&
              info['message'].toString().isNotEmpty) {
            message = info['message'].toString();
          } else if (info['puskesmas'] != null && info['time'] != null) {
            message =
                'Anda memiliki jadwal kunjungan ke ${info['puskesmas']} pukul ${info['time']} WIB hari ini.';
          }
        }
      } catch (e) {
        log('[ALARM] Error decoding visit info: $e');
      }
    }

    final notifications = FlutterLocalNotificationsPlugin();
    await notifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );

    await notifications.show(
      notificationId,
      title,
      message,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'visit_channel',
          'Pengingat Kunjungan',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          sound: RawResourceAndroidNotificationSound('alarm_tb_care2'),
          category: AndroidNotificationCategory.alarm,
          fullScreenIntent: true,
        ),
      ),
    );
    log('[ALARM] Visit notification shown with ID $notificationId');
  } catch (e) {
    log('[ALARM] Error showing visit notification: $e');
  }
}

/// ================= WORKMANAGER BACKUP =================
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getInt('user_type_id') != 2) {
      log('[WORKMANAGER] Task skipped: user is not patient');
      return true;
    }

    final notifications = FlutterLocalNotificationsPlugin();
    await notifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );

    if (task == 'daily_medication') {
      final scheduledTimeStr = inputData?['scheduled_time'];
      if (scheduledTimeStr == null) {
        log('[WORKMANAGER] Error: scheduled_time is null');
        return true;
      }

      final scheduledTime = DateTime.parse(scheduledTimeStr).toLocal();
      final now = DateTime.now().toLocal();
      final diff = now.difference(scheduledTime).inMinutes;

      log('[WORKMANAGER] diff minutes: $diff');

      // ⏱ Toleransi 3 jam (180 menit) untuk mengantisipasi Doze mode / keterlambatan Android OS
      if (diff >= -5 && diff <= 180) {
        final lastShown = prefs.getString('last_shown_date');
        final today = DateFormat('yyyy-MM-dd').format(now);

        if (lastShown != today) {
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
                playSound: true,
                enableVibration: true,
                sound: RawResourceAndroidNotificationSound('alarm_tb_care2'),
                category: AndroidNotificationCategory.alarm,
                visibility: NotificationVisibility.public,
                fullScreenIntent: true,
              ),
            ),
          );

          await prefs.setString('last_shown_date', today);
          await prefs.setInt(
            'lastNotificationTime',
            now.millisecondsSinceEpoch,
          );
          log('[ALARM] Notification shown');
        } else {
          log('[WORKMANAGER] Notification skipped: already shown today');
        }
      } else {
        log(
          '[WORKMANAGER] Notification skipped: outside 3-hour tolerance window',
        );
      }

      // RESCHEDULE UNTUK BESOK
      final hour = inputData?['hour'] ?? 12;
      final minute = inputData?['minute'] ?? 0;
      final nextTime = DateTime(
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      ).add(const Duration(days: 1));

      await Workmanager().registerOneOffTask(
        'daily_medication_${nextTime.millisecondsSinceEpoch}',
        'daily_medication',
        initialDelay: nextTime.difference(now),
        constraints: Constraints(networkType: NetworkType.notRequired),
        inputData: {
          'hour': hour,
          'minute': minute,
          'scheduled_time': nextTime.toString(),
        },
        tag: 'daily_medication',
      );
      log('[WORKMANAGER] Rescheduled for tomorrow at $nextTime');
    }

    if (task == 'visit_reminder') {
      final visitId = inputData?['visit_id'] ?? 100;
      final title = inputData?['title'] ?? '🏥 Jadwal Kunjungan Puskesmas';
      final message =
          inputData?['message'] ?? 'Anda memiliki jadwal kunjungan ke Puskesmas hari ini.';

      await notifications.show(
        visitId,
        title,
        message,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'visit_channel',
            'Pengingat Kunjungan',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            sound: RawResourceAndroidNotificationSound('alarm_tb_care2'),
          ),
        ),
      );
      log('[WORKMANAGER] Visit reminder shown for ID: $visitId');
    }

    return true;
  });
}
