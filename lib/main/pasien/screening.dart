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
  // ignore: prefer_final_fields
  Map<int, int> _answers = {}; // question_id: answer (0 for No, 1 for Yes)
  bool _isLoading = false;
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
    setState(() => _isLoading = true);
    final session = await SharedPreferences.getInstance();
    final token = session.getString('token') ?? '';

    try {
      final response = await http.get(
        Uri.parse('${Connection.BASE_URL}/screening/categories'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          categories = data['data'];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          // ignore: use_build_context_synchronously
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal memuat kategori')));
      }
    } catch (e) {
      setState(() => _isLoading = false);
      log(e.toString());
      ScaffoldMessenger.of(
        // ignore: use_build_context_synchronously
        context,
      ).showSnackBar(SnackBar(content: Text('Terjadi kesalahan')));
    }
  }

  Future<void> _loadQuestions(int categoryId) async {
    setState(() => _isLoading = true);
    final session = await SharedPreferences.getInstance();
    final token = session.getString('token') ?? '';

    try {
      final response = await http.post(
        Uri.parse('${Connection.BASE_URL}/screening/questions'),
        headers: {'Authorization': 'Bearer $token'},
        body: {'category_id': categoryId.toString()},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          questions = data['data'];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          // ignore: use_build_context_synchronously
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal memuat pertanyaan')));
      }
    } catch (e) {
      setState(() => _isLoading = false);
      log(e.toString());
      ScaffoldMessenger.of(
        // ignore: use_build_context_synchronously
        context,
      ).showSnackBar(SnackBar(content: Text('Terjadi kesalahan')));
    }
  }

  Future<void> _submitAnswers() async {
    setState(() => _isLoading = true);
    final session = await SharedPreferences.getInstance();
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
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorResponse['message'] ?? 'Gagal mengirim jawaban'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      log('Error submitting answers: $e');
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Terjadi kesalahan saat mengirim jawaban'),
          duration: Duration(seconds: 3),
        ),
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF1565C0),
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            "Skrining TB",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF1565C0),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_showResultScreen && _result != null) {
      return _buildResultScreen();
    }

    if (_selectedCategoryId == null) {
      return _buildCategorySelection();
    }

    if (questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Skrining TB"),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => setState(() => _selectedCategoryId = null),
          ),
        ),
        body: const Center(child: Text("Tidak ada pertanyaan tersedia")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Skrining TB",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_currentStep == 0) {
              setState(() => _selectedCategoryId = null);
            } else {
              setState(() => _currentStep--);
            }
          },
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1565C0),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
        ),
      ),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep < _getAllQuestions().length - 1) {
            setState(() => _currentStep++);
          } else {
            _submitAnswers();
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() => _currentStep--);
          }
        },
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              children: [
                if (_currentStep != 0)
                  ElevatedButton(
                    onPressed: details.onStepCancel,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                    ),
                    child: const Text(
                      'Kembali',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed:
                      _answers.containsKey(
                            _getAllQuestions()[_currentStep]['question_id'],
                          )
                          ? details.onStepContinue
                          : null,
                  child: Text(
                    _currentStep == _getAllQuestions().length - 1
                        ? 'Selesai'
                        : 'Lanjut',
                  ),
                ),
              ],
            ),
          );
        },
        steps: _buildQuestionSteps(),
      ),
    );
  }

  Widget _buildCategorySelection() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Skrining TB",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1565C0),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Text(
              "Kategori Usia",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final category = categories[index];
                final int categoryId = category['id'];
                final String categoryName = category['name'];

                return Card(
                  margin: EdgeInsets.zero,
                  color: const Color(0xFF42A5F5),
                  elevation: 4,
                  // ignore: deprecated_member_use
                  shadowColor: Colors.blueAccent.withOpacity(0.25),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      setState(() {
                        _selectedCategoryId = categoryId;
                        _currentStep = 0;
                        _answers.clear();
                      });

                      _loadQuestions(categoryId);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              // ignore: deprecated_member_use
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(
                              Icons.person_rounded,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 16),

                          Expanded(
                            child: Text(
                              categoryName,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),

                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              // ignore: deprecated_member_use
                              color: Colors.white.withOpacity(0.18),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
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
      ),
    );
  }

  List<Step> _buildQuestionSteps() {
    final allQuestions = _getAllQuestions();
    return allQuestions.map((question) {
      final questionId = question['question_id'];
      final answer = _answers[questionId];

      return Step(
        title: Text("Pertanyaan ${allQuestions.indexOf(question) + 1}"),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              question['question_text'],
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _answers[questionId] = 1;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: answer == 1 ? Colors.blue : null,
                    ),
                    child: Text(
                      "Ya",
                      style: TextStyle(
                        color: answer == 1 ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _answers[questionId] = 0;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: answer == 0 ? Colors.red : null,
                    ),
                    child: Text(
                      "Tidak",
                      style: TextStyle(
                        color: answer == 0 ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        isActive: _currentStep == allQuestions.indexOf(question),
        state:
            _currentStep > allQuestions.indexOf(question)
                ? StepState.complete
                : StepState.indexed,
      );
    }).toList();
  }

  Widget _buildResultScreen() {
    final result = _result?['result'] ?? 'Tidak Diketahui';
    final isSuspected = result == 'Terduga TB';

    return Scaffold(
      appBar: AppBar(
        title: const Text("Hasil Skrining"),
        automaticallyImplyLeading: false,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              color: isSuspected ? Colors.orange[50] : Colors.green[50],
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color:
                            isSuspected
                                ? Colors.orange[100]
                                : Colors.green[100],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isSuspected
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle,
                        color:
                            isSuspected
                                ? Colors.orange[800]
                                : Colors.green[800],
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      result,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color:
                            isSuspected
                                ? Colors.orange[800]
                                : Colors.green[800],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isSuspected
                          ? "Segera konsultasi dengan petugas kesehatan"
                          : "Tetap jaga kesehatan Anda",
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (isSuspected) ...[
              const Text(
                "Apa yang harus dilakukan?",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              _buildRecommendationItem(
                Icons.local_hospital,
                "Kunjungi fasilitas kesehatan terdekat",
                "Lakukan pemeriksaan lebih lanjut untuk diagnosis pasti",
              ),
              _buildRecommendationItem(
                Icons.people,
                "Hindari kontak dekat dengan orang lain",
                "Gunakan masker untuk mencegah penularan",
              ),
              _buildRecommendationItem(
                Icons.medical_services,
                "Ikuti petunjuk petugas kesehatan",
                "Jika didiagnosis TB, jalani pengobatan dengan disiplin",
              ),
              const SizedBox(height: 16),
            ],
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Kembali', style: TextStyle(fontSize: 16)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 20,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationItem(
    IconData icon,
    String title,
    String subtitle,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.orange[800], size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
