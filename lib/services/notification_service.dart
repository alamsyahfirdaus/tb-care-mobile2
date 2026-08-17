import 'dart:convert';
import 'package:apk_tb_care/connection.dart';
import 'package:apk_tb_care/main/pasien/materi_detail.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

// Global Navigator Key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling background message: ${message.messageId}");
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static int? pendingMaterialId;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // 1. Request Permission
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    // Request notification permission for Android 13+
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    // 2. Set up Background Message Handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 3. Android Notification Channel setup
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'education_channel',
      'Edukasi TB Care',
      description: 'Channel untuk notifikasi materi edukasi baru',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    // 4. Initialize Local Notifications
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          final materialId = int.tryParse(response.payload!);
          if (materialId != null) {
            routeToDetail(materialId);
          }
        }
      },
    );

    // 5. Listen to Foreground Messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint("Foreground message received: ${message.notification?.title}");

      final notification = message.notification;
      final data = message.data;

      if (notification != null) {
        final materialIdStr = data['material_id'] ?? '';
        final materialId = int.tryParse(materialIdStr);

        // Mencegah duplicate local notifications jika ID materi sama
        _showLocalNotification(
          id: materialId ?? message.hashCode,
          title: notification.title ?? 'Materi Edukasi Baru',
          body: notification.body ?? '',
          payload: materialIdStr,
        );
      }
    });

    // 6. Listen to notification taps when app is in background (but running)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint("Notification tapped from background state: ${message.data}");
      final materialIdStr = message.data['material_id'] ?? '';
      final materialId = int.tryParse(materialIdStr);
      if (materialId != null) {
        routeToDetail(materialId);
      }
    });

    // 7. Check if opened from a terminated state via a notification
    final RemoteMessage? initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      debugPrint(
        "Notification tapped from terminated state: ${initialMessage.data}",
      );
      final materialIdStr = initialMessage.data['material_id'] ?? '';
      final materialId = int.tryParse(materialIdStr);
      if (materialId != null) {
        pendingMaterialId = materialId;
      }
    }

    // 8. Listen for token refreshes
    _fcm.onTokenRefresh.listen((newToken) {
      uploadFcmToken(newToken);
    });

    _isInitialized = true;
    debugPrint("NotificationService initialized successfully.");
  }

  Future<void> getAndUploadToken() async {
    try {
      String? token = await _fcm.getToken();
      if (token != null) {
        debugPrint("FCM Device Token: $token");
        await uploadFcmToken(token);
      }
    } catch (e) {
      debugPrint("Error fetching FCM token: $e");
    }
  }

  Future<void> uploadFcmToken(String fcmToken) async {
    final prefs = await SharedPreferences.getInstance();
    final apiToken = prefs.getString('token');

    if (apiToken == null || apiToken.isEmpty) {
      debugPrint("Skipping token upload, user is not logged in.");
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('${Connection.BASE_URL}/profile/fcm-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiToken',
        },
        body: jsonEncode({'fcm_token': fcmToken}),
      );

      if (response.statusCode == 200) {
        debugPrint("FCM token successfully registered to server.");
      } else {
        debugPrint(
          "Failed to register FCM token. Status code: ${response.statusCode}",
        );
      }
    } catch (e) {
      debugPrint("Error uploading FCM token: $e");
    }
  }

  void _showLocalNotification({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'education_channel',
          'Edukasi TB Care',
          channelDescription: 'Channel untuk notifikasi materi edukasi baru',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _localNotifications.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  void routeToDetail(int materialId) {
    if (navigatorKey.currentState != null) {
      navigatorKey.currentState!.push(
        MaterialPageRoute(
          builder: (context) => MateriDetailPage(materialId: materialId),
        ),
      );
    } else {
      pendingMaterialId = materialId;
    }
  }
}
