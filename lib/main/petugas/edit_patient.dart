import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apk_tb_care/connection.dart';

// ignore: must_be_immutable
class EditPatientPage extends StatefulWidget {
  int patientId;

  EditPatientPage({super.key, required this.patientId});

  @override
  State<EditPatientPage> createState() => _EditPatientPageState();
}

class _EditPatientPageState extends State<EditPatientPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _dateOfBirthController = TextEditingController();
  final TextEditingController _diagnosisDateController =
      TextEditingController();

  // Form fields
  late String _nik;
  late String _name;
  late String _email;
  late String _phone;
  late String _gender;
  late String _placeOfBirth;
  late DateTime _dateOfBirth;
  late int _puskesmasId;
  late int _subdistrictId;
  late String _address;
  String? _occupation;
  int? _height;
  int? _weight;
  String? _bloodType;
  DateTime? _diagnosisDate;

  // Dropdown options
  List<Map<String, dynamic>> _puskesmasOptions = [];
  List<Map<String, dynamic>> _subdistrictOptions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeFormData();
    _fetchDropdownData();
  }

  Future<void> _initializeFormData() async {
    try {
      final session = await SharedPreferences.getInstance();
      final token = session.getString('token') ?? '';

      final response = await http.get(
        Uri.parse('${Connection.BASE_URL}/patients/${widget.patientId}/show'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        Map<String, dynamic> dataJson = jsonDecode(response.body);
        Map<String, dynamic> patient = dataJson['data'];
        setState(() {
          _nik = patient['nik'] ?? '';
          _name = patient['name'] ?? '';
          _email = patient['email'] ?? '';
          _phone = patient['phone'] ?? '';
          _gender = patient['gender'] ?? 'L';
          _placeOfBirth = patient['place_of_birth'] ?? '';
          _dateOfBirth =
              patient['date_of_birth'] != null
                  ? DateTime.parse(patient['date_of_birth'])
                  : DateTime.now();
          _puskesmasId = patient['puskesmas_id'] ?? 0;
          _subdistrictId = patient['subdistrict_id'] ?? 0;
          _address = patient['address'] ?? '';
          _occupation = patient['occupation'];
          _height = patient['height'];
          _weight = patient['weight'];
          _bloodType = patient['blood_type'];
          _diagnosisDate =
              patient['diagnosis_date'] != null
                  ? DateTime.parse(patient['diagnosis_date'])
                  : null;

          _dateOfBirthController.text = DateFormat(
            'yyyy-MM-dd',
          ).format(_dateOfBirth);
          if (_diagnosisDate != null) {
            _diagnosisDateController.text = DateFormat(
              'yyyy-MM-dd',
            ).format(_diagnosisDate!);
          }
        });
      } else {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error status code: ${response.statusCode}')),
        );
        log(response.body.toString());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
        log(e.toString());
      }
    }
  }

  Future<void> _fetchDropdownData() async {
    try {
      final session = await SharedPreferences.getInstance();
      final token = session.getString('token') ?? '';

      // Fetch puskesmas data
      final puskesmasResponse = await http.get(
        Uri.parse('${Connection.BASE_URL}/puskesmas'),
        headers: {'Authorization': 'Bearer $token'},
      );

      // Fetch subdistrict data
      final subdistrictResponse = await http.get(
        Uri.parse('${Connection.BASE_URL}/subdistricts'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (puskesmasResponse.statusCode == 200 &&
          subdistrictResponse.statusCode == 200) {
        setState(() {
          _puskesmasOptions = List<Map<String, dynamic>>.from(
            jsonDecode(puskesmasResponse.body)['data'],
          );
          _subdistrictOptions = List<Map<String, dynamic>>.from(
            jsonDecode(subdistrictResponse.body)['data'],
          );
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load dropdown data');
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

  Future<void> _selectDate(BuildContext context, bool isBirthDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          isBirthDate ? _dateOfBirth : _diagnosisDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isBirthDate) {
          _dateOfBirth = picked;
          _dateOfBirthController.text = DateFormat('yyyy-MM-dd').format(picked);
        } else {
          _diagnosisDate = picked;
          _diagnosisDateController.text = DateFormat(
            'yyyy-MM-dd',
          ).format(picked);
        }
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    _formKey.currentState!.save();

    try {
      log(widget.patientId.toString());
      final session = await SharedPreferences.getInstance();
      final token = session.getString('token') ?? '';

      final response = await http.post(
        Uri.parse('${Connection.BASE_URL}/patients/store'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'patient_id': widget.patientId.toString(),
          'nik': _nik,
          'name': _name,
          'email': _email,
          'phone': _phone,
          'gender': _gender,
          'place_of_birth': _placeOfBirth,
          'date_of_birth': _dateOfBirth.toIso8601String(),
          'puskesmas_id': _puskesmasId,
          'subdistrict_id': _subdistrictId,
          'address': _address,
          'occupation': _occupation,
          'height': _height,
          'weight': _weight,
          'blood_type': _bloodType,
          'diagnosis_date': _diagnosisDate?.toIso8601String(),
        }),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pasien berhasil diubah')),
          );
          Navigator.pop(context, true);
        }
      } else if (response.statusCode == 422) {
        // Handle validation errors
        final errors = responseData['errors'] as Map<String, dynamic>;
        String errorMessage = '';

        // Build error message from all validation errors
        errors.forEach((field, messages) {
          if (messages is List) {
            errorMessage += '${messages.join(', ')}\n';
          } else {
            errorMessage += '$messages\n';
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(errorMessage.trim())));
        }
      } else {
        // Handle other errors
        throw Exception(responseData['message'] ?? 'Failed to add patient');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Data Pasien'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _confirmDelete,
            tooltip: 'Hapus Pasien',
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
                      // NIK
                      TextFormField(
                        initialValue: _nik,
                        decoration: const InputDecoration(
                          labelText: 'NIK',
                          hintText: 'Masukkan 16 digit NIK',
                        ),
                        keyboardType: TextInputType.number,
                        maxLength: 16,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'NIK wajib diisi';
                          }
                          if (value.length != 16) {
                            return 'NIK harus 16 digit';
                          }
                          return null;
                        },
                        onSaved: (value) => _nik = value!,
                      ),
                      const SizedBox(height: 16),

                      // Name
                      TextFormField(
                        initialValue: _name,
                        decoration: const InputDecoration(
                          labelText: 'Nama Lengkap',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Nama wajib diisi';
                          }
                          return null;
                        },
                        onSaved: (value) => _name = value!,
                      ),
                      const SizedBox(height: 16),

                      // Email
                      TextFormField(
                        initialValue: _email,
                        decoration: const InputDecoration(labelText: 'Email'),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Email wajib diisi';
                          }
                          if (!RegExp(
                            r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                          ).hasMatch(value)) {
                            return 'Format email tidak valid';
                          }
                          return null;
                        },
                        onSaved: (value) => _email = value!,
                      ),
                      const SizedBox(height: 16),

                      // Phone
                      TextFormField(
                        initialValue: _phone,
                        decoration: const InputDecoration(
                          labelText: 'Nomor HP',
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Nomor HP wajib diisi';
                          }
                          if (value.length < 10 || value.length > 15) {
                            return 'Nomor HP harus 10-15 digit';
                          }
                          return null;
                        },
                        onSaved: (value) => _phone = value!,
                      ),
                      const SizedBox(height: 16),

                      // Gender
                      DropdownButtonFormField<String>(
                        // ignore: deprecated_member_use
                        value: _gender,
                        decoration: const InputDecoration(
                          labelText: 'Jenis Kelamin',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'L',
                            child: Text('Laki-laki'),
                          ),
                          DropdownMenuItem(
                            value: 'P',
                            child: Text('Perempuan'),
                          ),
                        ],
                        validator: (value) {
                          if (value == null) {
                            return 'Jenis kelamin wajib dipilih';
                          }
                          return null;
                        },
                        onChanged: (value) => setState(() => _gender = value!),
                        onSaved: (value) => _gender = value!,
                      ),
                      const SizedBox(height: 16),

                      // Place of Birth
                      TextFormField(
                        initialValue: _placeOfBirth,
                        decoration: const InputDecoration(
                          labelText: 'Tempat Lahir',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Tempat lahir wajib diisi';
                          }
                          if (value.length > 100) {
                            return 'Maksimal 100 karakter';
                          }
                          return null;
                        },
                        onSaved: (value) => _placeOfBirth = value!,
                      ),
                      const SizedBox(height: 16),

                      // Date of Birth
                      TextFormField(
                        controller: _dateOfBirthController,
                        decoration: const InputDecoration(
                          labelText: 'Tanggal Lahir',
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        readOnly: true,
                        onTap: () => _selectDate(context, true),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Tanggal lahir wajib diisi';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Puskesmas
                      DropdownButtonFormField<int>(
                        // ignore: deprecated_member_use
                        value: _puskesmasId,
                        decoration: const InputDecoration(
                          labelText: 'Puskesmas',
                        ),
                        items:
                            _puskesmasOptions.map((puskesmas) {
                              return DropdownMenuItem<int>(
                                value: puskesmas['id'],
                                child: Text(puskesmas['name']),
                              );
                            }).toList(),
                        validator: (value) {
                          if (value == null) {
                            return 'Puskesmas wajib dipilih';
                          }
                          return null;
                        },
                        onChanged:
                            (value) => setState(() => _puskesmasId = value!),
                        onSaved: (value) => _puskesmasId = value!,
                      ),
                      const SizedBox(height: 16),

                      // Subdistrict
                      DropdownButtonFormField<int>(
                        // ignore: deprecated_member_use
                        value: _subdistrictId,
                        isExpanded: true, // ⬅️ cegah teks terpotong
                        decoration: const InputDecoration(
                          labelText: 'Kecamatan',
                          isDense: false, // ⬅️ tinggi field normal
                          // contentPadding: EdgeInsets.symmetric(
                          //   vertical: 18, //
                          //   horizontal: 12,
                          // ),
                        ),
                        items:
                            _subdistrictOptions.map((subdistrict) {
                              return DropdownMenuItem<int>(
                                value: subdistrict['id'],
                                child: Text(
                                  subdistrict['name'],
                                  overflow:
                                      TextOverflow
                                          .ellipsis, // ⬅️ aman untuk nama panjang
                                ),
                              );
                            }).toList(),
                        validator: (value) {
                          if (value == null) {
                            return 'Kecamatan wajib dipilih';
                          }
                          return null;
                        },
                        onChanged:
                            (value) => setState(() => _subdistrictId = value!),
                        onSaved: (value) => _subdistrictId = value!,
                      ),

                      const SizedBox(height: 16),

                      // Address
                      TextFormField(
                        initialValue: _address,
                        decoration: const InputDecoration(labelText: 'Alamat'),
                        maxLines: 2,
                        onSaved: (value) => _address = value ?? '',
                      ),
                      const SizedBox(height: 16),

                      // Occupation
                      TextFormField(
                        initialValue: _occupation,
                        decoration: const InputDecoration(
                          labelText: 'Pekerjaan',
                        ),
                        onSaved: (value) => _occupation = value,
                      ),
                      const SizedBox(height: 16),

                      // Height and Weight
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue: _height?.toString(),
                              decoration: const InputDecoration(
                                labelText: 'Tinggi Badan (cm)',
                              ),
                              keyboardType: TextInputType.number,
                              onSaved:
                                  (value) =>
                                      _height =
                                          value != null && value.isNotEmpty
                                              ? int.parse(value)
                                              : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              initialValue: _weight?.toString(),
                              decoration: const InputDecoration(
                                labelText: 'Berat Badan (kg)',
                              ),
                              keyboardType: TextInputType.number,
                              onSaved:
                                  (value) =>
                                      _weight =
                                          value != null && value.isNotEmpty
                                              ? int.parse(value)
                                              : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Blood Type
                      TextFormField(
                        initialValue: _bloodType,
                        decoration: const InputDecoration(
                          labelText: 'Golongan Darah',
                          hintText: 'Contoh: A, B, AB, O',
                        ),
                        maxLength: 3,
                        onSaved: (value) => _bloodType = value,
                      ),
                      const SizedBox(height: 16),

                      // Diagnosis Date
                      TextFormField(
                        controller: _diagnosisDateController,
                        decoration: const InputDecoration(
                          labelText: 'Tanggal Diagnosis (opsional)',
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        readOnly: true,
                        onTap: () => _selectDate(context, false),
                      ),
                      const SizedBox(height: 24),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _submitForm,
                          // ignore: sort_child_properties_last
                          child: Text('Simpan Perubahan', style: TextStyle(color: Colors.white),),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Hapus Pasien'),
            content: const Text(
              'Apakah Anda yakin ingin menghapus data pasien ini?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Hapus'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await _deletePatient();
    }
  }

  Future<void> _deletePatient() async {
    try {
      final session = await SharedPreferences.getInstance();
      final token = session.getString('token') ?? '';

      final response = await http.delete(
        Uri.parse('${Connection.BASE_URL}/patients/${widget.patientId}'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pasien berhasil dihapus')),
          );
          Navigator.pop(context, true); // Return success
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to delete patient');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  @override
  void dispose() {
    _dateOfBirthController.dispose();
    _diagnosisDateController.dispose();
    super.dispose();
  }
}
