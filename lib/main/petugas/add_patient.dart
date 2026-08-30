import 'dart:convert';
import 'package:apk_tb_care/connection.dart';
import 'package:apk_tb_care/values/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddPatientPage extends StatefulWidget {
  const AddPatientPage({super.key});

  @override
  State<AddPatientPage> createState() => _AddPatientPageState();
}

class _AddPatientPageState extends State<AddPatientPage> {
  final _formKey = GlobalKey<FormState>();

  // Form Controllers
  final TextEditingController _nikController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _placeOfBirthController = TextEditingController();
  final TextEditingController _dateOfBirthDisplayController =
      TextEditingController();

  // Form State Values
  String _gender = 'L';
  DateTime? _dateOfBirth;
  int? _selectedPuskesmasId;
  String? _selectedPuskesmasName;

  // Dropdown options & UI States
  List<Map<String, dynamic>> _puskesmasOptions = [];
  bool _isLoadingPuskesmas = true;
  String? _puskesmasError;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchPuskesmasData();
  }

  @override
  void dispose() {
    _nikController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _placeOfBirthController.dispose();
    _dateOfBirthDisplayController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // DATA FETCHING (PUSKESMAS)
  // ===========================================================================

  Future<void> _fetchPuskesmasData() async {
    setState(() {
      _isLoadingPuskesmas = true;
      _puskesmasError = null;
    });

    try {
      final session = await SharedPreferences.getInstance();
      final token = session.getString('token') ?? '';

      final response = await http.get(
        Uri.parse('${Connection.BASE_URL}/puskesmas'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body is Map && body.containsKey('data') && body['data'] is List) {
          final rawList = body['data'] as List;
          final parsedList = <Map<String, dynamic>>[];
          for (final item in rawList) {
            if (item is Map) {
              final rawId = item['id'];
              final parsedId = int.tryParse(rawId?.toString() ?? '');
              final rawName = item['name']?.toString() ?? '';
              if (parsedId != null && rawName.isNotEmpty) {
                parsedList.add({'id': parsedId, 'name': rawName});
              }
            }
          }
          setState(() {
            _puskesmasOptions = parsedList;
            _isLoadingPuskesmas = false;
          });
        } else {
          throw Exception('Format data Puskesmas tidak valid');
        }
      } else if (response.statusCode == 401) {
        setState(() {
          _isLoadingPuskesmas = false;
          _puskesmasError = 'Sesi Anda telah berakhir. Silakan login kembali.';
        });
      } else if (response.statusCode == 403) {
        setState(() {
          _isLoadingPuskesmas = false;
          _puskesmasError =
              'Anda tidak memiliki akses untuk memuat data Puskesmas.';
        });
      } else {
        setState(() {
          _isLoadingPuskesmas = false;
          _puskesmasError =
              'Gagal memuat data Puskesmas (Status: ${response.statusCode}).';
        });
      }
    } catch (e) {
      debugPrint('Error fetching puskesmas: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingPuskesmas = false;
        _puskesmasError =
            'Gagal memuat data Puskesmas. Periksa koneksi internet Anda.';
      });
    }
  }

  // ===========================================================================
  // DATE PICKER (TANGGAL LAHIR)
  // ===========================================================================

  Future<void> _selectBirthDate(BuildContext context) async {
    final initialDate = _dateOfBirth ?? DateTime(2000, 1, 1);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          initialDate.isAfter(DateTime.now()) ? DateTime.now() : initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.text,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dateOfBirth = picked;
        _dateOfBirthDisplayController.text = DateFormat(
          'dd/MM/yyyy',
          'id_ID',
        ).format(picked);
      });
    }
  }

  // ===========================================================================
  // FORM SUBMISSION & API INTEGRATION
  // ===========================================================================

  Future<void> _submitForm() async {
    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Mohon lengkapi semua data wajib dengan benar.',
            style: GoogleFonts.plusJakartaSans(fontSize: 12),
          ),
          backgroundColor: const Color(0xFFC62828),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_selectedPuskesmasId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Puskesmas wajib dipilih dari daftar.',
            style: GoogleFonts.plusJakartaSans(fontSize: 12),
          ),
          backgroundColor: const Color(0xFFC62828),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final session = await SharedPreferences.getInstance();
      final token = session.getString('token') ?? '';

      final payload = {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'gender': _gender,
        'place_of_birth': _placeOfBirthController.text.trim(),
        'date_of_birth': _dateOfBirth?.toIso8601String(),
        'puskesmas_id': _selectedPuskesmasId,
        'nik':
            _nikController.text.trim().isEmpty
                ? null
                : _nikController.text.trim(),
        'email':
            _emailController.text.trim().isEmpty
                ? null
                : _emailController.text.trim(),
      };

      final response = await http.post(
        Uri.parse('${Connection.BASE_URL}/patients/store'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Pasien berhasil ditambahkan.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
        return;
      }

      // Handle Error Responses
      String errorMessage = 'Gagal menambahkan pasien.';

      try {
        final responseData = jsonDecode(response.body);

        if (response.statusCode == 401) {
          errorMessage = 'Sesi Anda telah berakhir. Silakan login kembali.';
        } else if (response.statusCode == 409) {
          errorMessage =
              responseData['message']?.toString() ??
              'Data sudah terdaftar dalam sistem (Konflik).';
        } else if (response.statusCode == 422) {
          if (responseData['errors'] is Map) {
            final errors = responseData['errors'] as Map<String, dynamic>;
            final errorList = <String>[];
            errors.forEach((key, val) {
              if (val is List && val.isNotEmpty) {
                errorList.add(val.first.toString());
              } else if (val is String) {
                errorList.add(val);
              }
            });
            if (errorList.isNotEmpty) {
              errorMessage = errorList.join('\n');
            } else {
              errorMessage =
                  responseData['message']?.toString() ?? 'Data tidak valid.';
            }
          } else {
            errorMessage =
                responseData['message']?.toString() ?? 'Data tidak valid.';
          }
        } else if (response.statusCode == 500) {
          errorMessage =
              'Terjadi kesalahan pada server. Silakan coba beberapa saat lagi.';
        } else if (responseData['message'] != null) {
          errorMessage = responseData['message'].toString();
        }
      } catch (_) {
        errorMessage = 'Terjadi kesalahan (Kode: ${response.statusCode})';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorMessage,
            style: GoogleFonts.plusJakartaSans(fontSize: 12),
          ),
          backgroundColor: const Color(0xFFC62828),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('Error submitting patient: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal menghubungkan ke server. Periksa koneksi internet Anda.',
            style: GoogleFonts.plusJakartaSans(fontSize: 12),
          ),
          backgroundColor: const Color(0xFFC62828),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  // ===========================================================================
  // MAIN BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Tambah Pasien Baru',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
      ),
      body: SafeArea(
        child:
            _isLoadingPuskesmas
                ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                        strokeWidth: 3,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Memuat data formulir...',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
                : _puskesmasError != null
                ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.cloud_off_rounded,
                          color: Color(0xFFC62828),
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _puskesmasError!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _fetchPuskesmasData,
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('Coba Lagi'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                : Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 36),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. NIK (Opsional)
                        _buildFieldLabel('NIK (Opsional)', isRequired: false),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _nikController,
                          keyboardType: TextInputType.number,
                          maxLength: 16,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(16),
                          ],
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.5,
                            color: AppColors.text,
                          ),
                          decoration: _buildInputDecoration(
                            hintText: 'Masukkan 16 digit NIK (opsional)',
                            prefixIcon: Icons.badge_outlined,
                          ),
                          validator: (value) {
                            if (value != null && value.trim().isNotEmpty) {
                              if (value.trim().length != 16) {
                                return 'NIK harus terdiri dari 16 digit';
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // 2. Nama Lengkap *
                        _buildFieldLabel('Nama Lengkap', isRequired: true),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.5,
                            color: AppColors.text,
                          ),
                          decoration: _buildInputDecoration(
                            hintText: 'Masukkan nama lengkap pasien',
                            prefixIcon: Icons.person_outline_rounded,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Nama lengkap wajib diisi';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // 3. Email (Opsional)
                        _buildFieldLabel('Email (Opsional)', isRequired: false),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.5,
                            color: AppColors.text,
                          ),
                          decoration: _buildInputDecoration(
                            hintText: 'Contoh: pasien@email.com (opsional)',
                            prefixIcon: Icons.mail_outline_rounded,
                          ),
                          validator: (value) {
                            if (value != null && value.trim().isNotEmpty) {
                              if (!RegExp(
                                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                              ).hasMatch(value.trim())) {
                                return 'Format email tidak valid';
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // 4. Nomor HP / WhatsApp *
                        _buildFieldLabel(
                          'Nomor HP / WhatsApp',
                          isRequired: true,
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(15),
                          ],
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.5,
                            color: AppColors.text,
                          ),
                          decoration: _buildInputDecoration(
                            hintText: 'Contoh: 081234567890',
                            prefixIcon: Icons.phone_outlined,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Nomor HP wajib diisi';
                            }
                            if (value.trim().length < 10 ||
                                value.trim().length > 15) {
                              return 'Nomor HP harus 10-15 digit';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // 5. Jenis Kelamin *
                        _buildFieldLabel('Jenis Kelamin', isRequired: true),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: _gender,
                          icon: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.grey,
                          ),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.5,
                            color: AppColors.text,
                          ),
                          decoration: _buildInputDecoration(
                            prefixIcon: Icons.people_outline_rounded,
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
                            if (value == null || value.isEmpty) {
                              return 'Jenis kelamin wajib dipilih';
                            }
                            return null;
                          },
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _gender = val;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 14),

                        // 6. Tempat Lahir *
                        _buildFieldLabel('Tempat Lahir', isRequired: true),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _placeOfBirthController,
                          textCapitalization: TextCapitalization.words,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.5,
                            color: AppColors.text,
                          ),
                          decoration: _buildInputDecoration(
                            hintText: 'Masukkan kota/tempat lahir',
                            prefixIcon: Icons.location_city_rounded,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Tempat lahir wajib diisi';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // 7. Tanggal Lahir *
                        _buildFieldLabel('Tanggal Lahir', isRequired: true),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _dateOfBirthDisplayController,
                          readOnly: true,
                          onTap: () => _selectBirthDate(context),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.5,
                            color: AppColors.text,
                          ),
                          decoration: _buildInputDecoration(
                            hintText: 'Pilih tanggal lahir',
                            prefixIcon: Icons.cake_outlined,
                            suffixIcon: const Icon(
                              Icons.calendar_today_outlined,
                              size: 18,
                              color: AppColors.primary,
                            ),
                          ),
                          validator: (value) {
                            if (_dateOfBirth == null) {
                              return 'Tanggal lahir wajib diisi';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // 8. Puskesmas * (Searchable Autocomplete)
                        _buildPuskesmasAutocomplete(),
                        const SizedBox(height: 28),

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _submitForm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              disabledBackgroundColor: AppColors.primary
                                  .withValues(alpha: 0.6),
                              elevation: 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child:
                                _isSubmitting
                                    ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                    : Text(
                                      'Simpan Pasien',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
      ),
    );
  }

  // ===========================================================================
  // PUSKESMAS AUTOCOMPLETE WIDGET
  // ===========================================================================

  Widget _buildPuskesmasAutocomplete() {
    return FormField<int>(
      initialValue: _selectedPuskesmasId,
      validator: (val) {
        if (_selectedPuskesmasId == null) {
          return 'Puskesmas wajib dipilih dari daftar';
        }
        return null;
      },
      builder: (formFieldState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFieldLabel('Puskesmas', isRequired: true),
            const SizedBox(height: 6),
            LayoutBuilder(
              builder: (context, constraints) {
                return Autocomplete<Map<String, dynamic>>(
                  displayStringForOption:
                      (option) => option['name']?.toString() ?? '',
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return _puskesmasOptions;
                    }
                    final query = textEditingValue.text.toLowerCase().trim();
                    return _puskesmasOptions.where((option) {
                      final name =
                          option['name']?.toString().toLowerCase() ?? '';
                      return name.contains(query);
                    });
                  },
                  onSelected: (Map<String, dynamic> selection) {
                    final rawId = selection['id'];
                    final parsedId = int.tryParse(rawId?.toString() ?? '');
                    final name = selection['name']?.toString() ?? '';

                    setState(() {
                      _selectedPuskesmasId = parsedId;
                      _selectedPuskesmasName = name;
                    });
                    formFieldState.didChange(parsedId);
                    FocusScope.of(context).unfocus();
                  },
                  fieldViewBuilder: (
                    context,
                    textEditingController,
                    focusNode,
                    onFieldSubmitted,
                  ) {
                    return TextFormField(
                      controller: textEditingController,
                      focusNode: focusNode,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        color: AppColors.text,
                      ),
                      decoration: _buildInputDecoration(
                        hintText: 'Cari dan pilih Puskesmas...',
                        prefixIcon: Icons.local_hospital_outlined,
                        suffixIcon:
                            textEditingController.text.isNotEmpty
                                ? IconButton(
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () {
                                    textEditingController.clear();
                                    setState(() {
                                      _selectedPuskesmasId = null;
                                      _selectedPuskesmasName = null;
                                    });
                                    formFieldState.didChange(null);
                                  },
                                )
                                : const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: Colors.grey,
                                ),
                      ),
                      onChanged: (value) {
                        if (value.trim() != _selectedPuskesmasName) {
                          setState(() {
                            _selectedPuskesmasId = null;
                            _selectedPuskesmasName = null;
                          });
                          formFieldState.didChange(null);
                        }
                      },
                    );
                  },
                  optionsViewBuilder: (context, onSelected, options) {
                    if (options.isEmpty) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4,
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.white,
                          child: Container(
                            width: constraints.maxWidth,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Text(
                              'Puskesmas tidak ditemukan',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                color: Colors.grey.shade500,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white,
                        child: Container(
                          width: constraints.maxWidth,
                          constraints: const BoxConstraints(maxHeight: 220),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            shrinkWrap: true,
                            itemCount: options.length,
                            separatorBuilder:
                                (_, __) => const Divider(
                                  height: 1,
                                  color: Color(0xFFF1F5F9),
                                ),
                            itemBuilder: (BuildContext context, int index) {
                              final option = options.elementAt(index);
                              final rawId = option['id'];
                              final optionId = int.tryParse(
                                rawId?.toString() ?? '',
                              );
                              final name = option['name']?.toString() ?? '';
                              final isSelected =
                                  optionId != null &&
                                  optionId == _selectedPuskesmasId;

                              return InkWell(
                                onTap: () => onSelected(option),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 11,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.local_hospital_outlined,
                                        size: 16,
                                        color:
                                            isSelected
                                                ? AppColors.primary
                                                : Colors.grey.shade500,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          name,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 13,
                                            fontWeight:
                                                isSelected
                                                    ? FontWeight.bold
                                                    : FontWeight.w500,
                                            color:
                                                isSelected
                                                    ? AppColors.primary
                                                    : AppColors.text,
                                          ),
                                        ),
                                      ),
                                      if (isSelected)
                                        const Icon(
                                          Icons.check_rounded,
                                          size: 16,
                                          color: AppColors.primary,
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            if (formFieldState.hasError) ...[
              const SizedBox(height: 5),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  formFieldState.errorText!,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: const Color(0xFFE53935),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  // ===========================================================================
  // FORM STYLING HELPERS
  // ===========================================================================

  Widget _buildFieldLabel(String label, {bool isRequired = false}) {
    return RichText(
      text: TextSpan(
        text: label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF334155),
        ),
        children: [
          if (isRequired)
            TextSpan(
              text: ' *',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFFE53935),
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    String? hintText,
    IconData? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.plusJakartaSans(
        fontSize: 13,
        color: Colors.grey.shade400,
      ),
      counterText: '',
      prefixIcon:
          prefixIcon != null
              ? Icon(prefixIcon, size: 18, color: Colors.grey.shade500)
              : null,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE53935), width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE53935), width: 1.5),
      ),
      errorStyle: GoogleFonts.plusJakartaSans(
        fontSize: 11,
        color: const Color(0xFFE53935),
      ),
    );
  }
}
