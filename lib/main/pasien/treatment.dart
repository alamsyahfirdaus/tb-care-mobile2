// ignore_for_file: deprecated_member_use, unused_field, unused_element

import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:apk_tb_care/main/pasien/history.dart';
import 'package:apk_tb_care/main/pasien/treatment_history.dart';
import 'package:apk_tb_care/connection.dart';
import 'package:apk_tb_care/values/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:google_fonts/google_fonts.dart';
import 'package:apk_tb_care/main/login.dart';
import 'package:apk_tb_care/alarm_service.dart';

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
  bool _uploadedToday = false;
  bool _isUploading = false;

  static const String _lastMedicationTimeKey = 'last_medication_time';

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (await _isPatientUser()) {
        await AlarmService.initialize();
        await _disableBatteryOptimization();
        _checkMissedNotifications();
      } else {
        await AlarmService.stopAllMedicationAlarm();
      }
    });
    _patientFuture = _fetchPatientData();
  }

  Future<bool> _isPatientUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userType = prefs.getInt('user_type_id');
    return userType == 2;
  }

  bool _alreadyUploadedToday(List<dynamic> history) {
    if (history.isEmpty) {
      return false;
    }

    final latest = history.first;
    if (latest == null || latest['submitted_at'] == null) {
      return false;
    }
    final submittedAt = DateTime.tryParse(latest['submitted_at']);
    if (submittedAt == null) {
      return false;
    }

    final today = DateTime.now();

    return submittedAt.year == today.year &&
        submittedAt.month == today.month &&
        submittedAt.day == today.day;
  }

  Future<void> _refreshTreatmentPage() async {
    if (mounted) {
      setState(() {
        _patientFuture = _fetchPatientData();
      });
    }
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

  Future<void> _checkMissedNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final lastNotificationTime = prefs.getInt('lastNotificationTime');
    final now = DateTime.now().millisecondsSinceEpoch;

    if (lastNotificationTime != null) {
      final diffHours = (now - lastNotificationTime) / (1000 * 60 * 60);
      if (diffHours > 26) {
        _showMissedNotificationWarning();
      }
    } else {
      // Hanya inisialisasi jika null
      prefs.setInt('lastNotificationTime', now);
    }
  }

  void _showMissedNotificationWarning() {
    if (!mounted) {
      return;
    }

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
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
                      color: Colors.orange.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.notification_important_rounded,
                      color: Colors.orange.shade800,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Pengingat Terlewat',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Sepertinya Anda melewatkan waktu minum obat. Apakah Anda sudah minum obat?',
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
                            _showUploadDialog();
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
                            'Sudah Minum',
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

  Future<Map<String, dynamic>> _fetchPatientData() async {
    final session = await SharedPreferences.getInstance();
    final token = session.getString('token') ?? '';

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
        final Map<String, dynamic> data = jsonDecode(response.body);

        if (mounted) {
          setState(() {
            _patientData = data['data'];
            _treatments = data['data']['treatments'] ?? [];
            _currentTreatment =
                _treatments.isNotEmpty ? _treatments.first : null;
          });
        }

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

        // ================== SINKRONISASI ALARM & KUNJUNGAN ==================
        await AlarmService.handleTreatment(
          status: treatmentStatus ?? '',
          medicationTime: medicationTime,
          visits: _currentTreatment!['visits'],
        );

        _checkTodayUpload();
        return data['data'];
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
        throw Exception('Data pengobatan tidak ditemukan.');
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

  Future<void> _checkTodayUpload() async {
    final session = await SharedPreferences.getInstance();
    final token = session.getString('token') ?? '';

    try {
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
        final history = data['data'] as List<dynamic>;

        if (mounted) {
          setState(() {
            _uploadedToday = _alreadyUploadedToday(history);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: Text(
          'Pengobatan Saya',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: AppColors.primary,
          ),
        ),
        // actions: [
        //   IconButton(
        //     icon: const Icon(Icons.medication_rounded),
        //     tooltip: 'Riwayat Minum Obat',
        //     onPressed: () {
        //       Navigator.push(
        //         context,
        //         MaterialPageRoute(
        //           builder:
        //               (context) =>
        //                   MedicationHistoryPage(patientId: widget.patientId),
        //         ),
        //       );
        //     },
        //   ),
        // ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshTreatmentPage,
        color: AppColors.primary,
        child: FutureBuilder<Map<String, dynamic>>(
          future: _patientFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingState();
            } else if (snapshot.hasError) {
              return _buildErrorState(snapshot.error.toString());
            } else if (!snapshot.hasData || _currentTreatment == null) {
              return _buildEmptyTreatmentCard();
            }

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMainJourneyCard(_currentTreatment!),
                  const SizedBox(height: 24),
                  _buildDrugList(_currentTreatment!['prescription'] ?? []),
                  const SizedBox(height: 24),
                  _buildHistorySection(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMainJourneyCard(Map<String, dynamic> treatmentData) {
    final treatmentStatus = treatmentData['treatment_status'] ?? 'Berjalan';
    final treatmentTypeId = treatmentData['treatment_type_id'];

    String duration = '--';
    String startDateFormatted = '--';
    String endDateFormatted = '--';

    try {
      if (treatmentData['start_date'] != null &&
          treatmentData['end_date'] != null) {
        final start = DateTime.parse(treatmentData['start_date']);
        final end = DateTime.parse(treatmentData['end_date']);
        duration = _calculateDuration(start, end);
        startDateFormatted = DateFormat('dd MMMM yyyy', 'id_ID').format(start);
        endDateFormatted = DateFormat('dd MMMM yyyy', 'id_ID').format(end);
      }
    } catch (e) {
      log('Error parsing dates for status card: $e');
    }

    String formattedMedicationTime = '--:-- WIB';
    try {
      final rawMedTime = treatmentData['medication_time'];
      if (rawMedTime != null && rawMedTime.toString().trim().isNotEmpty) {
        final medStr = rawMedTime.toString().trim();
        final parts = medStr.split(':');
        if (parts.length >= 2) {
          final hh = parts[0].padLeft(2, '0');
          final mm = parts[1].padLeft(2, '0');
          formattedMedicationTime = '$hh:$mm WIB';
        } else {
          formattedMedicationTime = '$medStr WIB';
        }
      }
    } catch (e) {
      log('Error parsing medication time: $e');
    }

    final isBerjalan = treatmentStatus == 'Berjalan';
    final isSelesai = treatmentStatus == 'Selesai';

    final badgeBgColor =
        isBerjalan
            ? const Color(0xFFECFDF5)
            : isSelesai
            ? const Color(0xFFEFF6FF)
            : const Color(0xFFF3F4F6);

    final badgeTextColor =
        isBerjalan
            ? const Color(0xFF059669)
            : isSelesai
            ? const Color(0xFF2563EB)
            : const Color(0xFF4B5563);

    final badgeBorderColor =
        isBerjalan
            ? const Color(0xFFA7F3D0)
            : isSelesai
            ? const Color(0xFFBFDBFE)
            : const Color(0xFFE5E7EB);

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
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  'Informasi Pengobatan',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBgColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: badgeBorderColor, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isBerjalan
                          ? Icons.play_circle_fill_rounded
                          : isSelesai
                          ? Icons.check_circle_rounded
                          : Icons.help_rounded,
                      size: 12,
                      color: badgeTextColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      treatmentStatus,
                      style: GoogleFonts.plusJakartaSans(
                        color: badgeTextColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24, thickness: 1, color: Color(0xFFF1F5F9)),

          _buildStatusDetailRow(
            Icons.medical_services_rounded,
            "Jenis Pengobatan",
            _getTreatmentType(treatmentTypeId),
          ),
          const Divider(height: 24, thickness: 1, color: Color(0xFFF1F5F9)),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildStatusDetailRow(
                  Icons.calendar_today_rounded,
                  "Tanggal Mulai",
                  startDateFormatted,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatusDetailRow(
                  Icons.event_available_rounded,
                  "Tanggal Selesai",
                  endDateFormatted,
                ),
              ),
            ],
          ),
          const Divider(height: 24, thickness: 1, color: Color(0xFFF1F5F9)),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildStatusDetailRow(
                  Icons.timelapse_rounded,
                  "Durasi Pengobatan",
                  duration,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatusDetailRow(
                  Icons.access_time_rounded,
                  "Waktu Minum Obat",
                  formattedMedicationTime,
                ),
              ),
            ],
          ),

          if (_uploadedToday) ...[
            const Divider(height: 24, thickness: 1, color: Color(0xFFF1F5F9)),
            Row(
              children: [
                const Icon(
                  Icons.verified_rounded,
                  color: Color(0xFF10B981),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Bukti minum obat hari ini sudah berhasil dikirim",
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF10B981),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusDetailRow(IconData icon, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey.shade400),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.grey.shade500,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 22),
          child: Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Riwayat",
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "Catatan aktivitas dan perjalanan pengobatan Anda",
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),
        _buildHistoryActionCard(
          icon: Icons.medication_rounded,
          title: "Riwayat Minum Obat",
          subtitle: "Lihat catatan bukti minum obat",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) =>
                        MedicationHistoryPage(patientId: widget.patientId),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        _buildHistoryActionCard(
          icon: Icons.timeline_rounded,
          title: "Riwayat Pengobatan",
          subtitle: "Lihat perjalanan pengobatan",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) => TreatmentHistoryPage(
                      patientId: widget.patientId,
                      patientName: _patientData['name'] ?? 'Pasien',
                    ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildHistoryActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.grey.shade400,
                  size: 14,
                ),
              ],
            ),
          ),
        ),
      ),
    );
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

  void _showUploadDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
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
                  'Sudah Minum Obat?',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Pastikan Anda sudah minum obat TB hari ini. Anda dapat mengunggah foto sebagai bukti.',
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
                        onPressed: () {
                          Navigator.pop(context);
                        },
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
        );
      },
    );
  }

  Widget _buildDrugList(List<dynamic> prescription) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Daftar Obat",
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),
        if (prescription.isNotEmpty)
          Column(
            children:
                prescription
                    .map((drug) => _buildDrugCard(drug.toString()))
                    .toList(),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade100, width: 1.5),
            ),
            child: Center(
              child: Text(
                "Tidak ada informasi obat.",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDrugCard(String drug) {
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.medication_rounded,
            color: AppColors.primary,
            size: 22,
          ),
        ),
        title: Text(
          drug,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.grey.shade800,
          ),
        ),
      ),
    );
  }

  String _calculateDuration(DateTime startDate, DateTime endDate) {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    final totalDays = end.difference(start).inDays + 1;
    final months = (totalDays / 30).round();
    final displayMonths = months > 0 ? months : 1;
    return '$displayMonths Bulan';
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
                    color: Colors.grey.shade600,
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

  Widget _buildEmptyTreatmentCard() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 60),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.medical_services_outlined,
                color: AppColors.primary,
                size: 38,
              ),
            ),
            const SizedBox(height: 20),
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
              "Belum terdapat informasi pengobatan TB pada akun Anda.",
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.grey.shade600,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F8FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.primary,
                    size: 22,
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
      ),
    );
  }

  Widget _buildErrorState(String message) {
    log('DEBUG ERROR: $message');

    String friendlyMsg =
        'Terjadi kesalahan saat memuat data. Silakan coba lagi.';
    final lowerMsg = message.toLowerCase();

    if (lowerMsg.contains('socketexception') ||
        lowerMsg.contains('koneksi ke server gagal')) {
      friendlyMsg = 'Koneksi ke server gagal. Periksa koneksi internet Anda.';
    } else if (lowerMsg.contains('timeout') ||
        lowerMsg.contains('timeoutexception')) {
      friendlyMsg = 'Waktu muat data habis. Silakan coba lagi.';
    } else if (lowerMsg.contains('401') ||
        lowerMsg.contains('sesi telah berakhir')) {
      friendlyMsg = 'Sesi telah berakhir. Silakan login kembali.';
    } else if (lowerMsg.contains('403') || lowerMsg.contains('akses ditolak')) {
      friendlyMsg =
          'Akses ditolak. Anda tidak memiliki izin untuk melihat data ini.';
    } else if (lowerMsg.contains('404') ||
        lowerMsg.contains('tidak ditemukan')) {
      friendlyMsg = 'Data pengobatan tidak ditemukan.';
    } else if (lowerMsg.contains('500') ||
        lowerMsg.contains('kesalahan pada server')) {
      friendlyMsg = 'Terjadi kesalahan pada server. Silakan coba lagi nanti.';
    } else {
      friendlyMsg =
          message
              .replaceAll('Exception:', '')
              .replaceAll('exception:', '')
              .trim();
      if (friendlyMsg.isEmpty) {
        friendlyMsg = 'Data belum dapat dimuat. Silakan coba lagi.';
      }
    }

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
              friendlyMsg,
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
                onPressed: _refreshTreatmentPage,
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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
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
                      width: 120,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Container(
                      width: 70,
                      height: 22,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ],
                ),
                const Divider(
                  height: 24,
                  thickness: 1,
                  color: Color(0xFFF1F5F9),
                ),
                // Jenis Pengobatan
                Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 100,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 22),
                  child: Container(
                    width: 140,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const Divider(
                  height: 24,
                  thickness: 1,
                  color: Color(0xFFF1F5F9),
                ),
                // Tanggal Mulai & Tanggal Selesai (Dua Kolom)
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                width: 60,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.only(left: 22),
                            child: Container(
                              width: 80,
                              height: 14,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                width: 60,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.only(left: 22),
                            child: Container(
                              width: 80,
                              height: 14,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Durasi & Waktu Minum Obat (Dua Kolom)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                width: 80,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.only(left: 22),
                            child: Container(
                              width: 60,
                              height: 14,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                width: 80,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.only(left: 22),
                            child: Container(
                              width: 80,
                              height: 14,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Daftar Obat
          Container(
            width: 100,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < 2; i++) ...[
            Container(
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade100, width: 1.5),
              ),
            ),
            const SizedBox(height: 12),
          ],
          // Riwayat
          Container(
            width: 80,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 220,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 16),
          for (int i = 0; i < 2; i++) ...[
            Container(
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade100, width: 1.5),
              ),
            ),
            if (i < 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Future<void> _uploadImage(File imageFile, String patientTreatmentId) async {
    final uri = Uri.parse('${Connection.BASE_URL}/treatments/proof');

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    if (token.isEmpty) {
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

    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll({
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    });

    request.fields['patient_treatment_id'] = patientTreatmentId;

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
      final response = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final body = await response.stream.bytesToString();

      debugPrint('UPLOAD STATUS: ${response.statusCode}');
      debugPrint('UPLOAD BODY: $body');

      if (response.statusCode == 201) {
        if (mounted) {
          setState(() {
            _uploadedToday = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Foto berhasil diunggah',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500),
              ),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      } else if (response.statusCode == 401) {
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _handleUnauthorized();
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Upload gagal (${response.statusCode})'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terjadi error: $e'),
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

  void _handleSelectedImage(File imageFile) async {
    if (_currentTreatment == null) {
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final bytes = await imageFile.readAsBytes();
      final decodedImage = img.decodeImage(bytes);

      if (decodedImage == null) {
        throw Exception('Gagal memproses gambar');
      }

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

      await _uploadImage(fixedFile, _currentTreatment!['id'].toString());

      // 🔁 refresh data agar sinkron
      await _refreshTreatmentPage();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal upload: $e'),
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
}
