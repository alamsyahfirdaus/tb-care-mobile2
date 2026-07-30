import 'package:apk_tb_care/connection.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isPatient = true;
  bool _isLoading = false;
  bool _isSubmitting = false;

  // Form controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nikController = TextEditingController();
  final TextEditingController _dateOfBirthController = TextEditingController();

  // Dropdown values
  String? _selectedGender;
  String? _selectedPuskesmas;
  String? _selectedSubdistrict;
  String? _selectedOfficerType;

  // Data lists
  List<dynamic> _puskesmasList = [];
  List<dynamic> _subdistrictList = [];
  List<dynamic> _officerTypesList = [];

  // Success data
  Map<String, dynamic>? _successData;
  // ignore: unused_field
  bool _showSuccessDetails = false;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);

    try {
      final puskesmasResponse = await http.get(
        Uri.parse('${Connection.BASE_URL}/puskesmas'),
      );
      final subdistrictResponse = await http.get(
        Uri.parse('${Connection.BASE_URL}/subdistricts'),
      );
      final officerTypesResponse = await http.get(
        Uri.parse('${Connection.BASE_URL}/register/roles'),
      );

      if (puskesmasResponse.statusCode == 200) {
        setState(() {
          _puskesmasList = json.decode(puskesmasResponse.body)['data'];
        });
      }

      if (subdistrictResponse.statusCode == 200) {
        setState(() {
          _subdistrictList = json.decode(subdistrictResponse.body)['data'];
        });
      }

      if (officerTypesResponse.statusCode == 200) {
        setState(() {
          _officerTypesList = json.decode(officerTypesResponse.body)['data'];
        });
      }
    } catch (e) {
      _showError('Gagal memuat data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _dateOfBirthController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(Map<String, dynamic> data) {
    setState(() {
      _successData = data;
      _showSuccessDetails = true;
    });
    _showSuccessResponse(_successData!);
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _successData = null;
      _showSuccessDetails = false;
    });

    try {
      final Map<String, dynamic> requestData = {
        'user_type': _isPatient ? 'patient' : 'officer',
        'name': _nameController.text.trim(),
        'email':
            _emailController.text.trim().isEmpty
                ? null
                : _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'gender': _selectedGender,
        'date_of_birth':
            _dateOfBirthController.text.isEmpty
                ? null
                : _dateOfBirthController.text,
        'puskesmas_id': _selectedPuskesmas,
      };

      if (_isPatient) {
        requestData['nik'] = _nikController.text.trim();

        if (_selectedSubdistrict != null) {
          requestData['subdistrict_id'] = _selectedSubdistrict;
        }
      } else {
        requestData['officer_type_id'] = _selectedOfficerType;
      }

      final response = await http.post(
        Uri.parse('${Connection.BASE_URL}/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestData),
      );

      // ignore: avoid_print
      print("STATUS : ${response.statusCode}");
      // ignore: avoid_print
      print("BODY :");
      // ignore: avoid_print
      print(response.body);

      final responseData = json.decode(response.body);

      if (response.statusCode == 201) {
        _showSuccess(responseData);
      } else if (response.statusCode == 422) {
        // Handle validation errors
        final errors = responseData['errors'] as Map<String, dynamic>;
        String errorMessage = '';

        errors.forEach((field, messages) {
          errorMessage += '${messages.join(', ')}\n';
        });

        _showError(errorMessage.isNotEmpty ? errorMessage : 'Registrasi gagal');
      } else {
        _showError(responseData['message'] ?? 'Registrasi gagal');
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _showSuccessResponse(Map<String, dynamic> data) {
    setState(() {
      _successData = data;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(
            20,
          ), // Memberi jarak dari tepi layar
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight:
                  MediaQuery.of(context).size.height *
                  0.8, // Maksimal 80% tinggi layar
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header dengan tombol close
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            data['message'] ?? 'Registrasi Berhasil',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          Navigator.of(context).pop(); // Close dialog
                          Navigator.of(context).pop(); // Go back to login
                        },
                      ),
                    ],
                  ),
                ),

                // Konten yang bisa discroll
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (data.containsKey('info'))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              data['info'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),

                        if (data.containsKey('note'))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              data['note'],
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),

                        const Divider(),

                        const Text(
                          'Informasi Akun:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),

                        const SizedBox(height: 8),

                        if (data.containsKey('user')) ...[
                          _buildInfoRow('Nama Lengkap', data['user']['name']),
                          _buildInfoRow('Username', data['user']['username']),
                          _buildInfoRow('Email', data['user']['email']),
                          _buildInfoRow(
                            'Status',
                            data['user']['is_active']
                                ? 'Aktif'
                                : 'Menunggu verifikasi admin',
                          ),
                        ],

                        const SizedBox(height: 16),

                        // Peringatan penting
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.warning_amber,
                                color: Colors.orange,
                                size: 30,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'PENTING!',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Simpan informasi akun Anda dengan:',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.screenshot, size: 16),
                                  const SizedBox(width: 4),
                                  const Text('Screenshot halaman ini'),
                                ],
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.note_alt, size: 16),
                                  const SizedBox(width: 4),
                                  const Text('Catat username & password'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Tombol footer
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Colors.green,
                      ),
                      onPressed: () {
                        Navigator.of(context).pop(); // Close dialog
                        Navigator.of(context).pop(); // Go back to login
                      },
                      child: const Text(
                        'MENUJU HALAMAN LOGIN',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrasi'),
        centerTitle: true,
        elevation: 0,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'Saya adalah:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                ToggleButtons(
                                  isSelected: [_isPatient, !_isPatient],
                                  onPressed: (index) {
                                    setState(() => _isPatient = index == 0);
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  selectedColor: Colors.white,
                                  fillColor: Theme.of(context).primaryColor,
                                  constraints: const BoxConstraints(
                                    minHeight: 40,
                                    minWidth: 120,
                                  ),
                                  children: const [
                                    Text('Pasien'),
                                    Text('Petugas'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // if (_isPatient) ...[
                          //   TextFormField(
                          //     controller: _nikController,
                          //     maxLength: 16,
                          //     decoration: InputDecoration(
                          //       labelText: 'NIK',
                          //       hintText: 'Masukkan 16 digit NIK',

                          //       prefixIcon: const Icon(Icons.credit_card),
                          //       border: OutlineInputBorder(
                          //         borderRadius: BorderRadius.circular(10),
                          //       ),
                          //       filled: true,
                          //       fillColor: Colors.grey[100],
                          //     ),
                          //     keyboardType: TextInputType.number,
                          //     validator: (value) {
                          //       if (value == null || value.isEmpty) {
                          //         return 'NIK wajib diisi';
                          //       }
                          //       if (value.length != 16) {
                          //         return 'NIK harus 16 digit';
                          //       }
                          //       return null;
                          //     },
                          //   ),
                          //   const SizedBox(height: 15),
                          // ],

                          // Nama
                          TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: 'Nama Lengkap',
                              prefixIcon: const Icon(Icons.person),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              filled: true,
                              fillColor: Colors.grey[100],
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Nama wajib diisi';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 15),

                          // Email
                          // TextFormField(
                          //   controller: _emailController,
                          //   decoration: InputDecoration(
                          //     labelText: 'Email (Opsional)',
                          //     prefixIcon: const Icon(Icons.email),
                          //     border: OutlineInputBorder(
                          //       borderRadius: BorderRadius.circular(10),
                          //     ),
                          //     filled: true,
                          //     fillColor: Colors.grey[100],
                          //   ),
                          //   keyboardType: TextInputType.emailAddress,
                          //   validator: (value) {
                          //     if (value == null || value.isEmpty) {
                          //       return null;
                          //     }

                          //     final emailRegex = RegExp(
                          //       r'^[^@]+@[^@]+\.[^@]+$',
                          //     );

                          //     if (!emailRegex.hasMatch(value.trim())) {
                          //       return 'Email tidak valid';
                          //     }

                          //     return null;
                          //   },
                          // ),
                          // const SizedBox(height: 15),

                          // Nomor HP
                          TextFormField(
                            controller: _phoneController,
                            decoration: InputDecoration(
                              labelText: 'Nomor HP',
                              hintText: 'Contoh: 081234567890',
                              prefixIcon: const Icon(Icons.phone),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              filled: true,
                              fillColor: Colors.grey[100],
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
                          ),
                          const SizedBox(height: 15),

                          // Jenis Kelamin
                          DropdownButtonFormField<String>(
                            // ignore: deprecated_member_use
                            value: _selectedGender,
                            decoration: InputDecoration(
                              labelText: 'Jenis Kelamin',
                              prefixIcon: const Icon(Icons.person_outline),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              filled: true,
                              fillColor: Colors.grey[100],
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
                            onChanged: (value) {
                              setState(() => _selectedGender = value);
                            },
                            validator: (value) {
                              if (value == null) {
                                return 'Pilih jenis kelamin';
                              }
                              return null;
                            },
                            isExpanded: true,
                          ),
                          const SizedBox(height: 15),

                          // Tanggal Lahir
                          // TextFormField(
                          //   controller: _dateOfBirthController,
                          //   decoration: InputDecoration(
                          //     labelText: 'Tanggal Lahir (Opsional)',
                          //     prefixIcon: const Icon(Icons.calendar_today),
                          //     border: OutlineInputBorder(
                          //       borderRadius: BorderRadius.circular(10),
                          //     ),
                          //     filled: true,
                          //     fillColor: Colors.grey[100],
                          //   ),
                          //   readOnly: true,
                          //   onTap: () => _selectDate(context),
                          //   validator: (value) {
                          //     return null;
                          //   },
                          // ),
                          // const SizedBox(height: 15),

                          // Puskesmas
                          DropdownButtonFormField<String>(
                            // ignore: deprecated_member_use
                            value: _selectedPuskesmas,
                            decoration: InputDecoration(
                              labelText: 'Puskesmas',
                              prefixIcon: const Icon(Icons.local_hospital),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              filled: true,
                              fillColor: Colors.grey[100],
                            ),
                            items:
                                _puskesmasList.map((puskesmas) {
                                  return DropdownMenuItem(
                                    value: puskesmas['id'].toString(),
                                    child: Text(
                                      puskesmas['name'],
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                            onChanged: (value) {
                              setState(() => _selectedPuskesmas = value);
                            },
                            validator: (value) {
                              if (value == null) {
                                return 'Pilih puskesmas';
                              }
                              return null;
                            },
                            isExpanded: true,
                          ),
                          const SizedBox(height: 15),

                          // Kecamatan (hanya untuk pasien)
                          // if (_isPatient) ...[
                          //   DropdownButtonFormField<String>(
                          //     // ignore: deprecated_member_use
                          //     value: _selectedSubdistrict,
                          //     decoration: InputDecoration(
                          //       labelText: 'Kecamatan',
                          //       prefixIcon: const Icon(Icons.location_on),
                          //       border: OutlineInputBorder(
                          //         borderRadius: BorderRadius.circular(10),
                          //       ),
                          //       filled: true,
                          //       fillColor: Colors.grey[100],
                          //     ),
                          //     items:
                          //         _subdistrictList.map((subdistrict) {
                          //           return DropdownMenuItem(
                          //             value: subdistrict['id'].toString(),
                          //             child: Text(
                          //               subdistrict['name'],
                          //               overflow: TextOverflow.ellipsis,
                          //             ),
                          //           );
                          //         }).toList(),
                          //     onChanged: (value) {
                          //       setState(() => _selectedSubdistrict = value);
                          //     },
                          //     validator: (_) => null,
                          //     isExpanded: true,
                          //   ),
                          //   const SizedBox(height: 15),
                          // ],

                          // Jenis Petugas (hanya untuk petugas)
                          if (!_isPatient) ...[
                            DropdownButtonFormField<String>(
                              // ignore: deprecated_member_use
                              value: _selectedOfficerType,
                              decoration: InputDecoration(
                                labelText: 'Jenis Petugas',
                                prefixIcon: const Icon(Icons.work),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                filled: true,
                                fillColor: Colors.grey[100],
                              ),
                              items:
                                  _officerTypesList.map((type) {
                                    return DropdownMenuItem(
                                      value: type['id'].toString(),
                                      child: Text(
                                        type['name'],
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                              onChanged: (value) {
                                setState(() => _selectedOfficerType = value);
                              },
                              validator: (value) {
                                if (value == null) {
                                  return 'Pilih jenis petugas';
                                }
                                return null;
                              },
                              isExpanded: true,
                            ),
                            const SizedBox(height: 15),
                          ],

                          // Tombol Daftar
                          SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isSubmitting ? null : _submitForm,
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              child:
                                  _isSubmitting
                                      ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                      : const Text(
                                        'DAFTAR',
                                        style: TextStyle(fontSize: 16),
                                      ),
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

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _nikController.dispose();
    _dateOfBirthController.dispose();
    super.dispose();
  }
}
