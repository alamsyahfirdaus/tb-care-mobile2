import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apk_tb_care/connection.dart';

class TreatmentManagementPage extends StatefulWidget {
  final int patientId;
  final String patientName;
  final Map<String, dynamic>? existingTreatment;
  final VoidCallback? onShowHistory; // Callback for history button

  const TreatmentManagementPage({
    super.key,
    required this.patientId,
    required this.patientName,
    this.existingTreatment,
    this.onShowHistory,
  });

  @override
  State<TreatmentManagementPage> createState() =>
      _TreatmentManagementPageState();
}

class _TreatmentManagementPageState extends State<TreatmentManagementPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _diagnosisDateController =
      TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _medicationTimeController =
      TextEditingController();

  // Form fields
  int? _treatmentId;
  int? _treatmentTypeId;
  String _treatmentStatus = 'Berjalan';
  String? _prescription;
  TimeOfDay? _medicationTime;

  // Dropdown options
  List<Map<String, dynamic>> _treatmentTypes = [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _initializeFormData();
    _fetchTreatmentTypes();
  }

  void _initializeFormData() {
    if (widget.existingTreatment != null) {
      final treatment = widget.existingTreatment!;
      _treatmentId = treatment['id'];

      if (treatment['diagnosis_date'] != null) {
        _diagnosisDateController.text = treatment['diagnosis_date'];
      }

      if (treatment['start_date'] != null) {
        _startDateController.text = treatment['start_date'];
      }

      if (treatment['medication_time'] != null) {
        _medicationTimeController.text = treatment['medication_time'];
        final timeParts = treatment['medication_time'].split(':');
        _medicationTime = TimeOfDay(
          hour: int.parse(timeParts[0]),
          minute: int.parse(timeParts[1]),
        );
      }

      _treatmentTypeId = treatment['treatment_type_id'];
      _treatmentStatus = treatment['treatment_status'] ?? 'Berjalan';
      _prescription = treatment['prescription']?.join(', ');
    }
  }

  Future<void> _fetchTreatmentTypes() async {
    try {
      final session = await SharedPreferences.getInstance();
      final token = session.getString('token') ?? '';

      final response = await http.get(
        Uri.parse('${Connection.BASE_URL}/treatments/types'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _treatmentTypes = List<Map<String, dynamic>>.from(
            jsonDecode(response.body)['data'],
          );
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load treatment types');
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

  Future<void> _selectDate(BuildContext context, bool isDiagnosisDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      final formattedDate = DateFormat('yyyy-MM-dd').format(picked);
      if (isDiagnosisDate) {
        _diagnosisDateController.text = formattedDate;
      } else {
        _startDateController.text = formattedDate;
      }
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _medicationTime ?? TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() {
        _medicationTime = picked;
        _medicationTimeController.text =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_medicationTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Waktu minum obat wajib diisi')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final session = await SharedPreferences.getInstance();
      final token = session.getString('token') ?? '';

      final url = '${Connection.BASE_URL}/treatments/store';

      final requestBody = {
        if (_treatmentId != null) 'id': _treatmentId,
        'patient_id': widget.patientId,
        'treatment_type_id': _treatmentTypeId,
        if (_diagnosisDateController.text.isNotEmpty)
          'diagnosis_date': _diagnosisDateController.text,
        if (_startDateController.text.isNotEmpty)
          'start_date': _startDateController.text,
        'medication_time': DateFormat('HH:mm').format(
          DateTime(0, 0, 0, _medicationTime!.hour, _medicationTime!.minute),
        ),
        'prescription': _prescription?.split(', ') ?? [],
        'treatment_status': _treatmentStatus,
      };

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _treatmentId != null
                    ? 'Data pengobatan berhasil diperbarui'
                    : 'Data pengobatan berhasil disimpan',
              ),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } else if (response.statusCode == 422) {
        final errors = responseData['errors'] as Map<String, dynamic>;
        String errorMessage = '';

        errors.forEach((field, messages) {
          if (messages is List) {
            errorMessage += '${messages.join(', ')}\n';
          } else {
            errorMessage += '$messages\n';
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage.trim()),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        throw Exception(responseData['message'] ?? 'Failed to save treatment');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existingTreatment != null
              ? 'Edit Pengobatan - ${widget.patientName}'
              : 'Tambah Pengobatan - ${widget.patientName}',
        ),
        actions: [
          if (widget.onShowHistory != null)
            IconButton(
              icon: const Icon(Icons.history),
              tooltip: 'Riwayat Pengobatan',
              onPressed: widget.onShowHistory,
            ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Treatment Type Dropdown
                      DropdownButtonFormField<int>(
                        // ignore: deprecated_member_use
                        value: _treatmentTypeId,
                        decoration: InputDecoration(
                          labelText: 'Jenis Pengobatan*',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        items:
                            _treatmentTypes.map((type) {
                              return DropdownMenuItem<int>(
                                value: type['id'],
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      type['treatment_type'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Durasi: ${type['duration']}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                        validator: (value) {
                          if (value == null) {
                            return 'Jenis pengobatan wajib dipilih';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          setState(() {
                            _treatmentTypeId = value;
                            final selectedType = _treatmentTypes.firstWhere(
                              (type) => type['id'] == value,
                              orElse: () => {},
                            );
                            if (selectedType.isNotEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(selectedType['description']),
                                  duration: const Duration(seconds: 5),
                                  behavior: SnackBarBehavior.floating,
                                  width: 600,
                                ),
                              );
                            }
                          });
                        },
                        selectedItemBuilder: (context) {
                          return _treatmentTypes.map((type) {
                            return Text(
                              '${type['treatment_type']} (${type['duration']})',
                              overflow: TextOverflow.ellipsis,
                            );
                          }).toList();
                        },
                      ),
                      const SizedBox(height: 16),

                      // Diagnosis Date
                      TextFormField(
                        controller: _diagnosisDateController,
                        decoration: InputDecoration(
                          labelText: 'Tanggal Diagnosis',
                          suffixIcon: const Icon(Icons.calendar_today),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        readOnly: true,
                        onTap: () => _selectDate(context, true),
                      ),
                      const SizedBox(height: 16),

                      // Start Date
                      TextFormField(
                        controller: _startDateController,
                        decoration: InputDecoration(
                          labelText: 'Tanggal Mulai Pengobatan',
                          suffixIcon: const Icon(Icons.calendar_today),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        readOnly: true,
                        onTap: () => _selectDate(context, false),
                        validator: (value) {
                          if (value?.isNotEmpty == true &&
                              _diagnosisDateController.text.isNotEmpty) {
                            final startDate = DateTime.parse(value!);
                            final diagnosisDate = DateTime.parse(
                              _diagnosisDateController.text,
                            );
                            if (startDate.isBefore(diagnosisDate)) {
                              return 'Tidak boleh sebelum tanggal diagnosis';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Medication Time
                      TextFormField(
                        controller: _medicationTimeController,
                        decoration: InputDecoration(
                          labelText: 'Waktu Minum Obat*',
                          suffixIcon: const Icon(Icons.access_time),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        readOnly: true,
                        onTap: () => _selectTime(context),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Waktu minum obat wajib diisi';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Prescription
                      TextFormField(
                        initialValue: _prescription,
                        decoration: InputDecoration(
                          labelText: 'Resep Obat (pisahkan dengan koma)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        maxLines: 3,
                        onChanged: (value) => _prescription = value,
                      ),
                      const SizedBox(height: 16),

                      // Treatment Status
                      DropdownButtonFormField<String>(
                        // ignore: deprecated_member_use
                        value: _treatmentStatus,
                        decoration: InputDecoration(
                          labelText: 'Status Pengobatan*',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Berjalan',
                            child: Text('Berjalan'),
                          ),
                          DropdownMenuItem(
                            value: 'Selesai',
                            child: Text('Selesai'),
                          ),
                          DropdownMenuItem(
                            value: 'Gagal',
                            child: Text('Gagal'),
                          ),
                          DropdownMenuItem(
                            value: 'Meninggal',
                            child: Text('Meninggal'),
                          ),
                        ],
                        validator: (value) {
                          if (value == null) {
                            return 'Status pengobatan wajib dipilih';
                          }
                          return null;
                        },
                        onChanged:
                            (value) =>
                                setState(() => _treatmentStatus = value!),
                      ),
                      const SizedBox(height: 24),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitForm,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            backgroundColor: Theme.of(context).primaryColor,
                          ),
                          child:
                              _isSubmitting
                                  ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : Text(
                                    _treatmentId != null
                                        ? 'PERBARUI PENGATURAN PENGOBATAN'
                                        : 'SIMPAN PENGATURAN PENGOBATAN',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }

  @override
  void dispose() {
    _diagnosisDateController.dispose();
    _startDateController.dispose();
    _medicationTimeController.dispose();
    super.dispose();
  }
}
