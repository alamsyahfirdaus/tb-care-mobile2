import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:apk_tb_care/connection.dart';
import 'package:apk_tb_care/main/login.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

// Constants for Modern Health Theme Styling (Blue Palette)
const Color kPrimaryColor = Color(0xFF1E88E5); // Vibrant Primary Blue
const Color kSecondaryColor = Color(0xFF1565C0); // Deep Corporate Blue
const Color kAccentColor = Color(0xFF64B5F6); // Soft Sky Blue Accent
const Color kLightBg = Color(0xFFF8FAFC); // Slate 50
const Color kCardBg = Colors.white;
const Color kBorderColor = Color(0xFFE2E8F0); // Slate 200
const Color kTextColor = Color(0xFF0F172A); // Slate 900
const Color kSubtitleColor = Color(0xFF64748B); // Slate 500
const Color kSuccessColor = Color(0xFF10B981); // Emerald 500
const Color kSuccessBg = Color(0xFFECFDF5); // Emerald 50
const Color kErrorColor = Color(0xFFEF4444); // Red 500

class RegisterPage extends StatefulWidget {
  final int initialStep;
  final List<dynamic>? initialPuskesmasList;
  final List<dynamic>? initialProvinceList;
  final List<dynamic>? initialDistrictList;
  final List<dynamic>? initialSubdistrictList;
  final List<dynamic>? initialVillageList;

  const RegisterPage({
    super.key,
    this.initialStep = 1,
    this.initialPuskesmasList,
    this.initialProvinceList,
    this.initialDistrictList,
    this.initialSubdistrictList,
    this.initialVillageList,
  });

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // Stepper state: 1 = Data Pasien, 2 = Alamat Pasien
  int currentStep = 1;
  bool isInitialLoading = true;
  bool isSubmitting = false;

  // Step 1 Controllers & State
  final _step1FormKey = GlobalKey<FormState>();
  final namaController = TextEditingController();
  final nikController = TextEditingController();
  final hpController = TextEditingController();
  final puskesmasSearchController = TextEditingController();
  final treatmentStartDateDisplayController = TextEditingController();

  String? selectedPuskesmasId;
  DateTime? selectedTreatmentStartDate = DateTime.now();
  List<dynamic> puskesmasList = [];

  // Step 2 Controllers & State
  final _step2FormKey = GlobalKey<FormState>();
  final villageSearchController = TextEditingController();
  final subdistrictDisplayController = TextEditingController();
  final districtDisplayController = TextEditingController();
  final provinceDisplayController = TextEditingController();

  // Backward compatibility alias for any existing reference
  final provinceSearchController = TextEditingController();
  final districtSearchController = TextEditingController();
  final subdistrictSearchController = TextEditingController();

  String? selectedVillageId;
  String? selectedVillageName;
  String? selectedSubdistrictId;
  String? selectedSubdistrictName;
  String? selectedDistrictId;
  String? selectedDistrictName;
  String? selectedProvinceId;
  String? selectedProvinceName;

  List<dynamic> villageList = [];
  List<dynamic> subdistrictList = [];
  List<dynamic> districtList = [];
  List<dynamic> provinceList = [];

  bool isLoadingVillages = false;
  bool isLoadingSubdistricts = false;
  bool isLoadingDistricts = false;
  bool isLoadingProvinces = false;

  @override
  void initState() {
    super.initState();
    currentStep = widget.initialStep;
    if (widget.initialPuskesmasList != null) {
      puskesmasList = List.from(widget.initialPuskesmasList!);
    }
    if (widget.initialVillageList != null) {
      villageList = List.from(widget.initialVillageList!);
    }
    if (widget.initialSubdistrictList != null) {
      subdistrictList = List.from(widget.initialSubdistrictList!);
    }
    if (widget.initialDistrictList != null) {
      districtList = List.from(widget.initialDistrictList!);
    }
    if (widget.initialProvinceList != null) {
      provinceList = List.from(widget.initialProvinceList!);
    }

    if (selectedTreatmentStartDate != null) {
      treatmentStartDateDisplayController.text = DateFormat(
        'dd-MM-yyyy',
      ).format(selectedTreatmentStartDate!);
    }

    if (widget.initialPuskesmasList == null &&
        widget.initialVillageList == null &&
        widget.initialProvinceList == null) {
      _loadInitialData();
    } else {
      isInitialLoading = false;
    }
  }

  @override
  void dispose() {
    namaController.dispose();
    nikController.dispose();
    hpController.dispose();
    puskesmasSearchController.dispose();
    treatmentStartDateDisplayController.dispose();
    villageSearchController.dispose();
    subdistrictDisplayController.dispose();
    districtDisplayController.dispose();
    provinceDisplayController.dispose();
    provinceSearchController.dispose();
    districtSearchController.dispose();
    subdistrictSearchController.dispose();
    super.dispose();
  }

  // ================= DATA LOADING =================

  Future<void> _loadInitialData() async {
    setState(() => isInitialLoading = true);
    await Future.wait([
      getPuskesmas(),
      getVillages(),
      getSubdistricts(),
    ]);
    if (mounted) {
      setState(() => isInitialLoading = false);
    }
  }

  Future<void> getPuskesmas() async {
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
        setState(() {
          puskesmasList = result["data"] ?? [];
        });
      } else {
        throw Exception("Gagal mengambil data puskesmas.");
      }
    } catch (e) {
      if (!mounted) return;
      showModernSnackBar(
        context,
        "Tidak dapat memuat data Puskesmas. Periksa koneksi internet Anda.",
        isError: true,
      );
    }
  }

  Future<void> getVillages([String? keyword]) async {
    setState(() => isLoadingVillages = true);
    try {
      final uri = (keyword != null && keyword.trim().isNotEmpty)
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
          villageList = list;
        });
      }
    } catch (_) {
      // Handled silently
    } finally {
      if (mounted) {
        setState(() => isLoadingVillages = false);
      }
    }
  }

  Future<void> getSubdistricts([String? districtId]) async {
    setState(() => isLoadingSubdistricts = true);
    try {
      final uri =
          districtId != null
              ? Uri.parse(
                '${Connection.BASE_URL}/districts/$districtId/subdistricts',
              )
              : Uri.parse('${Connection.BASE_URL}/subdistricts');

      final response = await http
          .get(uri, headers: const {"Accept": "application/json"})
          .timeout(const Duration(seconds: 30));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        setState(() {
          subdistrictList = result["data"] ?? [];
        });
      }
    } catch (_) {
      // Handled silently
    } finally {
      if (mounted) {
        setState(() => isLoadingSubdistricts = false);
      }
    }
  }

  Future<void> getProvinces() async {
    setState(() => isLoadingProvinces = true);
    try {
      final response = await http
          .get(
            Uri.parse('${Connection.BASE_URL}/provinces'),
            headers: const {"Accept": "application/json"},
          )
          .timeout(const Duration(seconds: 30));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        setState(() {
          provinceList = result["data"] ?? [];
        });
      }
    } catch (_) {
      if (!mounted) return;
      showModernSnackBar(context, "Gagal memuat data provinsi.", isError: true);
    } finally {
      if (mounted) {
        setState(() => isLoadingProvinces = false);
      }
    }
  }

  Future<void> getDistricts(String provinceId) async {
    setState(() => isLoadingDistricts = true);
    try {
      final response = await http
          .get(
            Uri.parse('${Connection.BASE_URL}/provinces/$provinceId/districts'),
            headers: const {"Accept": "application/json"},
          )
          .timeout(const Duration(seconds: 30));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        setState(() {
          districtList = result["data"] ?? [];
        });
      }
    } catch (_) {
      if (!mounted) return;
      showModernSnackBar(
        context,
        "Gagal memuat data kabupaten/kota.",
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => isLoadingDistricts = false);
      }
    }
  }

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

    // Dynamic resolution if parent was not nested in response
    if (subName.isEmpty && subId.isNotEmpty && subdistrictList.isNotEmpty) {
      final matched = subdistrictList.firstWhere(
        (s) => s["id"].toString() == subId,
        orElse: () => null,
      );
      if (matched != null) {
        final parts = matched["name"].toString().split(',');
        if (parts.isNotEmpty) subName = parts[0].trim();
        if (parts.length > 1) distName = parts[1].trim();
        if (parts.length > 2) provName = parts[2].trim();
      }
    }

    setState(() {
      selectedVillageId = vId;
      selectedVillageName = vName;
      villageSearchController.text = vName;

      selectedSubdistrictId = subId.isNotEmpty ? subId : null;
      selectedSubdistrictName = subName;
      subdistrictDisplayController.text = subName;
      subdistrictSearchController.text = subName;

      selectedDistrictId = distId.isNotEmpty ? distId : null;
      selectedDistrictName = distName;
      districtDisplayController.text = distName;
      districtSearchController.text = distName;

      selectedProvinceId = provId.isNotEmpty ? provId : null;
      selectedProvinceName = provName;
      provinceDisplayController.text = provName;
      provinceSearchController.text = provName;
    });
  }

  void _clearVillageSelection() {
    setState(() {
      selectedVillageId = null;
      selectedVillageName = null;
      villageSearchController.clear();

      selectedSubdistrictId = null;
      selectedSubdistrictName = null;
      subdistrictDisplayController.clear();
      subdistrictSearchController.clear();

      selectedDistrictId = null;
      selectedDistrictName = null;
      districtDisplayController.clear();
      districtSearchController.clear();

      selectedProvinceId = null;
      selectedProvinceName = null;
      provinceDisplayController.clear();
      provinceSearchController.clear();
    });
  }

  // ================= STEP 1 ACTIONS =================

  Future<void> _selectTreatmentStartDate(BuildContext context) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initialDate =
        (selectedTreatmentStartDate != null &&
                !selectedTreatmentStartDate!.isAfter(today))
            ? selectedTreatmentStartDate!
            : today;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: today,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: kPrimaryColor,
              onPrimary: Colors.white,
              onSurface: kTextColor,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: kPrimaryColor),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        selectedTreatmentStartDate = picked;
        treatmentStartDateDisplayController.text = DateFormat(
          'dd-MM-yyyy',
        ).format(picked);
      });
    }
  }

  void _onStep1Continue() {
    FocusScope.of(context).unfocus();
    if (!_step1FormKey.currentState!.validate()) {
      return;
    }

    if (selectedPuskesmasId == null || selectedPuskesmasId!.isEmpty) {
      showModernSnackBar(context, "Puskesmas wajib dipilih.", isError: true);
      return;
    }

    if (selectedTreatmentStartDate == null) {
      showModernSnackBar(
        context,
        "Tanggal mulai pengobatan wajib diisi.",
        isError: true,
      );
      return;
    }

    setState(() {
      currentStep = 2;
    });
  }

  // ================= STEP 2 ACTIONS =================

  void _onStep2Back() {
    FocusScope.of(context).unfocus();
    setState(() {
      currentStep = 1;
    });
  }

  Future<void> _onRegisterSubmit() async {
    if (isSubmitting) return; // Prevent double submit

    FocusScope.of(context).unfocus();

    if (!_step2FormKey.currentState!.validate()) {
      return;
    }

    if (selectedVillageId == null || selectedVillageId!.isEmpty) {
      showModernSnackBar(
        context,
        "Silakan pilih Desa/Kelurahan terlebih dahulu.",
        isError: true,
      );
      return;
    }

    setState(() => isSubmitting = true);

    try {
      final Map<String, dynamic> payload = {
        "name": namaController.text.trim(),
        "nik": nikController.text.trim(),
        "phone": hpController.text.trim(),
        "puskesmas_id": selectedPuskesmasId,
        "treatment_start_date": DateFormat(
          'yyyy-MM-dd',
        ).format(selectedTreatmentStartDate!),
        "province_id": selectedProvinceId,
        "district_id": selectedDistrictId,
        "subdistrict_id": selectedSubdistrictId,
        "village_id": selectedVillageId,
      };

      final response = await http
          .post(
            Uri.parse('${Connection.BASE_URL}/register'),
            headers: const {
              "Content-Type": "application/json",
              "Accept": "application/json",
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));

      Map<String, dynamic> result;
      try {
        result = jsonDecode(response.body);
      } catch (_) {
        result = {"message": "Respons server tidak valid."};
      }

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = result["data"] as Map<String, dynamic>? ?? {};
        final user = result["user"] as Map<String, dynamic>? ?? {};

        final username =
            (data["username"] ?? user["username"] ?? "").toString();
        final password = (data["password"] ?? "123456").toString();

        await showAccountDialog(
          context: context,
          username: username,
          password: password,
        );
      } else if (response.statusCode == 422) {
        if (result["errors"] != null && result["errors"] is Map) {
          final errorsMap = result["errors"] as Map<String, dynamic>;
          final errorMessages = errorsMap.values
              .expand((v) => (v is List) ? v : [v.toString()])
              .join('\n');
          showModernSnackBar(
            context,
            errorMessages.isNotEmpty
                ? errorMessages
                : (result["message"] ?? "Data yang dimasukkan belum benar."),
            isError: true,
          );
        } else {
          showModernSnackBar(
            context,
            result["message"] ?? "Data yang dimasukkan belum benar.",
            isError: true,
          );
        }
      } else if (response.statusCode == 409) {
        showModernSnackBar(
          context,
          result["message"] ?? "Data sudah terdaftar.",
          isError: true,
        );
      } else if (response.statusCode >= 500) {
        showModernSnackBar(
          context,
          "Terjadi kesalahan pada server (HTTP ${response.statusCode}). Silakan coba kembali.",
          isError: true,
        );
      } else {
        showModernSnackBar(
          context,
          result["message"] ??
              "Registrasi gagal (${response.statusCode}). Silakan coba lagi.",
          isError: true,
        );
      }
    } on TimeoutException {
      if (!mounted) return;
      showModernSnackBar(
        context,
        "Tidak dapat terhubung ke server. Periksa koneksi internet Anda dan coba kembali.",
        isError: true,
      );
    } on SocketException {
      if (!mounted) return;
      showModernSnackBar(
        context,
        "Tidak dapat terhubung ke server. Periksa koneksi internet Anda dan coba kembali.",
        isError: true,
      );
    } catch (e) {
      if (!mounted) return;
      showModernSnackBar(
        context,
        "Tidak dapat terhubung ke server. Periksa koneksi internet Anda dan coba kembali.",
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => isSubmitting = false);
      }
    }
  }

  // ================= BUILD UI =================

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: currentStep == 1,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && currentStep == 2) {
          _onStep2Back();
        }
      },
      child: Theme(
        data: Theme.of(context).copyWith(
          primaryColor: kPrimaryColor,
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: kPrimaryColor,
            secondary: kAccentColor,
          ),
        ),
        child: Scaffold(
          backgroundColor: kLightBg,
          appBar: AppBar(
            title: const Text("Buat Akun Pasien"),
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_rounded,
                size: 24,
              ),
              onPressed: () {
                if (currentStep == 2) {
                  _onStep2Back();
                } else {
                  Navigator.of(context).pop();
                }
              },
            ),
          ),
          body:
              isInitialLoading
                  ? const Center(
                    child: CircularProgressIndicator(color: kPrimaryColor),
                  )
                  : SafeArea(
                    child: Column(
                      children: [
                        // Step Indicator Card
                        _buildStepIndicator(),
                        // Form View
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                            child:
                                currentStep == 1
                                    ? _buildStep1Form()
                                    : _buildStep2Form(),
                          ),
                        ),
                      ],
                    ),
                  ),
        ),
      ),
    );
  }

  // ================= STEP INDICATOR =================

  Widget _buildStepIndicator() {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildStepCircle(
                step: 1,
                isActive: currentStep == 1,
                isCompleted: currentStep > 1,
              ),
              Expanded(
                child: Container(
                  height: 3,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: currentStep > 1 ? kPrimaryColor : kBorderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              _buildStepCircle(
                step: 2,
                isActive: currentStep == 2,
                isCompleted: false,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  "Data Pasien",
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        currentStep == 1 ? FontWeight.bold : FontWeight.w500,
                    color: currentStep == 1 ? kPrimaryColor : kSubtitleColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  "Alamat Pasien",
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        currentStep == 2 ? FontWeight.bold : FontWeight.w500,
                    color: currentStep == 2 ? kPrimaryColor : kSubtitleColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepCircle({
    required int step,
    required bool isActive,
    required bool isCompleted,
  }) {
    Color bgColor;
    Color textColor;
    Widget child;

    if (isCompleted) {
      bgColor = kSuccessColor;
      textColor = Colors.white;
      child = const Icon(Icons.check_rounded, color: Colors.white, size: 16);
    } else if (isActive) {
      bgColor = kPrimaryColor;
      textColor = Colors.white;
      child = Text(
        step.toString(),
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      );
    } else {
      bgColor = const Color(0xFFF1F5F9);
      textColor = kSubtitleColor;
      child = Text(
        step.toString(),
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      );
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: isActive || isCompleted ? Colors.transparent : kBorderColor,
        ),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }

  // ================= STEP 1 FORM =================

  Widget _buildStep1Form() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kBorderColor),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.black.withOpacity(0.02),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _step1FormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      color: kPrimaryColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      "Data Pasien",
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: kTextColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      // ignore: deprecated_member_use
                      color: kPrimaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      "Langkah 1 dari 2",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: kPrimaryColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 1. Nama Lengkap
              TextFormField(
                controller: namaController,
                textInputAction: TextInputAction.next,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration: buildInputDecoration(
                  labelText: "Nama Lengkap",
                  hintText: "Masukkan nama lengkap Anda",
                  prefixIcon: Icons.person_outline_rounded,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Nama lengkap wajib diisi";
                  }
                  if (value.trim().length < 3) {
                    return "Nama lengkap minimal 3 karakter";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 2. NIK
              TextFormField(
                controller: nikController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(16),
                ],
                autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration: buildInputDecoration(
                  labelText: "NIK",
                  hintText: "Masukkan 16 digit NIK",
                  prefixIcon: Icons.badge_outlined,
                ),
                validator: (value) {
                  final val = value?.trim() ?? "";
                  if (val.isEmpty) {
                    return "NIK wajib diisi";
                  }
                  if (val.length != 16) {
                    return "NIK harus terdiri dari 16 digit.";
                  }
                  if (!RegExp(r'^[0-9]+$').hasMatch(val)) {
                    return "NIK hanya boleh berisi angka";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 3. Nomor HP
              TextFormField(
                controller: hpController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(15),
                ],
                autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration: buildInputDecoration(
                  labelText: "Nomor HP",
                  hintText: "Contoh: 081234567890",
                  prefixIcon: Icons.phone_outlined,
                ),
                validator: (value) {
                  final val = value?.trim() ?? "";
                  if (val.isEmpty) {
                    return "Nomor HP wajib diisi";
                  }
                  if (!RegExp(r'^[0-9]+$').hasMatch(val)) {
                    return "Nomor HP hanya boleh berisi angka";
                  }
                  if (val.length < 10 || val.length > 15) {
                    return "Nomor HP harus antara 10 - 15 digit";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 4. Puskesmas (Searchable Autocomplete)
              buildPuskesmasAutocomplete(
                controller: puskesmasSearchController,
                puskesmasList: puskesmasList,
                selectedValue: selectedPuskesmasId,
                onSelected: (value) {
                  setState(() {
                    selectedPuskesmasId = value;
                  });
                },
              ),
              const SizedBox(height: 16),

              // 5. Tanggal Mulai Pengobatan
              TextFormField(
                controller: treatmentStartDateDisplayController,
                readOnly: true,
                onTap: () => _selectTreatmentStartDate(context),
                autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration: buildInputDecoration(
                  labelText: "Tanggal Mulai Pengobatan",
                  hintText: "Pilih tanggal mulai pengobatan",
                  prefixIcon: Icons.calendar_month_outlined,
                ),
                validator: (value) {
                  if (selectedTreatmentStartDate == null) {
                    return "Tanggal mulai pengobatan wajib diisi";
                  }
                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);
                  if (selectedTreatmentStartDate!.isAfter(today)) {
                    return "Tanggal mulai pengobatan tidak boleh di masa depan";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // Tombol Lanjutkan
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                    // ignore: deprecated_member_use
                    shadowColor: kPrimaryColor.withOpacity(0.3),
                  ),
                  onPressed: _onStep1Continue,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text(
                        "Lanjutkan",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= STEP 2 FORM =================

  Widget _buildStep2Form() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kBorderColor),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.black.withOpacity(0.02),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _step2FormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      color: kPrimaryColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      "Alamat Pasien",
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: kTextColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      // ignore: deprecated_member_use
                      color: kPrimaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      "Langkah 2 dari 2",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: kPrimaryColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 1. Searchable Desa/Kelurahan (Main territory selection)
              buildSearchableVillageAutocomplete(
                controller: villageSearchController,
                items: villageList,
                selectedValue: selectedVillageId,
                isLoading: isLoadingVillages,
                onSelected: _onVillageSelected,
                onCleared: _clearVillageSelection,
              ),
              const SizedBox(height: 16),

              // 2. Readonly Kecamatan (Otomatis terisi dari Desa/Kelurahan)
              buildReadonlyTerritoryField(
                controller: subdistrictDisplayController,
                labelText: "Kecamatan",
                hintText: "Otomatis terisi dari Desa/Kelurahan",
                prefixIcon: Icons.holiday_village_outlined,
              ),
              const SizedBox(height: 16),

              // 3. Readonly Kabupaten/Kota (Otomatis terisi dari Desa/Kelurahan)
              buildReadonlyTerritoryField(
                controller: districtDisplayController,
                labelText: "Kabupaten/Kota",
                hintText: "Otomatis terisi dari Desa/Kelurahan",
                prefixIcon: Icons.location_city_outlined,
              ),
              const SizedBox(height: 16),

              // 4. Readonly Provinsi (Otomatis terisi dari Desa/Kelurahan)
              buildReadonlyTerritoryField(
                controller: provinceDisplayController,
                labelText: "Provinsi",
                hintText: "Otomatis terisi dari Desa/Kelurahan",
                prefixIcon: Icons.map_outlined,
              ),
              const SizedBox(height: 32),

              // Action Buttons: Kembali & Daftar (Proporsional, Seimbang, Responsif)
              Row(
                children: [
                  // Tombol Kembali (Outlined / Secondary Style)
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: kBorderColor,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onPressed: isSubmitting ? null : _onStep2Back,
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: kSubtitleColor,
                          size: 18,
                        ),
                        label: const Text(
                          "Kembali",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: kSubtitleColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Tombol Daftar (Primary Blue Style)
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimaryColor,
                          foregroundColor: Colors.white,
                          // ignore: deprecated_member_use
                          disabledBackgroundColor:
                          // ignore: deprecated_member_use
                          kPrimaryColor.withOpacity(0.6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 2,
                          // ignore: deprecated_member_use
                          shadowColor: kPrimaryColor.withOpacity(0.3),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onPressed: isSubmitting ? null : _onRegisterSubmit,
                        icon:
                            isSubmitting
                                ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : const Icon(
                                  Icons.person_add_alt_1_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                        label: Text(
                          isSubmitting ? "Memproses..." : "Daftar",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================= GLOBAL HELPER WIDGETS =================

Widget buildReadonlyTerritoryField({
  required TextEditingController controller,
  required String labelText,
  required String hintText,
  required IconData prefixIcon,
}) {
  return TextFormField(
    controller: controller,
    readOnly: true,
    enableInteractiveSelection: false,
    decoration: buildInputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon,
    ).copyWith(
      fillColor: const Color(0xFFF8FAFC),
      filled: true,
      suffixIcon: const Padding(
        padding: EdgeInsets.only(right: 14),
        child: Icon(
          Icons.lock_outline_rounded,
          size: 18,
          color: Color(0xFF94A3B8),
        ),
      ),
    ),
    style: const TextStyle(
      color: kTextColor,
      fontWeight: FontWeight.w600,
      fontSize: 14,
    ),
  );
}

Widget buildSearchableVillageAutocomplete({
  required TextEditingController controller,
  required List<dynamic> items,
  required String? selectedValue,
  required bool isLoading,
  required ValueChanged<Map<String, dynamic>> onSelected,
  required VoidCallback onCleared,
}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final double fieldWidth = constraints.maxWidth;

      return Autocomplete<Map<String, dynamic>>(
        displayStringForOption: (item) => item["name"]?.toString() ?? "",
        optionsBuilder: (TextEditingValue textEditingValue) {
          final keyword = textEditingValue.text.trim().toLowerCase();

          if (items.isEmpty) {
            return const Iterable<Map<String, dynamic>>.empty();
          }

          if (keyword.isEmpty) {
            return items.cast<Map<String, dynamic>>();
          }

          return items.cast<Map<String, dynamic>>().where((item) {
            final name = item["name"]?.toString().toLowerCase() ?? "";
            final parent =
                item["parent_display"]?.toString().toLowerCase() ?? "";
            final full = item["full_address"]?.toString().toLowerCase() ?? "";
            return name.contains(keyword) ||
                parent.contains(keyword) ||
                full.contains(keyword);
          });
        },
        onSelected: (item) {
          onSelected(item);
        },
        fieldViewBuilder: (
          context,
          textController,
          focusNode,
          onFieldSubmitted,
        ) {
          // Sync text field to controller when initialized or updated externally
          if (controller.text.isNotEmpty && textController.text.isEmpty) {
            textController.text = controller.text;
          }

          // Clear text field when selection is cleared
          if ((selectedValue == null || selectedValue.isEmpty) &&
              !focusNode.hasFocus &&
              textController.text.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              textController.clear();
            });
          }

          return TextFormField(
            controller: textController,
            focusNode: focusNode,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            onChanged: (val) {
              if (val.isEmpty && selectedValue != null) {
                onCleared();
              }
            },
            decoration: buildInputDecoration(
              labelText: "Desa/Kelurahan",
              hintText: "Cari Desa/Kelurahan...",
              prefixIcon: Icons.home_work_outlined,
            ).copyWith(
              suffixIcon:
                  isLoading
                      ? const Padding(
                        padding: EdgeInsets.all(14.0),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: kPrimaryColor,
                          ),
                        ),
                      )
                      : (selectedValue != null && selectedValue.isNotEmpty)
                      ? IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: kSubtitleColor,
                        ),
                        tooltip: "Hapus Pilihan",
                        onPressed: () {
                          textController.clear();
                          controller.clear();
                          onCleared();
                        },
                      )
                      : const Icon(
                        Icons.arrow_drop_down_rounded,
                        color: kSubtitleColor,
                      ),
            ),
            validator: (_) {
              if (selectedValue == null || selectedValue.isEmpty) {
                return "Silakan pilih Desa/Kelurahan terlebih dahulu.";
              }
              return null;
            },
          );
        },
        optionsViewBuilder: (context, onSelectedOption, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Material(
                elevation: 8,
                shadowColor: Colors.black26,
                borderRadius: BorderRadius.circular(16),
                color: Colors.white,
                child: Container(
                  width: fieldWidth,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: kBorderColor),
                  ),
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child:
                        options.isEmpty
                            ? const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text(
                                "Desa/Kelurahan tidak ditemukan.\nSilakan periksa kembali nama wilayah.",
                                style: TextStyle(
                                  color: kSubtitleColor,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            )
                            : ListView.separated(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: options.length,
                              separatorBuilder:
                                  (context, index) => const Divider(
                                    height: 1,
                                    color: kBorderColor,
                                  ),
                              itemBuilder: (context, index) {
                                final item = options.elementAt(index);
                                final isSelected =
                                    selectedValue == item["id"].toString();

                                // Extract parent subtitle to disambiguate identical village names
                                String parentText =
                                    item["parent_display"]?.toString() ?? "";
                                if (parentText.isEmpty) {
                                  final sub = item["subdistrict"];
                                  final dist =
                                      item["district"] ?? item["regency"];
                                  final sName =
                                      sub is Map ? sub["name"]?.toString() : null;
                                  final dName =
                                      dist is Map
                                          ? dist["name"]?.toString()
                                          : null;
                                  parentText = [
                                    sName,
                                    dName,
                                  ].where((e) => e != null && e.isNotEmpty).join(' • ');
                                }

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      // ignore: deprecated_member_use
                                      color: kPrimaryColor.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.location_on_outlined,
                                      size: 18,
                                      color: kPrimaryColor,
                                    ),
                                  ),
                                  title: Text(
                                    item["name"]?.toString() ?? "",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color:
                                          isSelected
                                              ? kPrimaryColor
                                              : kTextColor,
                                      fontWeight:
                                          isSelected
                                              ? FontWeight.bold
                                              : FontWeight.w600,
                                    ),
                                  ),
                                  subtitle:
                                      parentText.isNotEmpty
                                          ? Padding(
                                            padding: const EdgeInsets.only(
                                              top: 2.0,
                                            ),
                                            child: Text(
                                              parentText,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: kSubtitleColor,
                                              ),
                                            ),
                                          )
                                          : null,
                                  trailing:
                                      isSelected
                                          ? const Icon(
                                            Icons.check_circle_rounded,
                                            color: kPrimaryColor,
                                            size: 20,
                                          )
                                          : null,
                                  tileColor:
                                      isSelected
                                          // ignore: deprecated_member_use
                                          ? kPrimaryColor.withOpacity(0.04)
                                          : null,
                                  onTap: () {
                                    onSelectedOption(item);
                                  },
                                );
                              },
                            ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

Widget buildSearchableTerritoryAutocomplete({
  required TextEditingController controller,
  required String labelText,
  required String hintText,
  required String notFoundText,
  required IconData prefixIcon,
  required List<dynamic> items,
  required String? selectedValue,
  required bool isEnabled,
  required String? disabledHint,
  required bool isLoading,
  required ValueChanged<Map<String, dynamic>> onSelected,
}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final double fieldWidth = constraints.maxWidth;

      if (!isEnabled) {
        return TextFormField(
          enabled: false,
          controller: controller,
          decoration: buildInputDecoration(
            labelText: labelText,
            hintText: disabledHint ?? hintText,
            prefixIcon: prefixIcon,
          ).copyWith(
            suffixIcon:
                isLoading
                    ? const Padding(
                      padding: EdgeInsets.all(14.0),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: kPrimaryColor,
                        ),
                      ),
                    )
                    : null,
          ),
          validator: (_) {
            if (selectedValue == null || selectedValue.isEmpty) {
              return "$labelText wajib dipilih.";
            }
            return null;
          },
        );
      }

      return Autocomplete<Map<String, dynamic>>(
        displayStringForOption: (item) => item["name"]?.toString() ?? "",
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (items.isEmpty) {
            return const Iterable<Map<String, dynamic>>.empty();
          }

          final keyword = textEditingValue.text.trim().toLowerCase();

          if (keyword.isEmpty) {
            return items.cast<Map<String, dynamic>>();
          }

          return items.cast<Map<String, dynamic>>().where(
            (item) => item["name"].toString().toLowerCase().contains(keyword),
          );
        },
        onSelected: (item) {
          controller.text = item["name"]?.toString() ?? "";
          onSelected(item);
        },
        fieldViewBuilder: (
          context,
          textController,
          focusNode,
          onFieldSubmitted,
        ) {
          // Sync text field to selected value on initial load / state updates
          if (selectedValue != null && textController.text.isEmpty) {
            final index = items.indexWhere(
              (e) => e["id"].toString() == selectedValue,
            );

            if (index != -1) {
              textController.text = items[index]["name"]?.toString() ?? "";
              controller.text = textController.text;
            }
          }

          // Clear text field when selection is cleared and field is not focused (e.g. form reset)
          if ((selectedValue == null || selectedValue.isEmpty) &&
              textController.text.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              textController.clear();
              controller.clear();
            });
          }

          return TextFormField(
            controller: textController,
            focusNode: focusNode,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            decoration: buildInputDecoration(
              labelText: labelText,
              hintText: hintText,
              prefixIcon: prefixIcon,
            ).copyWith(
              suffixIcon:
                  isLoading
                      ? const Padding(
                        padding: EdgeInsets.all(14.0),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: kPrimaryColor,
                          ),
                        ),
                      )
                      : const Icon(
                        Icons.arrow_drop_down_rounded,
                        color: kSubtitleColor,
                      ),
            ),
            validator: (_) {
              if (selectedValue == null || selectedValue.isEmpty) {
                return "$labelText wajib dipilih.";
              }
              final index = items.indexWhere(
                (e) => e["id"].toString() == selectedValue,
              );
              if (index == -1 ||
                  textController.text.trim() !=
                      items[index]["name"].toString().trim()) {
                return "Pilih $labelText dari daftar";
              }
              return null;
            },
          );
        },
        optionsViewBuilder: (context, onSelectedOption, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Material(
                elevation: 8,
                shadowColor: Colors.black26,
                borderRadius: BorderRadius.circular(16),
                color: Colors.white,
                child: Container(
                  width: fieldWidth,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: kBorderColor),
                  ),
                  constraints: const BoxConstraints(maxHeight: 250),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child:
                        options.isEmpty
                            ? Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                notFoundText,
                                style: const TextStyle(color: kSubtitleColor),
                              ),
                            )
                            : ListView.separated(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: options.length,
                              separatorBuilder:
                                  (context, index) => const Divider(
                                    height: 1,
                                    color: kBorderColor,
                                  ),
                              itemBuilder: (context, index) {
                                final item = options.elementAt(index);
                                final isSelected =
                                    selectedValue == item["id"].toString();

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  title: Text(
                                    item["name"]?.toString() ?? "",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color:
                                          isSelected
                                              ? kPrimaryColor
                                              : kTextColor,
                                      fontWeight:
                                          isSelected
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                    ),
                                  ),
                                  tileColor:
                                      isSelected
                                          // ignore: deprecated_member_use
                                          ? kPrimaryColor.withOpacity(0.02)
                                          : null,
                                  onTap: () {
                                    onSelectedOption(item);
                                  },
                                );
                              },
                            ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

Widget buildPuskesmasAutocomplete({
  required TextEditingController controller,
  required List<dynamic> puskesmasList,
  required String? selectedValue,
  required ValueChanged<String> onSelected,
  VoidCallback? onCleared,
  String? labelText,
}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final double fieldWidth = constraints.maxWidth;

      return Autocomplete<Map<String, dynamic>>(
        displayStringForOption: (item) => item["name"]?.toString() ?? "",
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (puskesmasList.isEmpty) {
            return const Iterable<Map<String, dynamic>>.empty();
          }

          final keyword = textEditingValue.text.trim().toLowerCase();

          if (keyword.isEmpty) {
            return puskesmasList.cast<Map<String, dynamic>>();
          }

          return puskesmasList.cast<Map<String, dynamic>>().where(
            (item) => item["name"].toString().toLowerCase().contains(keyword),
          );
        },
        onSelected: (item) {
          controller.text = item["name"]?.toString() ?? "";
          onSelected(item["id"].toString());
        },
        fieldViewBuilder: (
          context,
          textController,
          focusNode,
          onFieldSubmitted,
        ) {
          // Sync text field to controller when initialized externally
          if (controller.text.isNotEmpty && textController.text.isEmpty) {
            textController.text = controller.text;
          }

          // Sync text field to selected value on initial load / state updates
          if (selectedValue != null && textController.text.isEmpty) {
            final index = puskesmasList.indexWhere(
              (e) => e["id"].toString() == selectedValue,
            );

            if (index != -1) {
              textController.text = puskesmasList[index]["name"]?.toString() ?? "";
              controller.text = textController.text;
            }
          }

          // Clear text field when selection is cleared and field is not focused (e.g. form reset)
          if ((selectedValue == null || selectedValue.isEmpty) &&
              !focusNode.hasFocus &&
              textController.text.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              textController.clear();
            });
          }

          return TextFormField(
            controller: textController,
            focusNode: focusNode,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            onChanged: (val) {
              if (val.isEmpty && selectedValue != null) {
                if (onCleared != null) onCleared();
              }
            },
            decoration: buildInputDecoration(
              labelText: labelText ?? "Puskesmas",
              hintText: "Cari Puskesmas...",
              prefixIcon: Icons.local_hospital_rounded,
            ).copyWith(
              suffixIcon: (selectedValue != null && selectedValue.isNotEmpty)
                  ? IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: kSubtitleColor,
                      ),
                      tooltip: "Hapus Pilihan",
                      onPressed: () {
                        textController.clear();
                        controller.clear();
                        if (onCleared != null) onCleared();
                      },
                    )
                  : const Icon(
                      Icons.arrow_drop_down_rounded,
                      color: kSubtitleColor,
                    ),
            ),
            validator: (_) {
              if (selectedValue == null || selectedValue.isEmpty) {
                return "Puskesmas wajib dipilih.";
              }
              if (puskesmasList.isNotEmpty) {
                final index = puskesmasList.indexWhere(
                  (e) => e["id"].toString() == selectedValue,
                );
                if (index != -1 &&
                    textController.text.trim() !=
                        puskesmasList[index]["name"].toString().trim()) {
                  return "Pilih puskesmas dari daftar";
                }
              }
              return null;
            },
          );
        },
        optionsViewBuilder: (context, onSelected, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Material(
                elevation: 8,
                shadowColor: Colors.black26,
                borderRadius: BorderRadius.circular(16),
                color: Colors.white,
                child: Container(
                  width: fieldWidth,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: kBorderColor),
                  ),
                  constraints: const BoxConstraints(maxHeight: 250),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child:
                        options.isEmpty
                            ? const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text(
                                "Puskesmas tidak ditemukan",
                                style: TextStyle(color: kSubtitleColor),
                              ),
                            )
                            : ListView.separated(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: options.length,
                              separatorBuilder:
                                  (context, index) => const Divider(
                                    height: 1,
                                    color: kBorderColor,
                                  ),
                              itemBuilder: (context, index) {
                                final item = options.elementAt(index);
                                final isSelected =
                                    selectedValue == item["id"].toString();

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  title: Text(
                                    item["name"],
                                    style: TextStyle(
                                      fontSize: 14,
                                      color:
                                          isSelected
                                              ? kPrimaryColor
                                              : kTextColor,
                                      fontWeight:
                                          isSelected
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                    ),
                                  ),
                                  tileColor:
                                      isSelected
                                          // ignore: deprecated_member_use
                                          ? kPrimaryColor.withOpacity(0.02)
                                          : null,
                                  onTap: () => onSelected(item),
                                );
                              },
                            ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

InputDecoration buildInputDecoration({
  required String labelText,
  required String hintText,
  required IconData prefixIcon,
  Color? iconColor,
}) {
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    prefixIcon: Icon(prefixIcon, color: iconColor ?? kSubtitleColor, size: 20),
    filled: true,
    fillColor: kLightBg,
    labelStyle: const TextStyle(
      color: kSubtitleColor,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    ),
    floatingLabelStyle: const TextStyle(
      color: kPrimaryColor,
      fontWeight: FontWeight.bold,
    ),
    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: kBorderColor, width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: kPrimaryColor, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: kErrorColor, width: 1),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: kErrorColor, width: 1.5),
    ),
    errorStyle: const TextStyle(
      color: kErrorColor,
      fontSize: 12,
      fontWeight: FontWeight.w500,
    ),
  );
}

Future<void> showAccountDialog({
  required BuildContext context,
  required String username,
  required String password,
}) async {
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
        actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: kSuccessBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: kSuccessColor,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Registrasi Berhasil",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: kTextColor,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Akun pasien berhasil dibuat.\nSilakan simpan username dan password Anda untuk login:",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: kSubtitleColor,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: kLightBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kBorderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Username Row
                    Row(
                      children: [
                        const Icon(
                          Icons.account_circle_outlined,
                          color: kPrimaryColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          "Username",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: kTextColor,
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: username));
                            showModernSnackBar(
                              context,
                              "Username disalin ke clipboard",
                            );
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: const Padding(
                            padding: EdgeInsets.all(4.0),
                            child: Icon(
                              Icons.copy_rounded,
                              size: 18,
                              color: kPrimaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      username,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: kTextColor,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const Divider(height: 24, color: kBorderColor),
                    // Password Row
                    Row(
                      children: [
                        const Icon(
                          Icons.lock_outline_rounded,
                          color: kPrimaryColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          "Password",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: kTextColor,
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: password));
                            showModernSnackBar(
                              context,
                              "Password disalin ke clipboard",
                            );
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: const Padding(
                            padding: EdgeInsets.all(4.0),
                            child: Icon(
                              Icons.copy_rounded,
                              size: 18,
                              color: kPrimaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      password,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: kTextColor,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Copy all button
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(
                        text: "Username: $username\nPassword: $password",
                      ),
                    );
                    showModernSnackBar(
                      context,
                      "Data login berhasil disalin ke clipboard",
                    );
                  },
                  icon: const Icon(
                    Icons.copy_all_rounded,
                    size: 18,
                    color: kPrimaryColor,
                  ),
                  label: const Text(
                    "Salin Data Login",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: kPrimaryColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Security Warning Card
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        "Simpan informasi akun ini dengan aman dan jangan membagikannya kepada orang lain.",
                        style: TextStyle(
                          color: Colors.amber.shade900,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: kPrimaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              onPressed: () {
                Navigator.of(dialogContext).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false,
                );
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text(
                    "Login Sekarang",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}

void showModernSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isError ? kErrorColor : kPrimaryColor,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
      content: Row(
        children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
