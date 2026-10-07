import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:apk_tb_care/models/patient_medication.dart';
import 'package:apk_tb_care/services/patient_medication_service.dart';
import 'package:apk_tb_care/values/colors.dart';

class PatientMedicationsPage extends StatefulWidget {
  final int patientId;
  final Map<String, dynamic>? initialTreatment;
  final List<dynamic>? initialPrescriptions;
  final String? initialMedicationTime;

  const PatientMedicationsPage({
    super.key,
    required this.patientId,
    this.initialTreatment,
    this.initialPrescriptions,
    this.initialMedicationTime,
  });

  @override
  State<PatientMedicationsPage> createState() => _PatientMedicationsPageState();
}

class _PatientMedicationsPageState extends State<PatientMedicationsPage> {
  bool _isLoading = true;
  String? _errorMessage;
  PatientMedicationResponse? _data;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _fetchData();
  }

  void _loadInitialData() {
    // 1. Dari initialTreatment lengkap
    if (widget.initialTreatment != null) {
      final t = widget.initialTreatment!;
      final rawList = t['prescription'];
      final medTime = widget.initialMedicationTime ?? t['medication_time']?.toString();

      final List<PatientMedication> meds = [];
      if (rawList is List) {
        for (final item in rawList) {
          if (item != null) {
            meds.add(PatientMedication.fromDynamic(item, defaultScheduleTime: medTime));
          }
        }
      }

      _data = PatientMedicationResponse(
        treatmentId: t['id'] is int ? t['id'] as int : null,
        treatmentType: t['treatment_type']?.toString(),
        treatmentStatus: t['treatment_status']?.toString(),
        startDate: t['start_date']?.toString(),
        endDate: t['end_date']?.toString(),
        medicationTime: medTime,
        count: meds.length,
        medications: meds,
      );
      _isLoading = false;
      return;
    }

    // 2. Dari initialPrescriptions list
    if (widget.initialPrescriptions != null) {
      final List<PatientMedication> meds = [];
      for (final item in widget.initialPrescriptions!) {
        if (item != null) {
          meds.add(PatientMedication.fromDynamic(item, defaultScheduleTime: widget.initialMedicationTime));
        }
      }
      _data = PatientMedicationResponse(
        medicationTime: widget.initialMedicationTime,
        count: meds.length,
        medications: meds,
      );
      _isLoading = false;
    }
  }

  Future<void> _fetchData() async {
    if (_data == null) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final res = await PatientMedicationService.getMedications(
        patientId: widget.patientId,
      );

      if (mounted) {
        setState(() {
          _data = res;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_data == null) {
            _errorMessage = e.toString();
          }
        });
      }
    }
  }

  String _formatTime(String? rawTime) {
    if (rawTime == null || rawTime.isEmpty) return '--:--';
    final parts = rawTime.split(':');
    if (parts.length >= 2) {
      return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')} WIB';
    }
    return '$rawTime WIB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Daftar Obat'),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchData,
        color: AppColors.primary,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _data == null) {
      return _buildLoadingState();
    }

    if (_errorMessage != null && _data == null) {
      return _buildErrorState();
    }

    final medications = _data?.medications ?? [];
    if (medications.isEmpty) {
      return _buildEmptyState();
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      children: [
        _buildHeaderBanner(),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Obat yang Sedang Dikonsumsi',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${medications.length} Obat',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...medications.map((med) => _buildMedicationCard(med)),
        const SizedBox(height: 24),
        _buildInfoBanner(),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildHeaderBanner() {
    final status = _data?.treatmentStatus ?? 'Berjalan';
    final typeName = _data?.treatmentType;
    final timeStr = _data?.medicationTime;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200, width: 1.2),
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
                  Icons.medication_liquid_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Program Pengobatan TB',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    if (typeName != null && typeName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        typeName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFA7F3D0), width: 1),
                ),
                child: Text(
                  status,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF059669),
                  ),
                ),
              ),
            ],
          ),
          if (timeStr != null && timeStr.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200, width: 1),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.alarm_rounded,
                    color: AppColors.primary,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Jadwal Minum Harian: ',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    _formatTime(timeStr),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
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

  Widget _buildMedicationCard(PatientMedication med) {
    final hasDosage = med.dosage != null && med.dosage!.trim().isNotEmpty;
    final hasFrequency = med.frequency != null && med.frequency!.trim().isNotEmpty;
    final hasRules = med.rules != null && med.rules!.trim().isNotEmpty;
    final hasSchedule = med.scheduleTime != null && med.scheduleTime!.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
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
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  med.name,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.grey.shade800,
                  ),
                ),
                if (hasDosage) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.scale_rounded, size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 6),
                      Text(
                        med.dosage!,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
                if (hasFrequency) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.repeat_rounded, size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 6),
                      Text(
                        med.frequency!,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
                if (hasRules) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          med.rules!,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (hasSchedule) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.access_time_rounded, size: 13, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          'Jadwal: ${_formatTime(med.scheduleTime)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F8FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Konsumsi obat secara teratur sesuai anjuran petugas faskes. Jangan menghentikan pengobatan tanpa petunjuk dokter.',
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
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.medication_rounded,
                color: AppColors.primary,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Belum Ada Data Obat',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Informasi obat belum tersedia pada pengobatan Anda. Silakan hubungi petugas TB di fasilitas kesehatan Anda untuk mendapatkan resep.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _fetchData,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(
                'Perbarui Data',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      children: [
        Container(
          height: 80,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          width: 140,
          height: 16,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 14),
        for (int i = 0; i < 3; i++) ...[
          Container(
            height: 72,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade100, width: 1.5),
            ),
          ),
        ],
        const SizedBox(height: 20),
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Memuat informasi obat...',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                color: Colors.red.shade400,
                size: 36,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Gagal Memuat Daftar Obat',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Terjadi kesalahan saat memuat data obat.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchData,
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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
