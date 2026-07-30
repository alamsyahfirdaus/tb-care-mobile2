import 'dart:convert';
import 'package:apk_tb_care/main/pasien/history.dart';
import 'package:apk_tb_care/main/pasien/treatment_history.dart';
import 'package:apk_tb_care/main/petugas/add_patient.dart';
import 'package:apk_tb_care/main/petugas/edit_patient.dart';
import 'package:apk_tb_care/main/petugas/treatment_managment.dart';
import 'package:apk_tb_care/main/petugas/visit_managment.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:apk_tb_care/connection.dart';

class PatientPage extends StatefulWidget {
  const PatientPage({super.key});

  @override
  State<PatientPage> createState() => _PatientPageState();
}

class _PatientPageState extends State<PatientPage> {
  List<dynamic> _patientData = [];
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'all'; // all, active, completed

  @override
  void initState() {
    super.initState();
    _fetchPatientData();
  }

  Future<void> _fetchPatientData() async {
    final session = await SharedPreferences.getInstance();
    final token = session.getString('token') ?? '';

    try {
      final response = await http.get(
        Uri.parse('${Connection.BASE_URL}/patients'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        Map<String, dynamic> dataJson = jsonDecode(response.body);
        setState(() {
          _patientData = List<Map<String, dynamic>>.from(dataJson['data']);
        });
      } else {
        throw Exception('Failed to load patient data');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  // Helper method to get the first active treatment or null
  Map<String, dynamic>? _getActiveTreatment(Map<String, dynamic> patient) {
    if (patient['treatments'] == null || patient['treatments'].isEmpty) {
      return null;
    }

    // Find first treatment with status 'Berjalan' or return the first one
    return patient['treatments'].firstWhere(
      (t) => t['treatment_status'] == 'Berjalan',
      orElse: () => patient['treatments'].first,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Manajemen Pasien'),
          bottom: const TabBar(
            tabs: [Tab(text: 'Daftar Pasien'), Tab(text: 'Pengobatan')],
          ),
        ),
        body: TabBarView(
          children: [_buildPatientListTab(), _buildTreatmentTab()],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AddPatientPage()),
            );
          },
          backgroundColor: Colors.blue,
          // ignore: sort_child_properties_last
          child: Icon(Icons.add, color: Colors.white),
          tooltip: 'Tambah Pasien',
        ),
      ),
    );
  }

  Widget _buildPatientListTab() {
    final filteredPatients =
        _patientData.where((patient) {
          final query = _searchController.text.toLowerCase();
          final name = patient['name'].toString().toLowerCase();
          final nik = patient['nik'].toString().toLowerCase();

          if (!name.contains(query) && !nik.contains(query)) {
            return false;
          }

          return true;
        }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cari pasien...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              suffixIcon:
                  _searchController.text.isNotEmpty
                      ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                      : null,
            ),
            onChanged: (value) => setState(() {}),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchPatientData,
            child: ListView.builder(
              itemCount: filteredPatients.length,
              itemBuilder: (context, index) {
                return _buildPatientCard(filteredPatients[index]);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPatientCard(Map<String, dynamic> patient) {
    final treatment = _getActiveTreatment(patient);
    final status = treatment?['treatment_status'] ?? 'Belum ada pengobatan';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: InkWell(
        onTap: () => _showPatientDetail(patient),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // ignore: sort_child_properties_last
              CircleAvatar(child: Text(patient['name'][0]), radius: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient['name'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('NIK: ${patient['nik']}'),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.medical_services,
                          size: 16,
                          color: _getStatusColor(status),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          status,
                          style: TextStyle(color: _getStatusColor(status)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTreatmentTab() {
    final filteredPatients =
        _patientData.where((patient) {
          if (_selectedFilter == 'all') return true;

          final treatment = _getActiveTreatment(patient);
          if (treatment == null) return false;

          return treatment['treatment_status'].toLowerCase() == _selectedFilter;
        }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: DropdownButtonFormField<String>(
            // ignore: deprecated_member_use
            value: _selectedFilter,
            decoration: InputDecoration(
              labelText: 'Filter Status',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12),
            ),
            items: [
              DropdownMenuItem(value: 'all', child: Text('Semua Status')),
              DropdownMenuItem(value: 'berjalan', child: Text('Berjalan')),
              DropdownMenuItem(value: 'selesai', child: Text('Selesai')),
            ],
            onChanged: (value) {
              setState(() {
                _selectedFilter = value ?? 'all';
              });
            },
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: filteredPatients.length,
            itemBuilder: (context, index) {
              return _buildTreatmentCard(filteredPatients[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTreatmentCard(Map<String, dynamic> patient) {
    final treatment = _getActiveTreatment(patient);

    // Handle cases where patient has no treatments
    if (treatment == null) {
      return Card(
        margin: const EdgeInsets.all(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                patient['name'],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              const Text('Belum ada pengobatan'),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => TreatmentManagementPage(
                                patientId: patient['id'],
                                patientName: patient['name'],
                              ),
                        ),
                      );
                    },
                    child: const Text('Buat Pengobatan'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // Calculate treatment progress
    final hasDates =
        treatment['start_date'] != null && treatment['end_date'] != null;
    DateTime? startDate;
    DateTime? endDate;
    int totalDays = 0;
    int daysPassed = 0;
    double progress = 0.0;

    if (hasDates) {
      try {
        startDate = DateTime.parse(treatment['start_date']);
        endDate = DateTime.parse(treatment['end_date']);
        final today = DateTime.now();
        totalDays = endDate.difference(startDate).inDays;
        daysPassed = today.difference(startDate).inDays;
        progress = totalDays > 0 ? daysPassed / totalDays : 0;
      } catch (e) {
        debugPrint('Error parsing dates: $e');
      }
    }

    return Card(
      margin: const EdgeInsets.all(8),
      child: InkWell(
        onTap: () => _showTreatmentDetail(patient, treatment),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      patient['name'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Chip(
                    label: Text(
                      treatment['treatment_status'] ?? 'Belum Mulai',
                      style: const TextStyle(color: Colors.white),
                    ),
                    backgroundColor: _getStatusColor(
                      treatment['treatment_status'],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                hasDates
                    ? 'Periode: ${DateFormat('dd MMM yyyy').format(startDate!)} - ${DateFormat('dd MMM yyyy').format(endDate!)}'
                    : 'Jadwal pengobatan belum ditentukan',
              ),
              const SizedBox(height: 8),
              if (hasDates) ...[
                LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  backgroundColor: Colors.grey[200],
                  color: _getStatusColor(treatment['treatment_status']),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Hari ${daysPassed.clamp(0, totalDays)} dari $totalDays',
                    ),
                    Text('${(progress * 100).toStringAsFixed(1)}%'),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () => _updateTreatmentStatus(patient, treatment),
                    child: const Text('Update Status'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => VisitManagementPage(
                                patientId: patient['id'],
                                patientTreatmentId: treatment['id'],
                                patientName: patient['name'],
                              ),
                        ),
                      );
                    },
                    child: const Text('Kunjungan'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPatientDetail(Map<String, dynamic> patient) {
    final treatment = _getActiveTreatment(patient);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Detail Pasien',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildDetailRow('Nama', patient['name'] ?? '-'),
                _buildDetailRow('NIK', patient['nik'] ?? '-'),
                _buildDetailRow('Alamat', patient['address'] ?? '-'),
                _buildDetailRow('Telepon', patient['phone'] ?? '-'),
                _buildDetailRow(
                  'Jenis Kelamin',
                  patient['gender'] == 'L' ? 'Laki-laki' : 'Perempuan',
                ),
                _buildDetailRow(
                  'Tanggal Lahir',
                  patient['date_of_birth'] ?? '-',
                ),
                _buildDetailRow('Puskesmas', patient['puskesmas'] ?? '-'),
                _buildDetailRow('Kecamatan', patient['subdistrict'] ?? '-'),
                _buildDetailRow(
                  'Status Pengobatan',
                  treatment?['treatment_status'] ?? 'Belum ada pengobatan',
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
                    treatment['medication_time']?.substring(0, 5) ?? '-',
                  ),
                ],
                const SizedBox(height: 24),

                // Action Buttons Section - Row 1
                Row(
                  children: [
                    // Edit Button
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Edit Data'),
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) =>
                                      EditPatientPage(patientId: patient['id']),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Treatment Button
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.medical_services, size: 18),
                        label: Text(
                          treatment != null ? 'Pengobatan' : 'Buat Pengobatan',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) {
                                if (patient['treatment_status'] == 'Berjalan') {
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
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Action Buttons Section - Row 2
                if (treatment != null) ...[
                  Row(
                    children: [
                      // Visit Button
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.calendar_today, size: 18),
                          label: const Text('Kunjungan'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[700],
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            Navigator.pop(context);
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
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Medication History & Validation Button
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.medication, size: 18),
                          label: const Text('History & Validasi'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange[700],
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => MedicationHistoryPage(
                                      patientId: patient['id'],
                                      isStaff: true,
                                    ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showTreatmentDetail(
    Map<String, dynamic> patient,
    Map<String, dynamic> treatment,
  ) {
    final hasDates =
        treatment['start_date'] != null && treatment['end_date'] != null;
    DateTime? startDate;
    DateTime? endDate;
    int totalDays = 0;
    int daysPassed = 0;
    double progress = 0.0;

    if (hasDates) {
      try {
        startDate = DateTime.parse(treatment['start_date']);
        endDate = DateTime.parse(treatment['end_date']);
        final today = DateTime.now();
        totalDays = endDate.difference(startDate).inDays;
        daysPassed = today.difference(startDate).inDays;
        progress = totalDays > 0 ? daysPassed / totalDays : 0;
      } catch (e) {
        debugPrint('Error parsing dates: $e');
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Detail Pengobatan',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildDetailRow('Nama Pasien', patient['name'] ?? '-'),

              if (hasDates) ...[
                _buildDetailRow(
                  'Tanggal Mulai',
                  DateFormat('dd MMM yyyy').format(startDate!),
                ),
                _buildDetailRow(
                  'Tanggal Selesai',
                  DateFormat('dd MMM yyyy').format(endDate!),
                ),
                _buildDetailRow(
                  'Progress',
                  '${daysPassed.clamp(0, totalDays)} dari $totalDays hari (${(progress * 100).toStringAsFixed(1)}%)',
                ),
                LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  backgroundColor: Colors.grey[200],
                  color: _getStatusColor(treatment['treatment_status']),
                ),
              ] else
                _buildDetailRow('Status Pengobatan', 'Jadwal belum ditentukan'),

              _buildDetailRow(
                'Waktu Minum Obat',
                treatment['medication_time']?.substring(0, 5) ?? '-',
              ),
              _buildDetailRow(
                'Status',
                treatment['treatment_status'] ?? 'Belum dimulai',
              ),

              if (treatment['visits'] != null &&
                  treatment['visits'].isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Jadwal Kunjungan:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ...treatment['visits'].map<Widget>((visit) {
                  return ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: Text(
                      DateFormat(
                        'EEEE, d MMMM yyyy',
                        'id_ID',
                      ).format(DateTime.parse(visit['visit_date'])),
                    ),
                    subtitle: Text(
                      'Jam: ${visit['visit_time']?.substring(0, 5) ?? '-'}',
                    ),
                    trailing: Text(visit['visit_status'] ?? '-'),
                  );
                }).toList(),
              ],

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _updateTreatmentStatus(patient, treatment),
                  child: const Text('Update Status Pengobatan'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const Text(': '),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _updateTreatmentStatus(
    Map<String, dynamic> patient,
    Map<String, dynamic> treatment,
  ) {
    String? newStatus = treatment['treatment_status'];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Update Status Pengobatan'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<String>(
                    title: const Text('Berjalan'),
                    value: 'Berjalan',
                    // ignore: deprecated_member_use
                    groupValue: newStatus,
                    // ignore: deprecated_member_use
                    onChanged: (value) => setState(() => newStatus = value),
                  ),
                  RadioListTile<String>(
                    title: const Text('Selesai'),
                    value: 'Selesai',
                    // ignore: deprecated_member_use
                    groupValue: newStatus,
                    // ignore: deprecated_member_use
                    onChanged: (value) => setState(() => newStatus = value),
                  ),
                  RadioListTile<String>(
                    title: const Text('Gagal'),
                    value: 'Gagal',
                    // ignore: deprecated_member_use
                    groupValue: newStatus,
                    // ignore: deprecated_member_use
                    onChanged: (value) => setState(() => newStatus = value),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (newStatus != null &&
                    newStatus != treatment['treatment_status']) {
                  // Call API to update status
                  final success = await _updateTreatmentStatusOnServer(
                    treatment['id'],
                    newStatus!,
                  );

                  if (success && mounted) {
                    setState(() {
                      treatment['treatment_status'] = newStatus;
                    });
                    // ignore: use_build_context_synchronously
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Status pengobatan diperbarui'),
                      ),
                    );
                    // ignore: use_build_context_synchronously
                    Navigator.pop(context);
                  }
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memperbarui status: ${e.toString()}')),
        );
      }
      return false;
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'berjalan':
        return Colors.blue;
      case 'selesai':
        return Colors.green;
      case 'gagal':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
