import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:apk_tb_care/connection.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
// ignore: depend_on_referenced_packages
import 'package:http_parser/http_parser.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:permission_handler/permission_handler.dart';

class ConsultationService {
  final DatabaseReference _consultationsRef;
  final DatabaseReference _repliesRef;
  final FlutterLocalNotificationsPlugin _notificationsPlugin;

  DatabaseReference get consultationsRef => _consultationsRef;
  DatabaseReference get repliesRef => _repliesRef;

  List<Map<String, dynamic>> recipients = [];
  StreamSubscription<DatabaseEvent>? _consultationSubscription;
  StreamSubscription<DatabaseEvent>? _repliesSubscription;

  String? currentUserId;
  bool isConsultationDetailOpen = false;

  static const String _databaseUrl =
      'https://tb-care-id-default-rtdb.asia-southeast1.firebasedatabase.app/';

  ConsultationService()
    : _consultationsRef = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: _databaseUrl,
      ).ref('consultations'),
      _repliesRef = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: _databaseUrl,
      ).ref('replies'),
      _notificationsPlugin = FlutterLocalNotificationsPlugin() {
    FirebaseDatabase.instance.setPersistenceEnabled(true);
    FirebaseDatabase.instance.setPersistenceCacheSizeBytes(10000000);
    _initializeNotifications();
  }

  void setupRealtimeListeners({
    Function(List<dynamic>)? onConsultationsUpdated,
    Function(Map<String, dynamic>)? onConsultationUpdated,
    Function(List<dynamic>)? onRepliesUpdated,
  }) {
    _consultationSubscription?.cancel();
    _repliesSubscription?.cancel();

    // Setup consultations listener
    _consultationSubscription = _consultationsRef.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        final consultations =
            data.entries.map((entry) {
              final consultation = entry.value as Map<dynamic, dynamic>;
              return {
                'id': consultation['id'],
                'title': consultation['title'],
                'message': consultation['message'],
                'is_answered': consultation['is_answered'] ?? 0,
                'attachment': consultation['attachment'],
                'created_at': consultation['created_at'],
                'user_id': consultation['user_id'],
                'sender_name': consultation['sender_name'],
                'recipient_id': consultation['recipient_id'],
                'recipient_name': consultation['recipient_name'],
                'replies': consultation['replies'] ?? [],
              };
            }).toList();

        onConsultationsUpdated?.call(consultations);
      } else {
        onConsultationsUpdated?.call([]);
      }
    });

    // Setup replies listener
    _repliesSubscription = _repliesRef.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        final allReplies = <dynamic>[];
        data.forEach((consultationId, replies) {
          if (replies is Map) {
            replies.forEach((replyId, reply) {
              allReplies.add({
                'id': reply['id'] ?? replyId,
                'consultation_id': consultationId,
                'message': reply['message'],
                'attachment': reply['attachment'],
                'created_at': reply['created_at'],
                'user_id': reply['user_id'],
                'sender_name': reply['sender_name'],
                'is_read': reply['is_read'] ?? 0,
              });
            });
          }
        });
        onRepliesUpdated?.call(allReplies);
      }
    });
  }

  void dispose() {
    _consultationSubscription?.cancel();
    _repliesSubscription?.cancel();
  }

  Future<List<dynamic>> loadInitialConsultations() async {
    try {
      final session = await SharedPreferences.getInstance();
      final token = session.getString('token') ?? '';

      // Load from API
      final response = await http.get(
        Uri.parse('${Connection.BASE_URL}/consultations'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final consultations = data['data'] ?? [];

        // Normalize data structure
        final normalizedConsultations =
            consultations.map((consultation) {
              return {
                'id': consultation['id'],
                'title': consultation['title'] ?? '',
                'message': consultation['message'] ?? '',
                'is_answered': consultation['is_answered'] ?? 0,
                'attachment': consultation['attachment'],
                'created_at': consultation['created_at'] ?? '',
                'user_id': consultation['user_id'],
                'sender_name': consultation['sender_name'] ?? 'Unknown',
                'recipient_id': consultation['recipient_id'],
                'recipient_name': consultation['recipient_name'],
                'replies': consultation['replies'] ?? [],
              };
            }).toList();

        await _syncConsultationsToFirebase(normalizedConsultations);
        return normalizedConsultations;
      }
      throw Exception('Failed to load consultations: ${response.statusCode}');
    } catch (e) {
      // Fallback to Firebase cache if API fails
      log("Error loading from API: $e");

      final snapshot = await _consultationsRef.get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        return data.values.toList();
      }
      return [];
    }
  }

  Future<void> _syncConsultationsToFirebase(List<dynamic> consultations) async {
    try {
      await _consultationsRef.set({}); // Clear existing data

      for (var consultation in consultations) {
        await _consultationsRef
            .child(consultation['id'].toString())
            .set(consultation);
      }
    } catch (e) {
      log("Error syncing to Firebase: $e");
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> loadRecipients() async {
    final session = await SharedPreferences.getInstance();
    final token = session.getString('token') ?? '';

    try {
      final response = await http.get(
        Uri.parse('${Connection.BASE_URL}/consultations/recipients'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        dynamic recipientsData = data['data'];

        // Handle both List and Map cases
        List<dynamic> recipientsList;
        if (recipientsData is List) {
          recipientsList = recipientsData;
        } else if (recipientsData is Map) {
          recipientsList = recipientsData.values.toList();
        } else {
          recipientsList = [];
        }

        recipients =
            recipientsList
                .map(
                  (item) => {
                    'id': item['id'],
                    'name': item['name'],
                    'email': item['email'],
                    'role': item['role'],
                  },
                )
                .toList();
        return recipients;
      } else {
        throw Exception('Failed to load recipients');
      }
    } catch (e) {
      throw Exception('Error loading recipients: $e');
    }
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(initializationSettings);
  }

  Future<void> createConsultation({
    required String title,
    required String message,
    required String senderId,
    required String senderName,
    String? recipientId,
    File? attachment,
    String? attachmentName,
  }) async {
    final session = await SharedPreferences.getInstance();
    final token = session.getString('token') ?? '';

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${Connection.BASE_URL}/consultations/store'),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.fields['title'] = title;
      request.fields['message'] = message;
      if (recipientId != null) {
        request.fields['recipient_id'] = recipientId;
      }

      if (attachment != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'attachment',
            attachment.path,
            filename: attachmentName,
            contentType: MediaType('application', 'octet-stream'),
          ),
        );
      }

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final responseData = jsonDecode(responseBody);

      if (response.statusCode == 201) {
        final consultationData = {
          'id': responseData['data']['id'],
          'title': title,
          'message': message,
          'sender_id': senderId,
          'sender_name': senderName,
          'recipient_id': recipientId,
          'recipient_name':
              recipientId != null
                  ? recipients.firstWhere(
                    (r) => r['id'].toString() == recipientId,
                  )['name']
                  : null,
          'attachment':
              attachment != null
                  ? '${Connection.BASE_URL}/storage/${responseData['data']['attachment']}'
                  : null,
          'created_at': DateTime.now().toIso8601String(),
          'is_answered': false,
          'replies': [],
        };

        await _consultationsRef
            .child(responseData['data']['id'].toString())
            .set(consultationData);

        if (recipientId != null && recipientId.toString() == currentUserId) {
          await _showNotification(
            'Konsultasi Baru',
            'Anda mendapat konsultasi baru dari $senderName',
          );
        }
      }
    } catch (e) {
      debugPrint('Error creating consultation: $e');
      rethrow;
    }
  }

  // Add these methods to your ConsultationService class

  void setupConsultationListener(
    String consultationId,
    Function(Map<String, dynamic>) onConsultationUpdated,
  ) {
    _consultationsRef.child(consultationId).onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        onConsultationUpdated(Map<String, dynamic>.from(data));
      }
    });
  }

  void setupReplyListener(
    String consultationId,
    Function(List<dynamic>) onRepliesUpdated,
  ) {
    _repliesRef.child(consultationId).onValue.listen((event) {
      final data = event.snapshot.value;
      if (data != null) {
        if (data is Map) {
          // Handle Map format
          final replies = data.values.map((item) => item).toList();
          onRepliesUpdated(replies);
        } else if (data is List) {
          // Handle List format
          onRepliesUpdated(data);
        }
      } else {
        onRepliesUpdated([]);
      }
    });
  }

  Future<Map<String, dynamic>> loadConsultation(String consultationId) async {
    try {
      final snapshot = await _consultationsRef.child(consultationId).get();
      if (snapshot.exists) {
        return Map<String, dynamic>.from(
          snapshot.value as Map<dynamic, dynamic>,
        );
      }
      throw Exception('Consultation not found');
    } catch (e) {
      // Fallback to API if Firebase fails
      final session = await SharedPreferences.getInstance();
      final token = session.getString('token') ?? '';

      final response = await http.get(
        Uri.parse('${Connection.BASE_URL}/consultations/$consultationId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data['data'];
      }
      throw Exception('Failed to load consultation: ${response.statusCode}');
    }
  }

  Future<List<dynamic>> loadReplies(String consultationId) async {
    try {
      final snapshot = await _repliesRef.child(consultationId).get();
      if (snapshot.exists) {
        final data = snapshot.value;

        if (data is Map) {
          // Handle Map format
          return data.values.map((reply) => reply).toList();
        } else if (data is List) {
          // Handle List format
          return data;
        }
      }
      return [];
    } catch (e) {
      // Fallback to API if Firebase fails
      final session = await SharedPreferences.getInstance();
      final token = session.getString('token') ?? '';

      final response = await http.get(
        Uri.parse(
          '${Connection.BASE_URL}/consultations/$consultationId/replies',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data['data'] ?? [];
      }
      throw Exception('Failed to load replies: ${response.statusCode}');
    }
  }

  Future<void> sendReply(
    String consultationId,
    String message,
    File? attachment,
    String? attachmentName,
  ) async {
    final session = await SharedPreferences.getInstance();
    final token = session.getString('token') ?? '';
    final userId = session.getString('user_id') ?? ''; // Ensure non-null string
    final userName = session.getString('user_name') ?? 'Pengguna';

    // 1. Generate temporary ID for optimistic update
    final tempReplyId = DateTime.now().millisecondsSinceEpoch.toString();

    // 2. Create initial reply data (using client timestamp first)
    final newReply = {
      'id': tempReplyId,
      'consultation_id': consultationId,
      'message': message,
      'sender_id': userId,
      'sender_name': userName,
      'attachment': null,
      'created_at': DateTime.now().toIso8601String(), // Client timestamp first
      'is_read': false,
      'status': 'sending',
    };

    // 3. Optimistic update to Firebase
    final replyRef = _repliesRef.child(consultationId).child(tempReplyId);
    await replyRef.set({
      ...newReply,
      // Ensure all fields are present
      'consultation_id': consultationId,
      'message': message,
      'sender_id': userId,
      'sender_name': userName,
      'attachment': null,
      'created_at': DateTime.now().toIso8601String(),
      'is_read': false,
      'status': 'sending',
    });

    try {
      // 4. Prepare request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${Connection.BASE_URL}/consultations/reply'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['consultation_id'] = consultationId;
      request.fields['message'] = message;

      // 5. Handle attachment
      if (attachment != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'attachment',
            attachment.path,
            filename: attachmentName,
            contentType: MediaType('application', 'octet-stream'),
          ),
        );
      }

      // 6. Send request
      final response = await _retryRequest(request);
      final responseBody = await response.stream.bytesToString();
      final responseData = jsonDecode(responseBody);

      if (response.statusCode == 201) {
        // 7. Update with server data
        final serverId = responseData['data']['id'].toString();
        final updatedReply = {
          ...newReply,
          'id': serverId,

          // INI YANG HILANG & WAJIB ADA
          'sender_id': userId,
          'sender_name': userName,

          'status': 'delivered',
          'created_at':
              responseData['data']['created_at'] ?? newReply['created_at'],
          'attachment':
              attachment != null
                  ? '${Connection.BASE_URL}/storage/${responseData['data']['attachment']}'
                  : null,
        };

        // 8. Replace temporary reply with server version
        await _repliesRef.child(consultationId).child(tempReplyId).remove();
        await _repliesRef
            .child(consultationId)
            .child(serverId)
            .set(updatedReply);
      }
    } catch (e) {
      // 9. Mark as failed if error occurs
      await _repliesRef.child(consultationId).child(tempReplyId).update({
        'status': 'failed',
        'error': e.toString(),
      });

      debugPrint('Error sending reply: $e');
      rethrow;
    }
  }

  Future<http.StreamedResponse> _retryRequest(
    http.MultipartRequest request, {
    int maxRetries = 3,
  }) async {
    int attempt = 0;
    while (attempt < maxRetries) {
      try {
        final response = await request.send();
        if (response.statusCode < 500) {
          return response;
        }
        throw Exception('Server error: ${response.statusCode}');
      } catch (e) {
        attempt++;
        if (attempt == maxRetries) rethrow;
        await Future.delayed(Duration(seconds: attempt));
      }
    }
    throw Exception('Max retries exceeded');
  }

  Future<void> deleteConsultation(String id) async {
    final session = await SharedPreferences.getInstance();
    final token = session.getString('token') ?? '';

    try {
      await http.delete(
        Uri.parse('${Connection.BASE_URL}/consultations/$id/delete'),
        headers: {'Authorization': 'Bearer $token'},
      );

      await _consultationsRef.child(id).remove();
      await _repliesRef.child(id).remove();
    } catch (e) {
      debugPrint('Error deleting consultation: $e');
      rethrow;
    }
  }

  Future<void> deleteReply(String consultationId, String replyId) async {
    final session = await SharedPreferences.getInstance();
    final token = session.getString('token') ?? '';

    try {
      await http.delete(
        Uri.parse('${Connection.BASE_URL}/consultations/$replyId/reply'),
        headers: {'Authorization': 'Bearer $token'},
      );

      await _repliesRef.child(consultationId).child(replyId).remove();
    } catch (e) {
      debugPrint('Error deleting reply: $e');
      rethrow;
    }
  }

  Future<void> _showNotification(String title, String body) async {
    // ⛔ Jangan tampilkan notifikasi jika halaman detail sedang dibuka
    if (isConsultationDetailOpen) {
      log('Notification suppressed (detail page open)');
      return;
    }

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'consultation_channel',
          'Konsultasi',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          sound: const RawResourceAndroidNotificationSound(
            'notif_konsultasi', // TANPA .mp3
          ),
        );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await _notificationsPlugin.show(id, title, body, platformChannelSpecifics);
  }

  Future<void> viewAttachment(BuildContext context, String url) async {
    if (url.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('File tidak tersedia')));
      return;
    }

    final fileName = url.split('/').last;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(fileName),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _getFileIcon(fileName),
              const SizedBox(height: 16),
              Text('Lampiran: $fileName', textAlign: TextAlign.center),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup'),
            ),
            TextButton(
              onPressed: () async {
                await _downloadFile(url, context);
                // ignore: use_build_context_synchronously
                Navigator.pop(context);
              },
              child: const Text('Unduh'),
            ),
          ],
        );
      },
    );
  }

  Widget _getFileIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    const iconSize = 48.0;

    if (['pdf'].contains(ext)) {
      return const Icon(
        Icons.picture_as_pdf,
        size: iconSize,
        color: Colors.red,
      );
    } else if (['jpg', 'jpeg', 'png', 'gif'].contains(ext)) {
      return const Icon(Icons.image, size: iconSize, color: Colors.blue);
    } else if (['doc', 'docx'].contains(ext)) {
      return const Icon(Icons.description, size: iconSize, color: Colors.blue);
    } else if (['xls', 'xlsx'].contains(ext)) {
      return const Icon(Icons.table_chart, size: iconSize, color: Colors.green);
    } else {
      return const Icon(Icons.insert_drive_file, size: iconSize);
    }
  }

  Future<void> _downloadFile(String url, BuildContext context) async {
    try {
      // Check if URL is valid
      final uri = Uri.parse(url);
      if (!uri.isAbsolute) {
        throw Exception('Invalid URL');
      }

      // Handle permissions
      if (Platform.isAndroid) {
        // Request storage permissions

        if (await Permission.manageExternalStorage.request().isDenied) {
          // Buka pengaturan manual
          await openAppSettings();
        }

        // For Android 10+, we need manage external storage for some cases
        if (await Permission.manageExternalStorage.isDenied) {
          openAppSettings();
          await Permission.manageExternalStorage.request();
        }
      }

      // Get download directory
      final dir =
          Platform.isAndroid
              ? await getExternalStorageDirectory()
              : await getApplicationDocumentsDirectory();

      if (dir == null) {
        throw Exception('Could not access download directory');
      }

      // Create download directory if it doesn't exist
      final downloadDir = Directory('${dir.path}/Downloads');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      // Get file name from URL
      final fileName = url.split('/').last;
      final savePath = '${downloadDir.path}/$fileName';

      // Show download progress
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 10),
              Text('Downloading $fileName...'),
            ],
          ),
          duration: const Duration(minutes: 1),
        ),
      );

      // Download file
      await Dio().download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = (received / total * 100).toStringAsFixed(0);
            debugPrint('Download progress: $progress%');
          }
        },
      );

      // Show completion message
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('File downloaded to Downloads/$fileName'),
          action: SnackBarAction(
            label: 'Open',
            onPressed: () => _openFile(savePath, context),
          ),
        ),
      );
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download failed: ${e.toString()}'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _openFile(String path, BuildContext context) async {
    try {
      final result = await OpenFile.open(path);

      if (result.type != ResultType.done) {
        throw Exception('Failed to open file: ${result.message}');
      }
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot open file: ${e.toString()}')),
      );
    }
  }

  String formatDateTime(String? dateTime) {
    if (dateTime == null) return '';
    try {
      try {
        final format = DateFormat('yyyy-MM-dd HH:mm:ss');
        final dt = format.parse(dateTime);
        return DateFormat('dd MMM yyyy, HH:mm').format(dt);
      } catch (_) {
        final format = DateFormat('yyyy-MM-dd HH:mm');
        final dt = format.parse(dateTime);
        return DateFormat('dd MMM yyyy, HH:mm').format(dt);
      }
    } catch (e) {
      return dateTime;
    }
  }
}
