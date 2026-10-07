import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:apk_tb_care/models/close_contact.dart';
import 'package:apk_tb_care/services/close_contact_service.dart';
import 'package:apk_tb_care/values/colors.dart';
import 'package:apk_tb_care/main/pasien/household_member_form_page.dart';
import 'package:apk_tb_care/main/pasien/screening.dart';

class HouseholdMemberDetailPage extends StatefulWidget {
  final int contactId;
  final CloseContact? initialContact;
  final int? patientId;

  const HouseholdMemberDetailPage({
    super.key,
    required this.contactId,
    this.initialContact,
    this.patientId,
  });

  @override
  State<HouseholdMemberDetailPage> createState() =>
      _HouseholdMemberDetailPageState();
}

class _HouseholdMemberDetailPageState extends State<HouseholdMemberDetailPage> {
  late CloseContact? _contact;
  bool _isLoading = false;
  bool _isDeleting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _contact = widget.initialContact;
    _refreshDetail();
  }

  Future<void> _refreshDetail() async {
    if (_contact == null) {
      setState(() => _isLoading = true);
    }
    try {
      final updated = await CloseContactService.getContactDetail(
        widget.contactId,
      );
      if (mounted) {
        setState(() {
          _contact = updated;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToEdit() async {
    if (_contact == null) return;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder:
            (_) => HouseholdMemberFormPage(
              existingContact: _contact,
              patientId: widget.patientId,
            ),
      ),
    );

    if (result == true && mounted) {
      _refreshDetail();
    }
  }

  void _navigateToScreening() async {
    final contact = _contact;
    if (contact == null) return;

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ScreeningPage(contact: contact),
      ),
    );

    if (result == true && mounted) {
      await _refreshDetail();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Skrining untuk ${contact.name} berhasil disimpan.',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showScreeningDetailModal() {
    final contact = _contact;
    if (contact == null) return;

    final latest = contact.latestScreening;
    final riskLevel = latest?.riskLevel.isNotEmpty == true
        ? latest!.riskLevel
        : contact.screeningResult;
    final isHigh =
        riskLevel.contains('Tinggi') || riskLevel.contains('Positif');
    final isModerate = riskLevel.contains('Sedang');
    final themeColor =
        isHigh
            ? const Color(0xFFEF4444)
            : isModerate
            ? const Color(0xFFF59E0B)
            : const Color(0xFF10B981);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.85,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Title Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: themeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.assignment_outlined,
                        color: themeColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hasil Skrining TB',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${contact.name} (${contact.relationship})',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: const Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),

              // Scrollable content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badge status card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: themeColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: themeColor.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              riskLevel,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: themeColor,
                              ),
                            ),
                            if (latest != null &&
                                latest.status.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Status: ${latest.status}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF475569),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Info grid / rows
                      if (latest != null && latest.code.isNotEmpty)
                        _buildDetailRow('Kode Skrining', latest.code),
                      if (latest?.screenedAtFormatted != null ||
                          contact.formattedScreeningDate != null)
                        _buildDetailRow(
                          'Tanggal Skrining',
                          latest?.screenedAtFormatted ??
                              contact.formattedScreeningDate ??
                              '-',
                        ),
                      if (latest != null) ...[
                        _buildDetailRow(
                          'Total Skor',
                          '${latest.totalScore} poin',
                        ),
                        _buildDetailRow(
                          'Jumlah Gejala',
                          '${latest.symptomsCount} gejala',
                        ),
                      ],
                      if (contact.tptStatus.isNotEmpty &&
                          contact.tptStatus != '-')
                        _buildDetailRow('Status TPT', contact.tptStatus),

                      const SizedBox(height: 8),

                      // Rekomendasi
                      Text(
                        'Rekomendasi Tindak Lanjut',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          latest?.recommendation.isNotEmpty == true
                              ? latest!.recommendation
                              : isHigh
                              ? 'Segera bawa anggota ke fasilitas kesehatan rujukan untuk pemeriksaan dahak/medis lebih lanjut.'
                              : 'Terapkan Pola Hidup Bersih dan Sehat (PHBS). Jika timbul batuk atau demam lebih dari 2 minggu, segera periksakan ke Puskesmas.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: const Color(0xFF334155),
                            height: 1.45,
                          ),
                        ),
                      ),

                      // Riwayat skrining lainnya jika ada > 1
                      if (contact.screenings.length > 1) ...[
                        const SizedBox(height: 20),
                        Text(
                          'Riwayat Skrining Lainnya (${contact.screenings.length})',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...contact.screenings.skip(1).map((s) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.code,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        s.screenedAtFormatted ??
                                            s.screenedAt ??
                                            '-',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          color: const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE2E8F0),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    s.riskLevel,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ),

              // Bottom button
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Tutup',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _navigateToScreening();
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: Text(
                          'Skrining Ulang',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete() async {
    final contact = _contact;
    if (contact == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Hapus Anggota?',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            content: Text(
              'Apakah Anda yakin ingin menghapus ${contact.name} dari daftar anggota serumah?',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: const Color(0xFF475569),
                height: 1.4,
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  'Batal',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Hapus',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isDeleting = true);
      try {
        await CloseContactService.deleteContact(contact.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Anggota berhasil dihapus.',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
              ),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isDeleting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Gagal menghapus anggota: $e',
                style: GoogleFonts.plusJakartaSans(),
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final contact = _contact;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Detail Anggota')),
      body:
          _isLoading && contact == null
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null && contact == null
              ? _buildErrorView()
              : contact == null
              ? const Center(child: Text('Data tidak ditemukan.'))
              : _buildContent(contact),
    );
  }

  Widget _buildContent(CloseContact contact) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 36),
      child: Column(
        children: [
          // 1. Header Profile Card
          _buildProfileHeader(contact),
          const SizedBox(height: 16),

          // 2. Section: Informasi Pribadi
          _buildInfoSection(contact),
          const SizedBox(height: 16),

          // 3. Section: Status Skrining & Kesehatan
          _buildHealthSection(contact),
          const SizedBox(height: 24),

          // 4. Action Buttons (Ubah & Hapus)
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(CloseContact contact) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
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
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color:
                  contact.gender == 'P'
                      ? const Color(0xFFFCE7F3)
                      : const Color(0xFFE0F2FE),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                contact.gender == 'P'
                    ? Icons.face_3_rounded
                    : Icons.face_rounded,
                color:
                    contact.gender == 'P'
                        ? const Color(0xFFDB2777)
                        : const Color(0xFF0284C7),
                size: 40,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            contact.name,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              contact.relationship,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
          if (contact.contactCode.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Kode: ${contact.contactCode}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoSection(CloseContact contact) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Informasi Pribadi', Icons.person_outline_rounded),
          const SizedBox(height: 16),
          _buildDetailRow('Jenis Kelamin', contact.genderLabel),
          if (contact.formattedDateOfBirth != null)
            _buildDetailRow('Tanggal Lahir', contact.formattedDateOfBirth!),
          _buildDetailRow('Usia', '${contact.age} tahun'),
          if (contact.nik != null && contact.nik!.isNotEmpty)
            _buildDetailRow('NIK', contact.nik!),
          if (contact.phone != null && contact.phone!.isNotEmpty)
            _buildDetailRow('Nomor Telepon', contact.phone!),
          if (contact.address != null && contact.address!.isNotEmpty)
            _buildDetailRow('Alamat', contact.address!),
        ],
      ),
    );
  }

  Widget _buildHealthSection(CloseContact contact) {
    final isScreened = contact.isScreened;
    final latest = contact.latestScreening;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            'Status Skrining & Kesehatan',
            Icons.medical_services_outlined,
          ),
          const SizedBox(height: 16),

          // Status Skrining dengan Badge Berwarna
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 120,
                  child: Text(
                    'Status Skrining',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: contact.screeningColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: contact.screeningColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isScreened
                                ? Icons.check_circle_rounded
                                : Icons.schedule_rounded,
                            size: 14,
                            color: contact.screeningColor,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            contact.screeningResult,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: contact.screeningColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (contact.formattedScreeningDate != null)
            _buildDetailRow(
              'Tanggal Skrining',
              contact.formattedScreeningDate!,
            ),

          if (latest != null && latest.code.isNotEmpty)
            _buildDetailRow(
              'Kode Skrining',
              latest.code,
            ),

          if (latest != null && latest.recommendation.isNotEmpty)
            _buildDetailRow(
              'Rekomendasi',
              latest.recommendation,
            ),

          if (contact.notes != null && contact.notes!.isNotEmpty)
            _buildDetailRow('Catatan', contact.notes!),

          const SizedBox(height: 8),

          // Action button area
          if (!isScreened) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: Color(0xFFD97706),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Anggota ini belum melakukan skrining TB. Lakukan skrining sekarang untuk mengetahui risiko kesehatan.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: const Color(0xFF92400E),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _navigateToScreening,
                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                label: Text(
                  'Mulai Skrining Sekarang',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showScreeningDetailModal,
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: Text(
                      'Lihat Hasil Skrining',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _navigateToScreening,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: Text(
                    'Skrining Ulang',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        // Tombol Ubah
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isDeleting ? null : _navigateToEdit,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: Text(
              'Ubah',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Tombol Hapus
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isDeleting ? null : _confirmDelete,
            icon:
                _isDeleting
                    ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.delete_outline_rounded, size: 18),
            label: Text(
              'Hapus',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
              side: const BorderSide(color: Color(0xFFEF4444)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Gagal memuat detail anggota',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(fontSize: 14),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _refreshDetail,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
