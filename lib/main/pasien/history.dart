// ignore_for_file: library_private_types_in_public_api

import 'dart:convert';
import 'package:apk_tb_care/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:apk_tb_care/values/colors.dart';

class MedicationHistoryPage extends StatefulWidget {
  final int patientId;
  final bool isStaff;

  // ignore: use_super_parameters
  const MedicationHistoryPage({
    Key? key,
    required this.patientId,
    this.isStaff = false,
  }) : super(key: key);

  @override
  _MedicationHistoryPageState createState() => _MedicationHistoryPageState();
}

class _MedicationHistoryPageState extends State<MedicationHistoryPage> {
  List<dynamic> _records = [];
  bool _isLoading = true;
  bool _hasMore = true;
  int _currentPage = 1;
  final int _perPage = 10;
  String _currentFilter = 'all';
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _noteController = TextEditingController();

  // In-memory cache to prevent redundant HTTP image requests
  final Map<String, Uint8List> _imageCache = {};

  @override
  void initState() {
    super.initState();
    _fetchRecordData();
    _scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _fetchRecordData();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _fetchRecordData() async {
    if (_isLoading && _currentPage > 1) return;

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    final session = await SharedPreferences.getInstance();
    final token = session.getString('token') ?? '';

    try {
      final response = await http
          .get(
            Uri.parse(
              '${Connection.BASE_URL}/treatments/${widget.patientId}/history?'
              'page=$_currentPage&per_page=$_perPage&filter=$_currentFilter',
            ),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic> newRecords = data['data'] ?? [];

        if (mounted) {
          setState(() {
            _isLoading = false;
            if (_currentPage == 1) {
              _records = List<dynamic>.from(newRecords);
            } else {
              _records.addAll(newRecords);
            }
            _hasMore = newRecords.length >= _perPage;
            _currentPage++;
          });
        }
      } else {
        throw Exception(
          'Gagal memuat data (Status Code: ${response.statusCode})',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('TimeoutException')
                  ? 'Koneksi timeout. Periksa internet Anda.'
                  : 'Gagal memuat riwayat minum obat.',
            ),
          ),
        );
      }
    }
  }

  Future<Uint8List?> fetchImage(String fileName) async {
    if (_imageCache.containsKey(fileName)) {
      return _imageCache[fileName];
    }

    final session = await SharedPreferences.getInstance();
    final token = session.getString('token') ?? '';

    try {
      final response = await http.get(
        Uri.parse('${Connection.BASE_URL}/image/$fileName'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        _imageCache[fileName] = bytes;
        return bytes;
      } else {
        debugPrint('IMAGE LOAD FAILED => ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('IMAGE EXCEPTION => $e');
      return null;
    }
  }

  Future<void> _verifyRecord(int recordId, bool isApproved, String note) async {
    final session = await SharedPreferences.getInstance();
    final token = session.getString('token') ?? '';

    try {
      final response = await http.put(
        Uri.parse('${Connection.BASE_URL}/treatments/verify'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'id': recordId, 'notes': note}),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            final index = _records.indexWhere((r) => r['id'] == recordId);
            if (index != -1) {
              _records[index]['is_verified'] = isApproved ? 1 : 0;
              _records[index]['verification_note'] = note;
            }
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isApproved
                    ? 'Verifikasi berhasil disetujui'
                    : 'Verifikasi berhasil ditolak',
              ),
            ),
          );
        }
      } else {
        throw Exception('Failed to verify record');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  void _showVerificationDialog(int recordId) {
    _noteController.clear();

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Verifikasi Catatan',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Masukkan catatan verifikasi untuk pasien:',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _noteController,
                    maxLines: 3,
                    style: GoogleFonts.plusJakartaSans(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Catatan verifikasi...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Batal',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          if (_noteController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Catatan verifikasi wajib diisi'),
                              ),
                            );
                            return;
                          }
                          Navigator.pop(context);
                          _verifyRecord(
                            recordId,
                            true,
                            _noteController.text.trim(),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'Verifikasi',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
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

  void _showDetailsDialog(Map<String, dynamic> record) {
    final isVerified = record['is_verified'] == 1;
    final isLate = record['late'] == 1;
    final submittedAt = DateTime.tryParse(record['submitted_at'] ?? '');
    final notes = record['notes'];
    final verificationNote = record['verification_note'];

    final formattedDate =
        submittedAt != null
            ? DateFormat(
              'EEEE, d MMMM yyyy - HH:mm',
              'id_ID',
            ).format(submittedAt)
            : 'Waktu tidak tersedia';

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                color: Colors.white,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        color: AppColors.primary,
                        child: Text(
                          'Detail Minum Obat',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // STATUS SECTION
                            Text(
                              'Status Verifikasi',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        isVerified
                                            ? const Color(0xFFECFDF5)
                                            : const Color(0xFFFFF7ED),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color:
                                          isVerified
                                              ? const Color(0xFFA7F3D0)
                                              : const Color(0xFFFED7AA),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isVerified
                                            ? Icons.check_circle_rounded
                                            : Icons.pending_rounded,
                                        size: 14,
                                        color:
                                            isVerified
                                                ? const Color(0xFF059669)
                                                : const Color(0xFFD97706),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        isVerified
                                            ? 'Terverifikasi'
                                            : 'Menunggu Verifikasi',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                          color:
                                              isVerified
                                                  ? const Color(0xFF065F46)
                                                  : const Color(0xFF9A3412),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isLate) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF2F2),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: const Color(0xFFFCA5A5),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.error_rounded,
                                          size: 14,
                                          color: Color(0xFFDC2626),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Terlambat',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                            color: const Color(0xFF991B1B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 16),

                            // WAKTU SECTION
                            Text(
                              'Waktu Pengisian',
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
                                    '$formattedDate WIB',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Padding(
                              padding: const EdgeInsets.only(left: 22),
                              child: Text(
                                record['submitted_relative']?.toString() ?? '',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // FOTO BUKTI SECTION
                            if (record['photo'] != null) ...[
                              Text(
                                'Bukti Foto',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                height: 200,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: FutureBuilder<Uint8List?>(
                                    future: fetchImage(
                                      record['photo'].toString(),
                                    ),
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState ==
                                          ConnectionState.waiting) {
                                        return const Center(
                                          child: CircularProgressIndicator(),
                                        );
                                      }
                                      if (!snapshot.hasData ||
                                          snapshot.data == null) {
                                        return Center(
                                          child: Icon(
                                            Icons.broken_image_rounded,
                                            color: Colors.red.shade300,
                                            size: 32,
                                          ),
                                        );
                                      }
                                      return Image.memory(
                                        snapshot.data!,
                                        fit: BoxFit.cover,
                                      );
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // CATATAN PASIEN
                            if (notes != null &&
                                notes.toString().isNotEmpty) ...[
                              Text(
                                'Catatan Pasien',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                child: Text(
                                  notes.toString(),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // CATATAN VERIFIKASI
                            if (verificationNote != null &&
                                verificationNote.toString().isNotEmpty) ...[
                              Text(
                                'Catatan Verifikasi',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0FDF4),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFDCFCE7),
                                  ),
                                ),
                                child: Text(
                                  verificationNote.toString(),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    color: const Color(0xFF166534),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 20, bottom: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(
                                'Tutup',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade600,
                                ),
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
          ),
    );
  }

  Future<void> _refreshData() async {
    setState(() {
      _currentPage = 1;
      _records.clear();
      _imageCache.clear();
      _hasMore = true;
      _isLoading = false;
    });

    await _fetchRecordData();
  }

  List<dynamic> _filterRecords(List<dynamic> records) {
    return records.where((record) {
      if (_currentFilter == 'all') return true;
      if (_currentFilter == 'verified') return record['is_verified'] == 1;
      if (_currentFilter == 'pending') return record['is_verified'] == 0;
      if (_currentFilter == 'late') return record['late'] == 1;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredRecords = _filterRecords(_records);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Riwayat Minum Obat',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        // actions: [
        //   IconButton(
        //     icon: const Icon(Icons.filter_alt_rounded),
        //     tooltip: 'Filter',
        //     onPressed: _showFilterDialog,
        //   ),
        //   IconButton(
        //     icon: const Icon(Icons.refresh_rounded),
        //     tooltip: 'Perbarui',
        //     onPressed: _refreshData,
        //   ),
        // ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: AppColors.primary,
        child:
            _records.isEmpty && _isLoading
                ? _buildSkeletonLoader()
                : filteredRecords.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: filteredRecords.length + (_hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= filteredRecords.length) {
                      return _buildLoadingIndicator();
                    }
                    return _buildRecordCard(filteredRecords[index]);
                  },
                ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child:
            _hasMore
                ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                )
                : Text(
                  'Semua data telah dimuat',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: 4,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade100, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 120,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  Container(
                    width: 70,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 160,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 100,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 140,
                          height: 12,
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
              const SizedBox(height: 12),
              Divider(color: Colors.grey.shade100, height: 1),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    width: 80,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    final isFiltered = _currentFilter != 'all';
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        alignment: Alignment.center,
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
                Icons.medication_outlined,
                color: Colors.grey.shade400,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isFiltered ? 'Hasil Filter Kosong' : 'Belum Ada Riwayat',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isFiltered
                  ? 'Belum ada riwayat yang sesuai dengan filter.'
                  : 'Belum terdapat catatan minum obat pada akun Anda.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _refreshData,
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

  Widget _buildRecordCard(Map<String, dynamic> record) {
    final isVerified = record['is_verified'] == 1;
    final isLate = record['late'] == 1;
    final submittedAt = DateTime.tryParse(record['submitted_at'] ?? '');
    final notes = record['notes'];
    final verificationNote = record['verification_note'];

    final formattedDate =
        submittedAt != null
            ? DateFormat(
              'EEEE, d MMMM yyyy - HH:mm',
              'id_ID',
            ).format(submittedAt)
            : 'Waktu tidak tersedia';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showDetailsDialog(record),
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
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isVerified
                                  ? const Color(0xFFECFDF5)
                                  : const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color:
                                isVerified
                                    ? const Color(0xFFA7F3D0)
                                    : const Color(0xFFFED7AA),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isVerified
                                  ? Icons.check_circle_rounded
                                  : Icons.pending_rounded,
                              size: 14,
                              color:
                                  isVerified
                                      ? const Color(0xFF059669)
                                      : const Color(0xFFD97706),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isVerified
                                  ? 'Terverifikasi'
                                  : 'Menunggu Verifikasi',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color:
                                    isVerified
                                        ? const Color(0xFF065F46)
                                        : const Color(0xFF9A3412),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isLate)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFFFCA5A5),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error_rounded,
                                size: 14,
                                color: Color(0xFFDC2626),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Terlambat',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: const Color(0xFF991B1B),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          border: Border.all(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child:
                            record['photo'] != null
                                ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: FutureBuilder<Uint8List?>(
                                    future: fetchImage(
                                      record['photo'].toString(),
                                    ),
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState ==
                                          ConnectionState.waiting) {
                                        return const Center(
                                          child: SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        );
                                      }
                                      if (!snapshot.hasData ||
                                          snapshot.data == null) {
                                        return Center(
                                          child: Icon(
                                            Icons.broken_image_rounded,
                                            color: Colors.red.shade300,
                                            size: 24,
                                          ),
                                        );
                                      }
                                      return Image.memory(
                                        snapshot.data!,
                                        fit: BoxFit.cover,
                                      );
                                    },
                                  ),
                                )
                                : Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.image_not_supported_rounded,
                                        color: Colors.grey.shade400,
                                        size: 24,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "Tidak ada",
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 8,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time_rounded,
                                  size: 14,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    formattedDate,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              record['submitted_relative']?.toString() ?? '',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            if (notes != null &&
                                notes.toString().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Catatan: ${notes.toString().length > 30 ? "${notes.toString().substring(0, 30)}..." : notes.toString()}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                            if (verificationNote != null &&
                                verificationNote.toString().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Verifikasi: ${verificationNote.toString().length > 30 ? "${verificationNote.toString().substring(0, 30)}..." : verificationNote.toString()}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      isVerified
                                          ? const Color(0xFF166534)
                                          : const Color(0xFF991B1B),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (widget.isStaff && record['is_verified'] == 0) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton.icon(
                          onPressed:
                              () => _showVerificationDialog(record['id']),
                          icon: const Icon(
                            Icons.verified_user_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                          label: Text(
                            'Verifikasi Catatan',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD97706),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Divider(color: Colors.grey.shade100, height: 1),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'Lihat Detail',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Filter Riwayat',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
              _buildFilterOption(context, 'all', 'Semua'),
              _buildFilterOption(context, 'verified', 'Terverifikasi'),
              _buildFilterOption(context, 'pending', 'Menunggu Verifikasi'),
              _buildFilterOption(context, 'late', 'Terlambat'),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterOption(
    BuildContext context,
    String filterValue,
    String label,
  ) {
    final isSelected = _currentFilter == filterValue;
    return ListTile(
      title: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppColors.primary : Colors.grey.shade700,
        ),
      ),
      trailing:
          isSelected
              ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
              : const Icon(Icons.radio_button_off_rounded, color: Colors.grey),
      onTap: () {
        Navigator.pop(context);
        setState(() {
          _currentFilter = filterValue;
          _refreshData();
        });
      },
    );
  }
}
