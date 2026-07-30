import 'dart:convert';

import 'package:apk_tb_care/main/petugas/treatment_managment.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apk_tb_care/connection.dart';

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
    setState(() {
      _isLoading = true;
    });

    final session = await SharedPreferences.getInstance();
    final token = session.getString('token') ?? '';

    try {
      final response = await http.get(
        Uri.parse(
          '${Connection.BASE_URL}/patients/${widget.patientId}/treatments',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data['data'] ?? [];
      } else {
        throw Exception('Failed to load treatment history');
      }
    } catch (e) {
      throw Exception('Error fetching treatment history: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Pengobatan')),
      body: FutureBuilder<List<dynamic>>(
        future: _treatmentHistoryFuture,
        builder: (context, snapshot) {
          if (_isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Tidak ada riwayat pengobatan'));
          }

          final treatments = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: treatments.length,
            itemBuilder: (context, index) {
              final treatment = treatments[index];
              return _buildTreatmentCard(treatment, index);
            },
          );
        },
      ),
      floatingActionButton:
          (widget.isStaff == true && widget.isDone == true)
              ? FloatingActionButton(
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
                backgroundColor: Colors.blue,
                // ignore: sort_child_properties_last
                child: const Icon(Icons.add),
                tooltip: 'Tambah Pasien',
              )
              : null,
    );
  }

  Widget _buildTreatmentCard(Map<String, dynamic> treatment, int index) {
    final startDate =
        treatment['start_date'] != null
            ? DateTime.parse(treatment['start_date'])
            : null;

    final endDate =
        treatment['end_date'] != null
            ? DateTime.parse(treatment['end_date'])
            : null;

    final formattedStartDate =
        startDate != null ? DateFormat('dd MMM yyyy').format(startDate) : '-';

    final formattedEndDate =
        endDate != null ? DateFormat('dd MMM yyyy').format(endDate) : '-';

    final medicationTime =
        treatment['medication_time'] != null
            ? treatment['medication_time'].toString().substring(0, 5)
            : '--:--';

    final List prescriptions =
        treatment['prescription'] is List ? treatment['prescription'] : [];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pengobatan #${index + 1}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            _buildDetailRow('Tanggal Mulai', formattedStartDate),
            _buildDetailRow('Tanggal Selesai', formattedEndDate),
            _buildDetailRow('Waktu Minum Obat', '$medicationTime WIB'),

            if (prescriptions.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Daftar Obat:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Column(
                children:
                    prescriptions
                        .map((drug) => _buildDrugItem(drug.toString()))
                        .toList(),
              ),
            ] else ...[
              const SizedBox(height: 12),
              const Text(
                'Daftar obat tidak tersedia',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildDrugItem(String drugName) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.medication, size: 16),
          const SizedBox(width: 8),
          Text(drugName),
        ],
      ),
    );
  }

  // ignore: unused_element
  Color _getStatusColor(String status, bool isBackground) {
    switch (status) {
      case 'Berjalan':
        return isBackground ? Colors.green[50]! : Colors.green;
      case 'Selesai':
        return isBackground ? Colors.blue[50]! : Colors.blue;
      default:
        return isBackground ? Colors.grey[200]! : Colors.grey;
    }
  }

  // ignore: unused_element
  Color _getStatusTextColor(String status) {
    switch (status) {
      case 'Berjalan':
        return Colors.green[800]!;
      case 'Selesai':
        return Colors.blue[800]!;
      default:
        return Colors.grey[800]!;
    }
  }
}
