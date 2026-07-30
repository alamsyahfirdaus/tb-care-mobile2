// ignore_for_file: library_private_types_in_public_api

import 'dart:convert';
import 'dart:typed_data';
import 'package:apk_tb_care/connection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
// ignore: unused_import
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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
  // ignore: prefer_final_fields
  List<dynamic> _records = [];
  bool _isLoading = true;
  bool _hasMore = true;
  int _currentPage = 1;
  final int _perPage = 10;
  String _currentFilter = 'all';
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _noteController = TextEditingController();

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

    setState(() {
      _isLoading = true;
    });

    final session = await SharedPreferences.getInstance();
    final token = session.getString('token') ?? '';

    try {
      final response = await http.get(
        Uri.parse(
          '${Connection.BASE_URL}/treatments/${widget.patientId}/history?'
          'page=$_currentPage&per_page=$_perPage&filter=$_currentFilter',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic> newRecords = data['data'] ?? [];

        setState(() {
          _isLoading = false;
          _records.addAll(newRecords);
          _hasMore = newRecords.length >= _perPage;
          _currentPage++;
        });
      } else {
        throw Exception('Failed to load medication history');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  Future<Uint8List?> fetchImage(String fileName) async {
    final session = await SharedPreferences.getInstance();
    final token = session.getString('token') ?? '';

    try {
      final response = await http.get(
        Uri.parse('${Connection.BASE_URL}/image/$fileName'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return response.bodyBytes;
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
        // Update local record
        setState(() {
          final index = _records.indexWhere((r) => r['id'] == recordId);
          if (index != -1) {
            _records[index]['is_verified'] = isApproved ? 1 : 0;
            _records[index]['verification_note'] = note;
          }
        });

        if (mounted) {
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
          (context) => AlertDialog(
            title: const Text('Verifikasi Catatan'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Masukkan catatan verifikasi:'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _noteController,
                    decoration: const InputDecoration(
                      hintText: 'Catatan verifikasi...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (_noteController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Catatan verifikasi wajib diisi'),
                      ),
                    );
                    return;
                  }
                  Navigator.pop(context);
                  _verifyRecord(recordId, true, _noteController.text);
                },
                child: const Text('Verify'),
              ),
            ],
          ),
    );
  }

  void _showDetailsDialog(Map<String, dynamic> record) {
    final isVerified = record['is_verified'] == 1;
    final submittedAt = DateTime.parse(record['submitted_at']);
    final notes = record['notes'];
    final verificationNote = record['verification_note'];

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Detail Obat'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // STATUS
                  Row(
                    children: [
                      Icon(
                        isVerified ? Icons.verified : Icons.pending,
                        size: 20,
                        color: isVerified ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isVerified ? 'Terverifikasi' : 'Menunggu Verifikasi',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color:
                              isVerified
                                  ? Colors.green[800]
                                  : Colors.orange[800],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // WAKTU
                  const Text(
                    'Waktu Pengisian:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    DateFormat(
                      'EEEE, d MMMM yyyy - HH:mm',
                      'id_ID',
                    ).format(submittedAt),
                  ),
                  const SizedBox(height: 8),
                  Text(record['submitted_relative']),
                  const SizedBox(height: 16),

                  // FOTO (FIXED)
                  if (record['photo'] != null) ...[
                    const Text(
                      'Bukti Foto:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: FutureBuilder<Uint8List?>(
                          future: fetchImage(record['photo']),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            if (!snapshot.hasData) {
                              return const Icon(
                                Icons.broken_image,
                                color: Colors.red,
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
                  if (notes != null && notes.isNotEmpty) ...[
                    const Text(
                      'Catatan Pasien:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(notes),
                    const SizedBox(height: 16),
                  ],

                  // CATATAN VERIFIKASI
                  if (verificationNote != null &&
                      verificationNote.isNotEmpty) ...[
                    const Text(
                      'Catatan Verifikasi:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(verificationNote),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Tutup'),
              ),
            ],
          ),
    );
  }

  Future<void> _refreshData() async {
    setState(() {
      _currentPage = 1;
      _records.clear();
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
      appBar: AppBar(
        title: const Text('Riwayat Minum Obat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt),
            onPressed: _showFilterDialog,
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshData),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child:
            _records.isEmpty && _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredRecords.isEmpty
                ? const Center(child: Text('Belum ada riwayat minum obat'))
                : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(8),
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
                ? const CircularProgressIndicator()
                : const Text('Tidak ada data lagi'),
      ),
    );
  }

  Widget _buildRecordCard(Map<String, dynamic> record) {
    final isVerified = record['is_verified'] == 1;
    final isLate = record['late'] == 1;
    final submittedAt = DateTime.parse(record['submitted_at']);
    final notes = record['notes'];
    final verificationNote = record['verification_note'];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      elevation: 2,
      child: InkWell(
        onTap: () => _showDetailsDialog(record),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: isVerified ? Colors.green[50] : Colors.orange[50],
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isVerified ? Icons.verified : Icons.pending,
                    size: 16,
                    color: isVerified ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isVerified ? 'Terverifikasi' : 'Menunggu Verifikasi',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color:
                          isVerified ? Colors.green[800] : Colors.orange[800],
                    ),
                  ),
                  const Spacer(),
                  if (isLate)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Terlambat',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),

            // Photo and Details
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Photo
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child:
                        record['photo'] != null
                            ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: FutureBuilder<Uint8List?>(
                                future: fetchImage(record['photo']),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  }
                                  if (!snapshot.hasData) {
                                    return const Icon(
                                      Icons.broken_image,
                                      color: Colors.red,
                                    );
                                  }
                                  return Image.memory(
                                    snapshot.data!,
                                    fit: BoxFit.cover,
                                  );
                                },
                              ),
                            )
                            : const Center(
                              child: Icon(Icons.medical_services, size: 40),
                            ),
                  ),

                  const SizedBox(width: 12),

                  // Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Submission Info
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              size: 16,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat(
                                'EEEE, d MMMM yyyy - HH:mm',
                              ).format(submittedAt),
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          record['submitted_relative'],
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),

                        // Notes (if any)
                        if (notes != null && notes.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Catatan: ${notes.length > 30 ? '${notes.substring(0, 30)}...' : notes}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],

                        // Verification Note (if any)
                        if (verificationNote != null &&
                            verificationNote.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Verifikasi: ${verificationNote.length > 30 ? '${verificationNote.substring(0, 30)}...' : verificationNote}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isVerified ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Verification buttons (for staff)
            if (widget.isStaff && record['is_verified'] == 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 12, left: 12, right: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.orange),
                      ),
                      onPressed: () => _showVerificationDialog(record['id']),
                      child: const Text(
                        'Verifikasi',
                        style: TextStyle(color: Colors.orange),
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

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Filter Riwayat'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Semua'),
                trailing:
                    _currentFilter == 'all' ? const Icon(Icons.check) : null,
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _currentFilter = 'all';
                    _refreshData();
                  });
                },
              ),
              ListTile(
                title: const Text('Terverifikasi'),
                trailing:
                    _currentFilter == 'verified'
                        ? const Icon(Icons.check)
                        : null,
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _currentFilter = 'verified';
                    _refreshData();
                  });
                },
              ),
              ListTile(
                title: const Text('Menunggu Verifikasi'),
                trailing:
                    _currentFilter == 'pending'
                        ? const Icon(Icons.check)
                        : null,
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _currentFilter = 'pending';
                    _refreshData();
                  });
                },
              ),
              ListTile(
                title: const Text('Terlambat'),
                trailing:
                    _currentFilter == 'late' ? const Icon(Icons.check) : null,
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _currentFilter = 'late';
                    _refreshData();
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
