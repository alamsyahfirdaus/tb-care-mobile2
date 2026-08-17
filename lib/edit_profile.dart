import 'dart:io';
import 'dart:typed_data';
import 'package:apk_tb_care/connection.dart';
import 'package:apk_tb_care/values/colors.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
// ignore: depend_on_referenced_packages
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfileEditPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const ProfileEditPage({super.key, required this.userData});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _birthDateController;
  late final TextEditingController _placeOfBirthController;
  late final TextEditingController _passwordController;
  String? _gender;
  File? _profileImage;
  Uint8List? _profileImageBytes;
  bool _isImageLoading = false;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    debugPrint('EDIT PROFILE: initState');

    _nameController = TextEditingController(
      text: widget.userData['name'] ?? '',
    );
    _emailController = TextEditingController(
      text: widget.userData['email'] ?? '',
    );
    _phoneController = TextEditingController(
      text: widget.userData['phone'] ?? '',
    );

    // Parse tanggal lahir secara aman
    String birthDateStr = '';
    final rawBirthDate = widget.userData['date_of_birth'];
    if (rawBirthDate != null && rawBirthDate.toString().isNotEmpty) {
      try {
        final parsedDate = DateTime.parse(rawBirthDate.toString());
        birthDateStr = DateFormat('yyyy-MM-dd').format(parsedDate);
      } catch (e) {
        debugPrint('Failed to parse date of birth inside initState: $e');
      }
    }
    _birthDateController = TextEditingController(text: birthDateStr);

    _placeOfBirthController = TextEditingController(
      text: widget.userData['place_of_birth'] ?? '',
    );
    _passwordController = TextEditingController();

    final rawGender = widget.userData['gender'];
    if (rawGender == 'L') {
      _gender = 'Laki-laki';
    } else if (rawGender == 'P') {
      _gender = 'Perempuan';
    } else {
      _gender = null; // Menjadi null agar dropdown meminta input jika belum ada
    }

    _loadInitialProfileImage();
  }

  @override
  void dispose() {
    debugPrint('EDIT PROFILE: dispose');
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _birthDateController.dispose();
    _placeOfBirthController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /* =========================================================
   * LOAD PROFILE IMAGE ONCE (STABILITY FIX)
   * ========================================================= */
  Future<void> _loadInitialProfileImage() async {
    final photo = widget.userData['photo'];
    if (photo != null && photo.toString().trim().isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _isImageLoading = true;
      });

      try {
        final bytes = await fetchProfileImage(photo.toString());
        if (!mounted) return;
        setState(() {
          _profileImageBytes = bytes;
          _isImageLoading = false;
        });
      } catch (e) {
        debugPrint('Error loading initial profile image: $e');
        if (!mounted) return;
        setState(() {
          _isImageLoading = false;
        });
      }
    }
  }

  Future<Uint8List?> fetchProfileImage(String fileName) async {
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
        debugPrint('PROFILE IMAGE LOAD FAILED: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('PROFILE IMAGE ERROR: $e');
      return null;
    }
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 800, // Menghindari memory spike dengan membatasi resolusi
        maxHeight: 800,
      );
      if (pickedFile != null) {
        if (!mounted) return;
        setState(() {
          _profileImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal memilih gambar dari galeri',
            style: GoogleFonts.plusJakartaSans(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    DateTime initialDate = DateTime.now();
    final rawDate = _birthDateController.text;
    if (rawDate.isNotEmpty) {
      try {
        initialDate = DateTime.parse(rawDate);
      } catch (e) {
        debugPrint('Failed to parse date for DatePicker: $e');
      }
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      if (!mounted) return;
      setState(() {
        _birthDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  /* =========================================================
   * SAVE PROFILE (SECURED & TIMEOUT EQUIPPED)
   * ========================================================= */
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final session = await SharedPreferences.getInstance();
    final token = session.getString('token') ?? '';

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${Connection.BASE_URL}/profile/update'),
      );

      // Header
      request.headers['Authorization'] = 'Bearer $token';

      // ===== TEXT FIELDS =====
      request.fields['name'] = _nameController.text.trim();
      request.fields['email'] = _emailController.text.trim();
      request.fields['phone'] = _phoneController.text.trim();
      request.fields['gender'] = _gender == 'Laki-laki' ? 'L' : 'P';
      request.fields['place_of_birth'] = _placeOfBirthController.text.trim();
      request.fields['date_of_birth'] = _birthDateController.text.trim();

      if (_passwordController.text.trim().isNotEmpty) {
        request.fields['password'] = _passwordController.text.trim();
      }

      // ===== IMAGE FILE =====
      if (_profileImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'photo',
            _profileImage!.path,
            contentType: MediaType('image', 'jpeg'),
          ),
        );
      }

      // Laravel butuh PUT → method spoofing
      request.fields['_method'] = 'PUT';

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 15),
      );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Profil berhasil diperbarui',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        throw Exception(
          'Gagal update profil (${response.statusCode}): ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error saving profile: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains('TimeoutException')
                ? 'Koneksi terputus. Silakan periksa jaringan Anda dan coba lagi.'
                : 'Terjadi kendala saat menyimpan profil. Coba lagi nanti.',
            style: GoogleFonts.plusJakartaSans(),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /* =========================================================
   * UI HELPER WIDGETS
   * ========================================================= */
  InputDecoration _buildInputDecoration({
    required String labelText,
    required IconData prefixIcon,
    String? hintText,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: Icon(prefixIcon, color: AppColors.primary, size: 22),
      labelStyle: GoogleFonts.plusJakartaSans(
        color: Colors.grey[600],
        fontSize: 14,
      ),
      hintStyle: GoogleFonts.plusJakartaSans(
        color: Colors.grey[400],
        fontSize: 14,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey[300]!, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.red, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    );
  }

  Widget _buildAvatarSection() {
    final String name = widget.userData['name'] ?? '-';
    final String initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Center(
      child: GestureDetector(
        onTap: _isLoading ? null : _pickImage,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 55,
                backgroundColor: const Color(0xFFF3F4F6),
                child:
                    _profileImage != null
                        ? ClipOval(
                          child: Image.file(
                            _profileImage!,
                            width: 110,
                            height: 110,
                            fit: BoxFit.cover,
                          ),
                        )
                        : (widget.userData['photo'] != null &&
                                widget.userData['photo']
                                    .toString()
                                    .trim()
                                    .isNotEmpty
                            ? (_profileImageBytes != null
                                ? ClipOval(
                                  child: Image.memory(
                                    _profileImageBytes!,
                                    width: 110,
                                    height: 110,
                                    fit: BoxFit.cover,
                                  ),
                                )
                                : (_isImageLoading
                                    ? const SizedBox(
                                      width: 30,
                                      height: 30,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              AppColors.primary,
                                            ),
                                      ),
                                    )
                                    : Icon(
                                      Icons.person_rounded,
                                      size: 55,
                                      color: Colors.grey[400],
                                    )))
                            : Text(
                              initial,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            )),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child:
            _isLoading
                ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Menyimpan...',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                )
                : Text(
                  'Simpan Perubahan',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
      ),
    );
  }

  /* =========================================================
   * BUILD (MAIN FORM)
   * ========================================================= */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: Text(
          'Edit Profil',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildAvatarSection(),
              const SizedBox(height: 28),

              // Nama Lengkap
              TextFormField(
                controller: _nameController,
                decoration: _buildInputDecoration(
                  labelText: 'Nama Lengkap',
                  prefixIcon: Icons.person_rounded,
                  hintText: 'Masukkan nama lengkap Anda',
                ),
                style: GoogleFonts.plusJakartaSans(fontSize: 15),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Harap isi nama lengkap';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Username (Read-only)
              TextFormField(
                initialValue: widget.userData['username'] ?? '-',
                decoration: _buildInputDecoration(
                  labelText: 'Username (Tidak dapat diubah)',
                  prefixIcon: Icons.alternate_email_rounded,
                ).copyWith(fillColor: const Color(0xFFF3F4F6)),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  color: Colors.grey[600],
                ),
                readOnly: true,
                enabled: false,
              ),
              const SizedBox(height: 16),

              // Email
              TextFormField(
                controller: _emailController,
                decoration: _buildInputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icons.mail_outline_rounded,
                  hintText: 'Masukkan alamat email Anda',
                ),
                style: GoogleFonts.plusJakartaSans(fontSize: 15),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Harap isi alamat email';
                  }
                  if (!value.contains('@')) {
                    return 'Email tidak valid';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Nomor Telepon
              TextFormField(
                controller: _phoneController,
                decoration: _buildInputDecoration(
                  labelText: 'Nomor Telepon',
                  prefixIcon: Icons.phone_iphone_rounded,
                  hintText: 'Contoh: 081234567890',
                ),
                style: GoogleFonts.plusJakartaSans(fontSize: 15),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Harap isi nomor telepon';
                  }
                  if (value.length < 10 || value.length > 15) {
                    return 'Panjang nomor 10-15 digit';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Jenis Kelamin (Dropdown)
              DropdownButtonFormField<String>(
                initialValue: _gender,
                decoration: _buildInputDecoration(
                  labelText: 'Jenis Kelamin',
                  prefixIcon: Icons.wc_rounded,
                ),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  color: Colors.black87,
                ),
                hint: Text(
                  'Pilih jenis kelamin',
                  style: GoogleFonts.plusJakartaSans(color: Colors.grey[400]),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Laki-laki',
                    child: Text('Laki-laki'),
                  ),
                  DropdownMenuItem(
                    value: 'Perempuan',
                    child: Text('Perempuan'),
                  ),
                ],
                onChanged:
                    _isLoading
                        ? null
                        : (value) {
                          setState(() {
                            _gender = value;
                          });
                        },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Harap pilih jenis kelamin';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Tanggal Lahir (DatePicker)
              TextFormField(
                controller: _birthDateController,
                decoration: _buildInputDecoration(
                  labelText: 'Tanggal Lahir',
                  prefixIcon: Icons.cake_outlined,
                  hintText: 'Pilih tanggal lahir Anda',
                ),
                style: GoogleFonts.plusJakartaSans(fontSize: 15),
                readOnly: true,
                onTap: _isLoading ? null : () => _selectDate(context),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Harap pilih tanggal lahir';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Tempat Lahir
              TextFormField(
                controller: _placeOfBirthController,
                decoration: _buildInputDecoration(
                  labelText: 'Tempat Lahir',
                  prefixIcon: Icons.place_outlined,
                  hintText: 'Masukkan tempat lahir Anda',
                ),
                style: GoogleFonts.plusJakartaSans(fontSize: 15),
              ),
              const SizedBox(height: 16),

              // Password Baru (Optional)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _passwordController,
                    decoration: _buildInputDecoration(
                      labelText: 'Password Baru',
                      prefixIcon: Icons.lock_outline_rounded,
                      hintText: 'Kosongkan jika tidak ingin mengubah password',
                    ).copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: Colors.grey[500],
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    style: GoogleFonts.plusJakartaSans(fontSize: 15),
                    obscureText: _obscurePassword,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return null;
                      }
                      if (value.trim().length < 6) {
                        return 'Minimal 6 karakter';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      'Isi hanya jika Anda ingin mengganti password.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Tombol Simpan
              _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }
}
