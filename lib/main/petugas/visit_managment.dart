import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apk_tb_care/connection.dart';

class VisitManagementPage extends StatefulWidget {
  final int? patientTreatmentId;
  final int patientId;
  final String patientName;

  const VisitManagementPage({
    super.key,
    required this.patientTreatmentId,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<VisitManagementPage> createState() => _VisitManagementPageState();
}

class _VisitManagementPageState extends State<VisitManagementPage> {
  List<dynamic> _visits = [];
  bool _isLoading = true;
  // ignore: unused_field
  bool _isSubmitting = false;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _visitDateController = TextEditingController();
  final TextEditingController _visitTimeController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  // Form fields
  int? _visitId;
  String _visitStatus = 'Terjadwal';
  TimeOfDay? _selectedTime;

  @override
  void initState() {
    super.initState();
    if (widget.patientTreatmentId == null) {
      _showErrorDialog('ID Pengobatan tidak valid');
    } else {
      _fetchVisits();
    }
  }

  Future<void> _fetchVisits() async {
    try {
      final session = await SharedPreferences.getInstance();
      final token = session.getString('token') ?? '';

      final response = await http.get(
        Uri.parse(
          '${Connection.BASE_URL}/treatments/${widget.patientTreatmentId}/visits',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _visits = jsonDecode(response.body)['data'];
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load visits');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      _visitDateController.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
        _visitTimeController.text =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  void _showEditDialog(Map<String, dynamic>? visit) {
    if (visit != null) {
      _visitId = visit['id'];
      _visitDateController.text = visit['visit_date'];
      _visitTimeController.text = visit['visit_time']?.substring(0, 5) ?? '';
      _visitStatus = visit['visit_status'];
      _notesController.text = visit['notes'] ?? '';

      if (visit['visit_time'] != null) {
        final timeParts = visit['visit_time'].split(':');
        _selectedTime = TimeOfDay(
          hour: int.parse(timeParts[0]),
          minute: int.parse(timeParts[1]),
        );
      }
    } else {
      _visitId = null;
      _visitDateController.clear();
      _visitTimeController.clear();
      _visitStatus = 'Terjadwal';
      _notesController.clear();
      _selectedTime = null;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(visit != null ? 'Edit Kunjungan' : 'Tambah Kunjungan'),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Visit Date
                  TextFormField(
                    controller: _visitDateController,
                    decoration: const InputDecoration(
                      labelText: 'Tanggal Kunjungan*',
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    readOnly: true,
                    onTap: () => _selectDate(context),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Tanggal kunjungan wajib diisi';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Visit Time
                  TextFormField(
                    controller: _visitTimeController,
                    decoration: const InputDecoration(
                      labelText: 'Waktu Kunjungan',
                      suffixIcon: Icon(Icons.access_time),
                    ),
                    readOnly: true,
                    onTap: () => _selectTime(context),
                  ),
                  const SizedBox(height: 16),

                  // Visit Status
                  DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use
                    value: _visitStatus,
                    decoration: const InputDecoration(
                      labelText: 'Status Kunjungan*',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Terjadwal',
                        child: Text('Terjadwal'),
                      ),
                      DropdownMenuItem(value: 'Hadir', child: Text('Hadir')),
                      DropdownMenuItem(
                        value: 'Tidak Hadir',
                        child: Text('Tidak Hadir'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _visitStatus = value!;
                      });
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Status kunjungan wajib dipilih';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Notes
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(labelText: 'Catatan'),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: _submitVisitForm,
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitVisitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final session = await SharedPreferences.getInstance();
      final token = session.getString('token') ?? '';

      final url = '${Connection.BASE_URL}/visits/store';
      log(_visitTimeController.text);

      final response =
          _visitId != null
              ? await http.put(
                Uri.parse(url),
                headers: {
                  'Authorization': 'Bearer $token',
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
                body: jsonEncode({
                  'id': _visitId,
                  'patient_treatment_id': widget.patientTreatmentId,
                  'visit_date': _visitDateController.text,
                  'visit_time':
                      _visitTimeController.text.isEmpty
                          ? null
                          : _visitTimeController.text,
                  'visit_status': _visitStatus,
                  'notes':
                      _notesController.text.isEmpty
                          ? null
                          : _notesController.text,
                }),
              )
              : await http.post(
                Uri.parse(url),
                headers: {
                  'Authorization': 'Bearer $token',
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
                body: jsonEncode({
                  'patient_treatment_id': widget.patientTreatmentId,
                  'visit_date': _visitDateController.text,
                  'visit_time':
                      _visitTimeController.text.isEmpty
                          ? null
                          : _visitTimeController.text,
                  'visit_status': _visitStatus,
                  'notes':
                      _notesController.text.isEmpty
                          ? null
                          : _notesController.text,
                }),
              );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _visitId != null
                    ? 'Kunjungan berhasil diperbarui'
                    : 'Kunjungan berhasil ditambahkan',
              ),
            ),
          );
          Navigator.pop(context);
          _fetchVisits();
        }
      } else if (response.statusCode == 422) {
        final errors = responseData['errors'] as Map<String, dynamic>;
        String errorMessage = errors.values.join('\n');
        ScaffoldMessenger.of(
          // ignore: use_build_context_synchronously
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage)));
      } else {
        throw Exception(responseData['message'] ?? 'Failed to save visit');
      }
    } catch (e) {
      ScaffoldMessenger.of(
        // ignore: use_build_context_synchronously
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _deleteVisit(int visitId) async {
    try {
      final session = await SharedPreferences.getInstance();
      final token = session.getString('token') ?? '';

      final response = await http.delete(
        Uri.parse('${Connection.BASE_URL}/visits/$visitId/delete'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Kunjungan berhasil dihapus')),
          );
          _fetchVisits();
        }
      } else {
        throw Exception('Failed to delete visit');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Error'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Kunjungan - ${widget.patientName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showEditDialog(null),
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : widget.patientTreatmentId == null
              ? const Center(child: Text('ID Pengobatan tidak valid'))
              : _visits.isEmpty
              ? const Center(child: Text('Belum ada kunjungan'))
              : ListView.builder(
                itemCount: _visits.length,
                itemBuilder: (context, index) {
                  final visit = _visits[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: ListTile(
                      title: Text(
                        DateFormat(
                          'EEEE, d MMMM y',
                          'id_ID',
                        ).format(DateTime.parse(visit['visit_date'])),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (visit['visit_time'] != null)
                            Text('Jam: ${visit['visit_time'].substring(0, 5)}'),
                          Text('Status: ${visit['visit_status']}'),
                          if (visit['notes'] != null)
                            Text('Catatan: ${visit['notes']}'),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            onPressed: () => _showEditDialog(visit),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 20),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder:
                                    (context) => AlertDialog(
                                      title: const Text('Hapus Kunjungan'),
                                      content: const Text(
                                        'Apakah Anda yakin ingin menghapus kunjungan ini?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed:
                                              () => Navigator.pop(context),
                                          child: const Text('Batal'),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                            _deleteVisit(visit['id']);
                                          },
                                          child: const Text('Hapus'),
                                        ),
                                      ],
                                    ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
    );
  }

  @override
  void dispose() {
    _visitDateController.dispose();
    _visitTimeController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}
