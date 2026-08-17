import 'dart:convert';
import 'dart:io';
import 'package:apk_tb_care/main/pasien/materi_detail.dart';
import 'package:apk_tb_care/connection.dart';
import 'package:apk_tb_care/values/colors.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:http_parser/http_parser.dart';
import 'package:google_fonts/google_fonts.dart';

class EducationPage extends StatefulWidget {
  final bool isStaff;

  const EducationPage({super.key, this.isStaff = false});

  @override
  State<EducationPage> createState() => _EducationPageState();
}

class _EducationPageState extends State<EducationPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _materials = [];
  bool _isLoading = true;
  bool _isError = false;
  String _token = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: widget.isStaff ? 3 : 2, vsync: this);
    _loadTokenAndFetch();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTokenAndFetch() async {
    final session = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _token = session.getString('token') ?? '';
      });
    }
    await _fetchMaterials();
  }

  Future<void> _refreshMaterials() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _isError = false;
      });
    }
    await _fetchMaterials();
    await Future.delayed(const Duration(milliseconds: 300));
  }

  Future<void> _fetchMaterials() async {
    try {
      final response = await http.get(
        Uri.parse('${Connection.BASE_URL}/education'),
        headers: {'Authorization': 'Bearer $_token'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> dataJson = jsonDecode(response.body);
        List materials = dataJson['data'] ?? [];

        if (mounted) {
          setState(() {
            _materials = materials.cast<Map<String, dynamic>>();
            _isLoading = false;
            _isError = false;
          });
        }
      } else {
        throw Exception("Failed to load materials");
      }
    } catch (e) {
      debugPrint("FETCH MATERIALS ERROR: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isError = true;
        });
      }
    }
  }

  Future<void> _togglePublishStatus(int materialId, bool currentStatus) async {
    try {
      final response = await http.put(
        Uri.parse('${Connection.BASE_URL}/education/$materialId/publish'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Status publish berhasil diubah')),
          );
        }
        _fetchMaterials();
      } else {
        throw Exception("Failed to toggle publish status");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengubah status: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _addMaterial({
    required String title,
    required String description,
    required String type,
    File? imageFile,
    String? videoUrl,
    required bool isPublish,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${Connection.BASE_URL}/education/store'),
      );

      request.headers['Authorization'] = 'Bearer $_token';
      request.fields['title_material'] = title;
      request.fields['description'] = description;
      request.fields['material_type'] = type;
      request.fields['is_publish'] = isPublish ? '1' : '0';

      if (type == 'video') {
        request.fields['video_url'] = videoUrl!;
      } else if (imageFile != null) {
        final fixedImage = await _convertToJpeg(imageFile);
        final bytes = await fixedImage.readAsBytes();

        request.files.add(
          http.MultipartFile.fromBytes(
            'image_file',
            bytes,
            filename: fixedImage.path.split('/').last,
            contentType: MediaType('image', 'jpeg'),
          ),
        );
      }

      final response = await request.send();
      final responseData = await response.stream.bytesToString();

      if (response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Materi berhasil ditambahkan')),
          );
        }
        _fetchMaterials();
      } else {
        throw Exception(
          'Failed to add material. Status: ${response.statusCode}, Response: $responseData',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menambahkan materi: ${e.toString()}')),
        );
      }
      rethrow;
    }
  }

  Future<File> _convertToJpeg(File originalFile) async {
    final bytes = await originalFile.readAsBytes();
    final decodedImage = img.decodeImage(bytes);

    if (decodedImage == null) {
      throw Exception('Gagal memproses gambar');
    }

    final jpegBytes = img.encodeJpg(decodedImage, quality: 85);
    final tempDir = await getTemporaryDirectory();

    final fixedFile = File(
      '${tempDir.path}/edu_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );

    await fixedFile.writeAsBytes(jpegBytes);
    return fixedFile;
  }

  Future<void> _updateMaterial({
    required int materialId,
    required String title,
    required String description,
    required String type,
    File? imageFile,
    String? videoUrl,
    required bool isPublish,
    String? currentImageUrl,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${Connection.BASE_URL}/education/store'),
      );

      request.headers['Authorization'] = 'Bearer $_token';
      request.fields['id'] = materialId.toString();
      request.fields['title_material'] = title;
      request.fields['description'] = description;
      request.fields['material_type'] = type;
      request.fields['is_publish'] = isPublish ? '1' : '0';
      request.fields['_method'] = 'PUT';

      if (type == 'video') {
        request.fields['video_url'] = videoUrl!;
      } else if (imageFile != null) {
        final fixedImage = await _convertToJpeg(imageFile);
        final bytes = await fixedImage.readAsBytes();

        request.files.add(
          http.MultipartFile.fromBytes(
            'image_file',
            bytes,
            filename: fixedImage.path.split('/').last,
            contentType: MediaType('image', 'jpeg'),
          ),
        );
      } else if (currentImageUrl != null) {
        request.fields['current_image_url'] = currentImageUrl;
      }

      final response = await request.send();
      final responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Materi berhasil diperbarui')),
          );
        }
        _fetchMaterials();
      } else {
        throw Exception(
          'Failed to update material. Status: ${response.statusCode}, Response: $responseData',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengupdate materi: ${e.toString()}')),
        );
      }
      rethrow;
    }
  }

  Future<void> _deleteMaterial(int materialId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Hapus Materi',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
            ),
            content: Text(
              'Apakah Anda yakin ingin menghapus materi ini?',
              style: GoogleFonts.plusJakartaSans(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Batal',
                  style: GoogleFonts.plusJakartaSans(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Hapus',
                  style: GoogleFonts.plusJakartaSans(color: Colors.white),
                ),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    try {
      final response = await http.delete(
        Uri.parse('${Connection.BASE_URL}/education/$materialId/delete'),
        headers: {'Authorization': 'Bearer $_token'},
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Materi berhasil dihapus')),
          );
        }
        _fetchMaterials();
      } else {
        throw Exception("Failed to delete material");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghapus materi: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _showAddEditMaterialDialog({
    Map<String, dynamic>? material,
  }) async {
    final isEdit = material != null;
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController(
      text: material?['title_material'],
    );
    final descriptionController = TextEditingController(
      text: material?['description'],
    );
    final videoUrlController = TextEditingController(
      text: material?['video_url'],
    );
    File? imageFile;
    String? imageFileName;
    String selectedType = material?['material_type'] ?? 'image';
    bool isPublish = material?['is_publish'] == 1 || !isEdit;
    bool isDialogSaving = false;

    Future<void> pickImage(StateSetter dialogSetState) async {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        dialogSetState(() {
          imageFile = File(result.files.single.path!);
          imageFileName = result.files.single.name;
        });
      }
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                isEdit ? 'Edit Materi Edukasi' : 'Tambah Materi Edukasi',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: titleController,
                        style: GoogleFonts.plusJakartaSans(fontSize: 14),
                        decoration: InputDecoration(
                          labelText: 'Judul Materi',
                          labelStyle: GoogleFonts.plusJakartaSans(fontSize: 14),
                          hintText: 'Masukkan judul materi',
                          hintStyle: GoogleFonts.plusJakartaSans(fontSize: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Judul materi tidak boleh kosong';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: descriptionController,
                        maxLines: 4,
                        style: GoogleFonts.plusJakartaSans(fontSize: 14),
                        decoration: InputDecoration(
                          labelText: 'Deskripsi',
                          labelStyle: GoogleFonts.plusJakartaSans(fontSize: 14),
                          hintText: 'Masukkan deskripsi materi',
                          hintStyle: GoogleFonts.plusJakartaSans(fontSize: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Deskripsi tidak boleh kosong';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: selectedType,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Jenis Materi',
                          labelStyle: GoogleFonts.plusJakartaSans(fontSize: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'image',
                            child: Text(
                              'Gambar',
                              style: GoogleFonts.plusJakartaSans(fontSize: 14),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'video',
                            child: Text(
                              'Video',
                              style: GoogleFonts.plusJakartaSans(fontSize: 14),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            dialogSetState(() {
                              selectedType = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      if (selectedType == 'video') ...[
                        TextFormField(
                          controller: videoUrlController,
                          style: GoogleFonts.plusJakartaSans(fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'URL Video YouTube',
                            labelStyle: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                            ),
                            hintText: 'https://www.youtube.com/watch?v=...',
                            hintStyle: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            if (selectedType == 'video') {
                              if (value == null || value.trim().isEmpty) {
                                return 'URL video tidak boleh kosong';
                              }
                              final id = extractYoutubeId(value.trim());
                              if (id.isEmpty) {
                                return 'Masukkan URL YouTube yang valid';
                              }
                            }
                            return null;
                          },
                        ),
                      ] else ...[
                        if (imageFile != null ||
                            (isEdit && material['photo'] != null))
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.image, color: Colors.blue),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    imageFileName ??
                                        (material?['photo'] ?? 'gambar.jpg'),
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    color: Colors.grey,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    dialogSetState(() {
                                      imageFile = null;
                                      imageFileName = null;
                                      if (material != null) {
                                        material['photo'] = null;
                                      }
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => pickImage(dialogSetState),
                          icon: const Icon(Icons.cloud_upload_outlined),
                          label: Text(
                            imageFile != null ||
                                    (isEdit && material['photo'] != null)
                                ? 'Ubah Gambar'
                                : 'Pilih Gambar',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        if (selectedType == 'image' &&
                            imageFile == null &&
                            (material == null || material['photo'] == null))
                          Padding(
                            padding: const EdgeInsets.only(top: 8, left: 12),
                            child: Text(
                              'Pilih file gambar terlebih dahulu',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.redAccent,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Checkbox(
                            value: isPublish,
                            activeColor: Colors.blue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            onChanged: (value) {
                              dialogSetState(() {
                                isPublish = value ?? true;
                              });
                            },
                          ),
                          Text(
                            'Publikasikan langsung',
                            style: GoogleFonts.plusJakartaSans(fontSize: 14),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      isDialogSaving ? null : () => Navigator.pop(context),
                  child: Text(
                    'Batal',
                    style: GoogleFonts.plusJakartaSans(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed:
                      isDialogSaving
                          ? null
                          : () async {
                            if (!formKey.currentState!.validate()) return;

                            if (selectedType == 'image' &&
                                imageFile == null &&
                                (material == null ||
                                    material['photo'] == null)) {
                              return;
                            }

                            dialogSetState(() {
                              isDialogSaving = true;
                            });

                            try {
                              if (isEdit) {
                                await _updateMaterial(
                                  materialId: material['id'],
                                  title: titleController.text.trim(),
                                  description:
                                      descriptionController.text.trim(),
                                  type: selectedType,
                                  imageFile: imageFile,
                                  videoUrl: videoUrlController.text.trim(),
                                  isPublish: isPublish,
                                  currentImageUrl: material['photo'],
                                );
                              } else {
                                await _addMaterial(
                                  title: titleController.text.trim(),
                                  description:
                                      descriptionController.text.trim(),
                                  type: selectedType,
                                  imageFile: imageFile,
                                  videoUrl: videoUrlController.text.trim(),
                                  isPublish: isPublish,
                                );
                              }
                              if (context.mounted) {
                                Navigator.pop(context);
                              }
                            } catch (e) {
                              dialogSetState(() {
                                isDialogSaving = false;
                              });
                            }
                          },
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child:
                      isDialogSaving
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : Text(
                            isEdit ? 'Simpan' : 'Tambah',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          "Materi Edukasi",
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (widget.isStaff)
            IconButton(
              icon: const Icon(
                Icons.add_circle_outline_rounded,
                color: Colors.blue,
                size: 28,
              ),
              onPressed: () => _showAddEditMaterialDialog(),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(72),
          child: Container(
            width: double.infinity,
            color: const Color(0xFFF5F7FA),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.blue,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.blue,
              indicatorWeight: 3,
              labelStyle: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontSize: 14),
              tabs: [
                const Tab(icon: Icon(Icons.image_outlined), text: "Gambar"),
                const Tab(
                  icon: Icon(Icons.video_library_outlined),
                  text: "Video",
                ),
                if (widget.isStaff)
                  const Tab(icon: Icon(Icons.lock_outline), text: "Draft"),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRefreshableTab(
            _materials
                .where(
                  (m) => m['material_type'] == "image" && m['is_publish'] == 1,
                )
                .toList(),
          ),
          _buildRefreshableTab(
            _materials
                .where(
                  (m) => m['material_type'] == "video" && m['is_publish'] == 1,
                )
                .toList(),
          ),
          if (widget.isStaff)
            _buildRefreshableDraftTab(
              _materials.where((m) => m['is_publish'] != 1).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildRefreshableTab(List<Map<String, dynamic>> materials) {
    return RefreshIndicator(
      onRefresh: _refreshMaterials,
      color: Colors.blue,
      child: _buildMaterialList(materials),
    );
  }

  Widget _buildRefreshableDraftTab(List<Map<String, dynamic>> materials) {
    return RefreshIndicator(
      onRefresh: _refreshMaterials,
      color: Colors.blue,
      child: _buildMaterialList(materials),
    );
  }

  Widget _buildMaterialList(List<Map<String, dynamic>> materials) {
    if (_isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: 3,
        itemBuilder: (context, index) => _buildSkeletonCard(),
      );
    }

    if (_isError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: Colors.red[300],
              ),
              const SizedBox(height: 16),
              Text(
                'Gagal memuat materi',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Silakan periksa koneksi Anda dan coba lagi.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(color: Colors.grey),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _refreshMaterials,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(
                  'Coba Lagi',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (materials.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.menu_book_outlined, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                'Belum ada materi edukasi',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.isStaff
                    ? 'Ketuk tombol "+" di kanan atas untuk menambahkan materi.'
                    : 'Materi edukasi akan muncul di sini setelah dipublikasikan.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: materials.length,
      itemBuilder: (context, index) {
        return _buildMaterialCard(materials[index]);
      },
    );
  }

  Widget _buildSkeletonCard() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: Colors.grey[50],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(color: Colors.grey[200]),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 16, width: 200, color: Colors.grey[200]),
                const SizedBox(height: 8),
                Container(
                  height: 12,
                  width: double.infinity,
                  color: Colors.grey[200],
                ),
                const SizedBox(height: 4),
                Container(height: 12, width: 150, color: Colors.grey[200]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialCard(Map<String, dynamic> material) {
    final materialType = material['material_type'] ?? 'unknown';
    final isDraft = material['is_publish'] != 1;
    final title = material['title_material'] ?? 'Judul tidak tersedia';
    final description = material['description'] ?? '';
    final createdAt = material['created_at'];

    String formattedDate = 'Tanggal tidak tersedia';
    if (createdAt != null) {
      try {
        final date = DateTime.parse(createdAt);
        formattedDate = DateFormat('dd MMMM yyyy', 'id_ID').format(date);
      } catch (e) {
        // ignore
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      clipBehavior: Clip.antiAlias,
      color: Colors.white,
      child: InkWell(
        onTap: () => _handleMaterialTap(material),
        onLongPress:
            widget.isStaff
                ? () => _showAddEditMaterialDialog(material: material)
                : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildCardMedia(material),
                  if (isDraft)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.5),
                        child: const Center(
                          child: Text(
                            'DRAFT',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getMaterialTypeIcon(materialType),
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _getMaterialTypeText(materialType),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            height: 1.3,
                          ),
                        ),
                      ),
                      if (widget.isStaff) ...[
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              isDraft ? 'Draft' : 'Publish',
                              style: TextStyle(
                                fontSize: 10,
                                color: isDraft ? Colors.orange : Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Transform.scale(
                              scale: 0.8,
                              child: Switch(
                                value: !isDraft,
                                // ignore: deprecated_member_use
                                activeColor: Colors.green,
                                onChanged:
                                    (value) => _togglePublishStatus(
                                      material['id'],
                                      !isDraft,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (description.isNotEmpty)
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        height: 1.4,
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        formattedDate,
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                      if (widget.isStaff)
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.redAccent,
                            size: 20,
                          ),
                          onPressed: () => _deleteMaterial(material['id']),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardMedia(Map<String, dynamic> material) {
    final materialType = material['material_type'] ?? 'unknown';

    if (materialType == 'image') {
      final photo = material['photo'];
      if (photo != null && photo.isNotEmpty) {
        return CachedNetworkImage(
          imageUrl: '${Connection.BASE_URL}/image/$photo',
          httpHeaders: {'Authorization': 'Bearer $_token'},
          fit: BoxFit.cover,
          placeholder:
              (context, url) => Container(
                color: Colors.grey[100],
                child: const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
          errorWidget:
              (context, url, error) => Container(
                color: Colors.grey[100],
                child: Icon(
                  Icons.broken_image_outlined,
                  color: Colors.grey[400],
                  size: 40,
                ),
              ),
        );
      } else {
        return Container(
          color: Colors.grey[100],
          child: Icon(Icons.image_outlined, color: Colors.grey[400], size: 40),
        );
      }
    } else if (materialType == 'video') {
      final videoUrl = material['video_url'];
      final thumbnailUrl = _getYoutubeThumbnail(videoUrl);

      return Stack(
        fit: StackFit.expand,
        children: [
          if (thumbnailUrl != null)
            CachedNetworkImage(
              imageUrl: thumbnailUrl,
              fit: BoxFit.cover,
              placeholder:
                  (context, url) => Container(
                    color: Colors.grey[100],
                    child: const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
              errorWidget:
                  (context, url, error) => Container(
                    color: Colors.grey[100],
                    child: Icon(
                      Icons.video_library_outlined,
                      color: Colors.grey[400],
                      size: 40,
                    ),
                  ),
            )
          else
            Container(
              color: Colors.grey[100],
              child: Icon(
                Icons.video_library_outlined,
                color: Colors.grey[400],
                size: 40,
              ),
            ),
          Center(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      color: Colors.grey[100],
      child: Icon(
        Icons.insert_drive_file_outlined,
        color: Colors.grey[400],
        size: 40,
      ),
    );
  }

  String? _getYoutubeThumbnail(String? videoUrl) {
    if (videoUrl == null) return null;

    try {
      final videoId = extractYoutubeId(videoUrl);
      if (videoId.isNotEmpty) {
        return 'https://img.youtube.com/vi/$videoId/0.jpg';
      }
    } catch (e) {
      // ignore
    }

    return null;
  }

  IconData _getMaterialTypeIcon(String type) {
    switch (type) {
      case 'video':
        return Icons.video_library;
      case 'image':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _getMaterialTypeText(String type) {
    switch (type) {
      case 'video':
        return 'Video';
      case 'image':
        return 'Gambar';
      default:
        return 'File';
    }
  }

  void _handleMaterialTap(Map<String, dynamic> material) async {
    if (material['is_publish'] != 1 && !widget.isStaff) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Materi ini belum dipublikasikan')),
      );
      return;
    }

    if (material['material_type'] == "video") {
      String videoUrl = material['video_url'];
      String youtubeId = extractYoutubeId(videoUrl);

      if (youtubeId.isNotEmpty) {
        String youtubeAppUrl = "vnd.youtube:$youtubeId";
        String youtubeWebUrl = "https://www.youtube.com/watch?v=$youtubeId";

        try {
          if (await canLaunchUrl(Uri.parse(youtubeAppUrl))) {
            await launchUrl(
              Uri.parse(youtubeAppUrl),
              mode: LaunchMode.externalApplication,
            );
          } else if (await canLaunchUrl(Uri.parse(youtubeWebUrl))) {
            await launchUrl(
              Uri.parse(youtubeWebUrl),
              mode: LaunchMode.externalApplication,
            );
          } else {
            await launchUrl(
              Uri.parse(youtubeWebUrl),
              mode: LaunchMode.inAppWebView,
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Gagal membuka video: ${e.toString()}")),
            );
          }
        }
      } else {
        final Uri videoUri = Uri.parse(videoUrl);
        if (await canLaunchUrl(videoUri)) {
          await launchUrl(videoUri, mode: LaunchMode.externalApplication);
        }
      }
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MateriDetailPage(materialId: material['id']),
        ),
      );
    }
  }

  String extractYoutubeId(String url) {
    RegExp regExp = RegExp(
      r'(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})',
      caseSensitive: false,
    );
    Match? match = regExp.firstMatch(url);
    return match?.group(1) ?? '';
  }
}
