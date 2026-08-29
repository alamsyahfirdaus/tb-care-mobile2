import 'dart:convert';
import 'package:apk_tb_care/connection.dart';
import 'package:apk_tb_care/main/pasien/history.dart';
import 'package:apk_tb_care/main/pasien/treatment_history.dart';
import 'package:apk_tb_care/main/petugas/add_patient.dart';
import 'package:apk_tb_care/main/petugas/edit_patient.dart';
import 'package:apk_tb_care/main/petugas/treatment_managment.dart';
import 'package:apk_tb_care/main/petugas/visit_managment.dart';
import 'package:apk_tb_care/values/colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PatientPage extends StatefulWidget {
  const PatientPage({super.key});

  @override
  State<PatientPage> createState() => _PatientPageState();
}

class _PatientPageState extends State<PatientPage> {
  List<Map<String, dynamic>> _patientData = [];
  final TextEditingController _searchController = TextEditingController();

  // Filter: 'all', 'berjalan', 'selesai', 'belum mulai', 'gagal', 'meninggal'
  String _selectedFilter = 'all';

  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchPatientData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // API CALLS & AUTH
  // ===========================================================================

  Future<void> _fetchPatientData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
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
        final Map<String, dynamic> dataJson = jsonDecode(response.body);
        if (dataJson['data'] is List) {
          setState(() {
            _patientData = List<Map<String, dynamic>>.from(
              dataJson['data'].whereType<Map<String, dynamic>>(),
            );
            _isLoading = false;
          });
        } else {
          setState(() {
            _patientData = [];
            _isLoading = false;
          });
        }
      } else {
        throw Exception('Gagal memuat data (Status: ${response.statusCode})');
      }
    } catch (e) {
      debugPrint('Error fetching patients: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal memuat data pasien: $_errorMessage',
            style: GoogleFonts.plusJakartaSans(fontSize: 12),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<bool> _updateTreatmentStatusOnServer(
    int treatmentId,
    String newStatus,
  ) async {
    final session = await SharedPreferences.getInstance();
    final token = session.getString('token') ?? '';

    try {
      final response = await http.post(
        Uri.parse('${Connection.BASE_URL}/treatments/status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'id': treatmentId, 'treatment_status': newStatus}),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating treatment status: $e');
      return false;
    }
  }

  // ===========================================================================
  // LOGIC & HELPER FUNCTIONS
  // ===========================================================================

  /// Mengembalikan treatment yang statusnya BENAR-BENAR 'Berjalan'
  Map<String, dynamic>? _getActiveTreatment(Map<String, dynamic> patient) {
    final treatments = patient['treatments'];
    if (treatments is! List || treatments.isEmpty) {
      return null;
    }

    for (final t in treatments) {
      if (t is Map<String, dynamic>) {
        final status = t['treatment_status']?.toString().toLowerCase().trim();
        if (status == 'berjalan') {
          return t;
        }
      }
    }
    return null;
  }

  /// Mengembalikan treatment terbaru / paling relevan
  Map<String, dynamic>? _getLatestTreatment(Map<String, dynamic> patient) {
    final treatments = patient['treatments'];
    if (treatments is! List || treatments.isEmpty) {
      return null;
    }

    final active = _getActiveTreatment(patient);
    if (active != null) {
      return active;
    }

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

    if (latest != null) {
      return latest;
    }

    return treatments.first is Map<String, dynamic>
        ? treatments.first as Map<String, dynamic>
        : null;
  }

  /// Menghasilkan label status pengobatan yang dinormalisasi
  String _getTreatmentStatus(
    Map<String, dynamic> patient, [
    Map<String, dynamic>? treatment,
  ]) {
    final tr =
        treatment ??
        _getActiveTreatment(patient) ??
        _getLatestTreatment(patient);
    if (tr == null) {
      return 'Belum Mulai';
    }

    final rawStatus = tr['treatment_status']?.toString().trim();
    if (rawStatus == null || rawStatus.isEmpty) {
      return 'Belum Mulai';
    }

    final lower = rawStatus.toLowerCase();
    if (lower == 'berjalan') {
      return 'Berjalan';
    }
    if (lower == 'selesai') {
      return 'Selesai';
    }
    if (lower == 'gagal') {
      return 'Gagal';
    }
    if (lower == 'meninggal') {
      return 'Meninggal';
    }
    if (lower == 'belum mulai' || lower == 'belum ada pengobatan') {
      return 'Belum Mulai';
    }

    return rawStatus;
  }

  /// Helper untuk warna badge status
  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase().trim()) {
      case 'berjalan':
        return const Color(0xFF1565C0);
      case 'selesai':
        return const Color(0xFF2E7D32);
      case 'gagal':
        return const Color(0xFFC62828);
      case 'meninggal':
        return const Color(0xFFE65100);
      default:
        return const Color(0xFF64748B);
    }
  }

  /// Helper untuk background badge status yang soft
  Color _getStatusBgColor(String? status) {
    switch (status?.toLowerCase().trim()) {
      case 'berjalan':
        return const Color(0xFFE3F2FD);
      case 'selesai':
        return const Color(0xFFE8F5E9);
      case 'gagal':
        return const Color(0xFFFFEBEE);
      case 'meninggal':
        return const Color(0xFFFFF3E0);
      default:
        return const Color(0xFFF1F5F9);
    }
  }

  /// Helper untuk icon status
  IconData _getStatusIcon(String? status) {
    switch (status?.toLowerCase().trim()) {
      case 'berjalan':
        return Icons.autorenew_rounded;
      case 'selesai':
        return Icons.check_circle_outline_rounded;
      case 'gagal':
        return Icons.cancel_outlined;
      case 'meninggal':
        return Icons.info_outline_rounded;
      default:
        return Icons.access_time_rounded;
    }
  }

  /// Format waktu minum obat yang aman dari RangeError
  String _formatMedicationTime(dynamic value) {
    if (value == null) {
      return '-';
    }
    final str = value.toString().trim();
    if (str.isEmpty) {
      return '-';
    }

    final parts = str.split(':');
    if (parts.length >= 2) {
      final hour = parts[0].padLeft(2, '0');
      final minute = parts[1].padLeft(2, '0');
      return '$hour:$minute';
    }

    return str.length >= 5 ? str.substring(0, 5) : str;
  }

  /// Format gender yang aman
  String _formatGender(dynamic value) {
    if (value == null) {
      return '-';
    }
    final str = value.toString().trim().toUpperCase();
    if (str == 'L' || str == 'LAKI-LAKI') {
      return 'Laki-laki';
    }
    if (str == 'P' || str == 'PEREMPUAN') {
      return 'Perempuan';
    }
    return value.toString().trim().isEmpty ? '-' : value.toString();
  }

  /// Format tanggal aman
  String _formatDate(dynamic dateStr) {
    if (dateStr == null) {
      return '-';
    }
    try {
      final parsed = DateTime.parse(dateStr.toString().trim());
      return DateFormat('dd MMM yyyy', 'id_ID').format(parsed);
    } catch (_) {
      return dateStr.toString();
    }
  }

  /// Helper mendapatkan jadwal kunjungan berikutnya
  String _getUpcomingVisitText(Map<String, dynamic>? treatment) {
    if (treatment == null) return 'Belum ada jadwal';
    final visits = treatment['visits'];
    if (visits is! List || visits.isEmpty) return 'Belum ada jadwal';

    DateTime? nearestDate;
    String? nearestTime;

    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);

    for (final v in visits) {
      if (v is Map<String, dynamic>) {
        final dateStr = v['visit_date'];
        if (dateStr != null) {
          final parsed = DateTime.tryParse(dateStr.toString().trim());
          if (parsed != null) {
            final visitMidnight = DateTime(
              parsed.year,
              parsed.month,
              parsed.day,
            );
            if (!visitMidnight.isBefore(todayMidnight)) {
              if (nearestDate == null || parsed.isBefore(nearestDate)) {
                nearestDate = parsed;
                nearestTime = v['visit_time']?.toString();
              }
            }
          }
        }
      }
    }

    // Jika tidak ada jadwal mendatang, cari kunjungan terakhir yang tercatat
    if (nearestDate == null) {
      for (final v in visits) {
        if (v is Map<String, dynamic>) {
          final dateStr = v['visit_date'];
          if (dateStr != null) {
            final parsed = DateTime.tryParse(dateStr.toString().trim());
            if (parsed != null) {
              if (nearestDate == null || parsed.isAfter(nearestDate)) {
                nearestDate = parsed;
                nearestTime = v['visit_time']?.toString();
              }
            }
          }
        }
      }
    }

    if (nearestDate != null) {
      final dateFormatted = DateFormat('dd/MM', 'id_ID').format(nearestDate);
      final timeFormatted = _formatMedicationTime(nearestTime);
      if (timeFormatted != '-') {
        return '$dateFormatted • $timeFormatted';
      }
      return dateFormatted;
    }

    return 'Belum ada jadwal';
  }

  /// Perhitungan kalkulasi progress pengobatan yang aman & clamped
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
          'startDate': startDate,
          'endDate': endDate,
        };
      }

      final totalDays = endDate.difference(startDate).inDays;
      final status =
          treatment['treatment_status']?.toString().toLowerCase().trim();

      if (status == 'selesai') {
        return {
          'hasDates': true,
          'daysPassed': totalDays,
          'totalDays': totalDays,
          'progress': 1.0,
          'startDate': startDate,
          'endDate': endDate,
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
        daysPassed = todayMidnight.difference(startMidnight).inDays;
        daysPassed = daysPassed.clamp(0, totalDays);
        progress = totalDays > 0 ? daysPassed / totalDays : 0.0;
        progress = progress.clamp(0.0, 1.0);
      }

      return {
        'hasDates': true,
        'daysPassed': daysPassed,
        'totalDays': totalDays,
        'progress': progress,
        'startDate': startDate,
        'endDate': endDate,
      };
    } catch (e) {
      debugPrint('Error calculating treatment progress: $e');
      return {
        'hasDates': false,
        'daysPassed': 0,
        'totalDays': 0,
        'progress': 0.0,
      };
    }
  }

  // ===========================================================================
  // FILTERING LOGIC
  // ===========================================================================

  List<Map<String, dynamic>> _getFilteredPatients() {
    final query = _searchController.text.trim().toLowerCase();

    return _patientData.where((patient) {
      final name = (patient['name']?.toString() ?? '').toLowerCase();
      final nik = (patient['nik']?.toString() ?? '').toLowerCase();

      // Search filter
      if (query.isNotEmpty && !name.contains(query) && !nik.contains(query)) {
        return false;
      }

      // Status filter
      if (_selectedFilter != 'all') {
        final status = _getTreatmentStatus(patient).toLowerCase();
        if (status != _selectedFilter) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  // ===========================================================================
  // NAVIGATION HELPERS (AUTO-REFRESH ON RETURN)
  // ===========================================================================

  Future<void> _navigateToAddPatient() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddPatientPage()),
    );
    _fetchPatientData();
  }

  Future<void> _navigateToEditPatient(int patientId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditPatientPage(patientId: patientId),
      ),
    );
    _fetchPatientData();
  }

  Future<void> _navigateToTreatmentManagement(
    Map<String, dynamic> patient,
    Map<String, dynamic>? treatment,
  ) async {
    final patientId = patient['id'];
    final patientName = patient['name']?.toString() ?? 'Pasien';

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => TreatmentManagementPage(
              patientId: patientId,
              patientName: patientName,
              existingTreatment: treatment,
              onShowHistory: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => TreatmentHistoryPage(
                          patientId: patientId,
                          patientName: patientName,
                          isStaff: true,
                        ),
                  ),
                );
              },
            ),
      ),
    );
    _fetchPatientData();
  }

  Future<void> _navigateToTreatmentHistory(
    Map<String, dynamic> patient, {
    bool isDone = false,
  }) async {
    final patientId = patient['id'];
    final patientName = patient['name']?.toString() ?? 'Pasien';

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => TreatmentHistoryPage(
              patientId: patientId,
              patientName: patientName,
              isStaff: true,
              isDone: isDone,
            ),
      ),
    );
    _fetchPatientData();
  }

  Future<void> _navigateToVisitManagement(
    Map<String, dynamic> patient,
    int? patientTreatmentId,
  ) async {
    final patientId = patient['id'];
    final patientName = patient['name']?.toString() ?? 'Pasien';

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => VisitManagementPage(
              patientId: patientId,
              patientTreatmentId: patientTreatmentId,
              patientName: patientName,
            ),
      ),
    );
    _fetchPatientData();
  }

  Future<void> _navigateToMedicationHistory(int patientId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) =>
                MedicationHistoryPage(patientId: patientId, isStaff: true),
      ),
    );
    _fetchPatientData();
  }

  // ===========================================================================
  // MAIN BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: false,
        leading:
            Navigator.canPop(context)
                ? IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  onPressed: () => Navigator.pop(context),
                )
                : null,
        title: Text(
          'Manajemen Pasien',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Segarkan Data',
            icon: const Icon(
              Icons.refresh_rounded,
              color: Colors.white,
              size: 22,
            ),
            onPressed: _fetchPatientData,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSummaryStats(),
          _buildSearchAndFilterSection(),
          Expanded(child: _buildPatientList()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddPatient,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
      ),
    );
  }

  // ===========================================================================
  // RINGKASAN DATA (SUMMARY STATS)
  // ===========================================================================

  Widget _buildSummaryStats() {
    final totalPatients = _patientData.length;
    final activeTreatments =
        _patientData.where((p) => _getActiveTreatment(p) != null).length;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: [
          // Total Pasien Card
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.people_alt_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Total Pasien',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$totalPatients',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Pengobatan Aktif Card
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.medical_services_rounded,
                      color: Color(0xFF1565C0),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Pengobatan Aktif',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$activeTreatments',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1565C0),
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
      ),
    );
  }

  // ===========================================================================
  // SEARCH & FILTER BAR
  // ===========================================================================

  Widget _buildSearchAndFilterSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: Column(
        children: [
          // Search Field
          Container(
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: TextField(
              controller: _searchController,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppColors.text,
              ),
              decoration: InputDecoration(
                hintText: 'Cari nama pasien atau NIK...',
                hintStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: Colors.grey.shade500,
                  size: 18,
                ),
                suffixIcon:
                    _searchController.text.isNotEmpty
                        ? IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                        : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 8),

          // Horizontal Status Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                _buildFilterChip('all', 'Semua'),
                const SizedBox(width: 6),
                _buildFilterChip('berjalan', 'Berjalan'),
                const SizedBox(width: 6),
                _buildFilterChip('selesai', 'Selesai'),
                const SizedBox(width: 6),
                _buildFilterChip('belum mulai', 'Belum Mulai'),
                const SizedBox(width: 6),
                _buildFilterChip('gagal', 'Gagal'),
                const SizedBox(width: 6),
                _buildFilterChip('meninggal', 'Meninggal'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    final color = value == 'all' ? AppColors.primary : _getStatusColor(value);

    return InkWell(
      onTap: () {
        setState(() {
          _selectedFilter = value;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5.5),
        decoration: BoxDecoration(
          color: isSelected ? color : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // PATIENT LIST VIEW
  // ===========================================================================

  Widget _buildPatientList() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_hasError) {
      return _buildErrorState();
    }

    final filteredPatients = _getFilteredPatients();

    if (filteredPatients.isEmpty) {
      return _buildEmptyState(
        isSearchResult:
            _searchController.text.isNotEmpty || _selectedFilter != 'all',
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: Colors.white,
      onRefresh: _fetchPatientData,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 85),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        itemCount: filteredPatients.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          return _buildPatientCard(filteredPatients[index]);
        },
      ),
    );
  }

  Widget _buildPatientCard(Map<String, dynamic> patient) {
    final name =
        (patient['name']?.toString().trim().isNotEmpty ?? false)
            ? patient['name'].toString().trim()
            : 'Nama tidak tersedia';

    final initial =
        name.isNotEmpty && name != 'Nama tidak tersedia'
            ? name[0].toUpperCase()
            : '?';

    final activeTreatment = _getActiveTreatment(patient);
    final latestTreatment = _getLatestTreatment(patient);
    final treatment = activeTreatment ?? latestTreatment;
    final status = _getTreatmentStatus(patient, treatment);
    final progressData = _calculateTreatmentProgress(treatment);
    final medTime = _formatMedicationTime(treatment?['medication_time']);
    final nextVisit = _getUpcomingVisitText(treatment);

    String? periodText;
    if (progressData['hasDates'] == true &&
        progressData['startDate'] != null &&
        progressData['endDate'] != null) {
      final startStr = DateFormat(
        'dd MMM yyyy',
        'id_ID',
      ).format(progressData['startDate']);
      final endStr = DateFormat(
        'dd MMM yyyy',
        'id_ID',
      ).format(progressData['endDate']);
      periodText = '$startStr — $endStr';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showPatientDetail(patient),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Top Row: Avatar, Name, NIK, Status Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.primary.withValues(alpha: 0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          initial,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppColors.text,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'NIK: ${patient['nik'] ?? '-'}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    _buildStatusBadge(status),
                  ],
                ),

                // 2. Treatment Details Section (if treatment exists)
                if (treatment != null) ...[
                  if (periodText != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Periode Pengobatan',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      periodText,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                  ],

                  // Progress Bar
                  if (progressData['hasDates'] == true) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Hari ${progressData['daysPassed']} dari ${progressData['totalDays']}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        Text(
                          '${((progressData['progress'] as double) * 100).toStringAsFixed(1)}%',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _getStatusColor(status),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progressData['progress'],
                        minHeight: 6,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _getStatusColor(status),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 10),

                  // Medication & Visit info line
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFEDF2F7)),
                    ),
                    child: Row(
                      children: [
                        // Medication Time
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(
                                Icons.medication_rounded,
                                size: 14,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  'Obat: $medTime',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF334155),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          height: 14,
                          width: 1,
                          color: Colors.grey.shade300,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        // Upcoming Visit
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_rounded,
                                size: 13,
                                color: Color(0xFF059669),
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  'Kunjungan: $nextVisit',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF334155),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Action Buttons Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Ubah Status Button (Secondary / Outlined)
                      OutlinedButton(
                        onPressed:
                            () => _updateTreatmentStatus(patient, treatment),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Ubah Status',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Kunjungan Button (Primary / Filled)
                      ElevatedButton(
                        onPressed:
                            () => _navigateToVisitManagement(
                              patient,
                              treatment['id'] is int ? treatment['id'] : null,
                            ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Kunjungan',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Belum ada riwayat pengobatan',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed:
                            () => _navigateToTreatmentManagement(patient, null),
                        icon: const Icon(Icons.add_rounded, size: 14),
                        label: const Text('Buat Pengobatan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          textStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // STATUS BADGE COMPONENT
  // ===========================================================================

  Widget _buildStatusBadge(String status) {
    final color = _getStatusColor(status);
    final bgColor = _getStatusBgColor(status);
    final icon = _getStatusIcon(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3.5),
          Text(
            status,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // DETAIL BOTTOM SHEET (PATIENT)
  // ===========================================================================

  void _showPatientDetail(Map<String, dynamic> patient) {
    final activeTreatment = _getActiveTreatment(patient);
    final latestTreatment = _getLatestTreatment(patient);
    final treatment = activeTreatment ?? latestTreatment;
    final status = _getTreatmentStatus(patient, treatment);

    final name =
        (patient['name']?.toString().trim().isNotEmpty ?? false)
            ? patient['name'].toString().trim()
            : 'Nama tidak tersedia';

    final initial =
        name.isNotEmpty && name != 'Nama tidak tersedia'
            ? name[0].toUpperCase()
            : '?';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Drag Handle Bar
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 6),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 12, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Detail Data Pasien',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.grey,
                            size: 20,
                          ),
                          onPressed: () => Navigator.pop(sheetContext),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),

                  // Scrollable Body
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Patient Summary Banner
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.primary,
                                      AppColors.primary.withValues(alpha: 0.8),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    initial,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.text,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'NIK: ${patient['nik'] ?? '-'}',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _buildStatusBadge(status),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Section 1: Data Pribadi
                        _buildDetailSectionTitle(
                          'Informasi Pasien',
                          Icons.person_outline_rounded,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: [
                              _buildModernDetailRow(
                                'NIK',
                                patient['nik']?.toString() ?? '-',
                              ),
                              _buildDivider(),
                              _buildModernDetailRow(
                                'Jenis Kelamin',
                                _formatGender(patient['gender']),
                              ),
                              _buildDivider(),
                              _buildModernDetailRow(
                                'Tanggal Lahir',
                                _formatDate(patient['date_of_birth']),
                              ),
                              _buildDivider(),
                              _buildModernDetailRow(
                                'Nomor Telepon',
                                patient['phone']?.toString() ?? '-',
                              ),
                              _buildDivider(),
                              _buildModernDetailRow(
                                'Alamat',
                                patient['address']?.toString() ?? '-',
                              ),
                              _buildDivider(),
                              _buildModernDetailRow(
                                'Puskesmas',
                                patient['puskesmas']?.toString() ?? '-',
                              ),
                              _buildDivider(),
                              _buildModernDetailRow(
                                'Kecamatan',
                                patient['subdistrict']?.toString() ?? '-',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Section 2: Data Pengobatan
                        _buildDetailSectionTitle(
                          'Informasi Pengobatan',
                          Icons.medical_services_outlined,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: [
                              _buildModernDetailRow(
                                'Status Pengobatan',
                                status,
                                valueColor: _getStatusColor(status),
                              ),
                              if (treatment != null) ...[
                                _buildDivider(),
                                _buildModernDetailRow(
                                  'Periode Pengobatan',
                                  treatment['start_date'] != null &&
                                          treatment['end_date'] != null
                                      ? '${_formatDate(treatment['start_date'])} — ${_formatDate(treatment['end_date'])}'
                                      : 'Belum ditentukan',
                                ),
                                _buildDivider(),
                                _buildModernDetailRow(
                                  'Waktu Minum Obat',
                                  _formatMedicationTime(
                                    treatment['medication_time'],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),

                        // Action Buttons - Row 1: Edit & Pengobatan
                        Row(
                          children: [
                            // Edit Data Button
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.pop(sheetContext);
                                  _navigateToEditPatient(patient['id']);
                                },
                                icon: const Icon(Icons.edit_outlined, size: 16),
                                label: const Text('Edit Data'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 11,
                                  ),
                                  foregroundColor: AppColors.primary,
                                  side: const BorderSide(
                                    color: AppColors.primary,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  textStyle: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Treatment / Buat Pengobatan Button
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(sheetContext);
                                  if (status == 'Berjalan') {
                                    _navigateToTreatmentManagement(
                                      patient,
                                      treatment,
                                    );
                                  } else if (treatment != null) {
                                    _navigateToTreatmentHistory(
                                      patient,
                                      isDone: true,
                                    );
                                  } else {
                                    _navigateToTreatmentManagement(
                                      patient,
                                      null,
                                    );
                                  }
                                },
                                icon: const Icon(
                                  Icons.medical_services_rounded,
                                  size: 16,
                                ),
                                label: Text(
                                  treatment != null
                                      ? 'Pengobatan'
                                      : 'Buat Pengobatan',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 11,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  textStyle: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Action Buttons - Row 2: Kunjungan & History (If treatment exists)
                        if (treatment != null) ...[
                          Row(
                            children: [
                              // Kunjungan Button
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(sheetContext);
                                    _navigateToVisitManagement(
                                      patient,
                                      treatment['id'] is int
                                          ? treatment['id']
                                          : null,
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.calendar_month_outlined,
                                    size: 16,
                                  ),
                                  label: const Text('Kunjungan'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF059669),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 11,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    textStyle: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),

                              // History & Validasi Button
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(sheetContext);
                                    _navigateToMedicationHistory(patient['id']);
                                  },
                                  icon: const Icon(
                                    Icons.history_rounded,
                                    size: 16,
                                  ),
                                  label: const Text('History & Validasi'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFD97706),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 11,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    textStyle: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // UPDATE TREATMENT STATUS DIALOG
  // ===========================================================================

  void _updateTreatmentStatus(
    Map<String, dynamic> patient,
    Map<String, dynamic> treatment,
  ) {
    final String currentStatus =
        treatment['treatment_status']?.toString() ?? 'Berjalan';
    String? selectedStatus = currentStatus;
    bool isSubmitting = false;

    final statuses = ['Berjalan', 'Selesai', 'Gagal', 'Meninggal'];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (modalContext, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              titlePadding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.published_with_changes_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Ubah Status Pengobatan',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children:
                    statuses.map((statusOption) {
                      final isSelected = selectedStatus == statusOption;
                      final color = _getStatusColor(statusOption);

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        decoration: BoxDecoration(
                          color:
                              isSelected
                                  ? _getStatusBgColor(statusOption)
                                  : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? color : Colors.transparent,
                            width: 1,
                          ),
                        ),
                        child: RadioListTile<String>(
                          activeColor: color,
                          dense: true,
                          title: Text(
                            statusOption,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight:
                                  isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                              color: isSelected ? color : AppColors.text,
                              fontSize: 13,
                            ),
                          ),
                          value: statusOption,
                          // ignore: deprecated_member_use
                          groupValue: selectedStatus,
                          // ignore: deprecated_member_use
                          onChanged:
                              isSubmitting
                                  ? null
                                  : (val) {
                                    setDialogState(() {
                                      selectedStatus = val;
                                    });
                                  },
                        ),
                      );
                    }).toList(),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
              actions: [
                TextButton(
                  onPressed:
                      isSubmitting ? null : () => Navigator.pop(dialogContext),
                  child: Text(
                    'Batal',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                      color:
                          isSubmitting
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed:
                      isSubmitting
                          ? null
                          : () async {
                            if (selectedStatus == null ||
                                selectedStatus ==
                                    treatment['treatment_status']) {
                              Navigator.pop(dialogContext);
                              return;
                            }

                            final treatmentId =
                                treatment['id'] is int
                                    ? treatment['id'] as int
                                    : 0;
                            if (treatmentId <= 0) {
                              Navigator.pop(dialogContext);
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'ID pengobatan tidak valid.',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                    ),
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }

                            // 1. Set loading state to prevent multiple taps
                            setDialogState(() {
                              isSubmitting = true;
                            });

                            // 2. Call server API
                            final newStatus = selectedStatus!;
                            final success =
                                await _updateTreatmentStatusOnServer(
                                  treatmentId,
                                  newStatus,
                                );

                            // 3. Close dialog safely using dialogContext
                            if (dialogContext.mounted &&
                                Navigator.canPop(dialogContext)) {
                              Navigator.pop(dialogContext);
                            }

                            // 4. Validate page mounted state before accessing page context or calling setState
                            if (!mounted) return;

                            if (success) {
                              // 5. Update local state immediately for instant feedback
                              setState(() {
                                treatment['treatment_status'] = newStatus;
                              });

                              // 6. Show success SnackBar using the main page's context
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Status pengobatan berhasil diubah menjadi $newStatus',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                    ),
                                  ),
                                  backgroundColor: const Color(0xFF2E7D32),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );

                              // 7. Refresh background patient data
                              _fetchPatientData();
                            } else {
                              // Show error SnackBar using the main page's context
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Gagal memperbarui status pengobatan. Silakan coba lagi.',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                    ),
                                  ),
                                  backgroundColor: const Color(0xFFC62828),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                  ),
                  child:
                      isSubmitting
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                          : Text(
                            'Simpan',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // HELPER WIDGETS (SECTIONS, DIVIDERS, ROWS)
  // ===========================================================================

  Widget _buildDetailSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
        ),
      ],
    );
  }

  Widget _buildModernDetailRow(
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9));
  }

  // ===========================================================================
  // STATES: LOADING, ERROR, EMPTY
  // ===========================================================================

  Widget _buildLoadingState() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder:
          (_, __) => Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 130,
                            height: 13,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Container(
                            width: 160,
                            height: 10,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 54,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: Color(0xFFFFEBEE),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFC62828),
                size: 42,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Data pasien belum dapat dimuat',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Periksa koneksi internet Anda lalu coba lagi.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _fetchPatientData,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 9,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({required bool isSearchResult}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSearchResult
                    ? Icons.person_search_rounded
                    : Icons.people_outline_rounded,
                size: 48,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              isSearchResult
                  ? 'Tidak ada pasien yang sesuai'
                  : 'Belum Ada Pasien',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              isSearchResult
                  ? 'Coba sesuaikan kata kunci pencarian atau filter status yang dipilih.'
                  : 'Belum terdapat data pasien yang sesuai.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            if (isSearchResult) ...[
              OutlinedButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _selectedFilter = 'all';
                  });
                },
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                child: Text(
                  'Reset Filter',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ] else ...[
              ElevatedButton.icon(
                onPressed: _navigateToAddPatient,
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                label: const Text('Tambah Pasien'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 9,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
