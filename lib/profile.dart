import 'dart:convert';
import 'dart:typed_data';
import 'package:apk_tb_care/main/login.dart';
import 'package:apk_tb_care/connection.dart';
import 'package:apk_tb_care/edit_profile.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
// ignore: unused_import
import 'package:cached_network_image/cached_network_image.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic> _userData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  /* =========================================================
   * LOAD USER PROFILE (FINAL)
   * ========================================================= */
  Future<void> _loadUserData() async {
    final session = await SharedPreferences.getInstance();
    final token = session.getString('token');

    // Jika token tidak ada → paksa login ulang
    if (token == null || token.isEmpty) {
      await _forceLogout();
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('${Connection.BASE_URL}/profile/show'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> dataJson = jsonDecode(response.body);
        setState(() {
          _userData = dataJson['data'] ?? {};
          _isLoading = false;
        });
      } else if (response.statusCode == 401) {
        // Token expired / invalid
        await _forceLogout();
      } else {
        throw Exception('Failed to load profile');
      }
    } catch (_) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal memuat data pengguna')),
      );
    }
  }

  /* =========================================================
   * FORCE LOGOUT (SESSION CLEANER)
   * ========================================================= */
  Future<void> _forceLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  /* =========================================================
   * LOGOUT WITH CONFIRMATION (FINAL)
   * ========================================================= */
  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Konfirmasi Keluar'),
            content: const Text('Yakin ingin keluar dari aplikasi?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Keluar',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      // Logout lokal SELALU dilakukan
      await _forceLogout();

      // Logout ke server → best effort
      final session = await SharedPreferences.getInstance();
      final token = session.getString('token');

      if (token != null) {
        await http.post(
          Uri.parse('${Connection.BASE_URL}/logout'),
          headers: {'Authorization': 'Bearer $token'},
        );
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

  Future<void> _refreshProfile() async {
    setState(() {
      _isLoading = true;
    });

    await _loadUserData();

    // Optional delay agar animasi smooth
    await Future.delayed(const Duration(milliseconds: 300));
  }

  /* =========================================================
   * HELPER FORMATTER
   * ========================================================= */
  String _getUserType() {
    switch (_userData['user_type_id']) {
      case 1:
        return 'Petugas Kesehatan';
      case 2:
        return 'Pasien';
      default:
        return 'Pengguna';
    }
  }

  String _getGender() {
    switch (_userData['gender']) {
      case 'L':
        return 'Laki-laki';
      case 'P':
        return 'Perempuan';
      default:
        return '-';
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '-';
    try {
      final dateTime = DateTime.parse(dateString);
      return DateFormat('dd MMMM yyyy').format(dateTime);
    } catch (_) {
      return '-';
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const Text(': '),
          Expanded(child: Text(value.isNotEmpty ? value : '-')),
        ],
      ),
    );
  }

  /* =========================================================
   * UI
   * ========================================================= */
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_userData.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profil Saya')),
        body: const Center(child: Text('Tidak ada data pengguna')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil Saya'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfileEditPage(userData: _userData),
                ),
              ).then((_) => _loadUserData());
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshProfile,
        color: Theme.of(context).primaryColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey[200],
                      child:
                          _userData['photo'] != null
                              ? FutureBuilder<Uint8List?>(
                                future: fetchProfileImage(_userData['photo']),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const CircularProgressIndicator(
                                      strokeWidth: 2,
                                    );
                                  }

                                  if (!snapshot.hasData) {
                                    return const Icon(
                                      Icons.broken_image,
                                      size: 40,
                                      color: Colors.grey,
                                    );
                                  }

                                  return ClipOval(
                                    child: Image.memory(
                                      snapshot.data!,
                                      width: 100,
                                      height: 100,
                                      fit: BoxFit.cover,
                                    ),
                                  );
                                },
                              )
                              : Text(
                                _userData['name']?[0]?.toUpperCase() ?? '?',
                                style: const TextStyle(fontSize: 28),
                              ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _userData['name'] ?? '-',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _getUserType(),
                      style: TextStyle(color: Theme.of(context).primaryColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ==== CARD INFO ====
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Informasi Pribadi',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Divider(),
                      _buildInfoRow('Username', _userData['username'] ?? ''),
                      _buildInfoRow('Email', _userData['email'] ?? ''),
                      _buildInfoRow('Telepon', _userData['phone'] ?? ''),
                      _buildInfoRow(
                        'Tempat Lahir',
                        _userData['place_of_birth'] ?? '',
                      ),
                      _buildInfoRow(
                        'Tanggal Lahir',
                        _formatDate(_userData['date_of_birth']),
                      ),
                      _buildInfoRow('Jenis Kelamin', _getGender()),
                      _buildInfoRow(
                        'Bergabung Pada',
                        _formatDate(_userData['created_at']),
                      ),
                      _buildInfoRow(
                        'Terakhir Login',
                        _formatDate(_userData['last_login_at']),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text(
                  'Keluar',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: _logout,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
