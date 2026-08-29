import 'dart:convert';
import 'dart:typed_data';
import 'package:apk_tb_care/main/login.dart';
import 'package:apk_tb_care/connection.dart';
import 'package:apk_tb_care/edit_profile.dart';
import 'package:apk_tb_care/values/colors.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic> _userData = {};
  bool _isLoading = true;
  bool _hasError = false;
  Uint8List? _profileImageBytes;
  bool _isImageLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  /* =========================================================
   * LOAD USER PROFILE (FINAL & SECURED)
   * ========================================================= */
  Future<void> _loadUserData({bool isRefresh = false}) async {
    final session = await SharedPreferences.getInstance();
    final token = session.getString('token');

    // Jika token tidak ada → paksa login ulang
    if (token == null || token.isEmpty) {
      await _forceLogout();
      return;
    }

    if (!isRefresh && _userData.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }

    try {
      final response = await http.get(
        Uri.parse('${Connection.BASE_URL}/profile/show'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> dataJson = jsonDecode(response.body);
        final userData = dataJson['data'] ?? {};

        if (!mounted) return;
        setState(() {
          _userData = userData;
          _isLoading = false;
          _hasError = false;
        });

        // Load photo if available
        final photoPath = userData['photo'];
        if (photoPath != null && photoPath.toString().trim().isNotEmpty) {
          await _loadProfileImage(photoPath.toString());
        } else {
          if (!mounted) return;
          setState(() {
            _profileImageBytes = null;
            _isImageLoading = false;
          });
        }
      } else if (response.statusCode == 401) {
        // Token expired / invalid
        await _forceLogout();
      } else {
        throw Exception('Failed to load profile');
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (_userData.isEmpty) {
          _hasError = true;
        }
      });

      if (isRefresh) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal memperbarui data profil. Periksa koneksi Anda.',
              style: GoogleFonts.plusJakartaSans(),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /* =========================================================
   * LOAD PROFILE IMAGE (CONCURRENT & LIFE-CYCLE SAFE)
   * ========================================================= */
  Future<void> _loadProfileImage(String photoPath) async {
    if (!mounted) return;
    setState(() {
      _isImageLoading = true;
    });

    try {
      final bytes = await fetchProfileImage(photoPath);
      if (!mounted) return;
      setState(() {
        _profileImageBytes = bytes;
        _isImageLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading profile image bytes: $e');
      if (!mounted) return;
      setState(() {
        _isImageLoading = false;
      });
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
   * LOGOUT WITH CONFIRMATION (REVISED & SECURED)
   * ========================================================= */
  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Keluar dari Akun?',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            content: Text(
              'Anda yakin ingin keluar dari akun TB Care?',
              style: GoogleFonts.plusJakartaSans(color: Colors.grey[600]),
            ),
            actionsPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Batal',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[50],
                  foregroundColor: Colors.red,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Keluar',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      final session = await SharedPreferences.getInstance();
      final token = session.getString('token');

      // Logout lokal SELALU dilakukan pertama kali agar responsif dan aman
      await _forceLogout();

      // Logout ke server → best effort (non-blocking)
      if (token != null && token.isNotEmpty) {
        try {
          http
              .post(
                Uri.parse('${Connection.BASE_URL}/logout'),
                headers: {'Authorization': 'Bearer $token'},
              )
              .timeout(const Duration(seconds: 3));
        } catch (e) {
          debugPrint('Server logout api error (best effort): $e');
        }
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
    await _loadUserData(isRefresh: true);
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
    if (dateString == null || dateString.trim().isEmpty) return '-';
    try {
      final dateTime = DateTime.parse(dateString);
      return DateFormat('dd MMMM yyyy', 'id_ID').format(dateTime);
    } catch (_) {
      try {
        final dateTime = DateTime.parse(dateString);
        return DateFormat('dd MMMM yyyy').format(dateTime);
      } catch (_) {
        return '-';
      }
    }
  }

  String _getNameInitial(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    return name.trim()[0].toUpperCase();
  }

  /* =========================================================
   * SUB-WIDGET BUILDERS (MODERN LAYOUT)
   * ========================================================= */
  Widget _buildSkeletonLoader() {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Profil Saya',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Center(
              child: Column(
                children: [
                  Container(
                    width: 110,
                    height: 110,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFE5E7EB),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: 180,
                    height: 24,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: const Color(0xFFE5E7EB),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 80,
                    height: 16,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: const Color(0xFFE5E7EB),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildSkeletonCard(),
            const SizedBox(height: 16),
            _buildSkeletonCard(),
            const SizedBox(height: 24),
            Container(
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 120,
            height: 20,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: const Color(0xFFE5E7EB),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          const SizedBox(height: 16),
          for (int i = 0; i < 3; i++) ...[
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: const Color(0xFFE5E7EB),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 80,
                      height: 12,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: const Color(0xFFE5E7EB),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 160,
                      height: 14,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: const Color(0xFFE5E7EB),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (i < 2) const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyOrErrorState({
    required String title,
    required String message,
    required IconData icon,
  }) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Profil Saya',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 80, color: AppColors.primary),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: Colors.grey[500],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _refreshProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Coba Lagi',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final String name = _userData['name'] ?? '-';
    final String initial = _getNameInitial(name);
    final String role = _getUserType();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    width: 3,
                  ),
                ),
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: const Color(0xFFF3F4F6),
                  child:
                      _userData['photo'] != null &&
                              _userData['photo'].toString().trim().isNotEmpty
                          ? (_profileImageBytes != null
                              ? ClipOval(
                                child: Image.memory(
                                  _profileImageBytes!,
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                ),
                              )
                              : (_isImageLoading
                                  ? const SizedBox(
                                    width: 30,
                                    height: 30,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppColors.primary,
                                      ),
                                    ),
                                  )
                                  : Icon(
                                    Icons.person_rounded,
                                    size: 50,
                                    color: Colors.grey[400],
                                  )))
                          : Text(
                            initial,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              role,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      width: double.infinity,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(color: Color(0xFFF3F4F6), thickness: 1.2),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    final displayValue =
        (value.trim().isEmpty || value == '-') ? 'Belum diisi' : value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  displayValue,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: Colors.grey[800],
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutRow() {
    return Container(
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _logout,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: Colors.red,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Keluar dari Akun',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Keluar dari aplikasi',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /* =========================================================
   * BUILD (MAIN BODY ROUTER)
   * ========================================================= */
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildSkeletonLoader();
    }

    if (_hasError) {
      return _buildEmptyOrErrorState(
        title: 'Profil Gagal Dimuat',
        message: 'Gagal memuat data profil. Periksa koneksi internet Anda.',
        icon: Icons.wifi_off_rounded,
      );
    }

    if (_userData.isEmpty) {
      return _buildEmptyOrErrorState(
        title: 'Profil Belum Tersedia',
        message: 'Data profil Anda belum dapat ditampilkan saat ini.',
        icon: Icons.account_circle_outlined,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Profil Saya',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            // color: AppColors.primary,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfileEditPage(userData: _userData),
                ),
              ).then((_) {
                if (mounted) {
                  _loadUserData();
                }
              });
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshProfile,
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            children: [
              _buildProfileHeader(),
              const SizedBox(height: 20),
              _buildSectionCard(
                title: 'Informasi Pribadi',
                children: [
                  _buildInfoItem(
                    Icons.person_outline_rounded,
                    'Nama Lengkap',
                    _userData['name'] ?? '',
                  ),
                  _buildInfoItem(
                    Icons.wc_rounded,
                    'Jenis Kelamin',
                    _getGender(),
                  ),
                  _buildInfoItem(
                    Icons.place_outlined,
                    'Tempat Lahir',
                    _userData['place_of_birth'] ?? '',
                  ),
                  _buildInfoItem(
                    Icons.cake_outlined,
                    'Tanggal Lahir',
                    _formatDate(_userData['date_of_birth']),
                  ),
                  _buildInfoItem(
                    Icons.phone_iphone_rounded,
                    'Nomor Telepon',
                    _userData['phone'] ?? '',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSectionCard(
                title: 'Informasi Akun',
                children: [
                  _buildInfoItem(
                    Icons.alternate_email_rounded,
                    'Username',
                    _userData['username'] ?? '',
                  ),
                  _buildInfoItem(
                    Icons.mail_outline_rounded,
                    'Email',
                    _userData['email'] ?? '',
                  ),
                  _buildInfoItem(
                    Icons.calendar_month_outlined,
                    'Bergabung Pada',
                    _formatDate(_userData['created_at']),
                  ),
                  _buildInfoItem(
                    Icons.login_rounded,
                    'Terakhir Login',
                    _formatDate(_userData['last_login_at']),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildLogoutRow(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
