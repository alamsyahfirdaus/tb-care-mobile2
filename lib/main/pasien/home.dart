// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:apk_tb_care/alarm_service.dart';
import 'package:apk_tb_care/connection.dart';
import 'package:apk_tb_care/main/login.dart';
import 'package:apk_tb_care/main/pasien/consultation.dart';
import 'package:apk_tb_care/main/pasien/education.dart';
import 'package:apk_tb_care/main/pasien/materi_detail.dart';
import 'package:apk_tb_care/main/pasien/treatment.dart';
import 'package:apk_tb_care/main/pasien/visit_schedule_page.dart';
import 'package:apk_tb_care/models/patient_home_model.dart';
import 'package:apk_tb_care/profile.dart';
import 'package:apk_tb_care/services/patient_home_service.dart';
import 'package:apk_tb_care/values/colors.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
  final Set<int> _visitedTabs = {0};

  // State Management
  PatientHomeData? _homeData;
  HomeServiceException? _error;
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isUploading = false;
  bool _alarmSetupCompleted = false;
  String _token = '';

  String? get _currentTreatmentId =>
      _homeData?.treatment?.id != null && _homeData!.treatment!.id > 0
          ? _homeData!.treatment!.id.toString()
          : null;

  bool get _uploadedToday => _homeData?.medication?.isTakenToday == true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  // ===================== DATA LOADING =====================
  Future<void> _loadInitialData() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      _token = prefs.getString('token') ?? '';
    }

    // 1. Tampilkan data dari cache lokal secara instan jika ada
    final cachedData = await PatientHomeService.getCachedHomeData(
      widget.patientId,
    );
    if (mounted && cachedData != null) {
      setState(() {
        _homeData = cachedData;
        _isLoading = false;
      });
      _setupAlarmIfNeeded(cachedData);
    }

    // 2. Muat data terbaru dari API di background / pertama kali
    await _fetchData(isBackground: cachedData != null);
  }

  Future<void> _fetchData({bool isBackground = false}) async {
    if (!isBackground) {
      setState(() {
        _isLoading = _homeData == null;
        _error = null;
      });
    }

    try {
      final freshData = await PatientHomeService.getPatientHome(
        patientId: widget.patientId,
      );

      if (!mounted) return;
      setState(() {
        _homeData = freshData;
        _error = null;
        _isLoading = false;
        _isRefreshing = false;
      });

      _setupAlarmIfNeeded(freshData);
    } on HomeServiceException catch (e) {
      if (!mounted) return;
      if (e.type == HomeErrorType.unauthorized) {
        _handleUnauthorized();
        return;
      }

      setState(() {
        _error = e;
        _isLoading = false;
        _isRefreshing = false;
      });

      // Jika sudah ada data dari cache, tampilkan info banner tanpa menutupi layar
      if (_homeData != null) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Menampilkan data tersimpan. ${e.message}',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF334155),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = HomeServiceException(
          title: 'Data belum dapat dimuat',
          message: 'Terjadi kendala saat memuat data. Silakan coba kembali.',
          type: HomeErrorType.general,
        );
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  Future<void> _refreshHome() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    await _fetchData(isBackground: false);
  }

  Future<void> _handleUnauthorized() async {
    final prefs = await SharedPreferences.getInstance();
    await PatientHomeService.clearCache();
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

  // ===================== ALARM =====================
  Future<void> _setupAlarmIfNeeded(PatientHomeData data) async {
    if (_alarmSetupCompleted) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final isPatient = prefs.getInt('user_type_id') == 2;
      if (!isPatient) return;

      final reminderTime =
          data.medication?.reminderTime ?? data.treatment?.medicationTime;
      if (reminderTime == null || reminderTime.trim().isEmpty) return;

      await AlarmService.initialize();
      await AlarmService.handleTreatment(
        status: data.treatment?.treatmentStatus ?? 'Berjalan',
        medicationTime: reminderTime.trim(),
        visits: data.upcomingVisits.map((v) => v.toJson()).toList(),
      );

      _alarmSetupCompleted = true;
      log('[HOME] Alarm initialized with reminderTime: $reminderTime');
    } catch (e) {
      log('[HOME] Error inisialisasi alarm: $e');
    }
  }

  // ===================== UPLOAD BUKTI MINUM OBAT =====================
  Future<void> _uploadImage(File imageFile, String patientTreatmentId) async {
    final uri = Uri.parse('${Connection.BASE_URL}/treatments/proof');
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null || token.isEmpty) {
      if (mounted) {
        _showAppSnackBar(
          'Sesi telah berakhir. Silakan login kembali.',
          isError: true,
        );
      }
      return;
    }

    if (!await imageFile.exists()) {
      if (mounted) {
        _showAppSnackBar('File gambar bukti tidak ditemukan.', isError: true);
      }
      return;
    }

    setState(() => _isUploading = true);

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
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (mounted) {
          _showAppSnackBar(
            'Bukti minum obat berhasil dikonfirmasi & diunggah.',
            isSuccess: true,
          );
          await _fetchData(isBackground: false);
        }
      } else if (response.statusCode == 401) {
        _handleUnauthorized();
      } else {
        log('[HOME] Upload failed (${response.statusCode}): $responseBody');
        if (mounted) {
          _showAppSnackBar(
            'Gagal mengunggah bukti minum obat. Silakan coba lagi.',
            isError: true,
          );
        }
      }
    } catch (e) {
      log('[HOME] Upload exception: $e');
      if (mounted) {
        _showAppSnackBar(
          'Koneksi terganggu saat mengunggah. Coba lagi.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
      try {
        if (await imageFile.exists()) await imageFile.delete();
      } catch (_) {}
    }
  }

  void _handleSelectedImage(File imageFile) async {
    final treatmentId = _currentTreatmentId;
    if (treatmentId == null) {
      _showAppSnackBar(
        'Program pengobatan belum aktif. Hubungi faskes Anda.',
        isError: true,
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final bytes = await imageFile.readAsBytes();
      final decodedImage = img.decodeImage(bytes);
      if (decodedImage == null) {
        throw Exception('Format gambar tidak didukung.');
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

      await _uploadImage(fixedFile, treatmentId);
    } catch (e) {
      if (mounted) {
        _showAppSnackBar('Gagal memproses gambar: $e', isError: true);
        setState(() => _isUploading = false);
      }
    }
  }

  void _showAppSnackBar(
    String message, {
    bool isSuccess = false,
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        backgroundColor:
            isSuccess
                ? const Color(0xFF10B981)
                : isError
                ? const Color(0xFFEF4444)
                : const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ===================== UI GREETING HELPER =====================
  String _getGreetingText() {
    final hour = DateTime.now().hour;
    if (hour >= 4 && hour < 11) return 'Selamat pagi,';
    if (hour >= 11 && hour < 15) return 'Selamat siang,';
    if (hour >= 15 && hour < 18) return 'Selamat sore,';
    return 'Selamat malam,';
  }

  // ===================== BUILD ROOT =====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _selectedIndex == 0 ? _buildAppBar() : null,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildBerandaTab(),
          _visitedTabs.contains(1)
              ? TreatmentPage(patientId: widget.patientId ?? 0)
              : const SizedBox.shrink(),
          _visitedTabs.contains(2)
              ? const ConsultationPage()
              : const SizedBox.shrink(),
          _visitedTabs.contains(3)
              ? const ProfilePage()
              : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final unreadCount = _homeData?.unreadNotificationsCount ?? 0;

    return AppBar(
      title: const Text('TB Care'),
      actions: [
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(
                Icons.notifications_none_rounded,
                color: Color(0xFFFFFFFF),
                size: 24,
              ),
              onPressed: _showNotificationSheet,
              tooltip: 'Notifikasi',
            ),
            if (unreadCount > 0)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    unreadCount > 9 ? '9+' : '$unreadCount',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: NavigationBar(
        height: 68,
        backgroundColor: Colors.white,
        indicatorColor: AppColors.primary.withValues(alpha: 0.12),
        elevation: 0,
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          if (mounted) {
            setState(() {
              _selectedIndex = index;
              _visitedTabs.add(index);
            });
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: AppColors.primary),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.medication_outlined),
            selectedIcon: Icon(
              Icons.medication_rounded,
              color: AppColors.primary,
            ),
            label: 'Pengobatan',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(
              Icons.chat_bubble_rounded,
              color: AppColors.primary,
            ),
            label: 'Konsultasi',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded, color: AppColors.primary),
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  // ===================== BERANDA TAB CONTENT =====================
  Widget _buildBerandaTab() {
    // 1. Loading State (ketika belum ada cache dan sedang mengambil data awal)
    if (_isLoading && _homeData == null) {
      return _buildSkeletonLoading();
    }

    // 2. Error State (ketika gagal dan tidak ada data cache yang dapat ditampilkan)
    if (_error != null && _homeData == null) {
      return _buildHumanizedErrorState(_error!);
    }

    final data = _homeData!;
    final patientName = data.patient?.name ?? widget.name;
    final puskesmasName = data.patient?.puskesmasName ?? 'Puskesmas';

    return RefreshIndicator(
      onRefresh: _refreshHome,
      color: AppColors.primary,
      backgroundColor: Colors.white,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // A. Header / Greeting
            _buildGreetingHeader(patientName),
            const SizedBox(height: 18),

            // B. Kartu Status Pengobatan
            _buildTreatmentCard(data.treatment, puskesmasName),
            const SizedBox(height: 18),

            // C. Pengingat Pengobatan & Unggah Bukti
            _buildMedicationReminderCard(data.medication, data.treatment),
            const SizedBox(height: 18),

            // D. Jadwal Kunjungan Puskesmas
            _buildNextVisitCard(
              data.nextVisit,
              puskesmasName,
              data.upcomingVisits,
            ),
            const SizedBox(height: 18),

            // E. Materi Edukasi Terbaru
            _buildLatestEducationSection(data.education),
          ],
        ),
      ),
    );
  }

  // ===================== SECTION WIDGETS =====================

  /// A. Greeting Section
  Widget _buildGreetingHeader(String patientName) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.15),
                  AppColors.primary.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
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
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getGreetingText(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  patientName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// B. Status Pengobatan Card
  Widget _buildTreatmentCard(TreatmentInfo? treatment, String puskesmasName) {
    if (treatment == null) {
      return _buildEmptyTreatmentCard();
    }

    final isBerjalan = treatment.treatmentStatus.toLowerCase() == 'berjalan';
    final isSelesai = treatment.treatmentStatus.toLowerCase() == 'selesai';
    final currentDay = treatment.currentDay;
    final totalDays = treatment.totalDays > 0 ? treatment.totalDays : 180;
    final percent = treatment.progressPercent.clamp(0, 100);
    final double progressVal = (percent / 100.0).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E88E5), Color(0xFF0D47A1)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E88E5).withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Judul
              Text(
                'Status Pengobatan',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.2,
                ),
              ),

              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isBerjalan
                          ? Icons.play_circle_fill_rounded
                          : isSelesai
                          ? Icons.check_circle_rounded
                          : Icons.info_rounded,
                      size: 13,
                      color:
                          isBerjalan
                              ? const Color(0xFF10B981)
                              : isSelesai
                              ? const Color(0xFF3B82F6)
                              : const Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isBerjalan ? 'Berjalan' : treatment.treatmentStatus,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color:
                            isBerjalan
                                ? const Color(0xFF065F46)
                                : isSelesai
                                ? const Color(0xFF1E40AF)
                                : const Color(0xFF92400E),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Tipe TB
          Text(
            treatment.treatmentTypeName.isNotEmpty
                ? treatment.treatmentTypeName.toUpperCase()
                : 'KATEGORI 1 (PASIEN BARU)',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white70,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 6),

          // Hari ke-X dari Y hari
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Hari ke-$currentDay',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'dari $totalDays hari',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '($percent% selesai)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 10,
              child: LinearProgressIndicator(
                value: progressVal,
                backgroundColor: Colors.white.withValues(alpha: 0.22),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Periode Tanggal
          if (treatment.startDate != null)
            Row(
              children: [
                const Icon(
                  Icons.calendar_month_rounded,
                  color: Colors.white70,
                  size: 14,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _formatTreatmentPeriod(
                      treatment.startDate,
                      treatment.endDate,
                    ),
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _formatTreatmentPeriod(String? start, String? end) {
    if (start == null || start.trim().isEmpty) return 'Jadwal belum ditentukan';
    try {
      final s = DateTime.parse(start);
      final sStr = DateFormat('d MMMM yyyy', 'id_ID').format(s);
      if (end != null && end.trim().isNotEmpty) {
        final e = DateTime.tryParse(end);
        if (e != null) {
          final eStr = DateFormat('d MMMM yyyy', 'id_ID').format(e);
          return '$sStr s.d. $eStr';
        }
      }
      return 'Mulai: $sStr';
    } catch (_) {
      return 'Mulai: $start';
    }
  }

  Widget _buildEmptyTreatmentCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.medical_services_outlined,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Belum Ada Program Pengobatan Aktif',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Program pengobatan TB Anda akan muncul di sini setelah didaftarkan oleh petugas Puskesmas.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: const Color(0xFF64748B),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  /// C. Pengingat Pengobatan Card
  Widget _buildMedicationReminderCard(
    MedicationInfo? med,
    TreatmentInfo? treatment,
  ) {
    final reminderTime =
        med?.reminderTime ?? treatment?.medicationTime ?? '20:00';
    final formattedTime =
        reminderTime.length >= 5 ? reminderTime.substring(0, 5) : reminderTime;
    final isTaken = _uploadedToday;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.alarm_on_rounded,
                  color: Color(0xFF16A34A),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pengingat Pengobatan',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Waktunya minum obat: Hari ini, $formattedTime WIB',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Status & Action
          if (isTaken)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF86EFAC)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF15803D),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Sudah minum obat hari ini',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF15803D),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _isUploading ? null : _showUploadDialog,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Perbarui Bukti',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF166534),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isUploading ? null : _showUploadDialog,
                icon:
                    _isUploading
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 20,
                        ),
                label: Text(
                  _isUploading
                      ? 'Sedang Mengunggah...'
                      : 'Tandai Sudah Minum Obat',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// D. Jadwal Kunjungan Puskesmas Card
  Widget _buildNextVisitCard(
    VisitInfo? nextVisit,
    String puskesmasName,
    List<VisitInfo> upcomingVisits,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
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
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.local_hospital_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Kunjungan Berikutnya',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              OutlinedButton(
                onPressed:
                    () => _openVisitSchedulePage(puskesmasName, upcomingVisits),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Lihat Jadwal',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (nextVisit != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.event_available_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        nextVisit.formattedDate,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${nextVisit.formattedTime} WIB',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0284C7),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          nextVisit.puskesmasName,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF475569),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (nextVisit.notes != null &&
                      nextVisit.notes!.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Catatan: ${nextVisit.notes}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    size: 20,
                    color: Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Belum ada jadwal kunjungan',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Anda belum memiliki jadwal kunjungan berikutnya.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
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

  void _openVisitSchedulePage(
    String puskesmasName,
    List<VisitInfo> upcomingVisits,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => VisitSchedulePage(
              patientId: widget.patientId ?? 0,
              treatmentId: int.tryParse(_currentTreatmentId ?? '0'),
              puskesmasName: puskesmasName,
              initialVisits: upcomingVisits.map((v) => v.toJson()).toList(),
            ),
      ),
    );
  }

  // ===================== E. MATERI EDUKASI TERBARU =====================
  /// E. Materi Edukasi Terbaru Section
  Widget _buildLatestEducationSection(List<EducationItem> educationList) {
    final items = educationList.take(3).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
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
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.menu_book_rounded,
                      color: Color(0xFF16A34A),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Materi Edukasi Terbaru',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const EducationPage()),
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Lihat Semua',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.school_outlined,
                    size: 22,
                    color: Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Belum ada materi edukasi',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Materi edukasi terbaru seputar pengobatan TB akan ditampilkan di sini.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return _buildEducationCard(items[index]);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildEducationCard(EducationItem item) {
    final formattedDate = _formatEducationDate(item.createdAt);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MateriDetailPage(materialId: item.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: _buildEducationThumbnail(item),
                ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildEducationBadge(item.materialType),
                    const SizedBox(height: 6),
                    Text(
                      item.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E293B),
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.description != null &&
                        item.description!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.description!.trim(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: const Color(0xFF64748B),
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (formattedDate.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_rounded,
                            size: 11,
                            color: Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            formattedDate,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEducationThumbnail(EducationItem item) {
    final lowerType = item.materialType.toLowerCase();

    if (lowerType == 'video') {
      final thumbUrl = _getYoutubeThumbnail(item.videoUrl);
      if (thumbUrl != null && thumbUrl.isNotEmpty) {
        return Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: thumbUrl,
              fit: BoxFit.cover,
              placeholder:
                  (_, __) => Container(
                    color: const Color(0xFFE2E8F0),
                    child: const Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
              errorWidget:
                  (_, __, ___) => Container(
                    color: const Color(0xFFE2E8F0),
                    child: const Icon(
                      Icons.video_library_rounded,
                      color: Color(0xFF94A3B8),
                      size: 28,
                    ),
                  ),
            ),
            Center(
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        );
      }
      return Container(
        color: const Color(0xFFFEE2E2),
        child: const Center(
          child: Icon(
            Icons.play_circle_fill_rounded,
            color: Color(0xFFDC2626),
            size: 32,
          ),
        ),
      );
    }

    final imageUrl = _resolveImageUrl(item.photo);
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        httpHeaders:
            _token.isNotEmpty ? {'Authorization': 'Bearer $_token'} : null,
        fit: BoxFit.cover,
        placeholder:
            (_, __) => Container(
              color: const Color(0xFFE2E8F0),
              child: const Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        errorWidget: (context, url, error) {
          debugPrint(
            '[HomeEducation] Image load error for url: $url, error: $error',
          );
          return Container(
            color: const Color(0xFFE2E8F0),
            child: const Icon(
              Icons.broken_image_rounded,
              color: Color(0xFF94A3B8),
              size: 28,
            ),
          );
        },
      );
    }

    return Container(
      color: const Color(0xFFF1F5F9),
      child: Center(
        child: Icon(
          lowerType == 'poster' || lowerType == 'image'
              ? Icons.image_rounded
              : Icons.menu_book_rounded,
          color: const Color(0xFF94A3B8),
          size: 28,
        ),
      ),
    );
  }

  Widget _buildEducationBadge(String type) {
    final lower = type.toLowerCase();
    Color bg;
    Color textColor;
    IconData icon;
    String label;

    if (lower == 'video') {
      bg = const Color(0xFFFEE2E2);
      textColor = const Color(0xFFDC2626);
      icon = Icons.play_arrow_rounded;
      label = 'Video';
    } else if (lower == 'poster' || lower == 'image' || lower == 'gambar') {
      bg = const Color(0xFFD1FAE5);
      textColor = const Color(0xFF059669);
      icon = Icons.image_rounded;
      label = lower == 'poster' ? 'Poster' : 'Gambar';
    } else {
      bg = const Color(0xFFE0F2FE);
      textColor = const Color(0xFF0284C7);
      icon = Icons.article_rounded;
      label = 'Artikel';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: textColor),
          const SizedBox(width: 3),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  String? _getYoutubeThumbnail(String? videoUrl) {
    if (videoUrl == null || videoUrl.isEmpty) return null;
    try {
      final regExp = RegExp(
        r'(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})',
        caseSensitive: false,
      );
      final match = regExp.firstMatch(videoUrl);
      final videoId = match?.group(1);
      if (videoId != null && videoId.isNotEmpty) {
        return 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
      }
    } catch (_) {}
    return null;
  }

  String? _resolveImageUrl(String? photo) {
    return Connection.resolveImageUrl(photo);
  }

  String _formatEducationDate(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return '';
    try {
      final dt = DateTime.parse(rawDate);
      return DateFormat('d MMMM yyyy', 'id_ID').format(dt);
    } catch (_) {
      try {
        final dt = DateFormat('yyyy-MM-dd HH:mm').parse(rawDate);
        return DateFormat('d MMMM yyyy', 'id_ID').format(dt);
      } catch (_) {
        return rawDate;
      }
    }
  }

  // ===================== NOTIFICATION BOTTOM SHEET =====================
  void _showNotificationSheet() {
    final notifs = _homeData?.notifications ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.65,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Notifikasi & Informasi',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: Color(0xFFF1F5F9)),
              const SizedBox(height: 8),

              Expanded(
                child:
                    notifs.isNotEmpty
                        ? ListView.separated(
                          itemCount: notifs.length,
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final n = notifs[index];
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  Navigator.pop(context);
                                  final lower = n.type.toLowerCase();
                                  if (lower.contains('edukasi') ||
                                      lower.contains('education')) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const EducationPage(),
                                      ),
                                    );
                                  }
                                },
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary
                                                  .withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              n.type,
                                              style:
                                                  GoogleFonts.plusJakartaSans(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.primary,
                                                  ),
                                            ),
                                          ),
                                          const Spacer(),
                                          if (n.createdAt != null)
                                            Text(
                                              n.createdAt!,
                                              style:
                                                  GoogleFonts.plusJakartaSans(
                                                    fontSize: 11,
                                                    color: const Color(
                                                      0xFF94A3B8,
                                                    ),
                                                  ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        n.title,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF1E293B),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        n.message,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          color: const Color(0xFF64748B),
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        )
                        : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.notifications_off_outlined,
                                size: 40,
                                color: Color(0xFF94A3B8),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Belum ada notifikasi baru',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),
                        ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ===================== UPLOAD DIALOGS =====================
  void _showUploadDialog() {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.medication_rounded,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Konfirmasi Minum Obat',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Apakah Anda sudah meminum obat TB hari ini? Silakan unggah foto sebagai bukti untuk pemantauan petugas.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: const Color(0xFF64748B),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Nanti',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
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
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Unggah Foto',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
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
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Unggah Bukti Minum Obat',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 18),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
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
                    if (photo != null) _handleSelectedImage(File(photo.path));
                  },
                ),
                const Divider(color: Color(0xFFF1F5F9)),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
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
                    if (image != null) _handleSelectedImage(File(image.path));
                  },
                ),
              ],
            ),
          ),
    );
  }

  // ===================== ERROR & LOADING STATES =====================

  /// Humanized Error State matching Section 5
  Widget _buildHumanizedErrorState(HomeServiceException err) {
    IconData errorIcon = Icons.cloud_off_rounded;
    Color iconColor = const Color(0xFFEF4444);
    Color bgColor = const Color(0xFFFEF2F2);
    String buttonText = 'Coba Lagi';
    VoidCallback onButtonTap = _refreshHome;

    if (err.type == HomeErrorType.timeout) {
      errorIcon = Icons.timer_outlined;
      iconColor = const Color(0xFFF59E0B);
      bgColor = const Color(0xFFFFFBEB);
      buttonText = 'Coba Lagi';
      onButtonTap = _refreshHome;
    } else if (err.type == HomeErrorType.offline) {
      errorIcon = Icons.wifi_off_rounded;
      iconColor = const Color(0xFF64748B);
      bgColor = const Color(0xFFF1F5F9);
      buttonText = 'Coba Lagi';
      onButtonTap = _refreshHome;
    } else if (err.type == HomeErrorType.unauthorized) {
      errorIcon = Icons.lock_outline_rounded;
      iconColor = const Color(0xFFEF4444);
      bgColor = const Color(0xFFFEF2F2);
      buttonText = 'Masuk Kembali';
      onButtonTap = _handleUnauthorized;
    } else if (err.type == HomeErrorType.server) {
      errorIcon = Icons.dns_rounded;
      iconColor = const Color(0xFFDC2626);
      bgColor = const Color(0xFFFEF2F2);
      buttonText = 'Coba Lagi';
      onButtonTap = _refreshHome;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
              child: Icon(errorIcon, color: iconColor, size: 48),
            ),
            const SizedBox(height: 20),
            Text(
              err.title,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              err.message,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: const Color(0xFF64748B),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 46,
              child: ElevatedButton.icon(
                onPressed: _isRefreshing ? null : onButtonTap,
                icon:
                    _isRefreshing
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Icon(Icons.refresh_rounded, size: 18),
                label: Text(
                  _isRefreshing ? 'Memuat...' : buttonText,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
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

  /// Modern Skeleton Loader
  Widget _buildSkeletonLoading() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting Skeleton
          _buildShimmerBox(height: 86, borderRadius: 20),
          const SizedBox(height: 18),

          // Treatment Skeleton
          _buildShimmerBox(height: 190, borderRadius: 22),
          const SizedBox(height: 18),

          // Reminder Skeleton
          _buildShimmerBox(height: 110, borderRadius: 20),
          const SizedBox(height: 18),

          // Visit Skeleton
          _buildShimmerBox(height: 120, borderRadius: 20),
          const SizedBox(height: 18),

          // Education Skeleton
          _buildShimmerBox(height: 180, borderRadius: 20),
        ],
      ),
    );
  }

  Widget _buildShimmerBox({
    required double height,
    required double borderRadius,
  }) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}
