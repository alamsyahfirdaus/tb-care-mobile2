import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:apk_tb_care/main/pasien/history.dart';
import 'package:apk_tb_care/main/pasien/treatment_history.dart';
import 'package:apk_tb_care/connection.dart';
import 'package:apk_tb_care/values/colors.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:image_picker/image_picker.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider/path_provider.dart';
// ignore: depend_on_referenced_packages
import 'package:http_parser/http_parser.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:workmanager/workmanager.dart';

// Notification callback for alarm manager
// @pragma('vm:entry-point')
// void notificationCallback() async {
//   try {
//     final prefs = await SharedPreferences.getInstance();
//     prefs.setInt('lastNotificationTime', DateTime.now().millisecondsSinceEpoch);

//     final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
//         FlutterLocalNotificationsPlugin();

//     await flutterLocalNotificationsPlugin.initialize(
//       const InitializationSettings(
//         android: AndroidInitializationSettings('@mipmap/ic_launcher'),
//       ),
//     );

//     await flutterLocalNotificationsPlugin.show(
//       0,
//       'Reminder Pengobatan',
//       'Saatnya minum obat! Jangan lupa ya!',
//       const NotificationDetails(
//         android: AndroidNotificationDetails(
//           'reminder_channel',
//           'Pengingat Harian',
//           channelDescription:
//               'Channel untuk pengingat harian seperti minum obat',
//           importance: Importance.high,
//           priority: Priority.high,
//           playSound: true,
//           enableVibration: true,
//           sound: UriAndroidNotificationSound(
//             'content://settings/system/notification_sound',
//           ),
//           color: Colors.green,
//           ledColor: Colors.green,
//           ledOnMs: 1000,
//           ledOffMs: 500,
//         ),
//       ),
//     );
//     log('Daily notification shown at ${DateTime.now()}');
//   } catch (e) {
//     log('Error showing notification: $e');
//   }
// }

@pragma('vm:entry-point')
void notificationCallback() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt('lastNotificationTime', DateTime.now().millisecondsSinceEpoch);

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );

    // await flutterLocalNotificationsPlugin.show(
    //   0,
    //   'Reminder Pengobatan',
    //   'Saatnya minum obat! Jangan lupa ya!',
    //   const NotificationDetails(
    //     android: AndroidNotificationDetails(
    //       'reminder_channel_v2', // GANTI CHANNEL ID
    //       'Pengingat Harian',
    //       channelDescription: 'Pengingat minum obat harian',
    //       importance: Importance.max, // WAJIB
    //       priority: Priority.high,
    //       playSound: true,
    //       enableVibration: true,
    //       visibility: NotificationVisibility.public,
    //       category: AndroidNotificationCategory.alarm, // 🔥 WAJIB
    //     ),
    //   ),
    // );

    await flutterLocalNotificationsPlugin.show(
      0,
      'Reminder Pengobatan',
      'Saatnya minum obat! Jangan lupa ya!',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'reminder_channel_alarm', // 🔥 SAMA
          'Alarm Minum Obat',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          sound: RawResourceAndroidNotificationSound('alarm_tb_care2'),
          category: AndroidNotificationCategory.alarm,
          visibility: NotificationVisibility.public,
        ),
      ),
    );

    log('Daily alarm notification shown');
  } catch (e) {
    log('Error showing notification: $e');
  }
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final notifications = FlutterLocalNotificationsPlugin();

    await notifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );

    // =========================================================
    // 🔔 ALARM MINUM OBAT (DAILY MEDICATION)
    // =========================================================
    if (task == 'daily_medication') {
      final scheduledTime =
          DateTime.parse(
            inputData?['scheduled_time'] ?? DateTime.now().toString(),
          ).toLocal();

      final now = DateTime.now().toLocal();
      final diff = now.difference(scheduledTime).inMinutes;

      // ⏱ Toleransi 10 menit
      if (diff >= 0 && diff <= 10) {
        final prefs = await SharedPreferences.getInstance();
        final lastShown = prefs.getString('last_shown_date');
        final today = DateFormat('yyyy-MM-dd').format(now);

        if (lastShown != today) {
          await notifications.show(
            0,
            'Reminder Pengobatan',
            'Saatnya minum obat! Jangan lupa ya!',
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'reminder_channel_alarm',
                'Alarm Minum Obat',
                importance: Importance.max,
                priority: Priority.high,
                playSound: true,
                enableVibration: true,
                sound: RawResourceAndroidNotificationSound('alarm_tb_care2'),
                category: AndroidNotificationCategory.alarm,
                visibility: NotificationVisibility.public,
              ),
            ),
          );

          await prefs.setString('last_shown_date', today);
        }
      }

      // 🔁 RESCHEDULE UNTUK BESOK
      final nextTime = DateTime(
        now.year,
        now.month,
        now.day,
        inputData?['hour'] ?? 12,
        inputData?['minute'] ?? 0,
      ).add(const Duration(days: 1));

      await Workmanager().registerOneOffTask(
        'daily_medication_${nextTime.millisecondsSinceEpoch}',
        'daily_medication',
        initialDelay: nextTime.difference(now),
        constraints: Constraints(networkType: NetworkType.notRequired),
        inputData: {
          'hour': inputData?['hour'] ?? 12,
          'minute': inputData?['minute'] ?? 0,
          'scheduled_time': nextTime.toString(),
        },
        tag: 'daily_medication',
      );
    }

    // =========================================================
    // 📅 PENGINGAT JADWAL KUNJUNGAN
    // =========================================================
    if (task == 'visit_reminder') {
      await notifications.show(
        inputData?['visit_id'] ?? 1001,
        inputData?['title'] ?? 'Pengingat Kunjungan',
        inputData?['message'] ?? 'Anda memiliki jadwal kunjungan pengobatan',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'visit_channel',
            'Pengingat Kunjungan',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          ),
        ),
      );
    }

    return Future.value(true);
  });
}

class TreatmentPage extends StatefulWidget {
  final int patientId;

  const TreatmentPage({super.key, required this.patientId});

  @override
  State<TreatmentPage> createState() => _TreatmentPageState();
}

class _TreatmentPageState extends State<TreatmentPage> {
  late Future<Map<String, dynamic>> _patientFuture;
  late Map<String, dynamic> _patientData;
  List<dynamic> _treatments = [];
  Map<String, dynamic>? _currentTreatment;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  // ignore: unused_field
  bool _notifIsActive = false;
  bool _uploadedToday = false;
  bool _isUploading = false;

  static const String _lastMedicationTimeKey = 'last_medication_time';
  static const String _lastTreatmentStatusKey = 'last_treatment_status';

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (await _isPatientUser()) {
        await _initializeBackgroundTasks();
      } else {
        // 🔥 PENTING: pastikan alarm benar-benar mati
        await AndroidAlarmManager.cancel(0);
        await Workmanager().cancelByTag('daily_medication');
        await Workmanager().cancelAll();
      }
    });
    _patientFuture = _fetchPatientData();
  }

  Future<void> _initializeBackgroundTasks() async {
    await _checkPermissions();
    await _disableBatteryOptimization();
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: true);
    await _initNotifications();
    _checkMissedNotifications();
    // _getSharedPreferences();
  }

  Future<bool> _isPatientUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userType = prefs.getInt('user_type_id');
    return userType == 2; // 2 = PASIEN
  }

  bool _alreadyUploadedToday(List<dynamic> history) {
    if (history.isEmpty) return false;

    final latest = history.first;
    final submittedAt = DateTime.parse(latest['submitted_at']);
    final today = DateTime.now();

    return submittedAt.year == today.year &&
        submittedAt.month == today.month &&
        submittedAt.day == today.day;
  }

  Future<void> _refreshTreatmentPage() async {
    setState(() {
      _patientFuture = _fetchPatientData();
    });

    // Optional delay biar animasi halus
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> _disableBatteryOptimization() async {
    try {
      if (await Permission.ignoreBatteryOptimizations.isDenied) {
        await Permission.ignoreBatteryOptimizations.request();
      }
    } catch (e) {
      debugPrint('Error disabling battery optimization: $e');
    }
  }

  Future<void> _rescheduleAlarmIfNeeded(String apiTime) async {
    final prefs = await SharedPreferences.getInstance();
    final lastTime = prefs.getString(_lastMedicationTimeKey);

    // ⏱ Pertama kali set alarm
    if (lastTime == null) {
      debugPrint('🆕 First alarm set from API: $apiTime');
      await _scheduleFromApiTime(apiTime);
      await prefs.setString(_lastMedicationTimeKey, apiTime);
      return;
    }

    // 🔁 Jika jam API berubah → reschedule
    if (lastTime != apiTime) {
      debugPrint('🔁 Alarm time changed: $lastTime → $apiTime');

      // ❌ HAPUS ALARM LAMA
      await AndroidAlarmManager.cancel(0);
      await Workmanager().cancelByTag('daily_medication');

      // 🔄 SET ALARM BARU
      await _scheduleFromApiTime(apiTime);

      // 💾 SIMPAN JAM BARU
      await prefs.setString(_lastMedicationTimeKey, apiTime);
    } else {
      debugPrint('✅ Alarm time unchanged ($apiTime)');
    }
  }

  Future<void> _scheduleFromApiTime(String timeString) async {
    final parts = timeString.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    debugPrint('⏰ Scheduling alarm at $hour:$minute');

    if (await _canScheduleExactAlarms()) {
      await _scheduleExactDailyReminder(hour, minute);
    }

    // 🔁 BACKUP
    await _scheduleWorkManagerBackup(hour, minute);
  }

  Future<void> _checkMissedNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final lastNotificationTime = prefs.getInt('lastNotificationTime');
    final now = DateTime.now().millisecondsSinceEpoch;

    if (lastNotificationTime != null) {
      final diffHours = (now - lastNotificationTime) / (1000 * 60 * 60);
      if (diffHours > 26) {
        _showMissedNotificationWarning();
      }
    }
    prefs.setInt('lastNotificationTime', now);
  }

  void _showMissedNotificationWarning() {
    if (!mounted) return;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Pengingat Terlewat'),
            content: const Text(
              'Sepertinya Anda melewatkan waktu minum obat. Apakah Anda sudah minum obat?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Nanti'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showUploadDialog();
                },
                child: const Text('Sudah Minum'),
              ),
            ],
          ),
    );
  }

  Future<void> _checkPermissions() async {
    final status = await Permission.notification.status;
    if (!status.isGranted) {
      await Permission.notification.request();
    }

    if (await Permission.scheduleExactAlarm.isDenied) {
      await Permission.scheduleExactAlarm.request();
    }
  }

  // ignore: unused_element
  Future<void> _getSharedPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _notifIsActive = prefs.getBool('notifIsActive') ?? false;
    });
  }

  Future<void> _initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    await flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(android: initializationSettingsAndroid),
    );

    // const AndroidNotificationChannel medicationChannel =
    //     AndroidNotificationChannel(
    //       'reminder_channel',
    //       'Pengingat Harian',
    //       description: 'Channel untuk pengingat harian seperti minum obat',
    //       importance: Importance.high,
    //       playSound: true,
    //       enableVibration: true,
    //       sound: RawResourceAndroidNotificationSound('notification'),
    //     );

    // const AndroidNotificationChannel medicationChannel =
    //     AndroidNotificationChannel(
    //       'reminder_channel_v2', //  GANTI ID
    //       'Pengingat Harian',
    //       description: 'Pengingat minum obat harian',
    //       importance: Importance.max, // WAJIB
    //       playSound: true,
    //       enableVibration: true,
    //     );

    const AndroidNotificationChannel medicationChannel =
        AndroidNotificationChannel(
          'reminder_channel_alarm', // GANTI ID (WAJIB BARU)
          'Alarm Minum Obat',
          description: 'Alarm khusus pengingat minum obat',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          sound: RawResourceAndroidNotificationSound(
            'alarm_tb_care2',
          ), // SUARA KHUSUS
        );

    const AndroidNotificationChannel visitChannel = AndroidNotificationChannel(
      'visit_channel',
      'Pengingat Kunjungan',
      description: 'Channel untuk pengingat kunjungan pengobatan',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      sound: RawResourceAndroidNotificationSound('notification'),
    );

    final androidPlatform =
        flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    await androidPlatform?.createNotificationChannel(medicationChannel);
    await androidPlatform?.createNotificationChannel(visitChannel);
  }

  // ignore: unused_element
  Future<void> _setNotificationStatus(bool status, int hour, int minute) async {
    final prefs = await SharedPreferences.getInstance();

    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    if (await Permission.scheduleExactAlarm.isDenied) {
      await Permission.scheduleExactAlarm.request();
    }

    setState(() {
      _notifIsActive = status;
      prefs.setBool('notifIsActive', status);
    });

    if (status) {
      if (await _canScheduleExactAlarms()) {
        await _scheduleExactDailyReminder(hour, minute);
      }
      await _scheduleWorkManagerBackup(hour, minute);
    } else {
      await AndroidAlarmManager.cancel(0);
      await Workmanager().cancelByTag('daily_medication');
    }
  }

  Future<bool> _canScheduleExactAlarms() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 31) {
        return await Permission.scheduleExactAlarm.isGranted;
      }
    }
    return true;
  }

  Future<void> _scheduleExactDailyReminder(int hour, int minute) async {
    try {
      await AndroidAlarmManager.cancel(0);
      await Workmanager().cancelByTag('daily_medication');

      // Get current time in local timezone
      final now = DateTime.now().toLocal();

      // Create scheduled time in local timezone
      var scheduledTime =
          DateTime(now.year, now.month, now.day, hour, minute).toLocal();

      if (scheduledTime.isBefore(now)) {
        scheduledTime = scheduledTime.add(const Duration(days: 1));
      }

      debugPrint(
        '⏰ Scheduling exact reminder for: $scheduledTime (Local time)',
      );

      await AndroidAlarmManager.oneShotAt(
        scheduledTime,
        0,
        notificationCallback,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
      );
    } catch (e) {
      debugPrint('❌ Error scheduling exact reminder: $e');
      await _scheduleWorkManagerBackup(hour, minute);
    }
  }

  Future<void> _scheduleWorkManagerBackup(int hour, int minute) async {
    try {
      await Workmanager().cancelByTag('daily_medication');

      final now = DateTime.now().toLocal();
      var scheduledTime =
          DateTime(now.year, now.month, now.day, hour, minute).toLocal();

      if (scheduledTime.isBefore(now)) {
        scheduledTime = scheduledTime.add(const Duration(days: 1));
      }

      final initialDelay = scheduledTime.difference(now);

      debugPrint(
        '📆 Scheduling WorkManager backup for: $scheduledTime (Local time)',
      );

      await Workmanager().registerOneOffTask(
        'daily_medication_${scheduledTime.millisecondsSinceEpoch}',
        'daily_medication',
        initialDelay: initialDelay,
        constraints: Constraints(networkType: NetworkType.notRequired),
        inputData: {
          'hour': hour,
          'minute': minute,
          'scheduled_time': scheduledTime.toString(),
        },
        tag: 'daily_medication',
      );
    } catch (e) {
      debugPrint('❌ Error scheduling WorkManager backup: $e');
    }
  }

  Future<void> _scheduleVisitNotifications(List<dynamic> visits) async {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: true);

    for (final visit in visits) {
      try {
        final visitDate = DateTime.parse(visit['visit_date']);
        final timeParts = visit['visit_time'].split(':');
        final hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);

        final scheduledTime =
            DateTime(
              visitDate.year,
              visitDate.month,
              visitDate.day,
              hour,
              minute,
            ).toLocal();

        final reminderTime = scheduledTime.subtract(const Duration(hours: 1));
        final initialDelay = reminderTime.difference(DateTime.now());

        if (initialDelay.isNegative) continue;

        await Workmanager().registerOneOffTask(
          'visit_${visit['id']}',
          'visit_reminder',
          inputData: {
            'visit_id': visit['id'],
            'title': 'Kunjungan Pengobatan',
            'message': 'Anda memiliki jadwal kunjungan dalam 1 jam',
          },
          initialDelay: initialDelay,
          constraints: Constraints(networkType: NetworkType.notRequired),
          existingWorkPolicy: ExistingWorkPolicy.replace,
        );

        debugPrint(
          'Scheduled visit reminder for ${visit['id']} at $reminderTime',
        );
      } catch (e) {
        debugPrint('Error scheduling visit ${visit['id']}: $e');
      }
    }
  }

  Future<Map<String, dynamic>> _fetchPatientData() async {
    final session = await SharedPreferences.getInstance();
    final token = session.getString('token') ?? '';

    try {
      final response = await http.get(
        Uri.parse('${Connection.BASE_URL}/patients/${widget.patientId}/show'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to load patient data');
      }

      final Map<String, dynamic> data = jsonDecode(response.body);

      // ================== STATE ==================
      setState(() {
        _patientData = data['data'];
        _treatments = data['data']['treatments'] ?? [];
        _currentTreatment = _treatments.isNotEmpty ? _treatments.first : null;
      });

      if (_currentTreatment == null) {
        return data['data'];
      }

      final treatmentStatus = _currentTreatment!['treatment_status'];
      final medicationTime = _currentTreatment!['medication_time'];

      final isPatient = await _isPatientUser();

      if (!isPatient) {
        debugPrint('Bukan pasien → alarm dilewati');
        return data['data'];
      }

      // ================== AUTO STOP / AUTO SET ALARM ==================
      if (treatmentStatus == 'Selesai') {
        await AndroidAlarmManager.cancel(0);
        await Workmanager().cancelByTag('daily_medication');

        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_lastMedicationTimeKey);
        await prefs.setString(_lastTreatmentStatusKey, 'Selesai');
      } else if (treatmentStatus == 'Berjalan' && medicationTime != null) {
        await _rescheduleAlarmIfNeeded(medicationTime);
      }

      // ================== JADWAL KUNJUNGAN ==================
      if (_currentTreatment!['visits'] != null) {
        await _scheduleVisitNotifications(_currentTreatment!['visits']);
      }

      _checkTodayUpload();
      return data['data'];
    } catch (e) {
      log('Error fetching patient data: $e');
      return {};
    }
  }

  Future<void> _checkTodayUpload() async {
    final session = await SharedPreferences.getInstance();
    final token = session.getString('token') ?? '';

    final response = await http.get(
      Uri.parse(
        '${Connection.BASE_URL}/treatments/${widget.patientId}/history?per_page=1',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final history = data['data'] as List<dynamic>;

      setState(() {
        _uploadedToday = _alreadyUploadedToday(history);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengobatan Saya'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (builder) =>
                            MedicationHistoryPage(patientId: widget.patientId),
                  ),
                ),
          ),
          // IconButton(
          //   icon: const Icon(Icons.alarm),
          //   onPressed: _testAlarmOneMinute,
          // ),
          // IconButton(
          //   icon: const Icon(Icons.bug_report),
          //   onPressed: _testAlarmFromApiTime,
          // ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshTreatmentPage,
        color: AppColors.primary,
        child: FutureBuilder<Map<String, dynamic>>(
          future: _patientFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else if (!snapshot.hasData || _currentTreatment == null) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Center(child: Text('Tidak ada data pengobatan')),
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusCard(_currentTreatment!),
                  const SizedBox(height: 24),
                  _buildRegimenDetails(_currentTreatment!),
                  const SizedBox(height: 24),
                  if (_currentTreatment!['medication_time'] != null)
                    _buildMedicationReminder(_currentTreatment!),
                  const SizedBox(height: 24),
                  if (_currentTreatment!['prescription'] != null &&
                      _currentTreatment!['prescription'].isNotEmpty)
                    _buildDrugList(_currentTreatment!['prescription']),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDrugCard(String drug) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.medication, color: Colors.blue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    drug,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(Map<String, dynamic> treatmentData) {
    final currentDay = _calculateCurrentDay(
      treatmentData['start_date'],
      treatmentData['end_date'],
    );
    final totalDays = _calculateTotalDays(
      treatmentData['start_date'],
      treatmentData['end_date'],
    );
    final progress = currentDay / totalDays;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.medical_services, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Status Pengobatan',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.history),
                  onPressed:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (builder) => TreatmentHistoryPage(
                                patientId: widget.patientId,
                                patientName: _patientData['name'] ?? 'Pasien',
                              ),
                        ),
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "Pengobatan TB",
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[200],
              color: Colors.green,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hari ke-$currentDay dari $totalDays',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    Text(
                      '${treatmentData['start_date'] ?? 'Tanggal mulai'} - ${treatmentData['end_date'] ?? 'Tanggal selesai'}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(
                      treatmentData['treatment_status'],
                      true,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getStatusColor(
                        treatmentData['treatment_status'],
                        false,
                      ),
                    ),
                  ),
                  child: Text(
                    treatmentData['treatment_status'] ??
                        'Status tidak tersedia',
                    style: TextStyle(
                      color: _getStatusTextColor(
                        treatmentData['treatment_status'],
                      ),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  int _calculateCurrentDay(String? startDate, String? endDate) {
    if (startDate == null || endDate == null) return 0;

    try {
      final start = DateTime.parse(startDate);
      final end = DateTime.parse(endDate);
      final today = DateTime.now();

      if (today.isBefore(start)) return 0;
      if (today.isAfter(end)) return end.difference(start).inDays;

      return today.difference(start).inDays;
    } catch (e) {
      return 0;
    }
  }

  int _calculateTotalDays(String? startDate, String? endDate) {
    if (startDate == null || endDate == null) return 1;

    try {
      final start = DateTime.parse(startDate);
      final end = DateTime.parse(endDate);
      return end.difference(start).inDays;
    } catch (e) {
      return 1;
    }
  }

  Color _getStatusColor(String? status, bool isBackground) {
    switch (status) {
      case 'Berjalan':
        return isBackground ? Colors.green[50]! : Colors.green;
      case 'Selesai':
        return isBackground ? Colors.blue[50]! : Colors.blue;
      default:
        return isBackground ? Colors.grey[200]! : Colors.grey;
    }
  }

  Color _getStatusTextColor(String? status) {
    switch (status) {
      case 'Berjalan':
        return Colors.green[800]!;
      case 'Selesai':
        return Colors.blue[800]!;
      default:
        return Colors.grey[800]!;
    }
  }

  Widget _buildRegimenDetails(Map<String, dynamic> treatment) {
    final duration = _calculateDuration(
      DateTime.parse(treatment['start_date']),
      DateTime.parse(treatment['end_date']),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Detail Regimen",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildDetailRow(
          "Tanggal Mulai",
          _formatDate(DateTime.parse(treatment['start_date'])),
        ),
        _buildDetailRow(
          "Tanggal Selesai",
          _formatDate(DateTime.parse(treatment['end_date'])),
        ),
        _buildDetailRow("Durasi", duration),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildMedicationReminder(Map<String, dynamic> treatment) {
    final timeString = treatment['medication_time'] as String; // e.g. "08:30"
    final timeParts = timeString.split(':');
    final medicationTime = TimeOfDay(
      hour: int.parse(timeParts[0]),
      minute: int.parse(timeParts[1]),
    );

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.notifications_active, color: Colors.orange),
                const SizedBox(width: 12),
                const Text(
                  "Pengingat Obat",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              "Minum obat berikutnya:",
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              _getNextMedicationTime(medicationTime),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _showUploadDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isUploading) ...[
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'MENGUNGGAH...',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ] else ...[
                      const Icon(Icons.medical_services, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        _uploadedToday
                            ? 'UPLOAD ULANG FOTO'
                            : 'SUDAH MINUM OBAT',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUploadDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Konfirmasi Minum Obat'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Apakah Anda sudah minum obat hari ini?'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Nanti'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _showUploadOptions();
                      },
                      child: const Text('Konfirmasi'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDrugList(List<dynamic> prescription) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Daftar Obat",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        // ignore: unnecessary_to_list_in_spreads
        ...prescription.map((drug) => _buildDrugCard(drug)).toList(),
      ],
    );
  }

  String _calculateDuration(DateTime startDate, DateTime endDate) {
    final months =
        (endDate.year - startDate.year) * 12 +
        (endDate.month - startDate.month);
    return '$months Bulan';
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd MMMM yyyy').format(date);
  }

  String _getNextMedicationTime(TimeOfDay medicationTime) {
    return 'Setiap hari, ${medicationTime.hour}:${medicationTime.minute.toString().padLeft(2, '0')} WIB';
  }

  // void _toggleReminder(bool value, int hour, int minute) async {
  //   try {
  //     // await _setNotificationStatus(value, hour, minute);

  //     // Debug print to verify the time being set
  //     debugPrint('Setting reminder for: $hour:$minute');

  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text(
  //           "Pengingat ${value ? 'diaktifkan' : 'dinonaktifkan'} untuk $hour:$minute",
  //         ),
  //       ),
  //     );
  //   } catch (e) {
  //     debugPrint('Error toggling reminder: $e');
  //     ScaffoldMessenger.of(
  //       context,
  //     ).showSnackBar(const SnackBar(content: Text("Gagal mengubah pengingat")));
  //   }
  // }

  void _showUploadOptions() {
    // ignore: no_leading_underscores_for_local_identifiers
    final ImagePicker _picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      builder:
          (context) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Upload Bukti Minum Obat',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Icon(Icons.camera_alt, color: AppColors.primary),
                  title: const Text('Ambil Foto'),
                  onTap: () async {
                    Navigator.pop(context);
                    final XFile? photo = await _picker.pickImage(
                      source: ImageSource.camera,
                    );
                    if (photo != null) {
                      _handleSelectedImage(File(photo.path));
                    }
                  },
                ),
                ListTile(
                  leading: Icon(Icons.photo_library, color: AppColors.primary),
                  title: const Text('Pilih dari Galeri'),
                  onTap: () async {
                    Navigator.pop(context);
                    final XFile? image = await _picker.pickImage(
                      source: ImageSource.gallery,
                    );
                    if (image != null) {
                      _handleSelectedImage(File(image.path));
                    }
                  },
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Konfirmasi obat berhasil dicatat'),
                      ),
                    );
                  },
                  child: const Text('Tanpa Foto'),
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _uploadImage(File imageFile, String patientTreatmentId) async {
    final uri = Uri.parse('${Connection.BASE_URL}/treatments/proof');

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    final request = http.MultipartRequest('POST', uri);

    request.headers.addAll({
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    });

    request.fields['patient_treatment_id'] = patientTreatmentId;

    // 🔥 FIX UTAMA: FORCE JPEG
    final bytes = await imageFile.readAsBytes();

    request.files.add(
      http.MultipartFile.fromBytes(
        'photo',
        bytes,
        filename: 'bukti_${DateTime.now().millisecondsSinceEpoch}.jpg',
        contentType: MediaType('image', 'jpeg'),
      ),
    );

    try {
      final response = await request.send();
      final body = await response.stream.bytesToString();

      debugPrint('UPLOAD STATUS: ${response.statusCode}');
      debugPrint('UPLOAD BODY: $body');

      if (response.statusCode == 201) {
        setState(() {
          _uploadedToday = true;
        });

        ScaffoldMessenger.of(
          // ignore: use_build_context_synchronously
          context,
        ).showSnackBar(const SnackBar(content: Text('Foto berhasil diunggah')));
      } else {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload gagal (${response.statusCode})')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        // ignore: use_build_context_synchronously
        context,
      ).showSnackBar(SnackBar(content: Text('Terjadi error: $e')));
    }
  }

  void _handleSelectedImage(File imageFile) async {
    if (_currentTreatment == null) return;

    setState(() {
      _isUploading = true; // 🔄 START LOADING
    });

    try {
      final bytes = await imageFile.readAsBytes();
      final decodedImage = img.decodeImage(bytes);

      if (decodedImage == null) {
        throw Exception('Gagal memproses gambar');
      }

      final jpegBytes = img.encodeJpg(decodedImage, quality: 85);
      final tempDir = await getTemporaryDirectory();

      final fixedFile = File(
        '${tempDir.path}/upload_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      await fixedFile.writeAsBytes(jpegBytes);

      await _uploadImage(fixedFile, _currentTreatment!['id'].toString());

      // 🔁 refresh data agar sinkron
      await _refreshTreatmentPage();
    } catch (e) {
      ScaffoldMessenger.of(
        // ignore: use_build_context_synchronously
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal upload: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false; // ✅ STOP LOADING
        });
      }
    }
  }
}
