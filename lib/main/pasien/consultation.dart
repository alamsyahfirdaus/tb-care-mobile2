import 'dart:convert';

import 'package:apk_tb_care/connection.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:apk_tb_care/main/pasien/detail_consultation.dart';
import 'package:apk_tb_care/main/pasien/new_consultation.dart';
import 'package:apk_tb_care/main/pasien/consultation_service.dart';

class ConsultationPage extends StatefulWidget {
  final bool isStaff;
  const ConsultationPage({super.key, this.isStaff = false});

  @override
  State<ConsultationPage> createState() => _ConsultationPageState();
}

class _ConsultationPageState extends State<ConsultationPage> {
  late final ConsultationService _service;
  List<dynamic> _consultations = [];
  bool _isLoading = true;
  String? _currentUserId;
  String? _currentUserName;

  @override
  void initState() {
    super.initState();
    _service = ConsultationService();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);

      final session = await SharedPreferences.getInstance();
      final userId = session.getString('user_id');
      final userName = session.getString('user_name');

      _service.currentUserId = userId;

      // 1. Load from API first
      final apiConsultations = await _loadFromAPI();

      // 2. Sync with Firebase
      await _syncWithFirebase(apiConsultations);

      setState(() {
        _currentUserId = userId;
        _currentUserName = userName;
        _consultations = apiConsultations;

        _isLoading = false;
      });

      setState(() => _isLoading = false);
      // 3. Setup Firebase listener
      _setupFirebaseListener();
    } catch (e) {
      ScaffoldMessenger.of(
        // ignore: use_build_context_synchronously
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));

      // Fallback to Firebase if API fails
      await _loadFromFirebase();
    }
  }

  Map<String, dynamic> _formatConsultation(dynamic consultation) {
    // Handle replies whether they come as List or Map
    dynamic repliesData = consultation['replies'];
    final Map<String, dynamic> repliesMap = {};

    if (repliesData is List) {
      // Handle API response format (List)
      for (var reply in repliesData) {
        if (reply is Map) {
          repliesMap[reply['id'].toString()] = {
            'id': reply['id'],
            'message': reply['message'],
            'attachment': reply['attachment'],
            'is_read': reply['is_read'] ?? 0,
            'created_at': reply['created_at'],
            'user_id': reply['user_id'],
            'sender_name': reply['sender_name'],
          };
        }
      }
    } else if (repliesData is Map) {
      // Handle Firebase format (Map)
      repliesData.forEach((key, reply) {
        if (reply is Map) {
          repliesMap[key.toString()] = {
            'id': reply['id'] ?? key,
            'message': reply['message'],
            'attachment': reply['attachment'],
            'is_read': reply['is_read'] ?? 0,
            'created_at': reply['created_at'],
            'user_id': reply['user_id'],
            'sender_name': reply['sender_name'],
          };
        }
      });
    }

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
      'replies': repliesMap,
    };
  }

  Future<List<dynamic>> _loadFromAPI() async {
    final session = await SharedPreferences.getInstance();
    final token = session.getString('token') ?? '';

    final response = await http
        .get(
          Uri.parse('${Connection.BASE_URL}/consultations'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return data['data'] ?? [];
    }
    throw Exception('API request failed with status ${response.statusCode}');
  }

  Future<void> _syncWithFirebase(List<dynamic> consultations) async {
    try {
      final futures =
          consultations.map((consultation) async {
            await Future.delayed(Duration(milliseconds: 300));
            final id = consultation['id'].toString();
            // ignore: avoid_print
            print('SYNCING ID: $id');

            final formatted = _formatConsultation(consultation);

            // Sync consultation
            await _service.consultationsRef.child(id).set(formatted);

            // Sync replies separately under the replies node
            final replies = formatted['replies'] as Map<String, dynamic>;
            // ignore: avoid_print
            print('✅ Consultation $id synced');

            if (replies.isNotEmpty) {
              // ignore: avoid_print
              print('⏳ Syncing replies for $id...');
              await _service.repliesRef.child(id).set(replies);
              // ignore: avoid_print
              print('✅ Replies for $id synced');
            }

            // ignore: avoid_print
            print('SYNCED ID: $id');
          }).toList();

      await Future.wait(futures);
      // ignore: avoid_print
      print('✅ Sync done');
    } catch (e) {
      debugPrint('❌ Firebase sync error: $e');
      rethrow;
    }
  }

  Future<void> _loadFromFirebase() async {
    try {
      final snapshot = await _service.consultationsRef.get();
      if (snapshot.exists) {
        final data = snapshot.value;
        if (data is Map<dynamic, dynamic>) {
          setState(() {
            _consultations =
                data.values.map((e) {
                  if (e is Map) {
                    return _formatConsultation(e);
                  }
                  return <String, dynamic>{};
                }).toList();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Firebase load error: $e');
      setState(() => _isLoading = false);
    }
  }

  // Update the _setupFirebaseListener method
  void _setupFirebaseListener() {
    _service.consultationsRef.onValue.listen((event) {
      if (!mounted) return;

      final data = event.snapshot.value;
      if (data is Map<dynamic, dynamic>) {
        final allConsultations =
            data.values.map((e) {
              if (e is Map) return _formatConsultation(e);
              return <String, dynamic>{};
            }).toList();

        setState(() {
          _consultations =
              widget.isStaff
                  ? allConsultations
                  : allConsultations.where((c) {
                    final senderId = c['user_id']?.toString();
                    final recipientId = c['recipient_id']?.toString();

                    return senderId == _currentUserId ||
                        recipientId == _currentUserId;
                  }).toList();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Forum Konsultasi'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_consultations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.forum_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              widget.isStaff
                  ? 'Belum ada konsultasi'
                  : 'Belum ada konsultasi\nMulai diskusi sekarang!',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [_buildInfoHeader(), Expanded(child: _buildConsultationList())],
    );
  }

  Widget _buildInfoHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.blue[50],
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.isStaff
                  ? 'Anda dapat menghapus konsultasi atau balasan yang tidak pantas'
                  : 'Forum ini dibimbing oleh petugas kesehatan. Mohon menjaga etika berkomunikasi.',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsultationList() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _consultations.length,
        itemBuilder: (context, index) {
          return _buildConsultationCard(_consultations[index]);
        },
      ),
    );
  }

  Widget _buildConsultationCard(Map<String, dynamic> consultation) {
    final isOwned = consultation['user_id'] == _currentUserId;
    final replies =
        consultation['replies'] is Map
            ? consultation['replies'] as Map<String, dynamic>
            : <String, dynamic>{};
    final hasReplies = replies.isNotEmpty;
    final isPublic = consultation['recipient_id'] == null;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _navigateToDetail(consultation['id'].toString()),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      consultation['title'] ?? 'Tanpa judul',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (!isPublic)
                    const Icon(
                      Icons.lock_outline,
                      size: 16,
                      color: Colors.orange,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(consultation['message'] ?? ''),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    'Oleh: ${consultation['sender_name'] ?? 'Anonim'}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const Spacer(),
                  Text(
                    _service.formatDateTime(consultation['created_at']),
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
              if (hasReplies) ...[
                const SizedBox(height: 8),
                Text(
                  '${replies.length} balasan',
                  style: TextStyle(color: Colors.blue[600], fontSize: 12),
                ),
              ],
              if (widget.isStaff || isOwned)
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                    onPressed:
                        () => _confirmDelete(
                          consultation['id'].toString(),
                          isOwned: isOwned,
                        ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget? _buildFloatingActionButton() {
    if (widget.isStaff) return null;

    return FloatingActionButton(
      onPressed:
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => NewConsultationPage(
                    service: _service,
                    currentUserId: _currentUserId!,
                    currentUserName: _currentUserName ?? 'Pengguna',
                  ),
            ),
          ),
      child: const Icon(Icons.add),
    );
  }

  Future<void> _navigateToDetail(String consultationId) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ConsultationDetailPage(
              consultationId: consultationId,
              service: _service,
              isStaff: widget.isStaff,
              currentUserId: _currentUserId!,
            ),
      ),
    );

    // Jika detail mengirim sinyal refresh (hapus konsultasi)
    if (result == true) {
      _loadData(); // refresh daftar konsultasi
    }
  }

  void _confirmDelete(String consultationId, {required bool isOwned}) {
    // Store context and scaffold references before async operations
    final currentContext = context;
    final scaffold = ScaffoldMessenger.of(currentContext);

    showDialog(
      context: currentContext,
      builder:
          (context) => AlertDialog(
            title: const Text('Hapus Konsultasi'),
            content: Text(
              isOwned
                  ? 'Apakah Anda yakin ingin menghapus konsultasi ini?'
                  : 'Apakah Anda yakin ingin menghapus konsultasi ini?\n(Hanya petugas yang dapat menghapus konsultasi orang lain)',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal'),
              ),
              TextButton(
                onPressed: () async {
                  // Close dialog immediately
                  Navigator.pop(context);

                  // Show loading indicator
                  // ignore: unused_local_variable
                  final loadingSnackBar = scaffold.showSnackBar(
                    const SnackBar(
                      content: Text('Menghapus konsultasi...'),
                      duration: Duration(
                        minutes: 1,
                      ), // Long duration for loading
                    ),
                  );

                  try {
                    await _service.deleteConsultation(consultationId);

                    // Hide loading indicator
                    scaffold.hideCurrentSnackBar();

                    // Show success message
                    scaffold.showSnackBar(
                      const SnackBar(
                        content: Text('Konsultasi berhasil dihapus'),
                        duration: Duration(seconds: 2),
                      ),
                    );

                    // Check if we can pop and if widget is still mounted
                    // ignore: use_build_context_synchronously
                    if (mounted && Navigator.canPop(currentContext)) {
                      // ignore: use_build_context_synchronously
                      Navigator.pop(currentContext);
                    }
                  } catch (e) {
                    // Hide loading indicator
                    scaffold.hideCurrentSnackBar();

                    // Show error message
                    scaffold.showSnackBar(
                      SnackBar(
                        content: Text('Gagal menghapus: ${e.toString()}'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
                child: const Text('Hapus', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
  }
}
