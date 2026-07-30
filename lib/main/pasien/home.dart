import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:apk_tb_care/main/pasien/consultation.dart';
import 'package:apk_tb_care/main/pasien/education.dart';
import 'package:apk_tb_care/connection.dart';
import 'package:apk_tb_care/main/pasien/screening.dart';
import 'package:apk_tb_care/profile.dart';
import 'package:apk_tb_care/main/pasien/treatment.dart';
import 'package:apk_tb_care/alarm_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider/path_provider.dart';
// ignore: depend_on_referenced_packages
import 'package:http_parser/http_parser.dart';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:apk_tb_care/values/colors.dart';

class HomePage extends StatefulWidget {
  final String name;
  final int userId;
  final int? patientId;

  const HomePage({
    super.key,
    required this.name,
    required this.userId,
    this.patientId,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  late Future<Map<String, dynamic>> _patientDataFuture;

  String? _currentTreatmentId;
  bool _uploadedToday = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _patientDataFuture = _fetchPatientData();
  }

  Future<void> _refreshHome() async {
    setState(() {
      _patientDataFuture = _fetchPatientData();
    });

    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<bool> _isPatientUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('user_type_id') == 2;
  }

  // ===================== UPLOAD CHECK =====================
  Future<void> _checkTodayUpload() async {
    if (widget.patientId == null) return;

    final session = await SharedPreferences.getInstance();
    final token = session.getString('token') ?? '';

    final response = await http.get(
      Uri.parse(
        '${Connection.BASE_URL}/treatments/${widget.patientId}/history?per_page=1',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200 && mounted) {
      final data = jsonDecode(response.body);
      final history = data['data'] as List<dynamic>;

      final today = DateTime.now();

      setState(() {
        if (history.isNotEmpty) {
          final submittedAt = DateTime.parse(history.first['submitted_at']);
          _uploadedToday =
              submittedAt.year == today.year &&
              submittedAt.month == today.month &&
              submittedAt.day == today.day;
        } else {
          _uploadedToday = false;
        }
      });
    }
  }

  // ===================== FETCH PATIENT =====================
  Future<Map<String, dynamic>> _fetchPatientData() async {
    final session = await SharedPreferences.getInstance();
    final token = session.getString('token') ?? '';

    try {
      final response = await http.get(
        Uri.parse('${Connection.BASE_URL}/patients/${widget.patientId}/show'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _checkTodayUpload();
        return data['data'] ?? {};
      } else {
        throw Exception('Failed to load patient data');
      }
    } catch (e) {
      log('Error fetching patient data: $e');
      return {};
    }
  }

  Future<void> _uploadImage(File imageFile, String patientTreatmentId) async {
    final uri = Uri.parse('${Connection.BASE_URL}/treatments/proof');
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    final request =
        http.MultipartRequest('POST', uri)
          ..headers.addAll({
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          })
          ..fields['patient_treatment_id'] = patientTreatmentId;

    final bytes = await imageFile.readAsBytes();

    request.files.add(
      http.MultipartFile.fromBytes(
        'photo',
        bytes,
        filename: 'bukti_${DateTime.now().millisecondsSinceEpoch}.jpg',
        contentType: MediaType('image', 'jpeg'),
      ),
    );

    final response = await request.send();
    final body = await response.stream.bytesToString();

    debugPrint('UPLOAD STATUS: ${response.statusCode}');
    debugPrint('UPLOAD BODY: $body');

    if (response.statusCode == 201) {
      await _checkTodayUpload();
      if (mounted) {
        setState(() {
          _uploadedToday = true;
          _isUploading = false;
          _patientDataFuture = _fetchPatientData();
        });
      }
      ScaffoldMessenger.of(
        // ignore: use_build_context_synchronously
        context,
      ).showSnackBar(const SnackBar(content: Text('Foto berhasil diunggah')));
    } else {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload gagal (${response.statusCode})')),
      );
    }
  }

  // ===================== HOME PAGE =====================
  Widget _buildHomePage() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _patientDataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData) {
          return const Center(child: Text('Gagal memuat data'));
        }

        final patientData = snapshot.data!;
        final treatments = patientData['treatments'] as List<dynamic>? ?? [];
        final currentTreatment = treatments.isNotEmpty ? treatments[0] : null;

        // ===================== ALARM AUTO (SATU KALI SAJA) =====================
        if (currentTreatment != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (await _isPatientUser()) {
              await AlarmService.initialize();
              await AlarmService.handleTreatment(
                status: currentTreatment['treatment_status'],
                medicationTime: currentTreatment['medication_time'],
                visits: currentTreatment['visits'],
              );
            }
          });
        }

        // FIX UTAMA: SIMPAN ID DI SINI (REAL-TIME)
        if (currentTreatment != null) {
          _currentTreatmentId ??= currentTreatment['id'].toString();
        }

        final visits = currentTreatment?['visits'] as List<dynamic>? ?? [];

        return RefreshIndicator(
          onRefresh: _refreshHome,
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildGreetingSection(),
                const SizedBox(height: 24),
                if (currentTreatment != null)
                  _buildTreatmentCard(currentTreatment)
                else
                  _buildEmptyTreatmentCard(),
                const SizedBox(height: 24),
                if (visits.isNotEmpty) _buildUpcomingEvents(visits),
                const SizedBox(height: 6),
                _buildFeatureSection(),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===================== HELPER =====================
  Widget _buildGreetingSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.person_rounded,
                color: AppColors.primary,
                size: 32,
              ),
            ),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selamat Datang',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTreatmentCard(Map<String, dynamic> treatment) {
    final currentDay = _calculateCurrentDay(
      treatment['start_date'],
      treatment['end_date'],
    );
    final totalDays = _calculateTotalDays(
      treatment['start_date'],
      treatment['end_date'],
    );
    final progress = totalDays > 0 ? currentDay / totalDays : 0.0;
    final medicationTime =
        treatment['medication_time']?.substring(0, 5) ?? '--:--';
    // ignore: unused_local_variable
    final prescription = (treatment['prescription'] as List<dynamic>? ?? [])
        .join(', ');

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            Color.lerp(AppColors.primary, Colors.blue.shade700, .35)!,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: .22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.medication_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Status Pengobatan',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _getTreatmentType(treatment['treatment_type_id']),
              style: const TextStyle(
                fontSize: 15,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              borderRadius: BorderRadius.circular(28),
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hari ke-$currentDay dari $totalDays',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${treatment['start_date']} - ${treatment['end_date']}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    treatment['treatment_status'] ?? 'Status',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(
                  Icons.notifications_active_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pengingat Minum Obat',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Setiap hari, $medicationTime WIB',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _showUploadDialog,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  disabledBackgroundColor: Colors.white70,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child:
                      _isUploading
                          ? const Row(
                            key: ValueKey("loading"),
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.3,
                                  color: AppColors.primary,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                "Mengunggah Bukti...",
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          )
                          : Row(
                            key: const ValueKey("button"),
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _uploadedToday
                                    ? Icons.photo_camera_rounded
                                    : Icons.check_circle_rounded,
                                color: AppColors.primary,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _uploadedToday
                                    ? "Perbarui Foto Bukti"
                                    : "Konfirmasi & Unggah Bukti",
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyTreatmentCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            Color.lerp(AppColors.primary, Colors.blue.shade700, .35)!,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: .22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.medication_outlined,
                color: Colors.white,
                size: 40,
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              "Belum Ada Pengobatan",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              "Saat ini Anda belum memiliki program pengobatan TB yang aktif.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 24),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Silakan menghubungi petugas TB untuk memulai atau melanjutkan pengobatan.",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
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
    );
  }

  Widget _buildUpcomingEvents(List<dynamic> visits) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Jadwal Mendatang',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 12),
        Column(
          children:
              visits.map((visit) {
                final date =
                    visit['visit_date'] != null
                        ? DateFormat(
                          'dd MMM yyyy',
                        ).format(DateTime.parse(visit['visit_date']))
                        : 'Tanggal tidak tersedia';
                final time = visit['visit_time']?.substring(0, 5) ?? '--:--';
                final status = visit['visit_status'] ?? 'Status tidak tersedia';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        // ignore: deprecated_member_use
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.event, color: AppColors.primary),
                    ),
                    title: const Text(
                      'Kunjungan Pengobatan',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('$date • $time • $status'),
                    trailing: const Icon(Icons.chevron_right),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    tileColor: Colors.grey[50],
                    onTap: () => _showEventDetails(visit),
                  ),
                );
              }).toList(),
        ),
      ],
    );
  }

  // ignore: unused_element
  Widget _buildHealthTips(List<Map<String, dynamic>> tips) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tips Kesehatan',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: tips.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final tip = tips[index];
              return SizedBox(
                width: 200,
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(tip['icon'], color: AppColors.primary, size: 32),
                        const SizedBox(height: 12),
                        Text(
                          tip['title'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          tip['description'],
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Helper methods
  int _calculateCurrentDay(String? startDate, String? endDate) {
    if (startDate == null || endDate == null) return 0;

    try {
      final start = DateTime.parse(startDate);
      final end = DateTime.parse(endDate);
      final today = DateTime.now();

      if (today.isBefore(start)) return 0;
      if (today.isAfter(end)) return end.difference(start).inDays;

      return today.difference(start).inDays + 1; // +1 to include current day
    } catch (e) {
      return 0;
    }
  }

  int _calculateTotalDays(String? startDate, String? endDate) {
    if (startDate == null || endDate == null) return 1;

    try {
      final start = DateTime.parse(startDate);
      final end = DateTime.parse(endDate);
      return end.difference(start).inDays;
    } catch (e) {
      return 1;
    }
  }

  String _getTreatmentType(int? typeId) {
    switch (typeId) {
      case 1:
        return 'TB Aktif';
      case 2:
        return 'TB Laten';
      case 3:
        return 'TB MDR';
      default:
        return 'Jenis TB Tidak Diketahui';
    }
  }

  void _showEventDetails(Map<String, dynamic> visit) {
    final date =
        visit['visit_date'] != null
            ? DateFormat(
              'EEEE, dd MMMM yyyy',
              'id_ID',
            ).format(DateTime.parse(visit['visit_date']))
            : 'Tanggal tidak tersedia';
    final time = visit['visit_time']?.substring(0, 5) ?? '--:--';
    final status = visit['visit_status'] ?? 'Status tidak tersedia';
    final notes = visit['notes'] ?? 'Tidak ada catatan';

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Detail Kunjungan'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tanggal: $date'),
                Text('Waktu: $time'),
                Text('Status: $status'),
                Text('Catatan: $notes'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Tutup'),
              ),
            ],
          ),
    );
  }

  void _showUploadDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Konfirmasi Minum Obat'),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [Text('Apakah Anda sudah minum obat hari ini?')],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Nanti'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showUploadOptions();
                },
                child: const Text('Konfirmasi'),
              ),
            ],
          ),
    );
  }

  void _showUploadOptions() {
    final ImagePicker picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      builder:
          (context) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Unggah Bukti Minum Obat',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Icon(Icons.camera_alt, color: AppColors.primary),
                  title: const Text('Ambil Foto'),
                  onTap: () async {
                    Navigator.pop(context);
                    final XFile? photo = await picker.pickImage(
                      source: ImageSource.camera,
                    );
                    if (photo != null) {
                      _handleSelectedImage(File(photo.path));
                    }
                  },
                ),
                ListTile(
                  leading: Icon(Icons.photo_library, color: AppColors.primary),
                  title: const Text('Pilih dari Galeri'),
                  onTap: () async {
                    Navigator.pop(context);
                    final XFile? image = await picker.pickImage(
                      source: ImageSource.gallery,
                    );
                    if (image != null) {
                      _handleSelectedImage(File(image.path));
                    }
                  },
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Konfirmasi obat berhasil dicatat'),
                      ),
                    );
                  },
                  child: const Text('Tanpa Foto'),
                ),
              ],
            ),
          ),
    );
  }

  // ===================== UPLOAD HANDLER =====================
  void _handleSelectedImage(File imageFile) async {
    if (_currentTreatmentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data pengobatan belum siap')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final bytes = await imageFile.readAsBytes();
      final decodedImage = img.decodeImage(bytes);
      if (decodedImage == null) {
        throw Exception('Gagal decode gambar');
      }

      final jpegBytes = img.encodeJpg(decodedImage, quality: 85);
      final tempDir = await getTemporaryDirectory();

      final fixedFile = File(
        '${tempDir.path}/upload_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      await fixedFile.writeAsBytes(jpegBytes);
      await _uploadImage(fixedFile, _currentTreatmentId!);
    } catch (e) {
      ScaffoldMessenger.of(
        // ignore: use_build_context_synchronously
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal memproses gambar: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Widget _buildFeatureSection() {
    return Row(
      children: [
        Expanded(
          child: Material(
            color: const Color(0xFFF3F8FF),
            borderRadius: BorderRadius.circular(22),
            elevation: 0,
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              splashColor: AppColors.primary.withValues(alpha: .10),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EducationPage()),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 22,
                  horizontal: 14,
                ),
                child: Column(
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: .08),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.menu_book_rounded,
                        color: AppColors.primary,
                        size: 34,
                      ),
                    ),

                    const SizedBox(height: 18),

                    const Text(
                      "Edukasi",
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        const SizedBox(width: 16),

        Expanded(
          child: Material(
            color: const Color(0xFFF3F8FF),
            borderRadius: BorderRadius.circular(22),
            elevation: 0,
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              splashColor: AppColors.primary.withValues(alpha: .10),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ScreeningPage()),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 22,
                  horizontal: 14,
                ),
                child: Column(
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: .08),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.fact_check_rounded,
                        color: AppColors.primary,
                        size: 34,
                      ),
                    ),

                    const SizedBox(height: 18),

                    const Text(
                      "Skrining",
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ===================== BUILD =====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: const Text(
          'TB Care',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildHomePage(),
          TreatmentPage(patientId: widget.patientId ?? 0),
          // const EducationPage(),
          const ConsultationPage(),
          const ProfilePage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Beranda'),
          NavigationDestination(
            icon: Icon(Icons.medication),
            label: 'Pengobatan',
          ),
          NavigationDestination(icon: Icon(Icons.chat), label: 'Konsultasi'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}
