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

  // ================= LOGIN =================
  Future<void> _login() async {
    log('🔘 LOGIN BUTTON CLICKED');

    if (!_formKey.currentState!.validate()) {
      log('❌ FORM TIDAK VALID');
      return;
    }

    setState(() => _isLoading = true);

    try {
      log('🌐 REQUEST LOGIN API');
      final response = await http.post(
        Uri.parse('${Connection.BASE_URL}/login'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': usernameController.text.trim(),
          'password': passwordController.text.trim(),
        }),
      );

      log('📥 STATUS: ${response.statusCode}');
      log('📦 BODY: ${response.body}');
      setState(() => _isLoading = false);

      if (response.statusCode != 200) {
        _showMessage('Username atau password salah');
        return;
      }

      final data = jsonDecode(response.body);
      final user = data['user'];
      final token = data['token'];

      final prefs = await SharedPreferences.getInstance();
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
      setState(() => _isLoading = false);
      log('🔥 ERROR LOGIN: $e');
      log('📌 STACKTRACE: $s');
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _contactAdmin() async {
    const phone = '6289693839624';
    final uri = Uri.parse(
      'https://wa.me/$phone?text=${Uri.encodeComponent('Halo Admin TB Care, saya mengalami kendala login.')}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _refreshLoginPage() async {
    setState(() {
      usernameController.clear();
      passwordController.clear();
      _obscureText = true;
      _isLoading = false;
    });

    // delay kecil agar animasi refresh halus & natural
    await Future.delayed(const Duration(milliseconds: 500));
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ===== BACKGROUND =====
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
              ),
            ),
          ),

          SafeArea(
            child: RefreshIndicator(
              onRefresh: _refreshLoginPage,
              color: const Color(0xFF1565C0),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 96),
                    // ===== CARD LOGIN WITH LOGO =====
                    Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        // ===== CARD =====
                        Padding(
                          padding: const EdgeInsets.only(top: 45),
                          child: Card(
                            elevation: 12,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                24,
                                48,
                                24,
                                24,
                              ),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const Text(
                                      'Selamat Datang di TB Care',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1565C0),
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
                                        Expanded(child: Divider()),
                                        Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 8,
                                          ),
                                          child: Text(
                                            'atau',
                                            style: TextStyle(
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ),
                                        Expanded(child: Divider()),
                                      ],
                                    ),

                                    const SizedBox(height: 16),
                                    _buildScreeningButton(),

                                    const SizedBox(height: 20),
                                    _buildRegisterText(),
                                    const SizedBox(height: 6),
                                    _buildAdminText(),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        // ===== LOGO DI DALAM CARD =====
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF1E88E5), // biru terang
                                Color(0xFF0D47A1), // biru gelap
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                // ignore: deprecated_member_use
                                color: Colors.black.withOpacity(0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/images/logo_tbcare1.png',
                            height: 52,
                            color: Colors.white, // penting agar logo kontras
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget _buildFormCard() {
  //   return SingleChildScrollView(
  //     padding: const EdgeInsets.symmetric(horizontal: 24),
  //     child: Card(
  //       elevation: 10,
  //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
  //       child: Padding(
  //         padding: const EdgeInsets.all(24),
  //         child: Form(
  //           key: _formKey,
  //           child: Column(
  //             children: [
  //               const Text(
  //                 'Selamat Datang di TB Care',
  //                 style: TextStyle(
  //                   fontSize: 20,
  //                   fontWeight: FontWeight.bold,
  //                   color: Color(0xFF1565C0),
  //                 ),
  //               ),
  //               const SizedBox(height: 24),
  //               _buildUsernameField(),
  //               const SizedBox(height: 16),
  //               _buildPasswordField(),
  //               const SizedBox(height: 20),
  //               _buildLoginButton(),
  //               const SizedBox(height: 20),
  //               _buildScreeningButton(),
  //               const SizedBox(height: 16),
  //               _buildRegisterText(),
  //               const SizedBox(height: 8),
  //               _buildAdminText(),
  //             ],
  //           ),
  //         ),
  //       ),
  //     ),
  //   );
  // }

  Widget _buildUsernameField() {
    return TextFormField(
      controller: usernameController,
      decoration: const InputDecoration(
        labelText: 'Username',
        prefixIcon: Icon(Icons.person),
        border: OutlineInputBorder(),
      ),
      validator: (v) => v!.isEmpty ? 'Username wajib diisi' : null,
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: passwordController,
      obscureText: _obscureText,
      decoration: InputDecoration(
        labelText: 'Password',
        prefixIcon: const Icon(Icons.lock),
        suffixIcon: IconButton(
          icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() => _obscureText = !_obscureText),
        ),
        border: const OutlineInputBorder(),
      ),
      validator: (v) => v!.isEmpty ? 'Password wajib diisi' : null,
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _isLoading ? null : _login,
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1E88E5), // biru terang
                Color(0xFF0D47A1), // biru gelap
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isLoading) ...[
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                ] else ...[
                  const Icon(Icons.login, color: Colors.white),
                  const SizedBox(width: 8),
                ],
                Text(
                  _isLoading ? 'Memproses...' : 'Masuk',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 16,
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
      text: TextSpan(
        style: const TextStyle(color: Colors.black87),
        children: [
          const TextSpan(text: 'Belum punya akun? '),
          TextSpan(
            text: 'Daftar di sini',
            style: const TextStyle(
              color: Color(0xFF4A8CF7),
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
    return RichText(
      text: TextSpan(
        style: const TextStyle(color: Colors.black87),
        children: [
          const TextSpan(text: 'Lupa akun? '),
          TextSpan(
            text: 'Hubungi Admin',
            style: const TextStyle(
              color: Color(0xFF4A8CF7),
              fontWeight: FontWeight.bold,
            ),
            recognizer: TapGestureRecognizer()..onTap = _contactAdmin,
          ),
        ],
      ),
    );
  }

  Widget _buildScreeningButton() {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ScreeningPage()),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF42A5F5), // biru terang
              Color(0xFF1565C0), // biru gelap
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              // ignore: deprecated_member_use
              color: Color(0xFF1565C0).withOpacity(0.35),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: const [
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Cek Gejala TB Sekarang',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
