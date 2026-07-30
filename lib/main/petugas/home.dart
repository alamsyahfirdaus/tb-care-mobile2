import 'dart:convert';
import 'package:apk_tb_care/main/pasien/consultation.dart';
import 'package:apk_tb_care/main/pasien/education.dart';
import 'package:apk_tb_care/main/pasien/screening.dart';
import 'package:apk_tb_care/main/petugas/patient.dart';
import 'package:apk_tb_care/connection.dart';
import 'package:apk_tb_care/profile.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apk_tb_care/values/colors.dart';

class StaffHomePage extends StatefulWidget {
  final String name;

  const StaffHomePage({super.key, required this.name});

  @override
  State<StaffHomePage> createState() => _StaffHomePageState();
}

class _StaffHomePageState extends State<StaffHomePage> {
  int _selectedIndex = 0;
  List<dynamic> _patientData = [];
  List<Widget> get _pages => [
    _buildStaffHomePage(),
    PatientPage(),
    EducationPage(isStaff: true),
    ConsultationPage(isStaff: true),
    ProfilePage(),
  ];

  double _adherenceRate = 0.0;
  bool _isAdherenceLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPatientData();
    _fetchAdherenceRate();
  }

  Future<void> _fetchPatientData() async {
    final session = await SharedPreferences.getInstance();
    final token = session.getString('token') ?? '';

    try {
      final response = await http.get(
        Uri.parse('${Connection.BASE_URL}/patients'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        Map<String, dynamic> dataJson = jsonDecode(response.body);
        setState(() {
          _patientData = List<Map<String, dynamic>>.from(dataJson['data']);
        });
      } else {
        throw Exception('Failed to load patient data');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  Future<void> _fetchAdherenceRate() async {
    final session = await SharedPreferences.getInstance();
    final token = session.getString('token') ?? '';

    try {
      final response = await http.get(
        Uri.parse('${Connection.BASE_URL}/patients/adherence'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final dataJson = jsonDecode(response.body);

        // "0.55%" → 0.55
        final rawValue = dataJson['data']['adherence_average']
            .toString()
            .replaceAll('%', '');

        setState(() {
          _adherenceRate = double.tryParse(rawValue) ?? 0.0;
          _isAdherenceLoading = false;
        });
      } else {
        throw Exception('Failed to load adherence rate');
      }
    } catch (e) {
      setState(() {
        _isAdherenceLoading = false;
      });
      debugPrint('Adherence API Error: $e');
    }
  }

  // Helper method to get the first active treatment or null
  Map<String, dynamic>? _getActiveTreatment(Map<String, dynamic> patient) {
    if (patient['treatments'] == null || patient['treatments'].isEmpty) {
      return null;
    }

    // Find first treatment with status 'Berjalan' or return the first one
    return patient['treatments'].firstWhere(
      (t) => t['treatment_status'] == 'Berjalan',
      orElse: () => patient['treatments'].first,
    );
  }

  Widget _buildStaffHomePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStaffGreetingSection(),
          const SizedBox(height: 24),
          _buildQuickStats(),
          const SizedBox(height: 16),
          _isAdherenceLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildAdherenceCard(_adherenceRate),
          const SizedBox(height: 24),
          _buildRecentPatientsSection(),
          const SizedBox(height: 16),
          _buildFullStats(),
          const SizedBox(height: 16),
          _buildScreeningSection(),
        ],
      ),
    );
  }

  Widget _buildStaffGreetingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Selamat datang, ${widget.name}',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Anda menangani ${_patientData.length} pasien TB',
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildQuickStats() {
    // Count total patients
    final totalPatients = _patientData.length;

    // Count new patients (those with recent start dates in last 30 days)
    final newPatientsCount =
        _patientData.where((patient) {
          final treatment = _getActiveTreatment(patient);
          if (treatment == null || treatment['start_date'] == null)
            // ignore: curly_braces_in_flow_control_structures
            return false;

          try {
            final startDate = DateTime.parse(treatment['start_date']);
            return DateTime.now().difference(startDate).inDays <= 30;
          } catch (e) {
            return false;
          }
        }).length;

    // Count active treatments
    final activeTreatmentsCount =
        _patientData.where((patient) {
          final treatment = _getActiveTreatment(patient);
          return treatment != null &&
              treatment['treatment_status'] == 'Berjalan';
        }).length;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            value: totalPatients.toString(),
            label: 'Total Pasien',
            icon: Icons.group,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            value: newPatientsCount.toString(),
            label: 'Pasien Baru',
            icon: Icons.person_add,
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            value: activeTreatmentsCount.toString(),
            label: 'Pengobatan Aktif',
            icon: Icons.medical_services,
            color: Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String value,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                // ignore: deprecated_member_use
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdherenceCard(double rate) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.medication, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Tingkat Kepatuhan',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 150,
                    height: 150,
                    child: CircularProgressIndicator(
                      value: rate / 100,
                      strokeWidth: 12,
                      backgroundColor: Colors.grey[200],
                      color:
                          rate > 80
                              ? Colors.green
                              : rate > 60
                              ? Colors.orange
                              : Colors.red,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$rate%',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      Text(
                        rate > 80
                            ? 'Baik'
                            : rate > 60
                            ? 'Cukup'
                            : 'Kurang',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Rata-rata kepatuhan minum obat pasien',
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentPatientsSection() {
    // Sort patients by most recent treatment start date
    final sortedPatients = List.from(_patientData);
    sortedPatients.sort((a, b) {
      final treatmentA = _getActiveTreatment(a);
      final treatmentB = _getActiveTreatment(b);

      final dateA =
          treatmentA?['start_date'] != null
              ? DateTime.tryParse(treatmentA?['start_date']) ?? DateTime(1970)
              : DateTime(1970);

      final dateB =
          treatmentB?['start_date'] != null
              ? DateTime.tryParse(treatmentB?['start_date']) ?? DateTime(1970)
              : DateTime(1970);

      return dateB.compareTo(dateA);
    });

    // Take only the first 5 patients for "recent" section
    final recentPatients = sortedPatients.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Pasien Terkini',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedIndex = 1; // Navigate to patient list
                });
              },
              child: const Text('Lihat Semua'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (recentPatients.isEmpty)
          const Center(child: Text('Tidak ada data pasien')),
        if (recentPatients.isNotEmpty)
          Column(
            children:
                recentPatients
                    .map((patient) => _buildPatientCard(patient))
                    .toList(),
          ),
      ],
    );
  }

  Widget _buildPatientCard(Map<String, dynamic> patient) {
    final treatment = _getActiveTreatment(patient);

    // Handle treatment dates
    DateTime? startDate;
    DateTime? endDate;
    int totalDays = 0;
    int daysPassed = 0;
    double progress = 0.0;
    bool hasDates = false;

    if (treatment != null &&
        treatment['start_date'] != null &&
        treatment['end_date'] != null) {
      try {
        startDate = DateTime.parse(treatment['start_date']);
        endDate = DateTime.parse(treatment['end_date']);
        final today = DateTime.now();
        totalDays = endDate.difference(startDate).inDays;
        daysPassed =
            today.isAfter(startDate) ? today.difference(startDate).inDays : 0;
        progress = totalDays > 0 ? daysPassed / totalDays : 0;
        hasDates = true;
      } catch (e) {
        debugPrint('Error parsing dates: $e');
      }
    }

    // Get next visit if available
    String nextVisitDate = '--/--';
    String nextVisitTime = '--:--';

    if (treatment != null &&
        treatment['visits'] != null &&
        treatment['visits'].isNotEmpty) {
      // Find the first upcoming visit
      final upcomingVisits =
          treatment['visits'].where((visit) {
            if (visit['visit_date'] == null) return false;

            final visitDate = DateTime.parse(visit['visit_date']);
            return visitDate.isAfter(DateTime.now());
          }).toList();

      if (upcomingVisits.isNotEmpty) {
        final nextVisit = upcomingVisits.first;
        try {
          nextVisitDate = DateFormat(
            'dd/MM',
          ).format(DateTime.parse(nextVisit['visit_date']));
          if (nextVisit['visit_time'] != null) {
            nextVisitTime = DateFormat(
              'HH:mm',
            ).format(DateFormat('HH:mm:ss').parse(nextVisit['visit_time']));
          }
        } catch (e) {
          debugPrint('Error parsing visit date/time: $e');
        }
      }
    }

    // Get treatment status or default
    final treatmentStatus = treatment?['treatment_status'] ?? 'Belum Mulai';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      child: InkWell(
        onTap: () {
          // Navigate to patient detail
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.grey[200],
                child: Text(
                  patient['name']?.isNotEmpty == true
                      ? patient['name'][0]
                      : '?',
                  style: const TextStyle(fontSize: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient['name'] ?? 'Nama tidak tersedia',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    if (hasDates)
                      LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        backgroundColor: Colors.grey[200],
                        color: AppColors.primary,
                        minHeight: 4,
                      ),
                    if (!hasDates)
                      const Text(
                        'Belum ada jadwal pengobatan',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (hasDates)
                          Text(
                            'Hari ${daysPassed.clamp(0, totalDays)}/$totalDays',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        const Spacer(),
                        Chip(
                          label: Text(treatmentStatus),
                          backgroundColor:
                              treatmentStatus == 'Berjalan'
                                  ? Colors.blue[100]
                                  : treatmentStatus == 'Selesai'
                                  ? Colors.green[100]
                                  : Colors.grey[200],
                          labelStyle: TextStyle(
                            color:
                                treatmentStatus == 'Berjalan'
                                    ? Colors.blue[800]
                                    : treatmentStatus == 'Selesai'
                                    ? Colors.green[800]
                                    : Colors.grey[800],
                            fontSize: 12,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                children: [
                  const Text(
                    'Kunjungan',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                  Text(
                    nextVisitDate,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    nextVisitTime,
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFullStats() {
    // Count treatment statuses
    int activeCount = 0;
    int completedCount = 0;
    int failedCount = 0;
    int deceasedCount = 0;

    for (var patient in _patientData) {
      if (patient['treatments'] != null) {
        for (var treatment in patient['treatments']) {
          switch (treatment['treatment_status']) {
            case 'Berjalan':
              activeCount++;
              break;
            case 'Selesai':
              completedCount++;
              break;
            case 'Gagal':
              failedCount++;
              break;
            case 'Meninggal':
              deceasedCount++;
              break;
          }
        }
      }
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Statistik Pengobatan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMiniStatCard(
                  value: activeCount.toString(),
                  label: 'Aktif',
                  color: Colors.blue,
                ),
                _buildMiniStatCard(
                  value: completedCount.toString(),
                  label: 'Selesai',
                  color: Colors.green,
                ),
                _buildMiniStatCard(
                  value: failedCount.toString(),
                  label: 'Gagal',
                  color: Colors.red,
                ),
                _buildMiniStatCard(
                  value: deceasedCount.toString(),
                  label: 'Meninggal',
                  color: Colors.redAccent,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStatCard({
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            // ignore: deprecated_member_use
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildScreeningSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Skrining TB",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const Text(
          "Lakukan pengecekan rutin terhadap gejala TB Anda. ",
          style: TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 12),
        _buildScreeningButton("Skrining TB", Icons.paste),
      ],
    );
  }

  Widget _buildScreeningButton(String title, IconData icon) {
    return OutlinedButton.icon(
      label: Text(title),
      onPressed: () => _navigateToScreening(title),
      icon: Icon(icon, color: Colors.blue),
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        fixedSize: Size(double.maxFinite, 48),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _navigateToScreening(String type) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const ScreeningPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          'TB Care - Petugas',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outlined),
            selectedIcon: Icon(Icons.people),
            label: 'Pasien',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Edukasi',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_outlined),
            selectedIcon: Icon(Icons.chat),
            label: 'Konsultasi',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
