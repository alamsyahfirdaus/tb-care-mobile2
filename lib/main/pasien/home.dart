import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:async';

import 'package:apk_tb_care/main/pasien/consultation.dart';
import 'package:apk_tb_care/main/pasien/education.dart';
import 'package:apk_tb_care/connection.dart';
import 'package:apk_tb_care/profile.dart';
import 'package:apk_tb_care/main/pasien/treatment.dart';
import 'package:apk_tb_care/alarm_service.dart';
import 'package:apk_tb_care/main/login.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider/path_provider.dart';
// ignore: depend_on_referenced_packages
import 'package:http_parser/http_parser.dart';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:apk_tb_care/values/colors.dart';

class HomePage extends StatefulWidget {
  final String name;
  final int userId;
  final int? patientId;

  const HomePage({
    super.key,
    required this.name,
    required this.userId,
    this.patientId,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  late Future<Map<String, dynamic>> _patientDataFuture;

  String? _currentTreatmentId;
  bool _uploadedToday = false;
  bool _isUploading = false;
  bool _alarmSetupCompleted = false;

  @override
  void initState() {
    super.initState();
    _patientDataFuture = _fetchPatientData();
  }

  Future<void> _refreshHome() async {
    if (mounted) {
      setState(() {
        _patientDataFuture = _fetchPatientData();
      });
    }
    try {
      await _patientDataFuture;
    } catch (_) {}
  }

  Future<bool> _isPatientUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('user_type_id') == 2;
  }

  String _formatTime(dynamic value) {
    if (value == null) return "--:--";
    final str = value.toString().trim();
    if (str.isEmpty) return "--:--";
    if (str.length >= 5) {
      try {
        return str.substring(0, 5);
      } catch (_) {
        return str;
      }
    }
    return str;
  }

  Future<void> _handleUnauthorized() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user_name');
    await prefs.remove('user_id');
    await prefs.remove('user_type_id');
    await prefs.remove('patient_id');

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    }
  }

  // ===================== UPLOAD CHECK =====================
  Future<void> _checkTodayUpload() async {
    if (widget.patientId == null) return;

    try {
      final session = await SharedPreferences.getInstance();
      final token = session.getString('token');
      if (token == null || token.isEmpty) return;

      final response = await http
          .get(
            Uri.parse(
              '${Connection.BASE_URL}/treatments/${widget.patientId}/history?per_page=1',
            ),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data == null || data['data'] == null) {
          if (mounted) {
            setState(() {
              _uploadedToday = false;
            });
          }
          return;
        }

        final historyList = data['data'];
        if (historyList is! List) {
          if (mounted) {
            setState(() {
              _uploadedToday = false;
            });
          }
          return;
        }

        final today = DateTime.now();
        bool uploaded = false;

        if (historyList.isNotEmpty) {
          final firstHistory = historyList.first;
          if (firstHistory != null && firstHistory['submitted_at'] != null) {
            final submittedAtStr = firstHistory['submitted_at'].toString();
            final submittedAt = DateTime.tryParse(submittedAtStr);
            if (submittedAt != null) {
              uploaded =
                  submittedAt.year == today.year &&
                  submittedAt.month == today.month &&
                  submittedAt.day == today.day;
            }
          }
        }

        if (mounted) {
          setState(() {
            _uploadedToday = uploaded;
          });
        }
      } else if (response.statusCode == 401) {
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _handleUnauthorized();
          });
        }
      }
    } catch (e) {
      log('Error checking today upload: $e');
    }
  }

  // ===================== FETCH PATIENT =====================
  Future<Map<String, dynamic>> _fetchPatientData() async {
    if (widget.patientId == null) {
      throw Exception('ID Pasien tidak ditemukan. Silakan login ulang.');
    }

    final session = await SharedPreferences.getInstance();
    final token = session.getString('token');
    if (token == null || token.isEmpty) {
      throw Exception('Sesi telah berakhir. Silakan login kembali.');
    }

    try {
      final response = await http
          .get(
            Uri.parse(
              '${Connection.BASE_URL}/patients/${widget.patientId}/show',
            ),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data == null || data['data'] == null) {
          throw Exception('Data kosong dari server.');
        }
        final patientData = data['data'] as Map<String, dynamic>;

        // Setup alarm once patient data is fetched successfully
        _setupAlarmIfNeeded(patientData);
        // Refresh upload status today
        _checkTodayUpload();

        // Update current treatment ID immediately
        final treatments = patientData['treatments'] as List<dynamic>? ?? [];
        if (treatments.isNotEmpty) {
          final currentTreatment = treatments[0];
          if (currentTreatment != null && currentTreatment['id'] != null) {
            _currentTreatmentId = currentTreatment['id'].toString();
          }
        }

        return patientData;
      } else if (response.statusCode == 401) {
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _handleUnauthorized();
          });
        }
        throw Exception('Sesi telah berakhir. Silakan login kembali.');
      } else if (response.statusCode == 403) {
        throw Exception(
          'Akses ditolak. Anda tidak memiliki izin untuk melihat data ini.',
        );
      } else if (response.statusCode == 404) {
        throw Exception('Data pasien tidak ditemukan.');
      } else if (response.statusCode >= 500) {
        throw Exception(
          'Terjadi kesalahan pada server. Silakan coba lagi nanti.',
        );
      } else {
        throw Exception(
          'Gagal memuat data dari server (${response.statusCode})',
        );
      }
    } on SocketException {
      throw Exception(
        'Koneksi ke server gagal. Periksa koneksi internet Anda.',
      );
    } on TimeoutException {
      throw Exception('Waktu muat data habis. Silakan coba lagi.');
    } on FormatException {
      throw Exception('Format data tidak sesuai. Silakan hubungi admin.');
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _setupAlarmIfNeeded(Map<String, dynamic> patientData) async {
    if (_alarmSetupCompleted) {
      log('Alarm setup already completed, skipping.');
      return;
    }

    try {
      final treatments = patientData['treatments'] as List<dynamic>? ?? [];
      if (treatments.isEmpty) return;

      final currentTreatment = treatments[0];
      if (currentTreatment == null) return;

      final medicationTime = currentTreatment['medication_time'];
      if (medicationTime == null) return;

      if (await _isPatientUser()) {
        await AlarmService.initialize();
        await AlarmService.handleTreatment(
          status: currentTreatment['treatment_status'] ?? '',
          medicationTime: medicationTime,
          visits: currentTreatment['visits'],
        );
        _alarmSetupCompleted = true;
        log('Alarm setup completed successfully.');
      }
    } catch (e) {
      log('Error inisialisasi alarm: $e');
    }
  }

  Future<void> _uploadImage(File imageFile, String patientTreatmentId) async {
    final uri = Uri.parse('${Connection.BASE_URL}/treatments/proof');
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null || token.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sesi telah berakhir. Silakan login kembali.'),
          ),
        );
      }
      return;
    }

    if (!await imageFile.exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File gambar bukti tidak ditemukan.')),
        );
      }
      return;
    }

    try {
      final request =
          http.MultipartRequest('POST', uri)
            ..headers.addAll({
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            })
            ..fields['patient_treatment_id'] = patientTreatmentId;

      final bytes = await imageFile.readAsBytes();

      request.files.add(
        http.MultipartFile.fromBytes(
          'photo',
          bytes,
          filename: 'bukti_${DateTime.now().millisecondsSinceEpoch}.jpg',
          contentType: MediaType('image', 'jpeg'),
        ),
      );

      final response = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final body = await response.stream.bytesToString();

      debugPrint('UPLOAD STATUS: ${response.statusCode}');
      debugPrint('UPLOAD BODY: $body');

      if (response.statusCode == 201) {
        await _checkTodayUpload();
        if (mounted) {
          setState(() {
            _uploadedToday = true;
            _isUploading = false;
            _patientDataFuture = _fetchPatientData();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Bukti minum obat berhasil diunggah',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500),
              ),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      } else if (response.statusCode == 401) {
        if (mounted) {
          setState(() {
            _isUploading = false;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _handleUnauthorized();
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isUploading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Gagal mengunggah bukti (${response.statusCode})',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500),
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal mengunggah bukti: $e',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      try {
        if (await imageFile.exists()) {
          await imageFile.delete();
        }
      } catch (e) {
        log('Gagal menghapus file sementara: $e');
      }
    }
  }

  // ===================== HOME PAGE =====================
  Widget _buildHomePage() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _patientDataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        if (snapshot.hasError) {
          final errorMsg = snapshot.error.toString();
          return _buildErrorState(errorMsg);
        }

        final patientData = snapshot.data;
        if (patientData == null || patientData.isEmpty) {
          return _buildErrorState('Data pasien kosong atau tidak ditemukan.');
        }

        final treatments = patientData['treatments'] as List<dynamic>? ?? [];
        final currentTreatment = treatments.isNotEmpty ? treatments[0] : null;
        final visits = currentTreatment?['visits'] as List<dynamic>? ?? [];

        return RefreshIndicator(
          onRefresh: _refreshHome,
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildGreetingSection(),
                const SizedBox(height: 24),
                if (currentTreatment != null)
                  _buildTreatmentCard(currentTreatment)
                else
                  _buildEmptyTreatmentCard(),
                const SizedBox(height: 28),
                if (currentTreatment != null && visits.isNotEmpty) ...[
                  _buildUpcomingEvents(visits),
                  const SizedBox(height: 24),
                ],
                _buildFeatureSection(),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===================== HELPER =====================
  Widget _buildGreetingSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade900.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.person_rounded,
                color: AppColors.primary,
                size: 28,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selamat Datang',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTreatmentCard(Map<String, dynamic> treatment) {
    final currentDay = _calculateCurrentDay(
      treatment['start_date'],
      treatment['end_date'],
    );
    final totalDays = _calculateTotalDays(
      treatment['start_date'],
      treatment['end_date'],
    );

    double progress = 0.0;
    if (totalDays > 0) {
      progress = (currentDay / totalDays).clamp(0.0, 1.0);
    }
    final percent = (progress * 100).toInt();

    final medicationTime = _formatTime(treatment['medication_time']);
    final treatmentStatus = treatment['treatment_status'] ?? 'Berjalan';
    final treatmentTypeId = treatment['treatment_type_id'];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            Color.lerp(AppColors.primary, Colors.blue.shade800, .4)!,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: .24),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.medication_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Status Pengobatan',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white30, width: 1),
                ),
                child: Text(
                  treatmentStatus,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Text(
            _getTreatmentType(treatmentTypeId).toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.white70,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            textBaseline: TextBaseline.alphabetic,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            children: [
              Text(
                'Hari ke-$currentDay dari $totalDays',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              Text(
                '$percent% Selesai',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 8,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              const Icon(
                Icons.date_range_rounded,
                color: Colors.white70,
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                '${treatment['start_date']} s.d. ${treatment['end_date']}',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          const Divider(color: Colors.white24, height: 28, thickness: 1),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_active_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pengingat Minum Obat',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      'Setiap hari, $medicationTime WIB',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isUploading ? null : _showUploadDialog,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.7),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _buildUploadButtonContent(),
            ),
          ),
          if (_uploadedToday) ...[
            const SizedBox(height: 12),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.verified_rounded,
                    color: Color(0xFF10B981),
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "Bukti hari ini sudah dikirim",
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUploadButtonContent() {
    if (_isUploading) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            "Mengunggah Bukti...",
            style: GoogleFonts.plusJakartaSans(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      );
    }

    if (_uploadedToday) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.camera_alt_rounded,
            color: AppColors.primary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            "Perbarui Foto Bukti",
            style: GoogleFonts.plusJakartaSans(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.check_circle_rounded,
          color: AppColors.primary,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          "Konfirmasi & Unggah Bukti",
          style: GoogleFonts.plusJakartaSans(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyTreatmentCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.medical_services_outlined,
              color: AppColors.primary,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Belum Ada Pengobatan",
            style: GoogleFonts.plusJakartaSans(
              color: Colors.grey.shade800,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Anda belum memiliki program pengobatan TB yang aktif di sistem kami.",
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.grey.shade600,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F8FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Silakan hubungi petugas TB di fasilitas kesehatan Anda untuk memulai program.",
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingEvents(List<dynamic> visits) {
    final now = DateTime.now();
    final todayOnly = DateTime(now.year, now.month, now.day);

    final List<dynamic> upcomingVisits =
        visits.where((v) {
          if (v['visit_date'] == null) return false;
          final date = DateTime.tryParse(v['visit_date']);
          if (date == null) return false;
          final dateOnly = DateTime(date.year, date.month, date.day);
          return dateOnly.isAfter(todayOnly) ||
              dateOnly.isAtSameMomentAs(todayOnly);
        }).toList();

    upcomingVisits.sort((a, b) {
      final da = DateTime.tryParse(a['visit_date']) ?? DateTime(3000);
      final db = DateTime.tryParse(b['visit_date']) ?? DateTime(3000);
      return da.compareTo(db);
    });

    final displayedVisits = upcomingVisits.take(3).toList();

    if (displayedVisits.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Jadwal Mendatang',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            Text(
              '${upcomingVisits.length} Jadwal',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Column(
          children:
              displayedVisits.map((visit) {
                final visitDateStr = visit['visit_date'];
                String formattedDate = 'Tanggal tidak tersedia';
                if (visitDateStr != null) {
                  try {
                    formattedDate = DateFormat(
                      'dd MMMM yyyy',
                      'id_ID',
                    ).format(DateTime.parse(visitDateStr));
                  } catch (e) {
                    formattedDate = visitDateStr;
                  }
                }
                final time = _formatTime(visit['visit_time']);
                final status = visit['visit_status'] ?? 'Mendatang';

                Color statusColor = Colors.orange;
                if (status == 'Selesai') {
                  statusColor = const Color(0xFF10B981);
                } else if (status == 'Batal') {
                  statusColor = Colors.redAccent;
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade100, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.01),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.calendar_today_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      'Kunjungan Pengobatan',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Row(
                        children: [
                          Text(
                            '$formattedDate • $time WIB',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              status,
                              style: GoogleFonts.plusJakartaSans(
                                color: statusColor,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.grey.shade400,
                    ),
                    onTap: () => _showEventDetails(visit),
                  ),
                );
              }).toList(),
        ),
      ],
    );
  }

  // Helper methods
  int _calculateCurrentDay(String? startDate, String? endDate) {
    if (startDate == null || endDate == null) return 0;

    try {
      final start = DateTime.parse(startDate);
      final end = DateTime.parse(endDate);
      final now = DateTime.now();

      final startOnly = DateTime(start.year, start.month, start.day);
      final endOnly = DateTime(end.year, end.month, end.day);
      final todayOnly = DateTime(now.year, now.month, now.day);

      if (todayOnly.isBefore(startOnly)) return 0;
      if (todayOnly.isAfter(endOnly)) {
        return endOnly.difference(startOnly).inDays + 1;
      }

      return todayOnly.difference(startOnly).inDays + 1;
    } catch (e) {
      return 0;
    }
  }

  int _calculateTotalDays(String? startDate, String? endDate) {
    if (startDate == null || endDate == null) return 1;

    try {
      final start = DateTime.parse(startDate);
      final end = DateTime.parse(endDate);

      final startOnly = DateTime(start.year, start.month, start.day);
      final endOnly = DateTime(end.year, end.month, end.day);

      return endOnly.difference(startOnly).inDays + 1;
    } catch (e) {
      return 1;
    }
  }

  String _getTreatmentType(int? typeId) {
    switch (typeId) {
      case 1:
        return 'TB Aktif';
      case 2:
        return 'TB Laten';
      case 3:
        return 'TB MDR';
      default:
        return 'Jenis TB Tidak Diketahui';
    }
  }

  void _showEventDetails(Map<String, dynamic> visit) {
    final visitDateStr = visit['visit_date'];
    String formattedDate = 'Tanggal tidak tersedia';
    if (visitDateStr != null) {
      try {
        formattedDate = DateFormat(
          'EEEE, dd MMMM yyyy',
          'id_ID',
        ).format(DateTime.parse(visitDateStr));
      } catch (e) {
        formattedDate = visitDateStr;
      }
    }
    final time = _formatTime(visit['visit_time']);
    final status = visit['visit_status'] ?? 'Status tidak tersedia';
    final notes = visit['notes'] ?? 'Tidak ada catatan';

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.event_note_rounded,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'Detail Kunjungan',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  _buildDetailRow(
                    Icons.calendar_month_rounded,
                    'Tanggal',
                    formattedDate,
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    Icons.access_time_filled_rounded,
                    'Waktu',
                    '$time WIB',
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.info_outline_rounded, 'Status', status),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    Icons.description_rounded,
                    'Catatan Petugas',
                    notes,
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Tutup',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade400),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: Colors.grey.shade800,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showUploadDialog() {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.done_all_rounded,
                      color: AppColors.primary,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Konfirmasi Minum Obat',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Apakah Anda sudah meminum obat TB Anda hari ini?',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            'Nanti',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _showUploadOptions();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            'Konfirmasi',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _showUploadOptions() {
    final ImagePicker picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Unggah Bukti Minum Obat',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Pilih metode pengambilan foto bukti minum obat',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  title: Text(
                    'Ambil Foto Kamera',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    final XFile? photo = await picker.pickImage(
                      source: ImageSource.camera,
                    );
                    if (photo != null) {
                      _handleSelectedImage(File(photo.path));
                    }
                  },
                ),
                Divider(color: Colors.grey.shade100, height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.photo_library_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  title: Text(
                    'Pilih dari Galeri',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    final XFile? image = await picker.pickImage(
                      source: ImageSource.gallery,
                    );
                    if (image != null) {
                      _handleSelectedImage(File(image.path));
                    }
                  },
                ),
                Divider(color: Colors.grey.shade100, height: 1),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Konfirmasi tanpa foto belum tersedia. Silakan unggah foto sebagai bukti minum obat.',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        backgroundColor: Colors.orangeAccent,
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Tanpa Foto',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  // ===================== UPLOAD HANDLER =====================
  void _handleSelectedImage(File imageFile) async {
    if (_currentTreatmentId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Data pengobatan belum siap. Silakan refresh.',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500),
            ),
            backgroundColor: Colors.orangeAccent,
          ),
        );
      }
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final bytes = await imageFile.readAsBytes();
      final decodedImage = img.decodeImage(bytes);
      if (decodedImage == null) {
        throw Exception('Gagal membaca format gambar.');
      }

      // Resize image down to max width 1080px to save memory and upload speed
      img.Image resizedImage = decodedImage;
      if (decodedImage.width > 1080) {
        resizedImage = img.copyResize(decodedImage, width: 1080);
      }

      final jpegBytes = img.encodeJpg(resizedImage, quality: 80);
      final tempDir = await getTemporaryDirectory();

      final fixedFile = File(
        '${tempDir.path}/upload_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      await fixedFile.writeAsBytes(jpegBytes);
      await _uploadImage(fixedFile, _currentTreatmentId!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal memproses gambar: $e',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Widget _buildFeatureSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Layanan TB Care',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),
        Material(
          color: const Color(0xFFF3F8FF),
          borderRadius: BorderRadius.circular(20),
          elevation: 0,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            splashColor: AppColors.primary.withValues(alpha: .10),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EducationPage()),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: .06),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.menu_book_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      "Informasi & Edukasi TB",
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.primary.withValues(alpha: 0.7),
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_off_rounded,
                color: Colors.red.shade400,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Data belum dapat dimuat',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: Colors.grey.shade500,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 160,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: _refreshHome,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(
                  'Coba Lagi',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            height: 96,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 120,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 180,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Container(
            width: double.infinity,
            height: 240,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.grey.shade100, width: 1.5),
            ),
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 140,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Container(
                      width: 60,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  width: 80,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 200,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const Spacer(),
                Container(
                  width: double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Container(
            width: 140,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===================== BUILD =====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: Text(
          'TB Care',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildHomePage(),
          TreatmentPage(patientId: widget.patientId ?? 0),
          const ConsultationPage(),
          const ProfilePage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: Colors.white,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          if (mounted) {
            setState(() => _selectedIndex = index);
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: AppColors.primary),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.medication_outlined),
            selectedIcon: Icon(Icons.medication, color: AppColors.primary),
            label: 'Pengobatan',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_outlined),
            selectedIcon: Icon(Icons.chat, color: AppColors.primary),
            label: 'Konsultasi',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: AppColors.primary),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
