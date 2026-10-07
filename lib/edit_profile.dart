import 'dart:convert';
import 'dart:io';
import 'package:apk_tb_care/connection.dart';
import 'package:apk_tb_care/register.dart';
import 'package:apk_tb_care/values/colors.dart';
import 'package:apk_tb_care/services/address_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  // Akun & Informasi Pribadi Controllers
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _birthDateController;
  late final TextEditingController _placeOfBirthController;
  late final TextEditingController _passwordController;

  // Pasien Controllers
  late final TextEditingController _nikController;
  late final TextEditingController _rtController;
  late final TextEditingController _rwController;
  late final TextEditingController _addressController;

  // Puskesmas Controller & State
  late final TextEditingController _puskesmasSearchController;
  String? _selectedPuskesmasId;
  String _selectedPuskesmasName = '';
  String _selectedPuskesmasLocation = '';
  bool _isChangingPuskesmas = false;
  List<dynamic> _puskesmasList = [];

  // Desa & Wilayah Search Controllers & State
  late final TextEditingController _villageSearchController;
  late final TextEditingController _subdistrictDisplayController;
  late final TextEditingController _districtDisplayController;
  late final TextEditingController _provinceDisplayController;

  String? _selectedVillageId;
  String? _selectedVillageName;
  String? _selectedSubdistrictId;
  String? _selectedSubdistrictName;
  String? _selectedDistrictId;
  String? _selectedDistrictName;
  String? _selectedProvinceId;
  String? _selectedProvinceName;

  List<dynamic> _villageList = [];
  bool _isLoadingVillages = false;

  String? _gender;
  File? _profileImage;
  Uint8List? _profileImageBytes;
  bool _isImageLoading = false;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;

  // Role detection
  bool _isPatient = false;

  @override
  void initState() {
    super.initState();
    debugPrint('EDIT PROFILE: initState');

    // 1. Identifikasi Role Pasien (user_type_id == 2)
    final rawUserType = widget.userData['user_type_id'];
    _isPatient =
        (rawUserType == 2 || rawUserType == '2') ||
        widget.userData.containsKey('nik') ||
        widget.userData.containsKey('puskesmas_id') ||
        widget.userData.containsKey('village_id');

    // 2. Controller Informasi Pribadi
    _nameController = TextEditingController(
      text: widget.userData['name'] ?? '',
    );
    _emailController = TextEditingController(
      text: widget.userData['email'] ?? '',
    );
    _phoneController = TextEditingController(
      text: widget.userData['phone'] ?? '',
    );
    _nikController = TextEditingController(
      text: widget.userData['nik']?.toString() ?? '',
    );
    _rtController = TextEditingController(
      text: widget.userData['rt']?.toString() ?? '',
    );
    _rwController = TextEditingController(
      text: widget.userData['rw']?.toString() ?? '',
    );
    _addressController = TextEditingController(
      text: widget.userData['address']?.toString() ?? '',
    );

    // 3. Controller Puskesmas (Langsung tampilkan Puskesmas saat ini jika sudah ada)
    _selectedPuskesmasId = widget.userData['puskesmas_id']?.toString();
    final initialPuskInfo = formatPuskesmasDisplay(
      rawName: widget.userData['puskesmas_name']?.toString(),
      formattedName: widget.userData['puskesmas_formatted_name']?.toString(),
      subdistrictName:
          widget.userData['puskesmas_subdistrict_name']?.toString(),
      districtName: widget.userData['puskesmas_district_name']?.toString(),
      location: widget.userData['puskesmas_location']?.toString(),
      puskesmasMap:
          widget.userData['puskesmas'] is Map<String, dynamic>
              ? widget.userData['puskesmas']
              : (widget.userData['patient'] is Map &&
                      widget.userData['patient']['puskesmas'] is Map
                  ? Map<String, dynamic>.from(
                    widget.userData['patient']['puskesmas'],
                  )
                  : null),
    );
    _selectedPuskesmasName = initialPuskInfo.name;
    _selectedPuskesmasLocation = initialPuskInfo.location;

    // Jika sudah punya puskesmas_id yang valid, jangan wajibkan pencarian
    _isChangingPuskesmas =
        (_selectedPuskesmasId == null || _selectedPuskesmasId!.isEmpty);

    _puskesmasSearchController = TextEditingController(
      text:
          _selectedPuskesmasName.isNotEmpty
              ? _selectedPuskesmasName
              : (widget.userData['puskesmas_name']?.toString() ?? ''),
    );

    // 4. Controller Wilayah (Langsung tampilkan Desa, Kecamatan, Kab/Kota, Provinsi saat ini)
    _selectedVillageId = widget.userData['village_id']?.toString();
    _selectedVillageName = widget.userData['village_name']?.toString();
    _selectedSubdistrictId = widget.userData['subdistrict_id']?.toString();
    _selectedSubdistrictName = widget.userData['subdistrict_name']?.toString();
    _selectedDistrictId = widget.userData['district_id']?.toString();
    _selectedDistrictName = widget.userData['district_name']?.toString();
    _selectedProvinceId = widget.userData['province_id']?.toString();
    _selectedProvinceName = widget.userData['province_name']?.toString();

    _villageSearchController = TextEditingController(
      text: _selectedVillageName ?? '',
    );
    _subdistrictDisplayController = TextEditingController(
      text: _selectedSubdistrictName ?? '',
    );
    _districtDisplayController = TextEditingController(
      text: _selectedDistrictName ?? '',
    );
    _provinceDisplayController = TextEditingController(
      text: _selectedProvinceName ?? '',
    );

    // 5. Tanggal Lahir & Tempat Lahir
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

    // 6. Gender
    final rawGender = widget.userData['gender'];
    if (rawGender == 'L') {
      _gender = 'Laki-laki';
    } else if (rawGender == 'P') {
      _gender = 'Perempuan';
    } else {
      _gender = null;
    }

    _loadInitialProfileImage();

    // 7. Muat list Puskesmas & Desa untuk autocomplete search
    if (_isPatient) {
      _loadSearchData();
    }
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
    _nikController.dispose();
    _rtController.dispose();
    _rwController.dispose();
    _addressController.dispose();
    _puskesmasSearchController.dispose();
    _villageSearchController.dispose();
    _subdistrictDisplayController.dispose();
    _districtDisplayController.dispose();
    _provinceDisplayController.dispose();
    super.dispose();
  }

  /* =========================================================
   * LOAD SEARCH DATA (PUSKESMAS & VILLAGES AUTOCOMPLETE)
   * ========================================================= */
  Future<void> _loadSearchData() async {
    await Future.wait([_getPuskesmas(), _getVillages()]);
  }

  Future<void> _getPuskesmas() async {
    try {
      final response = await http
          .get(
            Uri.parse('${Connection.BASE_URL}/puskesmas'),
            headers: const {"Accept": "application/json"},
          )
          .timeout(const Duration(seconds: 30));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        final list = result["data"] as List<dynamic>? ?? [];
        setState(() {
          _puskesmasList = list;
          // Perkaya data nama & lokasi Puskesmas jika puskesmas_id cocok dengan list
          if (_selectedPuskesmasId != null &&
              _selectedPuskesmasId!.isNotEmpty) {
            final matched = _puskesmasList.firstWhere(
              (p) => p["id"].toString() == _selectedPuskesmasId,
              orElse: () => null,
            );
            if (matched != null) {
              final info = formatPuskesmasDisplay(
                rawName: matched["raw_name"]?.toString(),
                formattedName: matched["name"]?.toString(),
                subdistrictName: matched["subdistrict_name"]?.toString(),
                districtName: matched["district_name"]?.toString(),
                location: matched["location"]?.toString(),
                puskesmasMap: matched is Map<String, dynamic> ? matched : null,
              );
              if (_selectedPuskesmasName.isEmpty ||
                  _selectedPuskesmasName == 'Puskesmas Terpilih') {
                _selectedPuskesmasName = info.name;
              }
              if (_selectedPuskesmasLocation.isEmpty) {
                _selectedPuskesmasLocation = info.location;
              }
              if (_puskesmasSearchController.text.isEmpty) {
                _puskesmasSearchController.text = info.name;
              }
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching puskesmas in edit profile: $e');
    }
  }

  Future<void> _getVillages([String? keyword]) async {
    if (!mounted) return;
    setState(() => _isLoadingVillages = true);
    try {
      final uri =
          (keyword != null && keyword.trim().isNotEmpty)
              ? Uri.parse(
                '${Connection.BASE_URL}/villages?search=${Uri.encodeComponent(keyword.trim())}',
              )
              : Uri.parse('${Connection.BASE_URL}/villages');

      final response = await http
          .get(uri, headers: const {"Accept": "application/json"})
          .timeout(const Duration(seconds: 30));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        final list = result["data"] as List<dynamic>? ?? [];
        setState(() {
          _villageList = list;
          // Jika wilayah subdistrict/district belum terisi tapi village_id ada, sinkronkan
          if (_selectedVillageId != null &&
              _subdistrictDisplayController.text.isEmpty) {
            final matched = _villageList.firstWhere(
              (v) => v["id"].toString() == _selectedVillageId,
              orElse: () => null,
            );
            if (matched != null) {
              _onVillageSelected(matched);
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching villages in edit profile: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingVillages = false);
      }
    }
  }

  /* =========================================================
   * VILLAGE SELECTION & AUTO TERRITORY RESOLVER
   * ========================================================= */
  void _onVillageSelected(Map<String, dynamic> item) {
    final vId = item["id"].toString();
    final vName = item["name"]?.toString() ?? "";

    Map<String, dynamic>? sub =
        item["subdistrict"] is Map<String, dynamic>
            ? item["subdistrict"] as Map<String, dynamic>
            : null;
    Map<String, dynamic>? dist =
        (item["district"] ?? item["regency"]) is Map<String, dynamic>
            ? (item["district"] ?? item["regency"]) as Map<String, dynamic>
            : null;
    Map<String, dynamic>? prov =
        item["province"] is Map<String, dynamic>
            ? item["province"] as Map<String, dynamic>
            : null;

    String subId = (sub?["id"] ?? item["subdistrict_id"])?.toString() ?? "";
    String subName = sub?["name"]?.toString() ?? "";

    String distId = (dist?["id"] ?? item["district_id"])?.toString() ?? "";
    String distName = dist?["name"]?.toString() ?? "";

    String provId = (prov?["id"] ?? item["province_id"])?.toString() ?? "";
    String provName = prov?["name"]?.toString() ?? "";

    setState(() {
      _selectedVillageId = vId;
      _selectedVillageName = vName;
      _villageSearchController.text = vName;

      _selectedSubdistrictId = subId.isNotEmpty ? subId : null;
      _selectedSubdistrictName = subName;
      _subdistrictDisplayController.text = subName;

      _selectedDistrictId = distId.isNotEmpty ? distId : null;
      _selectedDistrictName = distName;
      _districtDisplayController.text = distName;

      _selectedProvinceId = provId.isNotEmpty ? provId : null;
      _selectedProvinceName = provName;
      _provinceDisplayController.text = provName;
    });
  }

  void _clearVillageSelection() {
    setState(() {
      _selectedVillageId = null;
      _selectedVillageName = null;
      _villageSearchController.clear();

      _selectedSubdistrictId = null;
      _selectedSubdistrictName = null;
      _subdistrictDisplayController.clear();

      _selectedDistrictId = null;
      _selectedDistrictName = null;
      _districtDisplayController.clear();

      _selectedProvinceId = null;
      _selectedProvinceName = null;
      _provinceDisplayController.clear();
    });
  }

  /* =========================================================
   * LOAD PROFILE IMAGE ONCE
   * ========================================================= */
  Future<void> _loadInitialProfileImage() async {
    final photo = widget.userData['photo'];
    if (photo != null && photo.toString().trim().isNotEmpty) {
      if (!mounted) return;
      setState(() => _isImageLoading = true);

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
        setState(() => _isImageLoading = false);
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
        maxWidth: 800,
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
   * SAVE PROFILE (SECURED & COMPREHENSIVELY VALIDATED)
   * ========================================================= */
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    // Validasi eksplisit khusus Pasien
    if (_isPatient) {
      if (_selectedPuskesmasId == null || _selectedPuskesmasId!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Puskesmas wajib dipilih.',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      if (_selectedVillageId == null || _selectedVillageId!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Desa/Kelurahan wajib dipilih.',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      if (_rtController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'RT wajib diisi.',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      if (_rwController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'RW wajib diisi.',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

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
      request.headers['Accept'] = 'application/json';

      // ===== TEXT FIELDS =====
      request.fields['name'] = _nameController.text.trim();
      request.fields['email'] = _emailController.text.trim();
      request.fields['phone'] = _phoneController.text.trim();
      if (_gender != null) {
        request.fields['gender'] = _gender == 'Laki-laki' ? 'L' : 'P';
      }
      request.fields['place_of_birth'] = _placeOfBirthController.text.trim();
      request.fields['date_of_birth'] = _birthDateController.text.trim();

      if (_passwordController.text.trim().isNotEmpty) {
        request.fields['password'] = _passwordController.text.trim();
      }

      // ===== PATIENT FIELDS =====
      if (_isPatient) {
        request.fields['nik'] = _nikController.text.trim();
        request.fields['puskesmas_id'] = _selectedPuskesmasId!;
        request.fields['village_id'] = _selectedVillageId!;
        if (_selectedSubdistrictId != null &&
            _selectedSubdistrictId!.isNotEmpty) {
          request.fields['subdistrict_id'] = _selectedSubdistrictId!;
        }
        if (_selectedDistrictId != null && _selectedDistrictId!.isNotEmpty) {
          request.fields['district_id'] = _selectedDistrictId!;
        }
        if (_selectedProvinceId != null && _selectedProvinceId!.isNotEmpty) {
          request.fields['province_id'] = _selectedProvinceId!;
        }
        request.fields['rt'] = _rtController.text.trim();
        request.fields['rw'] = _rwController.text.trim();
        request.fields['address'] = _addressController.text.trim();
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

      // Laravel PUT method spoofing
      request.fields['_method'] = 'PUT';

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 25),
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
        String errorMessage = 'Gagal update profil (${response.statusCode})';
        try {
          final resJson = jsonDecode(response.body);
          if (resJson['errors'] != null && resJson['errors'] is Map) {
            final errs = (resJson['errors'] as Map).values
                .expand((e) => e is List ? e : [e.toString()])
                .join('\n');
            if (errs.isNotEmpty) errorMessage = errs;
          } else if (resJson['message'] != null) {
            errorMessage = resJson['message'].toString();
          }
        } catch (_) {}
        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint('Error saving profile: $e');
      if (!mounted) return;
      final cleanMsg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            cleanMsg.contains('TimeoutException')
                ? 'Koneksi terputus. Silakan periksa jaringan Anda dan coba lagi.'
                : cleanMsg,
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
  Widget _buildSectionHeader({required String title, required IconData icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
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
        title: const Text('Edit Profil'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildAvatarSection(),
              const SizedBox(height: 24),

              // ================= SECTION 1: INFORMASI PRIBADI =================
              _buildCardContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(
                      title: 'Informasi Pribadi',
                      icon: Icons.person_outline_rounded,
                    ),

                    // Nama Lengkap
                    TextFormField(
                      controller: _nameController,
                      decoration: buildInputDecoration(
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

                    // NIK (Khusus Pasien)
                    if (_isPatient) ...[
                      TextFormField(
                        controller: _nikController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(16),
                        ],
                        decoration: buildInputDecoration(
                          labelText: 'NIK (Nomor Induk Kependudukan) *',
                          prefixIcon: Icons.badge_outlined,
                          hintText: 'Masukkan 16 digit NIK',
                        ),
                        style: GoogleFonts.plusJakartaSans(fontSize: 15),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Harap isi NIK';
                          }
                          if (value.trim().length != 16) {
                            return 'NIK harus terdiri dari 16 digit angka';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Username (Read-only)
                    TextFormField(
                      initialValue: widget.userData['username'] ?? '-',
                      decoration: buildInputDecoration(
                        labelText: 'Username (Tidak dapat diubah)',
                        prefixIcon: Icons.alternate_email_rounded,
                        hintText: 'Username',
                      ).copyWith(fillColor: const Color(0xFFF3F4F6)),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        color: Colors.grey[600],
                      ),
                      readOnly: true,
                      enabled: false,
                    ),
                    const SizedBox(height: 16),

                    // Email (OPSIONAL)
                    TextFormField(
                      controller: _emailController,
                      decoration: buildInputDecoration(
                        labelText: 'Email (Opsional)',
                        prefixIcon: Icons.mail_outline_rounded,
                        hintText: 'Boleh dikosongkan jika tidak ada',
                      ),
                      style: GoogleFonts.plusJakartaSans(fontSize: 15),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return null; // Boleh kosong
                        }
                        if (!RegExp(
                          r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                        ).hasMatch(value.trim())) {
                          return 'Format email tidak valid';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Nomor Telepon
                    TextFormField(
                      controller: _phoneController,
                      decoration: buildInputDecoration(
                        labelText: 'Nomor Telepon',
                        prefixIcon: Icons.phone_iphone_rounded,
                        hintText: 'Contoh: 081234567890',
                      ),
                      style: GoogleFonts.plusJakartaSans(fontSize: 15),
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(15),
                      ],
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
                      key: ValueKey('gender_$_gender'),
                      initialValue: _gender,
                      decoration: buildInputDecoration(
                        labelText: 'Jenis Kelamin',
                        prefixIcon: Icons.wc_rounded,
                        hintText: 'Pilih jenis kelamin',
                      ),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        color: Colors.black87,
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
                      decoration: buildInputDecoration(
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
                      decoration: buildInputDecoration(
                        labelText: 'Tempat Lahir',
                        prefixIcon: Icons.place_outlined,
                        hintText: 'Masukkan tempat lahir Anda',
                      ),
                      style: GoogleFonts.plusJakartaSans(fontSize: 15),
                    ),
                  ],
                ),
              ),

              // ================= SECTION 2: PUSKESMAS DENGAN PENCARIAN (KHUSUS PASIEN) =================
              if (_isPatient) ...[
                _buildCardContainer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(
                        title: 'Fasilitas Kesehatan',
                        icon: Icons.local_hospital_outlined,
                      ),

                      if (!_isChangingPuskesmas &&
                          _selectedPuskesmasId != null &&
                          _selectedPuskesmasId!.isNotEmpty) ...[
                        // TAMPILAN PUSKESMAS SAAT INI (SUDAH ADA)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.local_hospital_rounded,
                                  color: AppColors.primary,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedPuskesmasName.isNotEmpty
                                          ? _selectedPuskesmasName
                                          : 'Puskesmas Terpilih',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF1E293B),
                                      ),
                                    ),
                                    if (_selectedPuskesmasLocation
                                        .isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        _selectedPuskesmasLocation,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _isChangingPuskesmas = true;
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: AppColors.primary.withValues(alpha: 0.4),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              'Ubah Puskesmas',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        // PENCARIAN PUSKESMAS (KONDISI BELUM ADA ATAU SEDANG UBAH)
                        buildPuskesmasAutocomplete(
                          controller: _puskesmasSearchController,
                          puskesmasList: _puskesmasList,
                          selectedValue: _selectedPuskesmasId,
                          labelText: 'Puskesmas Pendamping *',
                          onSelected: (value) {
                            setState(() {
                              _selectedPuskesmasId = value;
                              final matched = _puskesmasList.firstWhere(
                                (p) => p["id"].toString() == value,
                                orElse: () => null,
                              );
                              if (matched != null) {
                                final info = formatPuskesmasDisplay(
                                  rawName: matched["raw_name"]?.toString(),
                                  formattedName: matched["name"]?.toString(),
                                  subdistrictName:
                                      matched["subdistrict_name"]?.toString(),
                                  districtName:
                                      matched["district_name"]?.toString(),
                                  location: matched["location"]?.toString(),
                                  puskesmasMap:
                                      matched is Map<String, dynamic>
                                          ? matched
                                          : null,
                                );
                                _selectedPuskesmasName = info.name;
                                _selectedPuskesmasLocation = info.location;
                                _puskesmasSearchController.text = info.name;
                                _isChangingPuskesmas = false;
                              }
                            });
                          },
                          onCleared: () {
                            setState(() {
                              _selectedPuskesmasId = null;
                              _selectedPuskesmasName = '';
                              _selectedPuskesmasLocation = '';
                            });
                          },
                        ),
                        if (widget.userData['puskesmas_id'] != null &&
                            widget.userData['puskesmas_id']
                                .toString()
                                .isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _isChangingPuskesmas = false;
                                });
                              },
                              icon: const Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: Colors.grey,
                              ),
                              label: Text(
                                'Batal',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),

                // ================= SECTION 3: ALAMAT DOMISILI (KHUSUS PASIEN - POLA REGISTER) =================
                _buildCardContainer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(
                        title: 'Alamat Domisili',
                        icon: Icons.location_on_outlined,
                      ),

                      // 1. Searchable Desa/Kelurahan (Main territory selection - Pola Register)
                      buildSearchableVillageAutocomplete(
                        controller: _villageSearchController,
                        items: _villageList,
                        selectedValue: _selectedVillageId,
                        isLoading: _isLoadingVillages,
                        onSelected: _onVillageSelected,
                        onCleared: _clearVillageSelection,
                      ),
                      const SizedBox(height: 16),

                      // 2. Readonly Kecamatan (Otomatis terisi dari Desa/Kelurahan)
                      buildReadonlyTerritoryField(
                        controller: _subdistrictDisplayController,
                        labelText: "Kecamatan",
                        hintText: "Otomatis terisi dari Desa/Kelurahan",
                        prefixIcon: Icons.holiday_village_outlined,
                      ),
                      const SizedBox(height: 16),

                      // 3. Readonly Kabupaten/Kota (Otomatis terisi dari Desa/Kelurahan)
                      buildReadonlyTerritoryField(
                        controller: _districtDisplayController,
                        labelText: "Kabupaten/Kota",
                        hintText: "Otomatis terisi dari Desa/Kelurahan",
                        prefixIcon: Icons.location_city_outlined,
                      ),
                      const SizedBox(height: 16),

                      // 4. Readonly Provinsi (Otomatis terisi dari Desa/Kelurahan)
                      buildReadonlyTerritoryField(
                        controller: _provinceDisplayController,
                        labelText: "Provinsi",
                        hintText: "Otomatis terisi dari Desa/Kelurahan",
                        prefixIcon: Icons.map_outlined,
                      ),
                      const SizedBox(height: 16),

                      // 5. RT & RW (WAJIB DIISI)
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _rtController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(5),
                              ],
                              decoration: buildInputDecoration(
                                labelText: 'RT *',
                                prefixIcon: Icons.tag_rounded,
                                hintText: 'Contoh: 001',
                              ),
                              style: GoogleFonts.plusJakartaSans(fontSize: 15),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'RT wajib diisi';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _rwController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(5),
                              ],
                              decoration: buildInputDecoration(
                                labelText: 'RW *',
                                prefixIcon: Icons.tag_rounded,
                                hintText: 'Contoh: 005',
                              ),
                              style: GoogleFonts.plusJakartaSans(fontSize: 15),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'RW wajib diisi';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 6. Alamat Jalan / Detail Rumah
                      TextFormField(
                        controller: _addressController,
                        maxLines: 3,
                        decoration: buildInputDecoration(
                          labelText: 'Alamat Jalan / Detail Rumah',
                          prefixIcon: Icons.home_outlined,
                          hintText:
                              'Contoh: Jl. Cikadu No. 25 atau Kp. Sukamaju',
                        ),
                        style: GoogleFonts.plusJakartaSans(fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ],

              // ================= SECTION 4: KEAMANAN AKUN =================
              _buildCardContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(
                      title: 'Keamanan Akun',
                      icon: Icons.lock_outline_rounded,
                    ),
                    TextFormField(
                      controller: _passwordController,
                      decoration: buildInputDecoration(
                        labelText: 'Password Baru',
                        prefixIcon: Icons.lock_outline_rounded,
                        hintText:
                            'Kosongkan jika tidak ingin mengubah password',
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
              ),
              const SizedBox(height: 12),

              // Tombol Simpan
              _buildSaveButton(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
