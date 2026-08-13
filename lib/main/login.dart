// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'dart:developer';

import 'package:apk_tb_care/main/pasien/screening.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

// ===== INTERNAL APP IMPORT =====
import 'package:apk_tb_care/connection.dart';
import 'package:apk_tb_care/register.dart';
import 'package:apk_tb_care/main/pasien/home.dart';
import 'package:apk_tb_care/main/petugas/home.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // ================= FORM =================
  final _formKey = GlobalKey<FormState>();
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  // ================= STATE =================
  bool _obscureText = true;
  bool _isLoading = false;

  // ================= LIFECYCLE =================
  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // ================= LOGIN =================
  Future<void> _login() async {
    log('LOGIN BUTTON CLICKED');

    if (!_formKey.currentState!.validate()) {
      log('FORM TIDAK VALID');
      return;
    }

    setState(() => _isLoading = true);

    try {
      log('REQUEST LOGIN API');
      final response = await http.post(
        Uri.parse('${Connection.BASE_URL}/login'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': usernameController.text.trim(),
          'password': passwordController.text.trim(),
        }),
      );

      if (!mounted) return;
      log('STATUS: ${response.statusCode}');
      setState(() => _isLoading = false);

      if (response.statusCode != 200) {
        _showMessage('Username atau password salah');
        return;
      }

      final data = jsonDecode(response.body);
      final user = data['user'];
      final token = data['token'];

      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;

      await prefs.setString('token', token);
      await prefs.setString('user_name', user['name']);
      await prefs.setString('user_id', user['id'].toString());
      await prefs.setInt('user_type_id', user['user_type_id']);

      if (user['user_type_id'] == 2) {
        await prefs.setString('patient_id', user['patient']['id'].toString());
      }

      if (!mounted) return;
      _goToHome(prefs, user['user_type_id']);
    } catch (e, s) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      log('ERROR LOGIN: $e');
      log('STACKTRACE: $s');
      _showMessage('Terjadi kesalahan jaringan');
    }
  }

  // ================= NAVIGASI =================
  void _goToHome(SharedPreferences prefs, int userType) {
    if (userType == 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (_) => HomePage(
                name: prefs.getString('user_name') ?? '',
                userId: int.parse(prefs.getString('user_id')!),
                patientId: int.parse(prefs.getString('patient_id')!),
              ),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (_) => StaffHomePage(name: prefs.getString('user_name') ?? ''),
        ),
      );
    }
  }

  // ================= UTIL =================
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _contactAdmin() async {
    const phone = '6289693839624';
    final message = Uri.encodeComponent(
      'Halo Admin TB Care, saya mengalami kendala login.',
    );
    final uri = Uri.parse('https://wa.me/$phone?text=$message');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _refreshLoginPage() async {
    setState(() {
      usernameController.clear();
      passwordController.clear();
      _obscureText = true;
      _isLoading = false;
    });
  }

  // ================= DECORATIVE DECORATION HELPER =================
  InputDecoration _buildInputDecoration({
    required String labelText,
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: Icon(prefixIcon, color: const Color(0xFF64748B), size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      labelStyle: const TextStyle(
        color: Color(0xFF64748B),
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      floatingLabelStyle: const TextStyle(
        color: Color(0xFF1E88E5),
        fontWeight: FontWeight.bold,
      ),
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF1E88E5), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
      ),
      errorStyle: const TextStyle(
        color: Color(0xFFEF4444),
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  // ================= UI BUILDERS =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ===== BACKGROUND GRADIENT =====
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF1E88E5), // Biru terang
                  Color(0xFF1565C0), // Biru gelap
                ],
              ),
            ),
          ),

          // ===== DECORATIVE BACKGROUND SHAPES =====
          Positioned(
            top: -150,
            left: -50,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withOpacity(0.12),
                    Colors.white.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -50,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withOpacity(0.08),
                    Colors.white.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: RefreshIndicator(
              onRefresh: _refreshLoginPage,
              color: const Color(0xFF1E88E5),
              backgroundColor: Colors.white,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),
                    // ===== BRANDING HEADER =====
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1.5,
                          ),
                        ),
                        child: Image.asset(
                          'assets/images/tbcare-transparent.png',
                          height: 72,
                          width: 72,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ===== CARD LOGIN =====
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'TB Care',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1565C0),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 24),
                            _buildUsernameField(),
                            const SizedBox(height: 16),
                            _buildPasswordField(),

                            const SizedBox(height: 24),
                            _buildLoginButton(),

                            const SizedBox(height: 20),
                            Row(
                              children: const [
                                Expanded(
                                  child: Divider(
                                    color: Color(0xFFE2E8F0),
                                    thickness: 1,
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(
                                    'atau',
                                    style: TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: Color(0xFFE2E8F0),
                                    thickness: 1,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),
                            _buildScreeningButton(),

                            const SizedBox(height: 24),
                            _buildRegisterText(),
                            const SizedBox(height: 6),
                            _buildAdminText(),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsernameField() {
    return TextFormField(
      controller: usernameController,
      textInputAction: TextInputAction.next,
      decoration: _buildInputDecoration(
        labelText: 'Username',
        hintText: 'Masukkan username Anda',
        prefixIcon: Icons.person_outline_rounded,
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) {
          return 'Username wajib diisi';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: passwordController,
      obscureText: _obscureText,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) {
        if (!_isLoading) {
          _login();
        }
      },
      decoration: _buildInputDecoration(
        labelText: 'Password',
        hintText: 'Masukkan password Anda',
        prefixIcon: Icons.lock_outline_rounded,
        suffixIcon: IconButton(
          icon: Icon(
            _obscureText
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: const Color(0xFF64748B),
            size: 20,
          ),
          onPressed: () => setState(() => _obscureText = !_obscureText),
        ),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) {
          return 'Password wajib diisi';
        }
        return null;
      },
    );
  }

  Widget _buildLoginButton() {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient:
            _isLoading
                ? null
                : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1E88E5), Color(0xFF1565C0)],
                ),
        color: _isLoading ? const Color(0xFF90CAF9) : null,
        boxShadow:
            _isLoading
                ? null
                : [
                  BoxShadow(
                    color: const Color(0xFF1E88E5).withOpacity(0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : _login,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isLoading) ...[
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                ] else ...[
                  const Icon(
                    Icons.login_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  _isLoading ? 'Memproses...' : 'Masuk Sekarang',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRegisterText() {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
        children: [
          const TextSpan(text: 'Belum punya akun? '),
          TextSpan(
            text: 'Daftar di sini',
            style: const TextStyle(
              color: Color(0xFF1E88E5),
              fontWeight: FontWeight.bold,
            ),
            recognizer:
                TapGestureRecognizer()
                  ..onTap = () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RegisterPage()),
                    );
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildAdminText() {
    return Center(
      child: InkWell(
        onTap: _contactAdmin,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                'Lupa akun? Hubungi Admin',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScreeningButton() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBBDEFB), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ScreeningPage()),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: const [
                Icon(
                  Icons.health_and_safety_rounded,
                  color: Color(0xFF1E88E5),
                  size: 24,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Cek Gejala TB Sekarang',
                    style: TextStyle(
                      color: Color(0xFF1565C0),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF1565C0),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
