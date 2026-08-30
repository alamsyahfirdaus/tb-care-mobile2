import 'dart:convert';
import 'package:apk_tb_care/main/pasien/consultation.dart';
import 'package:apk_tb_care/main/pasien/education.dart';
import 'package:apk_tb_care/main/petugas/patient.dart';
import 'package:apk_tb_care/connection.dart';
import 'package:apk_tb_care/profile.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apk_tb_care/values/colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:apk_tb_care/main/pasien/history.dart';
import 'package:apk_tb_care/main/pasien/treatment_history.dart';
import 'package:apk_tb_care/main/petugas/edit_patient.dart';
import 'package:apk_tb_care/main/petugas/treatment_managment.dart';
import 'package:apk_tb_care/main/petugas/visit_managment.dart';

class StaffHomePage extends StatefulWidget {
  final String name;

  const StaffHomePage({super.key, required this.name});

  @override
  State<StaffHomePage> createState() => _StaffHomePageState();
}

class _StaffHomePageState extends State<StaffHomePage> {
  int _selectedIndex = 0;
  List<Map<String, dynamic>> _patientData = [];

  // Retain instances of tab pages to preserve state in IndexedStack
  late final List<Widget> _navigationPages;

  double? _adherenceRate;
  bool _isAdherenceLoading = true;
  bool _hasAdherenceError = false;

  bool _isPatientsLoading = true;
  bool _hasPatientsError = false;

  @override
  void initState() {
    super.initState();
    _navigationPages = [
      const PatientPage(),
      const EducationPage(isStaff: true),
      const ConsultationPage(isStaff: true),
      const ProfilePage(),
    ];
    _fetchPatientData();
    _fetchAdherenceRate();
  }

  // ===========================================================================
  // API & DATA FETCHING
  // ===========================================================================

  Future<void> _fetchPatientData() async {
    if (!mounted) return;
    setState(() {
      _isPatientsLoading = true;
      _hasPatientsError = false;
    });

    final session = await SharedPreferences.getInstance();
    final token = session.getString('token') ?? '';

    try {
      final response = await http.get(
        Uri.parse('${Connection.BASE_URL}/patients'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final dynamic dataJson = jsonDecode(response.body);
        if (dataJson is Map<String, dynamic> && dataJson['data'] is List) {
          final list = dataJson['data'] as List;
          setState(() {
            _patientData = list.whereType<Map<String, dynamic>>().toList();
            _isPatientsLoading = false;
          });
        } else {
          setState(() {
            _patientData = [];
            _isPatientsLoading = false;
          });
        }
      } else {
        throw Exception('Status code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching patient data: $e');
      if (mounted) {
        setState(() {
          _isPatientsLoading = false;
          _hasPatientsError = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal memuat data pasien. Silakan coba lagi.',
              style: GoogleFonts.plusJakartaSans(fontSize: 12),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _fetchAdherenceRate() async {
    if (!mounted) return;
    setState(() {
      _isAdherenceLoading = true;
      _hasAdherenceError = false;
    });

    final session = await SharedPreferences.getInstance();
    final token = session.getString('token') ?? '';

    try {
      final response = await http.get(
        Uri.parse('${Connection.BASE_URL}/patients/adherence'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final dynamic dataJson = jsonDecode(response.body);

        if (dataJson is Map<String, dynamic> &&
            dataJson['data'] is Map<String, dynamic> &&
            dataJson['data']['adherence_average'] != null) {
          final rawValue =
              dataJson['data']['adherence_average']
                  .toString()
                  .replaceAll('%', '')
                  .trim();

          final rate = double.tryParse(rawValue);
          setState(() {
            _adherenceRate = rate;
            _isAdherenceLoading = false;
            _hasAdherenceError = rate == null;
          });
        } else {
          setState(() {
            _adherenceRate = null;
            _isAdherenceLoading = false;
            _hasAdherenceError = false;
          });
        }
      } else {
        throw Exception('Status code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Adherence API Error: $e');
      if (mounted) {
        setState(() {
          _isAdherenceLoading = false;
          _hasAdherenceError = true;
        });
      }
    }
  }

  // ===========================================================================
  // BUSINESS LOGIC & HELPERS
  // ===========================================================================

  /// Mendapatkan tanggal registrasi atau pendaftaran pasien.
  /// Memeriksa field direct: created_at, registered_at, registration_date, diagnosis_date.
  /// Jika tidak tersedia pada object pasien, fallback ke start_date pengobatan aktif/terkini.
  DateTime? _getPatientRegistrationDate(Map<String, dynamic> patient) {
    for (final key in [
      'created_at',
      'registered_at',
      'registration_date',
      'diagnosis_date',
    ]) {
      final val = patient[key];
      if (val != null) {
        final parsed = DateTime.tryParse(val.toString().trim());
        if (parsed != null) return parsed;
      }
    }
    final treatment = _getLatestOrActiveTreatment(patient);
    if (treatment != null && treatment['start_date'] != null) {
      final parsed = DateTime.tryParse(
        treatment['start_date'].toString().trim(),
      );
      if (parsed != null) return parsed;
    }
    return null;
  }

  /// Mendapatkan treatment yang sedang aktif ('Berjalan').
  /// String status dinormalisasi (trim & lowercase) untuk menghindari kegagalan pencocokan.
  Map<String, dynamic>? _getActiveTreatment(Map<String, dynamic> patient) {
    final treatments = patient['treatments'];
    if (treatments is! List || treatments.isEmpty) {
      return null;
    }

    for (final treatment in treatments) {
      if (treatment is Map<String, dynamic>) {
        final status =
            treatment['treatment_status']?.toString().trim().toLowerCase();
        if (status == 'berjalan') {
          return treatment;
        }
      }
    }

    return null;
  }

  /// Mendapatkan satu treatment paling relevan (prioritas Berjalan, atau treatment terbaru).
  /// Menghindari double-counting pasien dengan riwayat pengobatan majemuk.
  Map<String, dynamic>? _getLatestOrActiveTreatment(
    Map<String, dynamic> patient,
  ) {
    final treatments = patient['treatments'];
    if (treatments is! List || treatments.isEmpty) {
      return null;
    }

    final active = _getActiveTreatment(patient);
    if (active != null) return active;

    Map<String, dynamic>? latest;
    DateTime? latestDate;
    for (final t in treatments) {
      if (t is Map<String, dynamic>) {
        final dateStr = t['start_date'];
        if (dateStr != null) {
          final date = DateTime.tryParse(dateStr.toString().trim());
          if (date != null) {
            if (latestDate == null || date.isAfter(latestDate)) {
              latestDate = date;
              latest = t;
            }
          }
        }
      }
    }
    return latest ??
        (treatments.first is Map<String, dynamic>
            ? treatments.first as Map<String, dynamic>
            : null);
  }

  /// Menggabungkan tanggal dan jam kunjungan secara aman.
  /// Jika jam tidak tersedia, mengembalikan tanggal pada 00:00:00.
  DateTime? _parseVisitDateTime(dynamic date, dynamic time) {
    if (date == null) return null;
    try {
      final dateStr = date.toString().trim();
      if (dateStr.isEmpty) return null;
      final parsedDate = DateTime.parse(dateStr);

      if (time == null) {
        return DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
      }

      final timeStr = time.toString().trim();
      if (timeStr.isEmpty) {
        return DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
      }

      final parts = timeStr.split(':');
      final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
      final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
      final second = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;

      return DateTime(
        parsedDate.year,
        parsedDate.month,
        parsedDate.day,
        hour,
        minute,
        second,
      );
    } catch (e) {
      try {
        return DateTime.parse(date.toString().trim());
      } catch (_) {
        return null;
      }
    }
  }

  /// Memformat jam minum obat (HH:mm).
  String _formatMedicationTime(dynamic value) {
    if (value == null) return "-";
    final str = value.toString().trim();
    if (str.isEmpty) return "-";

    final parts = str.split(':');
    if (parts.length >= 2) {
      final hour = parts[0].padLeft(2, '0');
      final minute = parts[1].padLeft(2, '0');
      return "$hour:$minute";
    }

    return str.length >= 5 ? str.substring(0, 5) : str;
  }

  /// Memformat label jenis kelamin.
  String _formatGender(dynamic value) {
    if (value == null) return "-";
    final str = value.toString().trim().toUpperCase();
    if (str == 'L') {
      return 'Laki-laki';
    } else if (str == 'P') {
      return 'Perempuan';
    }
    return str.isNotEmpty ? str : "-";
  }

  /// Menghitung progress pengobatan secara akurat dan clamped [0.0, 1.0].
  Map<String, dynamic> _calculateTreatmentProgress(
    Map<String, dynamic>? treatment,
  ) {
    if (treatment == null ||
        treatment['start_date'] == null ||
        treatment['end_date'] == null) {
      return {
        'hasDates': false,
        'daysPassed': 0,
        'totalDays': 0,
        'progress': 0.0,
      };
    }
    try {
      final startDate = DateTime.parse(
        treatment['start_date'].toString().trim(),
      );
      final endDate = DateTime.parse(treatment['end_date'].toString().trim());

      if (startDate.isAfter(endDate)) {
        return {
          'hasDates': true,
          'daysPassed': 0,
          'totalDays': 0,
          'progress': 0.0,
        };
      }

      final totalDays = endDate.difference(startDate).inDays;
      if (totalDays <= 0) {
        return {
          'hasDates': true,
          'daysPassed': 1,
          'totalDays': 1,
          'progress': 1.0,
        };
      }

      final now = DateTime.now();
      final todayMidnight = DateTime(now.year, now.month, now.day);
      final startMidnight = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
      );
      final endMidnight = DateTime(endDate.year, endDate.month, endDate.day);

      int daysPassed = 0;
      double progress = 0.0;

      if (todayMidnight.isBefore(startMidnight)) {
        daysPassed = 0;
        progress = 0.0;
      } else if (todayMidnight.isAfter(endMidnight)) {
        daysPassed = totalDays;
        progress = 1.0;
      } else {
        // Hari ke-1 dimulai pada tanggal mulai pengobatan
        daysPassed = todayMidnight.difference(startMidnight).inDays + 1;
        daysPassed = daysPassed.clamp(1, totalDays);
        progress = (daysPassed / totalDays).clamp(0.0, 1.0);
      }

      return {
        'hasDates': true,
        'daysPassed': daysPassed,
        'totalDays': totalDays,
        'progress': progress,
      };
    } catch (e) {
      debugPrint('Error calculating progress: $e');
      return {
        'hasDates': false,
        'daysPassed': 0,
        'totalDays': 0,
        'progress': 0.0,
      };
    }
  }

  Widget _buildStaffHomePage() {
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: Colors.white,
      onRefresh: () async {
        await Future.wait([_fetchPatientData(), _fetchAdherenceRate()]);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStaffGreetingSection(),
            const SizedBox(height: 24),
            _buildQuickStats(),
            const SizedBox(height: 24),
            _buildAdherenceCard(),
            const SizedBox(height: 24),
            _buildFullStats(),
            const SizedBox(height: 24),
            _buildRecentPatientsSection(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffGreetingSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.person_rounded, color: Colors.white, size: 28),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Selamat Datang,',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.85),
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
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    if (_isPatientsLoading) {
      return Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade100, width: 1.5),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 32,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 55,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade100, width: 1.5),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 32,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 55,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (_hasPatientsError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            'Gagal memuat statistik',
            style: GoogleFonts.plusJakartaSans(color: Colors.red, fontSize: 13),
          ),
        ),
      );
    }

    final totalPatients = _patientData.length;

    // Menghitung pasien baru berdasarkan tanggal registrasi/mulai (0 <= diffDays <= 30)
    final newPatientsCount =
        _patientData.where((patient) {
          final regDate = _getPatientRegistrationDate(patient);
          if (regDate == null) return false;
          final now = DateTime.now();
          final regMidnight = DateTime(
            regDate.year,
            regDate.month,
            regDate.day,
          );
          final nowMidnight = DateTime(now.year, now.month, now.day);
          final diffDays = nowMidnight.difference(regMidnight).inDays;
          return diffDays >= 0 && diffDays <= 30;
        }).length;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            value: totalPatients.toString(),
            label: 'Total Pasien',
            icon: Icons.people_alt_outlined,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            value: newPatientsCount.toString(),
            label: 'Pasien Baru',
            icon: Icons.person_add_outlined,
            color: Colors.green.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String value,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdherenceCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.black.withOpacity(0.01),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 20),
            child: Text(
              'Analisis Kepatuhan',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: _buildAdherenceContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildAdherenceContent() {
    if (_isAdherenceLoading) {
      return Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 120,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 180,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (_hasAdherenceError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: Colors.red[400],
                size: 36,
              ),
              const SizedBox(height: 8),
              Text(
                'Gagal memuat tingkat kepatuhan',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.grey[800],
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _fetchAdherenceRate,
                icon: const Icon(Icons.refresh_rounded, size: 14),
                label: const Text('Coba Lagi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_adherenceRate == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Icon(
                Icons.insert_chart_outlined_rounded,
                color: Colors.grey[300],
                size: 36,
              ),
              const SizedBox(height: 8),
              Text(
                'Belum ada data kepatuhan',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.grey[500],
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final rate = _adherenceRate!;
    final String statusText;
    final Color statusColor;

    if (rate > 80) {
      statusText = 'Baik';
      statusColor = Colors.green.shade600;
    } else if (rate > 60) {
      statusText = 'Cukup';
      statusColor = Colors.orange.shade600;
    } else {
      statusText = 'Kurang';
      statusColor = Colors.red.shade600;
    }

    return Row(
      children: [
        // Circular Progress Indicator
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 70,
              height: 70,
              child: CircularProgressIndicator(
                value: rate / 100,
                strokeWidth: 8,
                backgroundColor: Colors.grey[100],
                color: statusColor,
                strokeCap: StrokeCap.round,
              ),
            ),
            Text(
              '${rate.toStringAsFixed(0)}%',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
          ],
        ),
        const SizedBox(width: 20),
        // Description and badge
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Kepatuhan Rata-rata',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusText,
                      style: GoogleFonts.plusJakartaSans(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 9,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Rata-rata tingkat kepatuhan minum obat seluruh pasien terpantau.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: Colors.grey[500],
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecentPatientsSection() {
    if (_isPatientsLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Pasien Terkini',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            children: List.generate(
              3,
              (index) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade100, width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 140,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: 80,
                            height: 10,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (_hasPatientsError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Text(
                'Gagal memuat data pasien',
                style: GoogleFonts.plusJakartaSans(color: Colors.grey[800]),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _fetchPatientData,
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    // Urutkan pasien berdasarkan tanggal pendaftaran/pengobatan terbaru
    final sortedPatients = List<Map<String, dynamic>>.from(_patientData);
    sortedPatients.sort((a, b) {
      final dateA = _getPatientRegistrationDate(a);
      final dateB = _getPatientRegistrationDate(b);

      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;

      return dateB.compareTo(dateA);
    });

    final recentPatients = sortedPatients.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Pasien Terkini',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedIndex = 1; // Navigasi ke daftar pasien
                });
              },
              child: Text(
                'Lihat Semua',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (recentPatients.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Icon(Icons.people_outline, size: 48, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text(
                    'Belum Ada Pasien',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Belum terdapat data pasien yang perlu ditampilkan.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (recentPatients.isNotEmpty)
          Column(
            children:
                recentPatients
                    .map((patient) => _buildPatientCard(patient))
                    .toList(),
          ),
      ],
    );
  }

  Widget _buildPatientCard(Map<String, dynamic> patient) {
    final treatment = _getActiveTreatment(patient);

    final progressData = _calculateTreatmentProgress(treatment);
    final bool hasDates = progressData['hasDates'];
    final int daysPassed = progressData['daysPassed'];
    final int totalDays = progressData['totalDays'];
    final double progress = progressData['progress'];

    String nextVisitDate = '--/--';
    String nextVisitTime = '--:--';

    if (treatment != null && treatment['visits'] is List) {
      final List<dynamic> visitsList = treatment['visits'];
      final parsedVisits = <Map<String, dynamic>>[];

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      for (var visit in visitsList) {
        if (visit is Map<String, dynamic>) {
          final hasTime =
              visit['visit_time'] != null &&
              visit['visit_time'].toString().trim().isNotEmpty;
          final visitDT = _parseVisitDateTime(
            visit['visit_date'],
            visit['visit_time'],
          );
          if (visitDT != null) {
            final isUpcoming =
                hasTime ? visitDT.isAfter(now) : !visitDT.isBefore(todayStart);
            if (isUpcoming) {
              parsedVisits.add({
                'visit': visit,
                'dateTime': visitDT,
                'hasTime': hasTime,
              });
            }
          }
        }
      }

      parsedVisits.sort((a, b) {
        final dtA = a['dateTime'] as DateTime;
        final dtB = b['dateTime'] as DateTime;
        return dtA.compareTo(dtB);
      });

      if (parsedVisits.isNotEmpty) {
        final next = parsedVisits.first;
        final nextVisitDT = next['dateTime'] as DateTime;
        final hasTime = next['hasTime'] as bool;

        try {
          nextVisitDate = DateFormat('dd/MM').format(nextVisitDT);
          nextVisitTime =
              hasTime ? DateFormat('HH:mm').format(nextVisitDT) : '--:--';
        } catch (e) {
          debugPrint('Error formatting next visit: $e');
        }
      }
    }

    final treatmentStatus = treatment?['treatment_status'] ?? 'Belum Mulai';
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 380;

    Widget visitInfo = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 12,
            color: Colors.grey[500],
          ),
          const SizedBox(width: 6),
          Text(
            'Kunjungan: $nextVisitDate @ $nextVisitTime',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );

    Widget visitInfoSide = Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'KUNJUNGAN',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 8,
              color: Colors.grey[500],
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            nextVisitDate,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
          Text(
            nextVisitTime,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              color: Colors.grey[500],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showPatientDetail(patient),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.primary.withValues(
                        alpha: 0.08,
                      ),
                      child: Text(
                        patient['name']?.isNotEmpty == true
                            ? patient['name'][0].toUpperCase()
                            : '?',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            patient['name'] ?? 'Nama tidak tersedia',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppColors.text,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(children: [_buildStatusChip(treatmentStatus)]),
                        ],
                      ),
                    ),
                    if (!isNarrow) ...[
                      const SizedBox(width: 12),
                      visitInfoSide,
                    ],
                  ],
                ),
                if (hasDates) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.grey[100],
                            color: AppColors.primary,
                            minHeight: 4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Hari $daysPassed/$totalDays',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
                if (isNarrow) ...[const SizedBox(height: 10), visitInfo],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color bg = Colors.grey[100]!;
    Color text = Colors.grey[800]!;

    final normalized = status.trim().toLowerCase();
    if (normalized == 'berjalan') {
      bg = Colors.blue.shade50;
      text = Colors.blue.shade700;
    } else if (normalized == 'selesai') {
      bg = Colors.green.shade50;
      text = Colors.green.shade700;
    } else if (normalized == 'gagal') {
      bg = Colors.red.shade50;
      text = Colors.red.shade700;
    } else if (normalized == 'meninggal') {
      bg = Colors.amber.shade50;
      text = Colors.amber.shade900;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          color: text,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildFullStats() {
    if (_isPatientsLoading) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade100, width: 1.5),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_hasPatientsError) {
      return const SizedBox.shrink();
    }

    int activeCount = 0;
    int completedCount = 0;
    int failedCount = 0;
    int deceasedCount = 0;

    for (final patient in _patientData) {
      final treatment = _getLatestOrActiveTreatment(patient);
      if (treatment != null && treatment['treatment_status'] != null) {
        final status =
            treatment['treatment_status'].toString().trim().toLowerCase();
        switch (status) {
          case 'berjalan':
            activeCount++;
            break;
          case 'selesai':
            completedCount++;
            break;
          case 'gagal':
            failedCount++;
            break;
          case 'meninggal':
            deceasedCount++;
            break;
        }
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Statistik Pengobatan',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMiniStatCard(
                  value: activeCount.toString(),
                  label: 'Aktif',
                  color: Colors.blue.shade600,
                ),
                _buildMiniStatCard(
                  value: completedCount.toString(),
                  label: 'Selesai',
                  color: Colors.green.shade600,
                ),
                _buildMiniStatCard(
                  value: failedCount.toString(),
                  label: 'Gagal',
                  color: Colors.red.shade600,
                ),
                _buildMiniStatCard(
                  value: deceasedCount.toString(),
                  label: 'Meninggal',
                  color: Colors.amber.shade700,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStatCard({
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            color: Colors.grey[600],
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  void _showPatientDetail(Map<String, dynamic> patient) {
    final treatment = _getActiveTreatment(patient);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Profil Pasien',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Patient Summary Card inside BottomSheet
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: AppColors.primary.withValues(
                          alpha: 0.1,
                        ),
                        child: Text(
                          patient['name']?.isNotEmpty == true
                              ? patient['name'][0].toUpperCase()
                              : '?',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              patient['name'] ?? 'Nama tidak tersedia',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.text,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'NIK: ${patient['nik'] == null || patient['nik'].toString().isEmpty ? '-' : patient['nik'].toString()}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: Colors.grey[500],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Details Grid
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    children: [
                      _buildDetailRow('Alamat', patient['address'] ?? '-'),
                      _buildDetailRow('Telepon', patient['phone'] ?? '-'),
                      _buildDetailRow(
                        'Jenis Kelamin',
                        _formatGender(patient['gender']),
                      ),
                      _buildDetailRow(
                        'Tanggal Lahir',
                        patient['date_of_birth'] ?? '-',
                      ),
                      _buildDetailRow('Puskesmas', patient['puskesmas'] ?? '-'),
                      _buildDetailRow(
                        'Kecamatan',
                        patient['subdistrict'] ?? '-',
                      ),
                      _buildDetailRow(
                        'Status Pengobatan',
                        treatment?['treatment_status'] ??
                            'Belum ada pengobatan',
                      ),
                      if (treatment != null) ...[
                        if (treatment['start_date'] != null &&
                            treatment['end_date'] != null)
                          _buildDetailRow(
                            'Periode Pengobatan',
                            '${treatment['start_date']} - ${treatment['end_date']}',
                          ),
                        _buildDetailRow(
                          'Waktu Minum Obat',
                          _formatMedicationTime(treatment['medication_time']),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons Section - Row 1
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Edit Data'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Colors.grey),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) =>
                                      EditPatientPage(patientId: patient['id']),
                            ),
                          ).then((_) {
                            if (mounted) {
                              _fetchPatientData();
                              _fetchAdherenceRate();
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(
                          Icons.medical_services_outlined,
                          size: 18,
                        ),
                        label: Text(
                          treatment != null ? 'Pengobatan' : 'Buat Pengobatan',
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) {
                                final status =
                                    treatment?['treatment_status']
                                        ?.toString()
                                        .trim()
                                        .toLowerCase();
                                if (treatment != null && status == 'berjalan') {
                                  return TreatmentManagementPage(
                                    patientId: patient['id'],
                                    patientName: patient['name'] ?? 'Pasien',
                                    existingTreatment: treatment,
                                    onShowHistory: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) => TreatmentHistoryPage(
                                                patientId: patient['id'],
                                                patientName:
                                                    patient['name'] ?? 'Pasien',
                                              ),
                                        ),
                                      );
                                    },
                                  );
                                } else {
                                  return TreatmentHistoryPage(
                                    patientId: patient['id'],
                                    patientName: patient['name'] ?? 'Pasien',
                                    isStaff: true,
                                    isDone: true,
                                  );
                                }
                              },
                            ),
                          ).then((_) {
                            if (mounted) {
                              _fetchPatientData();
                              _fetchAdherenceRate();
                            }
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Action Buttons Section - Row 2
                if (treatment != null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(
                            Icons.calendar_today_outlined,
                            size: 18,
                          ),
                          label: const Text('Kunjungan'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: Colors.green[700],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => VisitManagementPage(
                                      patientId: patient['id'],
                                      patientTreatmentId: treatment['id'],
                                      patientName: patient['name'] ?? 'Patient',
                                    ),
                              ),
                            ).then((_) {
                              if (mounted) {
                                _fetchPatientData();
                                _fetchAdherenceRate();
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.verified_outlined, size: 18),
                          label: const Text('History & Validasi'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: Colors.orange[700],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => MedicationHistoryPage(
                                      patientId: patient['id'],
                                      isStaff: true,
                                    ),
                              ),
                            ).then((_) {
                              if (mounted) {
                                _fetchPatientData();
                                _fetchAdherenceRate();
                              }
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade100, width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                color: Colors.grey[500],
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                color: AppColors.text,
                fontSize: 13,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar:
          _selectedIndex == 0
              ? AppBar(
                backgroundColor: AppColors.primary,
                elevation: 0,
                centerTitle: false,
                title: Text(
                  'TB Care',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(1),
                  child: Container(color: Colors.grey.shade100, height: 1),
                ),
              )
              : null,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildStaffHomePage(),
          _navigationPages[0],
          _navigationPages[1],
          _navigationPages[2],
          _navigationPages[3],
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: NavigationBar(
          backgroundColor: Colors.white,
          elevation: 0,
          height: 65,
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() {
              _selectedIndex = index;
            });
            if (index == 0) {
              _fetchPatientData();
              _fetchAdherenceRate();
            }
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home, color: AppColors.primary),
              label: 'Beranda',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outlined),
              selectedIcon: Icon(Icons.people, color: AppColors.primary),
              label: 'Pasien',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book, color: AppColors.primary),
              label: 'Edukasi',
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
      ),
    );
  }
}
