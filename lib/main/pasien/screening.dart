// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'dart:developer';

import 'package:apk_tb_care/connection.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ScreeningPage extends StatefulWidget {
  const ScreeningPage({super.key});

  @override
  State<ScreeningPage> createState() => _ScreeningPageState();
}

class _ScreeningPageState extends State<ScreeningPage> {
  int _currentStep = 0;
  int? _selectedCategoryId;
  final Map<int, int> _answers =
      {}; // question_id: answer (0 for No, 1 for Yes)
  bool _isLoading = false;
  String _loadingText = "Menyiapkan skrining...";
  List<dynamic> categories = [];
  List<dynamic> questions = [];
  bool _showResultScreen = false;
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
      _loadingText = "Memuat kategori skrining...";
    });
    final session = await SharedPreferences.getInstance();
    if (!mounted) return;
    final token = session.getString('token') ?? '';

    try {
      final response = await http.get(
        Uri.parse('${Connection.BASE_URL}/screening/categories'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          categories = data['data'];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        _showModernSnackBar('Gagal memuat kategori', isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      log(e.toString());
      _showModernSnackBar('Terjadi kesalahan koneksi', isError: true);
    }
  }

  Future<void> _loadQuestions(int categoryId) async {
    setState(() {
      _isLoading = true;
      _loadingText = "Memuat pertanyaan...";
    });
    final session = await SharedPreferences.getInstance();
    if (!mounted) return;
    final token = session.getString('token') ?? '';

    try {
      final response = await http.post(
        Uri.parse('${Connection.BASE_URL}/screening/questions'),
        headers: {'Authorization': 'Bearer $token'},
        body: {'category_id': categoryId.toString()},
      );
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          questions = data['data'];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        _showModernSnackBar('Gagal memuat pertanyaan', isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      log(e.toString());
      _showModernSnackBar('Terjadi kesalahan koneksi', isError: true);
    }
  }

  Future<void> _submitAnswers() async {
    setState(() {
      _isLoading = true;
      _loadingText = "Mengirim jawaban...";
    });
    final session = await SharedPreferences.getInstance();
    if (!mounted) return;
    final token = session.getString('token') ?? '';

    try {
      final answerList =
          _answers.entries
              .map((e) => {'question_id': e.key, 'answer': e.value})
              .toList();

      final response = await http.post(
        Uri.parse('${Connection.BASE_URL}/screening/submit'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'answers': answerList}),
      );
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _result = {
            'result': data['result'] ?? 'Tidak Diketahui',
            'message': data['message'] ?? 'Hasil skrining diterima',
          };
          _showResultScreen = true;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        final errorResponse = jsonDecode(response.body);
        _showModernSnackBar(
          errorResponse['message'] ?? 'Gagal mengirim jawaban',
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      log('Error submitting answers: $e');
      _showModernSnackBar(
        'Terjadi kesalahan saat mengirim jawaban',
        isError: true,
      );
    }
  }

  List<dynamic> _getAllQuestions() {
    List<dynamic> allQuestions = [];
    for (var group in questions) {
      allQuestions.addAll(group['sub_questions']);
    }
    return allQuestions;
  }

  void _showModernSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            isError ? const Color(0xFFEF4444) : const Color(0xFF1565C0),
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
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= APBAR BUILDER =================
  PreferredSizeWidget _buildAppBar({
    required String title,
    required VoidCallback? onBackPressed,
  }) {
    return AppBar(
      backgroundColor: const Color(0xFF1565C0),
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      automaticallyImplyLeading: false,
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.white,
          fontSize: 18,
        ),
      ),
      leading:
          onBackPressed != null
              ? IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: onBackPressed,
              )
              : null,
    );
  }

  // ================= MAIN BUILD METHOD =================
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingScreen();
    }

    if (_showResultScreen && _result != null) {
      return _buildResultScreen();
    }

    if (_selectedCategoryId == null) {
      return _buildCategorySelection();
    }

    return _buildQuestionScreen();
  }

  IconData _getCategoryIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('anak') ||
        lower.contains('balita') ||
        lower.contains('anak-anak')) {
      return Icons.child_care_rounded;
    } else if (lower.contains('dewasa') || lower.contains('umum')) {
      return Icons.person_rounded;
    } else if (lower.contains('lansia') || lower.contains('tua')) {
      return Icons.elderly_rounded;
    } else if (lower.contains('remaja')) {
      return Icons.face_rounded;
    }
    return Icons.people_rounded;
  }

  // ================= STAGE 1: CATEGORY SELECTION =================
  Widget _buildCategorySelection() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(
        title: "Skrining Gejala TB",
        onBackPressed: () => Navigator.of(context).pop(),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Banner
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: const Border(
                      left: BorderSide(color: Color(0xFF1E88E5), width: 4),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: Color(0xFFE3F2FD),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.info_outline_rounded,
                          color: Color(0xFF1E88E5),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          "Pilih kategori usia untuk memulai skrining. Jawab setiap pertanyaan sesuai kondisi Anda.",
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF475569),
                            height: 1.45,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  "Pilih Kategori Usia",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 16),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final int categoryId = category['id'];
                    final String categoryName = category['name'];

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () {
                            setState(() {
                              _selectedCategoryId = categoryId;
                              _currentStep = 0;
                              _answers.clear();
                              questions = [];
                            });
                            _loadQuestions(categoryId);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE3F2FD),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    _getCategoryIcon(categoryName),
                                    color: const Color(0xFF1E88E5),
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        categoryName,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        "Klik untuk memulai skrining",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF94A3B8),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF1F5F9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.chevron_right_rounded,
                                    color: Color(0xFF64748B),
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ================= STAGE 2: SCREENING QUESTIONS =================
  Widget _buildQuestionScreen() {
    final allQuestions = _getAllQuestions();
    if (allQuestions.isEmpty) {
      return Scaffold(
        appBar: _buildAppBar(
          title: "Skrining Gejala TB",
          onBackPressed: () => setState(() => _selectedCategoryId = null),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.folder_open_rounded,
                  color: Color(0xFF94A3B8),
                  size: 64,
                ),
                const SizedBox(height: 16),
                const Text(
                  "Tidak ada pertanyaan tersedia",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    onPressed: () => setState(() => _selectedCategoryId = null),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 48),
                      foregroundColor: const Color(0xFF1565C0),
                      side: const BorderSide(
                        color: Color(0xFF1565C0),
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      "Kembali",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final currentQuestion = allQuestions[_currentStep];
    final int questionId = currentQuestion['question_id'];
    final int? selectedAnswer = _answers[questionId];
    final progress = (_currentStep + 1) / allQuestions.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(title: "Skrining Gejala TB", onBackPressed: null),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Progress Bar Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Pertanyaan ${_currentStep + 1} dari ${allQuestions.length}",
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    "${((progress) * 100).toInt()}% Selesai",
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E88E5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: const Color(0xFFE2E8F0),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF1E88E5),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Question Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        "PERTANYAAN ${_currentStep + 1}",
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E88E5),
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      currentQuestion['question_text'],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Ya/Tidak Selectable Cards
                    Row(
                      children: [
                        // YA CARD
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _answers[questionId] = 1;
                              });
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color:
                                    selectedAnswer == 1
                                        ? const Color(0xFFE3F2FD)
                                        : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color:
                                      selectedAnswer == 1
                                          ? const Color(0xFF1E88E5)
                                          : const Color(0xFFE2E8F0),
                                  width: selectedAnswer == 1 ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    selectedAnswer == 1
                                        ? Icons.check_circle_rounded
                                        : Icons.check_circle_outline_rounded,
                                    color:
                                        selectedAnswer == 1
                                            ? const Color(0xFF1E88E5)
                                            : const Color(0xFF94A3B8),
                                    size: 32,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "YA",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          selectedAnswer == 1
                                              ? const Color(0xFF1E88E5)
                                              : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // TIDAK CARD
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _answers[questionId] = 0;
                              });
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color:
                                    selectedAnswer == 0
                                        ? const Color(0xFFF1F5F9)
                                        : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color:
                                      selectedAnswer == 0
                                          ? const Color(0xFF64748B)
                                          : const Color(0xFFE2E8F0),
                                  width: selectedAnswer == 0 ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    selectedAnswer == 0
                                        ? Icons.cancel_rounded
                                        : Icons.cancel_outlined,
                                    color:
                                        selectedAnswer == 0
                                            ? const Color(0xFF64748B)
                                            : const Color(0xFF94A3B8),
                                    size: 32,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "TIDAK",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          selectedAnswer == 0
                                              ? const Color(0xFF334155)
                                              : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Navigasi Bawah
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          if (_currentStep == 0) {
                            setState(() => _selectedCategoryId = null);
                          } else {
                            setState(() => _currentStep--);
                          }
                        },
                        icon: const Icon(Icons.arrow_back_rounded, size: 18),
                        label: const Text(
                          "Kembali",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                          side: const BorderSide(
                            color: Color(0xFFE2E8F0),
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed:
                            selectedAnswer != null
                                ? () {
                                  if (_currentStep < allQuestions.length - 1) {
                                    setState(() => _currentStep++);
                                  } else {
                                    _submitAnswers();
                                  }
                                }
                                : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1E88E5),
                          disabledBackgroundColor: const Color(0xFFBDD7F5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _currentStep == allQuestions.length - 1
                                  ? "Selesai"
                                  : "Lanjut",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              _currentStep == allQuestions.length - 1
                                  ? Icons.check_circle_rounded
                                  : Icons.arrow_forward_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                          ],
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

  // ================= STAGE 3: RESULT SCREEN =================
  Widget _buildResultScreen() {
    final result = _result?['result'] ?? 'Tidak Diketahui';
    // ignore: unused_local_variable
    final message = _result?['message'] ?? '';
    final isSuspected = result == 'Terduga TB';

    final themeColor =
        isSuspected ? const Color(0xFFF97316) : const Color(0xFF10B981);
    final themeBgColor =
        isSuspected ? const Color(0xFFFFF7ED) : const Color(0xFFECFDF5);
    final themeBorderColor =
        isSuspected ? const Color(0xFFFFE5D9) : const Color(0xFFD1FAE5);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(title: "Hasil Skrining", onBackPressed: null),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Result Card
              Container(
                decoration: BoxDecoration(
                  color: themeBgColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: themeBorderColor, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: themeColor.withOpacity(0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isSuspected
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle_rounded,
                        color: themeColor,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      isSuspected ? "Terduga TB" : "Tidak Terduga TB",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: themeColor,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isSuspected
                          ? "Hasil skrining menunjukkan adanya gejala yang perlu diperiksa lebih lanjut. Hasil ini bukan diagnosis TB."
                          : "Berdasarkan jawaban yang diberikan, hasil skrining tidak menunjukkan gejala yang mengarah pada terduga TB. Hasil skrining ini bukan diagnosis medis.",
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Recommendations Section (Only for Suspected)
              if (isSuspected) ...[
                const Text(
                  "Rekomendasi Langkah Selanjutnya",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 16),
                _buildRecommendationCard(
                  Icons.local_hospital_rounded,
                  "Kunjungi fasilitas kesehatan",
                  "Segera kunjungi fasilitas kesehatan untuk mendapatkan pemeriksaan dan penilaian lebih lanjut dari petugas kesehatan.",
                ),
                const SizedBox(height: 12),
                _buildRecommendationCard(
                  Icons.masks_rounded,
                  "Gunakan masker dan batasi kontak dekat",
                  "Gunakan masker dan hindari kontak dekat dengan orang lain, terutama di ruang tertutup, hingga mendapatkan pemeriksaan lebih lanjut.",
                ),
                const SizedBox(height: 12),
                _buildRecommendationCard(
                  Icons.fact_check_rounded,
                  "Ikuti anjuran petugas kesehatan",
                  "Ikuti pemeriksaan dan anjuran petugas kesehatan. Jika dinyatakan TB, jalani pengobatan sesuai petunjuk hingga selesai.",
                ),
                const SizedBox(height: 24),
              ] else ...[
                // Info for non-suspected
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.shield_outlined,
                        color: Color(0xFF10B981),
                        size: 32,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              "Tetap Jaga Kesehatan",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "Terapkan pola hidup sehat, jaga sirkulasi udara, dan perhatikan kondisi kesehatan. Jika muncul atau menetap gejala yang mengkhawatirkan, segera konsultasikan dengan petugas kesehatan.",
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],

              // Back Button
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.done_rounded, size: 18),
                  label: const Text(
                    "Selesai",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1565C0),
                    side: const BorderSide(
                      color: Color(0xFF1565C0),
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
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

  Widget _buildRecommendationCard(
    IconData icon,
    String title,
    String subtitle,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFFFFF7ED),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFFF97316), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= HEALTH LOADING SCREEN =================
  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(title: "Skrining Gejala TB", onBackPressed: null),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 44,
                height: 44,
                child: CircularProgressIndicator(
                  strokeWidth: 3.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E88E5)),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _loadingText,
                style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
