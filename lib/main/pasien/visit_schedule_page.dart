// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'package:apk_tb_care/alarm_service.dart';
import 'package:apk_tb_care/connection.dart';
import 'package:apk_tb_care/values/colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class VisitSchedulePage extends StatefulWidget {
  final int patientId;
  final int? treatmentId;
  final String puskesmasName;
  final List<dynamic>? initialVisits;

  const VisitSchedulePage({
    super.key,
    required this.patientId,
    required this.treatmentId,
    this.puskesmasName = 'Puskesmas',
    this.initialVisits,
  });

  @override
  State<VisitSchedulePage> createState() => _VisitSchedulePageState();
}

class _VisitSchedulePageState extends State<VisitSchedulePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _visits = [];
  bool _isLoading = false;
  String? _errorMessage;

  bool _isReminderEnabled = true;
  int _reminderOffsetMinutes = 60;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (widget.initialVisits != null && widget.initialVisits!.isNotEmpty) {
      _visits = List<dynamic>.from(widget.initialVisits!);
    }
    _loadReminderPreferences();
    _fetchVisits();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReminderPreferences() async {
    final enabled = await AlarmService.isVisitReminderEnabled();
    final offset = await AlarmService.getVisitReminderOffsetMinutes();
    if (mounted) {
      setState(() {
        _isReminderEnabled = enabled;
        _reminderOffsetMinutes = offset;
      });
    }
  }

  Future<void> _fetchVisits() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final session = await SharedPreferences.getInstance();
      final token = session.getString('token') ?? '';

      http.Response response;
      if (widget.treatmentId != null && widget.treatmentId! > 0) {
        response = await http
            .get(
              Uri.parse(
                '${Connection.BASE_URL}/treatments/${widget.treatmentId}/visits',
              ),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
            )
            .timeout(const Duration(seconds: 12));
      } else {
        response = await http
            .get(
              Uri.parse('${Connection.BASE_URL}/patient/visits'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
            )
            .timeout(const Duration(seconds: 12));
      }

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final list = (data['data'] as List<dynamic>?) ?? [];
        if (mounted) {
          setState(() {
            _visits = list;
            _isLoading = false;
          });
        }

        // Sync with AlarmService
        await AlarmService.scheduleVisitNotifications(
          _visits,
          puskesmasName: widget.puskesmasName,
          reminderOffsetMinutes: _reminderOffsetMinutes,
          isEnabled: _isReminderEnabled,
        );
      } else if (response.statusCode == 404) {
        if (mounted) {
          setState(() {
            _visits = [];
            _isLoading = false;
          });
        }
      } else {
        throw Exception(
          'Gagal memuat jadwal kunjungan (${response.statusCode})',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleReminder(bool value) async {
    setState(() {
      _isReminderEnabled = value;
    });

    await AlarmService.updateVisitReminderSettings(
      isEnabled: value,
      offsetMinutes: _reminderOffsetMinutes,
      visits: _visits,
      puskesmasName: widget.puskesmasName,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'Pengingat kunjungan diaktifkan (${_getOffsetLabel(_reminderOffsetMinutes)})'
                : 'Pengingat kunjungan dinonaktifkan',
            style: GoogleFonts.plusJakartaSans(fontSize: 13),
          ),
          backgroundColor:
              value ? const Color(0xFF059669) : Colors.grey.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _selectReminderOffset(int offsetMinutes) async {
    setState(() {
      _reminderOffsetMinutes = offsetMinutes;
    });

    await AlarmService.updateVisitReminderSettings(
      isEnabled: _isReminderEnabled,
      offsetMinutes: offsetMinutes,
      visits: _visits,
      puskesmasName: widget.puskesmasName,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Pengingat diatur ke: ${_getOffsetLabel(offsetMinutes)}',
            style: GoogleFonts.plusJakartaSans(fontSize: 13),
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  String _getOffsetLabel(int minutes) {
    switch (minutes) {
      case 0:
        return 'Tepat waktu kunjungan';
      case 30:
        return '30 menit sebelumnya';
      case 60:
        return '1 jam sebelumnya';
      case 120:
        return '2 jam sebelumnya';
      case 1440:
        return '1 hari sebelumnya';
      default:
        return '$minutes menit sebelumnya';
    }
  }

  List<dynamic> _getUpcomingVisits() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final list =
        _visits.where((v) {
          if (v is! Map) return false;
          final status = v['visit_status']?.toString();
          if (status != 'Terjadwal') return false;
          final dateStr = v['visit_date']?.toString();
          if (dateStr == null || dateStr.isEmpty) return false;
          final vDate = DateTime.tryParse(dateStr);
          if (vDate == null) return false;
          return !vDate.isBefore(today);
        }).toList();

    list.sort((a, b) {
      final dateA = a['visit_date']?.toString() ?? '';
      final dateB = b['visit_date']?.toString() ?? '';
      final cmp = dateA.compareTo(dateB);
      if (cmp != 0) return cmp;
      final timeA = a['visit_time']?.toString() ?? '';
      final timeB = b['visit_time']?.toString() ?? '';
      return timeA.compareTo(timeB);
    });

    return list;
  }

  List<dynamic> _getAllSortedVisits() {
    final list = List<dynamic>.from(_visits);
    list.sort((a, b) {
      final dateA = a['visit_date']?.toString() ?? '';
      final dateB = b['visit_date']?.toString() ?? '';
      final cmp = dateA.compareTo(dateB);
      if (cmp != 0) return cmp;
      final timeA = a['visit_time']?.toString() ?? '';
      final timeB = b['visit_time']?.toString() ?? '';
      return timeA.compareTo(timeB);
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Jadwal Kunjungan'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          unselectedLabelStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          tabs: const [Tab(text: 'Akan Datang'), Tab(text: 'Semua Kunjungan')],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchVisits,
        color: AppColors.primary,
        child: Column(
          children: [
            _buildReminderSettingsCard(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildVisitsListView(
                    _getUpcomingVisits(),
                    isUpcomingTab: true,
                  ),
                  _buildVisitsListView(
                    _getAllSortedVisits(),
                    isUpcomingTab: false,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderSettingsCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
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
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_active_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pengingat Kunjungan',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isReminderEnabled
                          ? 'Aktif (${_getOffsetLabel(_reminderOffsetMinutes)})'
                          : 'Nonaktif',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color:
                            _isReminderEnabled
                                ? const Color(0xFF059669)
                                : Colors.grey.shade500,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _isReminderEnabled,
                onChanged: _toggleReminder,
                activeColor: AppColors.primary,
              ),
            ],
          ),
          if (_isReminderEnabled) ...[
            const SizedBox(height: 12),
            Divider(color: Colors.grey.shade100, height: 1),
            const SizedBox(height: 10),
            Text(
              'Ingatkan Saya:',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildOffsetChip(30, '30 Menit'),
                  const SizedBox(width: 8),
                  _buildOffsetChip(60, '1 Jam'),
                  const SizedBox(width: 8),
                  _buildOffsetChip(120, '2 Jam'),
                  const SizedBox(width: 8),
                  _buildOffsetChip(1440, '1 Hari'),
                  const SizedBox(width: 8),
                  _buildOffsetChip(0, 'Tepat Waktu'),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOffsetChip(int minutes, String label) {
    final isSelected = _reminderOffsetMinutes == minutes;
    return InkWell(
      onTap: () => _selectReminderOffset(minutes),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildVisitsListView(
    List<dynamic> visits, {
    required bool isUpcomingTab,
  }) {
    if (_isLoading && _visits.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_errorMessage != null && _visits.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchVisits,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Coba Lagi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (visits.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.event_busy_rounded,
                  size: 36,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isUpcomingTab
                    ? 'Belum Ada Jadwal Kunjungan Mendatang'
                    : 'Belum Ada Jadwal Kunjungan Puskesmas',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Jadwal kunjungan Puskesmas akan ditampilkan setelah ditentukan oleh petugas kesehatan.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: visits.length,
      itemBuilder: (context, index) {
        final visit = visits[index];
        return _buildVisitItemCard(visit);
      },
    );
  }

  Widget _buildVisitItemCard(dynamic visit) {
    if (visit is! Map) return const SizedBox.shrink();

    final dateStr = visit['visit_date']?.toString() ?? '';
    final timeStr = visit['visit_time']?.toString() ?? '';
    final status = visit['visit_status']?.toString() ?? 'Terjadwal';
    final notes = visit['notes']?.toString();
    final puskesmas =
        (visit['puskesmas_name'] != null &&
                visit['puskesmas_name'].toString().isNotEmpty)
            ? visit['puskesmas_name'].toString()
            : widget.puskesmasName;

    String formattedDate = dateStr;
    bool isPast = false;
    DateTime? vDate;
    if (dateStr.isNotEmpty) {
      try {
        vDate = DateTime.parse(dateStr);
        formattedDate = DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(vDate);
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        isPast = vDate.isBefore(today);
      } catch (_) {
        formattedDate = dateStr;
      }
    }

    String formattedTime = timeStr;
    if (timeStr.isNotEmpty) {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        formattedTime =
            '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')} WIB';
      } else {
        formattedTime = '$timeStr WIB';
      }
    }

    // Badge configuration
    Color badgeBg;
    Color badgeText;
    Color badgeBorder;
    String badgeLabel = status;
    IconData badgeIcon = Icons.event_available_rounded;

    if (status == 'Terjadwal') {
      if (isPast) {
        badgeLabel = 'Terlewat';
        badgeBg = const Color(0xFFFEF3C7);
        badgeText = const Color(0xFFD97706);
        badgeBorder = const Color(0xFFFDE68A);
        badgeIcon = Icons.history_rounded;
      } else {
        badgeBg = const Color(0xFFECFDF5);
        badgeText = const Color(0xFF059669);
        badgeBorder = const Color(0xFFA7F3D0);
        badgeIcon = Icons.schedule_rounded;
      }
    } else if (status == 'Hadir') {
      badgeBg = const Color(0xFFEFF6FF);
      badgeText = const Color(0xFF2563EB);
      badgeBorder = const Color(0xFFBFDBFE);
      badgeIcon = Icons.check_circle_rounded;
    } else {
      badgeBg = const Color(0xFFFEE2E2);
      badgeText = const Color(0xFFDC2626);
      badgeBorder = const Color(0xFFFECACA);
      badgeIcon = Icons.cancel_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap:
              () => _showVisitDetailDialog(
                visit,
                formattedDate,
                formattedTime,
                puskesmas,
                badgeLabel,
                badgeBg,
                badgeText,
                badgeBorder,
              ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: badgeBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(badgeIcon, size: 12, color: badgeText),
                          const SizedBox(width: 4),
                          Text(
                            badgeLabel,
                            style: GoogleFonts.plusJakartaSans(
                              color: badgeText,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isPast && status == 'Terjadwal' && _isReminderEnabled)
                      Row(
                        children: [
                          const Icon(
                            Icons.notifications_active_rounded,
                            size: 14,
                            color: Color(0xFF059669),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _getOffsetLabel(_reminderOffsetMinutes),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF059669),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        formattedDate,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
                if (formattedTime.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formattedTime,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_rounded,
                      size: 16,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        puskesmas,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (notes != null && notes.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.description_outlined,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            notes,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: Colors.grey.shade700,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showVisitDetailDialog(
    Map<dynamic, dynamic> visit,
    String formattedDate,
    String formattedTime,
    String puskesmas,
    String badgeLabel,
    Color badgeBg,
    Color badgeText,
    Color badgeBorder,
  ) {
    final notes = visit['notes']?.toString();

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 8,
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Detail Kunjungan',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(color: Colors.grey.shade100, height: 1),
                const SizedBox(height: 16),
                _buildDetailRow(
                  'Tanggal',
                  formattedDate,
                  Icons.calendar_today_rounded,
                ),
                const SizedBox(height: 12),
                _buildDetailRow(
                  'Waktu',
                  formattedTime.isNotEmpty ? formattedTime : 'Belum ditentukan',
                  Icons.access_time_rounded,
                ),
                const SizedBox(height: 12),
                _buildDetailRow(
                  'Puskesmas',
                  puskesmas,
                  Icons.location_on_rounded,
                ),
                const SizedBox(height: 12),
                _buildDetailRow(
                  'Keperluan / Catatan',
                  (notes != null && notes.trim().isNotEmpty)
                      ? notes
                      : 'Pemeriksaan Rutin / Evaluasi Pengobatan TB',
                  Icons.notes_rounded,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.flag_rounded,
                      size: 16,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Status: ',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: badgeBorder),
                      ),
                      child: Text(
                        badgeLabel,
                        style: GoogleFonts.plusJakartaSans(
                          color: badgeText,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.alarm_rounded,
                      size: 16,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Pengingat: ',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    Text(
                      _isReminderEnabled
                          ? 'Aktif (${_getOffsetLabel(_reminderOffsetMinutes)})'
                          : 'Nonaktif',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color:
                            _isReminderEnabled
                                ? const Color(0xFF059669)
                                : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
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
                      'Tutup',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey.shade400),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 24),
          child: Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
        ),
      ],
    );
  }
}
