import 'dart:async';
import 'dart:convert';

import 'package:apk_tb_care/main/petugas/treatment_managment.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apk_tb_care/connection.dart';
import 'package:apk_tb_care/values/colors.dart';

// ignore: must_be_immutable
class TreatmentHistoryPage extends StatefulWidget {
  final int patientId;
  final String patientName;
  bool? isStaff;
  bool? isDone;

  TreatmentHistoryPage({
    super.key,
    required this.patientId,
    required this.patientName,
    this.isStaff = false,
    this.isDone = false,
  });

  @override
  State<TreatmentHistoryPage> createState() => _TreatmentHistoryPageState();
}

class _TreatmentHistoryPageState extends State<TreatmentHistoryPage> {
  late Future<List<dynamic>> _treatmentHistoryFuture;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _treatmentHistoryFuture = _fetchTreatmentHistory();
  }

  Future<List<dynamic>> _fetchTreatmentHistory() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final session = await SharedPreferences.getInstance();
      final token = session.getString('token') ?? '';

      final response = await http
          .get(
            Uri.parse(
              '${Connection.BASE_URL}/patients/${widget.patientId}/treatments',
            ),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data['data'] ?? [];
      } else {
        throw Exception(
          'Gagal memuat data dari server (Status Code: ${response.statusCode})',
        );
      }
    } on TimeoutException {
      throw Exception(
        'Koneksi timeout. Silakan periksa jaringan Anda dan coba lagi.',
      );
    } catch (e) {
      throw Exception('Gagal memuat riwayat pengobatan: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshHistory() async {
    if (!mounted) return;
    setState(() {
      _treatmentHistoryFuture = _fetchTreatmentHistory();
    });
    await _treatmentHistoryFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Riwayat Pengobatan',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshHistory,
        color: AppColors.primary,
        child: FutureBuilder<List<dynamic>>(
          future: _treatmentHistoryFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                _isLoading) {
              return _buildSkeletonLoader();
            }

            if (snapshot.hasError) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.7,
                  alignment: Alignment.center,
                  child: _buildErrorView(snapshot.error.toString()),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.7,
                  alignment: Alignment.center,
                  child: _buildEmptyState(),
                ),
              );
            }

            final treatments = snapshot.data!;

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: treatments.length,
              itemBuilder: (context, index) {
                final treatment = treatments[index];
                return _buildTreatmentCard(treatment, index);
              },
            );
          },
        ),
      ),
      floatingActionButton:
          (widget.isStaff == true && widget.isDone == true)
              ? FloatingActionButton.extended(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) {
                        return TreatmentManagementPage(
                          patientId: widget.patientId,
                          patientName: widget.patientName,
                          onShowHistory: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => TreatmentHistoryPage(
                                      patientId: widget.patientId,
                                      patientName: widget.patientName,
                                      isStaff: widget.isStaff,
                                      isDone: widget.isDone,
                                    ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  );
                },
                backgroundColor: AppColors.primary,
                icon: const Icon(Icons.add_rounded, color: Colors.white),
                label: Text(
                  'Tambah Pengobatan',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                tooltip: 'Tambah Pengobatan',
              )
              : null,
    );
  }

  Widget _buildTreatmentCard(Map<String, dynamic> treatment, int index) {
    final status = treatment['treatment_status']?.toString() ?? '';

    final startDate =
        treatment['start_date'] != null
            ? DateTime.tryParse(treatment['start_date'].toString())
            : null;

    final endDate =
        treatment['end_date'] != null
            ? DateTime.tryParse(treatment['end_date'].toString())
            : null;

    final formattedStartDate =
        startDate != null
            ? DateFormat('dd MMMM yyyy', 'id_ID').format(startDate)
            : 'Tanggal tidak tersedia';

    final formattedEndDate =
        endDate != null
            ? DateFormat('dd MMMM yyyy', 'id_ID').format(endDate)
            : 'Tanggal tidak tersedia';

    String medicationTime = '--:--';
    final rawMedTime = treatment['medication_time'];
    if (rawMedTime != null) {
      final medTimeStr = rawMedTime.toString();
      final parts = medTimeStr.split(':');
      if (parts.length >= 2) {
        final hour = parts[0].padLeft(2, '0');
        final minute = parts[1].padLeft(2, '0');
        medicationTime = '$hour:$minute';
      } else if (medTimeStr.length >= 5) {
        medicationTime = medTimeStr.substring(0, 5);
      } else if (medTimeStr.isNotEmpty) {
        medicationTime = medTimeStr;
      }
    }

    final List prescriptions =
        treatment['prescription'] is List ? treatment['prescription'] : [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pengobatan #${index + 1}',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.grey.shade800,
                  ),
                ),
                if (status.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status, true),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          status == 'Berjalan'
                              ? Icons.play_circle_fill_rounded
                              : status == 'Selesai'
                              ? Icons.check_circle_rounded
                              : Icons.help_rounded,
                          size: 14,
                          color: _getStatusColor(status, false),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          status,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: _getStatusTextColor(status),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Detail Tanggal (Periode)
            Text(
              'Periode Pengobatan',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$formattedStartDate — $formattedEndDate',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Waktu Minum Obat
            Text(
              'Waktu Minum Obat',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.access_time_filled_rounded,
                  size: 14,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 8),
                Text(
                  '$medicationTime WIB',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            Divider(color: Colors.grey.shade200, height: 1),
            const SizedBox(height: 12),

            // Daftar Obat
            Text(
              'Daftar Obat',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            if (prescriptions.isNotEmpty)
              Column(
                children:
                    prescriptions
                        .map((drug) => _buildDrugItem(drug.toString()))
                        .toList(),
              )
            else
              Text(
                'Tidak ada informasi obat.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrugItem(String drugName) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.medication_rounded,
              size: 14,
              color: Colors.blue.shade700,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              drugName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        children: List.generate(3, (index) => _buildSkeletonCard()),
      ),
    );
  }

  Widget _buildSkeletonCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildShimmerBlock(width: 120, height: 16),
              _buildShimmerBlock(width: 70, height: 20, borderRadius: 8),
            ],
          ),
          const SizedBox(height: 16),
          _buildShimmerBlock(width: 100, height: 12),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildShimmerBlock(width: 16, height: 16, shape: BoxShape.circle),
              const SizedBox(width: 8),
              _buildShimmerBlock(width: 180, height: 14),
            ],
          ),
          const SizedBox(height: 12),
          _buildShimmerBlock(width: 100, height: 12),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildShimmerBlock(width: 16, height: 16, shape: BoxShape.circle),
              const SizedBox(width: 8),
              _buildShimmerBlock(width: 80, height: 14),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.grey.shade100, height: 1),
          const SizedBox(height: 12),
          _buildShimmerBlock(width: 70, height: 14),
          const SizedBox(height: 8),
          Column(
            children: List.generate(
              2,
              (index) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    _buildShimmerBlock(
                      width: 16,
                      height: 16,
                      shape: BoxShape.circle,
                    ),
                    const SizedBox(width: 8),
                    _buildShimmerBlock(width: 100, height: 14),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerBlock({
    required double width,
    required double height,
    double borderRadius = 4,
    BoxShape shape = BoxShape.rectangle,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        shape: shape,
        borderRadius:
            shape == BoxShape.rectangle
                ? BorderRadius.circular(borderRadius)
                : null,
      ),
    );
  }

  Widget _buildErrorView(String error) {
    debugPrint('[ERROR] Treatment history error: $error');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                color: Colors.red.shade600,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Data Riwayat Belum Dapat Dimuat',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Periksa koneksi internet Anda dan coba lagi.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refreshHistory,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(
                'Coba Lagi',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.history_toggle_off_rounded,
                color: Colors.grey.shade400,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Belum Ada Riwayat Pengobatan',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Belum terdapat riwayat pengobatan TB pada akun pasien ini.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _refreshHistory,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(
                'Perbarui',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status, bool isBackground) {
    switch (status) {
      case 'Berjalan':
        return isBackground ? Colors.green.shade50 : Colors.green.shade600;
      case 'Selesai':
        return isBackground ? Colors.blue.shade50 : Colors.blue.shade600;
      default:
        return isBackground ? Colors.grey.shade100 : Colors.grey.shade600;
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status) {
      case 'Berjalan':
        return Colors.green.shade800;
      case 'Selesai':
        return Colors.blue.shade800;
      default:
        return Colors.grey.shade800;
    }
  }
}
