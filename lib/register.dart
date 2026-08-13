import 'dart:async';
import 'dart:convert';

import 'package:apk_tb_care/connection.dart';
import 'package:apk_tb_care/main/login.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

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
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> puskesmasList = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    getPuskesmas();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
    } on TimeoutException {
      if (!mounted) return;
      showModernSnackBar(context, "Koneksi timeout.", isError: true);
    } catch (e) {
      if (!mounted) return;
      showModernSnackBar(context, e.toString(), isError: true);
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        primaryColor: kPrimaryColor,
        colorScheme: Theme.of(
          context,
        ).colorScheme.copyWith(primary: kPrimaryColor, secondary: kAccentColor),
      ),
      child: Scaffold(
        backgroundColor: kLightBg,
        appBar: AppBar(
          backgroundColor: kPrimaryColor,
          elevation: 0,
          centerTitle: false,
          title: const Text(
            "Buat Akun",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 20,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body:
            isLoading
                ? const Center(
                  child: CircularProgressIndicator(color: kPrimaryColor),
                )
                : SafeArea(
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: _buildSegmentedControl(),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            PatientRegisterTab(puskesmasList: puskesmasList),
                            OfficerRegisterTab(puskesmasList: puskesmasList),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
      ),
    );
  }

  Widget _buildSegmentedControl() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(4),
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: EdgeInsets.zero,
        labelPadding: EdgeInsets.zero,
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              // ignore: deprecated_member_use
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        labelColor: kPrimaryColor,
        unselectedLabelColor: kSubtitleColor,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        tabs: const [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_rounded, size: 16),
                SizedBox(width: 6),
                Text("Pasien"),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.medical_services_rounded, size: 16),
                SizedBox(width: 6),
                Text("Petugas"),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// GLOBAL FUNCTION
Future<http.Response> submitRegister(Map<String, dynamic> body) async {
  try {
    return await http
        .post(
          Uri.parse('${Connection.BASE_URL}/register'),
          headers: const {
            "Content-Type": "application/json",
            "Accept": "application/json",
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));
  } on TimeoutException {
    throw Exception("Waktu koneksi habis. Silakan coba beberapa saat lagi.");
  } on http.ClientException {
    throw Exception("Tidak dapat terhubung ke server.");
  } catch (e) {
    throw Exception("Terjadi kesalahan: $e");
  }
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
                "Silakan simpan informasi akun berikut untuk masuk ke aplikasi:",
                textAlign: TextAlign.center,
                style: TextStyle(color: kSubtitleColor, fontSize: 13),
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
                              size: 16,
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
                        fontSize: 16,
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
                              size: 16,
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
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: kTextColor,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
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
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.amber.shade800,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
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

/// TAB PASIEN
class PatientRegisterTab extends StatefulWidget {
  final List<dynamic> puskesmasList;

  const PatientRegisterTab({super.key, required this.puskesmasList});

  @override
  State<PatientRegisterTab> createState() => _PatientRegisterTabState();
}

class _PatientRegisterTabState extends State<PatientRegisterTab> {
  final _formKey = GlobalKey<FormState>();

  final nama = TextEditingController();
  final hp = TextEditingController();
  final puskesmasController = TextEditingController();

  String? gender;
  String? puskesmas;

  bool isSubmitting = false;

  @override
  void dispose() {
    nama.dispose();
    hp.dispose();
    puskesmasController.dispose();
    super.dispose();
  }

  Future<void> registerPatient() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isSubmitting = true;
    });

    try {
      final response = await submitRegister({
        "user_type": "patient",
        "name": nama.text.trim(),
        "phone": hp.text.trim(),
        "gender": gender,
        "puskesmas_id": puskesmas,
      });

      Map<String, dynamic> result;

      try {
        result = jsonDecode(response.body);
      } catch (_) {
        result = {"message": "Respons server tidak valid."};
      }

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        await showAccountDialog(
          context: context,
          username: result["user"]["username"],
          password: result["user"]["username"],
        );
      } else {
        showModernSnackBar(
          context,
          result["message"] ?? "Registrasi gagal.",
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;

      showModernSnackBar(context, "Terjadi kesalahan: $e", isError: true);
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Container(
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
            key: _formKey,
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
                    const Text(
                      "Form Registrasi Pasien",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: kTextColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: nama,
                  textInputAction: TextInputAction.next,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  decoration: buildInputDecoration(
                    labelText: "Nama Lengkap",
                    hintText: "Masukkan nama lengkap Anda",
                    prefixIcon: Icons.person_outline_rounded,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "Nama wajib diisi";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: hp,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  decoration: buildInputDecoration(
                    labelText: "Nomor HP",
                    hintText: "Contoh: 08123456789",
                    prefixIcon: Icons.phone_outlined,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "Nomor HP wajib diisi";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  // ignore: deprecated_member_use
                  value: gender,
                  decoration: buildInputDecoration(
                    labelText: "Jenis Kelamin",
                    hintText: "Pilih Jenis Kelamin",
                    prefixIcon: Icons.wc_rounded,
                  ),
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: kSubtitleColor,
                  ),
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  items: const [
                    DropdownMenuItem(
                      value: "L",
                      child: Text(
                        "Laki-laki",
                        style: TextStyle(color: kTextColor, fontSize: 14),
                      ),
                    ),
                    DropdownMenuItem(
                      value: "P",
                      child: Text(
                        "Perempuan",
                        style: TextStyle(color: kTextColor, fontSize: 14),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      gender = value;
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return "Pilih jenis kelamin";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                buildPuskesmasAutocomplete(
                  controller: puskesmasController,
                  puskesmasList: widget.puskesmasList,
                  selectedValue: puskesmas,
                  onSelected: (value) {
                    setState(() {
                      puskesmas = value;
                    });
                  },
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: kPrimaryColor,
                      // ignore: deprecated_member_use
                      disabledBackgroundColor: kPrimaryColor.withOpacity(0.6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                      // ignore: deprecated_member_use
                      shadowColor: kPrimaryColor.withOpacity(0.3),
                    ),
                    onPressed: isSubmitting ? null : registerPatient,
                    child:
                        isSubmitting
                            ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                            : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(
                                  Icons.person_add_alt_1_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  "Daftar",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
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
}

/// TAB PETUGAS
class OfficerRegisterTab extends StatefulWidget {
  final List<dynamic> puskesmasList;

  const OfficerRegisterTab({super.key, required this.puskesmasList});

  @override
  State<OfficerRegisterTab> createState() => _OfficerRegisterTabState();
}

class _OfficerRegisterTabState extends State<OfficerRegisterTab> {
  final _formKey = GlobalKey<FormState>();

  final nama = TextEditingController();
  final hp = TextEditingController();
  final puskesmasController = TextEditingController();

  String? gender;
  String? puskesmas;
  String? jenisPetugas;

  bool isSubmitting = false;

  @override
  void dispose() {
    nama.dispose();
    hp.dispose();
    puskesmasController.dispose();
    super.dispose();
  }

  Future<void> registerOfficer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isSubmitting = true;
    });

    try {
      final response = await submitRegister({
        "user_type": "officer",
        "name": nama.text.trim(),
        "phone": hp.text.trim(),
        "gender": gender,
        "puskesmas_id": puskesmas,
        "officer_type_id": jenisPetugas,
      });

      Map<String, dynamic> result;

      try {
        result = jsonDecode(response.body);
      } catch (_) {
        result = {"message": "Respons server tidak valid."};
      }

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        await showAccountDialog(
          context: context,
          username: result["user"]["username"],
          password: result["user"]["username"],
        );
      } else {
        showModernSnackBar(
          context,
          result["message"] ?? "Registrasi gagal.",
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;

      showModernSnackBar(context, "Terjadi kesalahan: $e", isError: true);
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Container(
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
            key: _formKey,
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
                    const Text(
                      "Form Registrasi Petugas",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: kTextColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: nama,
                  textInputAction: TextInputAction.next,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  decoration: buildInputDecoration(
                    labelText: "Nama Lengkap",
                    hintText: "Masukkan nama lengkap Anda",
                    prefixIcon: Icons.person_outline_rounded,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "Nama wajib diisi";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: hp,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  decoration: buildInputDecoration(
                    labelText: "Nomor HP",
                    hintText: "Contoh: 08123456789",
                    prefixIcon: Icons.phone_outlined,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "Nomor HP wajib diisi";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  // ignore: deprecated_member_use
                  value: gender,
                  decoration: buildInputDecoration(
                    labelText: "Jenis Kelamin",
                    hintText: "Pilih Jenis Kelamin",
                    prefixIcon: Icons.wc_rounded,
                  ),
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: kSubtitleColor,
                  ),
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  items: const [
                    DropdownMenuItem(
                      value: "L",
                      child: Text(
                        "Laki-laki",
                        style: TextStyle(color: kTextColor, fontSize: 14),
                      ),
                    ),
                    DropdownMenuItem(
                      value: "P",
                      child: Text(
                        "Perempuan",
                        style: TextStyle(color: kTextColor, fontSize: 14),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      gender = value;
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return "Pilih jenis kelamin";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                buildPuskesmasAutocomplete(
                  controller: puskesmasController,
                  puskesmasList: widget.puskesmasList,
                  selectedValue: puskesmas,
                  onSelected: (value) {
                    setState(() {
                      puskesmas = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  // ignore: deprecated_member_use
                  value: jenisPetugas,
                  decoration: buildInputDecoration(
                    labelText: "Jenis Petugas",
                    hintText: "Pilih Jenis Petugas",
                    prefixIcon: Icons.badge_outlined,
                  ),
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: kSubtitleColor,
                  ),
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  items: const [
                    DropdownMenuItem(
                      value: "3",
                      child: Text(
                        "PJTB",
                        style: TextStyle(color: kTextColor, fontSize: 14),
                      ),
                    ),
                    DropdownMenuItem(
                      value: "4",
                      child: Text(
                        "Kader",
                        style: TextStyle(color: kTextColor, fontSize: 14),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      jenisPetugas = value;
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return "Pilih jenis petugas";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: kPrimaryColor,
                      // ignore: deprecated_member_use
                      disabledBackgroundColor: kPrimaryColor.withOpacity(0.6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                      // ignore: deprecated_member_use
                      shadowColor: kPrimaryColor.withOpacity(0.3),
                    ),
                    onPressed: isSubmitting ? null : registerOfficer,
                    child:
                        isSubmitting
                            ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                            : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(
                                  Icons.person_add_alt_1_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  "Daftar",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
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
}

Widget buildPuskesmasAutocomplete({
  required TextEditingController controller,
  required List<dynamic> puskesmasList,
  required String? selectedValue,
  required ValueChanged<String> onSelected,
}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final double fieldWidth = constraints.maxWidth;

      return Autocomplete<Map<String, dynamic>>(
        displayStringForOption: (item) => item["name"],
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
          onSelected(item["id"].toString());
        },
        fieldViewBuilder: (
          context,
          textController,
          focusNode,
          onFieldSubmitted,
        ) {
          // Sync text field to selected value on initial load / state updates
          if (selectedValue != null && textController.text.isEmpty) {
            final index = puskesmasList.indexWhere(
              (e) => e["id"].toString() == selectedValue,
            );

            if (index != -1) {
              textController.text = puskesmasList[index]["name"];
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
            decoration: buildInputDecoration(
              labelText: "Puskesmas",
              hintText: "Cari Puskesmas...",
              prefixIcon: Icons.local_hospital_rounded,
            ),
            validator: (_) {
              if (selectedValue == null || selectedValue.isEmpty) {
                return "Pilih puskesmas";
              }
              final index = puskesmasList.indexWhere(
                (e) => e["id"].toString() == selectedValue,
              );
              if (index == -1 ||
                  textController.text.trim() !=
                      puskesmasList[index]["name"].toString().trim()) {
                return "Pilih puskesmas dari daftar";
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
