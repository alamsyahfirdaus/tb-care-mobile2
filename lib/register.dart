import 'dart:async';
import 'dart:convert';

import 'package:apk_tb_care/connection.dart';
import 'package:apk_tb_care/main/login.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final nama = TextEditingController();
  final hp = TextEditingController();
  final puskesmasController = TextEditingController();

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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Koneksi timeout.")));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
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
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        elevation: 0,
        title: const Text("Registrasi"),
        bottom: TabBar(
          controller: _tabController,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.person), text: "Pasien"),
            Tab(icon: Icon(Icons.medical_services), text: "Petugas"),
          ],
        ),
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                controller: _tabController,
                children: [
                  PatientRegisterTab(puskesmasList: puskesmasList),
                  OfficerRegisterTab(puskesmasList: puskesmasList),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text("Registrasi Berhasil"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Silakan simpan informasi akun berikut untuk login:"),

            const SizedBox(height: 20),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Username",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    username,
                    style: const TextStyle(fontSize: 16),
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    "Password",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    password,
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            },
            child: const Text("OK"),
          ),
        ],
      );
    },
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

        nama.clear();
        hp.clear();
        puskesmasController.clear();

        _formKey.currentState?.reset();

        setState(() {
          gender = null;
          puskesmas = null;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result["message"] ?? "Registrasi gagal."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Terjadi kesalahan.\n$e"),
          backgroundColor: Colors.red,
        ),
      );
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
      padding: const EdgeInsets.all(20),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const Text(
                  "Registrasi Pasien",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 30),

                TextFormField(
                  controller: nama,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: "Nama Lengkap",
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
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
                  decoration: const InputDecoration(
                    labelText: "Nomor HP",
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
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
                  initialValue: gender,
                  decoration: const InputDecoration(
                    labelText: "Jenis Kelamin",
                    prefixIcon: Icon(Icons.people),
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: "L", child: Text("Laki-laki")),
                    DropdownMenuItem(value: "P", child: Text("Perempuan")),
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

                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed:
                        isSubmitting
                            ? null
                            : () async {
                              await registerPatient();
                            },
                    child:
                        isSubmitting
                            ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                            : const Text(
                              "Register",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
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

        nama.clear();
        hp.clear();
        puskesmasController.clear();

        _formKey.currentState?.reset();

        setState(() {
          gender = null;
          puskesmas = null;
          jenisPetugas = null;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result["message"] ?? "Registrasi gagal."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Terjadi kesalahan.\n$e"),
          backgroundColor: Colors.red,
        ),
      );
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
      padding: const EdgeInsets.all(20),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const Text(
                  "Registrasi Petugas",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 30),

                TextFormField(
                  controller: nama,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: "Nama Lengkap",
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
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
                  decoration: const InputDecoration(
                    labelText: "Nomor HP",
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
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
                  initialValue: gender,
                  decoration: const InputDecoration(
                    labelText: "Jenis Kelamin",
                    prefixIcon: Icon(Icons.people),
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: "L", child: Text("Laki-laki")),
                    DropdownMenuItem(value: "P", child: Text("Perempuan")),
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
                  initialValue: jenisPetugas,
                  decoration: const InputDecoration(
                    labelText: "Jenis Petugas",
                    prefixIcon: Icon(Icons.badge),
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: "3", child: Text("PJTB")),
                    DropdownMenuItem(value: "4", child: Text("Kader")),
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

                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: isSubmitting ? null : registerOfficer,
                    child:
                        isSubmitting
                            ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                            : const Text(
                              "Register",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
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

    fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
      if (selectedValue != null && controller.text.isEmpty) {
        final index = puskesmasList.indexWhere(
          (e) => e["id"].toString() == selectedValue,
        );

        if (index != -1) {
          controller.text = puskesmasList[index]["name"];
        }
      }

      return TextFormField(
        controller: textController,
        focusNode: focusNode,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        decoration: const InputDecoration(
          labelText: "Puskesmas",
          hintText: "Cari Puskesmas...",
          prefixIcon: Icon(Icons.local_hospital),
          border: OutlineInputBorder(),
        ),
        validator: (_) {
          if (selectedValue == null) {
            return "Pilih puskesmas";
          }
          return null;
        },
      );
    },

    optionsViewBuilder: (context, onSelected, options) {
      return Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 5,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 250),
            child: SizedBox(
              width: MediaQuery.of(context).size.width - 40,
              child:
                  options.isEmpty
                      ? const ListTile(title: Text("Puskesmas tidak ditemukan"))
                      : ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (context, index) {
                          final item = options.elementAt(index);

                          return ListTile(
                            leading: const Icon(Icons.local_hospital),
                            title: Text(item["name"]),
                            onTap: () => onSelected(item),
                          );
                        },
                      ),
            ),
          ),
        ),
      );
    },
  );
}
