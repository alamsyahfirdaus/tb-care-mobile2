import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:apk_tb_care/main/pasien/materi_detail.dart';
import 'package:apk_tb_care/connection.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
// ignore: depend_on_referenced_packages
import 'package:path_provider/path_provider.dart';
// ignore: depend_on_referenced_packages
import 'package:http_parser/http_parser.dart';
// ignore: unused_import
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: widget.isStaff ? 3 : 2, vsync: this);
    initNotification();
    _fetchMaterials();
  }

  Future<void> _refreshMaterials() async {
    setState(() {
      _isLoading = true;
    });

    await _fetchMaterials();

    // Optional delay agar animasi refresh terasa natural
    await Future.delayed(const Duration(milliseconds: 300));
  }

  Future<Uint8List?> fetchEducationImage(String fileName) async {
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
        debugPrint('IMAGE LOAD FAILED: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('IMAGE ERROR: $e');
      return null;
    }
  }

  Future<void> _fetchMaterials() async {
    final session = await SharedPreferences.getInstance();
    final token = session.getString('token') ?? '';

    try {
      final response = await http.get(
        Uri.parse('${Connection.BASE_URL}/education'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> dataJson = jsonDecode(response.body);

        List materials = dataJson['data'];

        await checkNewEducation(materials);

        setState(() {
          _materials = materials.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      } else {
        throw Exception("Failed to load materials");
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal memuat materi: ${e.toString()}")),
      );
    }
  }

  Future<void> _togglePublishStatus(int materialId, bool currentStatus) async {
    final session = await SharedPreferences.getInstance();
    final token = session.getString('token') ?? '';

    try {
      final response = await http.put(
        Uri.parse('${Connection.BASE_URL}/education/$materialId/publish'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status publish berhasil diubah')),
        );
        _fetchMaterials();
      } else {
        throw Exception("Failed to toggle publish status");
      }
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengubah status: ${e.toString()}')),
      );
    }
  }

  Future<void> _showAddEditMaterialDialog({
    Map<String, dynamic>? material,
  }) async {
    final isEdit = material != null;
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

    // ignore: no_leading_underscores_for_local_identifiers
    Future<void> _pickImage() async {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null) {
        setState(() {
          imageFile = File(result.files.single.path!);
          imageFileName = result.files.single.name;
        });
      }
    }

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(isEdit ? 'Edit Materi' : 'Tambah Materi'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Judul Materi',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Deskripsi',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      items: [
                        DropdownMenuItem(value: 'image', child: Text('Gambar')),
                        DropdownMenuItem(value: 'video', child: Text('Video')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedType = value!;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Jenis Materi',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 12),
                    if (selectedType == 'video')
                      TextField(
                        controller: videoUrlController,
                        decoration: InputDecoration(
                          labelText: 'URL Video Youtube',
                          hintText: 'https://www.youtube.com/watch?v=...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    if (selectedType == 'image') ...[
                      if (imageFile != null ||
                          (isEdit && material['image_url'] != null))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Icon(Icons.image, size: 16),
                              SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  imageFileName ??
                                      (material?['image_url']
                                              ?.split('/')
                                              .last ??
                                          'Gambar'),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.close, size: 16),
                                onPressed: () {
                                  setState(() {
                                    imageFile = null;
                                    imageFileName = null;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ElevatedButton.icon(
                        icon: Icon(Icons.upload_file),
                        label: Text(
                          isEdit && material['image_url'] != null
                              ? 'Ganti Gambar'
                              : 'Pilih Gambar',
                        ),
                        onPressed: _pickImage,
                      ),
                    ],
                    SizedBox(height: 12),
                    if (widget.isStaff)
                      Row(
                        children: [
                          Checkbox(
                            value: isPublish,
                            onChanged: (value) {
                              setState(() {
                                isPublish = value ?? true;
                              });
                            },
                          ),
                          Text('Publikasikan'),
                        ],
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (titleController.text.isEmpty ||
                        descriptionController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Judul dan deskripsi wajib diisi'),
                        ),
                      );
                      return;
                    }

                    if (selectedType == 'image' &&
                        imageFile == null &&
                        material?['image_url'] == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Harap pilih gambar')),
                      );
                      return;
                    }

                    if (selectedType == 'video' &&
                        videoUrlController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Harap masukkan URL video')),
                      );
                      return;
                    }

                    if (isEdit) {
                      await _updateMaterial(
                        materialId: material['id'],
                        title: titleController.text,
                        description: descriptionController.text,
                        type: selectedType,
                        imageFile: imageFile,
                        videoUrl: videoUrlController.text,
                        isPublish: isPublish,
                        currentImageUrl: material['image_url'],
                      );
                    } else {
                      await _addMaterial(
                        title: titleController.text,
                        description: descriptionController.text,
                        type: selectedType,
                        imageFile: imageFile,
                        videoUrl: videoUrlController.text,
                        isPublish: isPublish,
                      );
                    }
                    // ignore: use_build_context_synchronously
                    Navigator.pop(context);
                  },
                  child: Text(isEdit ? 'Update' : 'Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _addMaterial({
    required String title,
    required String description,
    required String type,
    File? imageFile,
    String? videoUrl,
    required bool isPublish,
  }) async {
    final session = await SharedPreferences.getInstance();
    final token = session.getString('token') ?? '';

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${Connection.BASE_URL}/education/store'),
      );

      request.headers['Authorization'] = 'Bearer $token';
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
        ScaffoldMessenger.of(
          // ignore: use_build_context_synchronously
          context,
        ).showSnackBar(SnackBar(content: Text('Materi berhasil ditambahkan')));
        _fetchMaterials();
      } else {
        throw Exception(
          'Failed to add material. Status: ${response.statusCode}, Response: $responseData',
        );
      }
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menambahkan materi: ${e.toString()}')),
      );
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
    final session = await SharedPreferences.getInstance();
    final token = session.getString('token') ?? '';

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${Connection.BASE_URL}/education/store'),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.fields['id'] = materialId.toString();
      request.fields['title_material'] = title;
      request.fields['description'] = description;
      request.fields['material_type'] = type;
      request.fields['is_publish'] = isPublish ? '1' : '0';
      request.fields['_method'] = 'PUT'; // For Laravel PUT method

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
        ScaffoldMessenger.of(
          // ignore: use_build_context_synchronously
          context,
        ).showSnackBar(SnackBar(content: Text('Materi berhasil diupdate')));
        _fetchMaterials();
      } else {
        throw Exception(
          'Failed to update material. Status: ${response.statusCode}, Response: $responseData',
        );
      }
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengupdate materi: ${e.toString()}')),
      );
    }
  }

  Future<void> _deleteMaterial(int materialId) async {
    final confirmed = await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Hapus Materi'),
            content: Text('Apakah Anda yakin ingin menghapus materi ini?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Batal'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Hapus', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    final session = await SharedPreferences.getInstance();
    final token = session.getString('token') ?? '';

    try {
      final response = await http.delete(
        Uri.parse('${Connection.BASE_URL}/education/$materialId/delete'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(
          // ignore: use_build_context_synchronously
          context,
        ).showSnackBar(SnackBar(content: Text('Materi berhasil dihapus')));
        _fetchMaterials();
      } else {
        throw Exception("Failed to delete material");
      }
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menghapus materi: ${e.toString()}')),
      );
    }
  }

  Future<void> initNotification() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        if (response.payload != null) {
          int materialId = int.parse(response.payload!);

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MateriDetailPage(materialId: materialId),
            ),
          );
        }
      },
    );
  }

  Future<void> showEducationNotification(
    String title,
    String description,
    int materialId,
  ) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'education_channel',
          'Edukasi TB Care',
          importance: Importance.max,
          priority: Priority.high,
        );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      description,
      notificationDetails,
      payload: materialId.toString(),
    );
  }

  Future<void> checkNewEducation(List materials) async {
    final prefs = await SharedPreferences.getInstance();
    String? lastSeen = prefs.getString("last_education_time");

    for (var material in materials) {
      if (material["is_publish"] == 1) {
        DateTime createdAt = DateTime.parse(material["created_at"]);

        if (lastSeen == null || createdAt.isAfter(DateTime.parse(lastSeen))) {
          await showEducationNotification(
            "Materi Edukasi Baru",
            material["title_material"],
            material["id"],
          );

          prefs.setString("last_education_time", createdAt.toIso8601String());

          break;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Materi Edukasi"),
        actions: [
          if (widget.isStaff)
            IconButton(
              icon: Icon(Icons.add),
              onPressed: () => _showAddEditMaterialDialog(),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: Icon(Icons.image)),
            Tab(icon: Icon(Icons.video_library)),
            if (widget.isStaff)
              Tab(icon: Icon(Icons.lock_clock), text: "Draft"),
          ],
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                controller: _tabController,
                children: [
                  _buildRefreshableTab(
                    _materials
                        .where(
                          (m) =>
                              m['material_type'] == "image" &&
                              (m['is_publish'] == 1 || !widget.isStaff),
                        )
                        .toList(),
                  ),
                  _buildRefreshableTab(
                    _materials
                        .where(
                          (m) =>
                              m['material_type'] == "video" &&
                              (m['is_publish'] == 1 || !widget.isStaff),
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

  Widget _buildMaterialList(
    List<Map<String, dynamic>> materials, {
    // ignore: unused_element_parameter
    bool showUnpublished = false,
  }) {
    if (materials.isEmpty) {
      return Center(
        child: Text(
          "Tidak ada materi tersedia",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(8),
      itemCount: materials.length,
      itemBuilder: (context, index) {
        final material = materials[index];
        final materialType = material['material_type'] ?? 'unknown';

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          elevation: 2,
          child: InkWell(
            onTap: () => _handleMaterialTap(material),
            onLongPress:
                widget.isStaff
                    ? () => _showAddEditMaterialDialog(material: material)
                    : null,
            borderRadius: BorderRadius.circular(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ===== IMAGE =====
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(8),
                  ),
                  child: Container(
                    height: 150,
                    color: Colors.grey[200],
                    child:
                        material['photo'] != null
                            ? FutureBuilder<Uint8List?>(
                              future: fetchEducationImage(material['photo']),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }

                                if (!snapshot.hasData) {
                                  return const Icon(
                                    Icons.broken_image,
                                    size: 50,
                                    color: Colors.grey,
                                  );
                                }

                                return Image.memory(
                                  snapshot.data!,
                                  fit: BoxFit.cover,
                                );
                              },
                            )
                            : const Icon(
                              Icons.image,
                              size: 50,
                              color: Colors.grey,
                            ),
                  ),
                ),

                // ===== CONTENT =====
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              material['title_material'] ??
                                  'Judul tidak tersedia',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (widget.isStaff)
                            Switch(
                              value: material['is_publish'] == 1,
                              onChanged:
                                  (value) => _togglePublishStatus(
                                    material['id'],
                                    material['is_publish'] == 1,
                                  ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (material['description'] != null &&
                          material['description'].isNotEmpty)
                        Text(
                          material['description'],
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            _getMaterialTypeIcon(materialType),
                            size: 16,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _getMaterialTypeText(materialType),
                            style: const TextStyle(fontSize: 12),
                          ),
                          const Spacer(),
                          Text(
                            material['created_at'] != null
                                ? DateFormat(
                                  'dd MMM yyyy',
                                ).format(DateTime.parse(material['created_at']))
                                : 'Tanggal tidak tersedia',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                if (widget.isStaff)
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: const Icon(
                        Icons.delete,
                        size: 20,
                        color: Colors.red,
                      ),
                      onPressed: () => _deleteMaterial(material['id']),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRefreshableTab(List<Map<String, dynamic>> materials) {
    return RefreshIndicator(
      onRefresh: _refreshMaterials,
      color: Colors.green,
      child: _buildMaterialList(materials),
    );
  }

  Widget _buildRefreshableDraftTab(List<Map<String, dynamic>> materials) {
    return RefreshIndicator(
      onRefresh: _refreshMaterials,
      color: Colors.green,
      child: _buildUnpublishedList(materials),
    );
  }

  Widget _buildUnpublishedList(List<Map<String, dynamic>> materials) {
    if (materials.isEmpty) {
      return Center(
        child: Text(
          "Tidak ada draft materi",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(8),
      itemCount: materials.length,
      itemBuilder: (context, index) {
        final material = materials[index];
        final materialType = material['material_type'] ?? 'unknown';
        final thumbnailUrl =
            materialType == 'image'
                ? material['image_url']
                : materialType == 'video'
                ? _getYoutubeThumbnail(material['video_url'])
                : null;

        return Card(
          margin: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          elevation: 2,
          color: Colors.grey[100],
          child: InkWell(
            onTap: () => _handleMaterialTap(material),
            onLongPress: () => _showAddEditMaterialDialog(material: material),
            borderRadius: BorderRadius.circular(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Thumbnail image with draft overlay
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(8),
                      ),
                      child: Container(
                        height: 150,
                        color: Colors.grey[200],
                        child:
                            thumbnailUrl != null
                                ? CachedNetworkImage(
                                  imageUrl: thumbnailUrl,
                                  fit: BoxFit.cover,
                                  placeholder:
                                      (context, url) => Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                  errorWidget:
                                      (context, url, error) => Icon(
                                        Icons.broken_image,
                                        size: 50,
                                        color: Colors.grey,
                                      ),
                                )
                                : Icon(
                                  Icons.image,
                                  size: 50,
                                  color: Colors.grey,
                                ),
                      ),
                    ),
                    Positioned.fill(
                      child: Container(
                        // ignore: deprecated_member_use
                        color: Colors.black.withOpacity(0.3),
                        child: Center(
                          child: Text(
                            'DRAFT',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        material['title_material'] ?? 'Judul tidak tersedia',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      if (material['description'] != null &&
                          material['description'].isNotEmpty)
                        Text(
                          material['description'],
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            _getMaterialTypeIcon(materialType),
                            size: 16,
                            color: Colors.blue,
                          ),
                          SizedBox(width: 4),
                          Text(
                            _getMaterialTypeText(materialType),
                            style: TextStyle(fontSize: 12),
                          ),
                          Spacer(),
                          Text(
                            material['created_at'] != null
                                ? DateFormat(
                                  'dd MMM yyyy',
                                ).format(DateTime.parse(material['created_at']))
                                : 'Tanggal tidak tersedia',
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ElevatedButton(
                            onPressed:
                                () =>
                                    _togglePublishStatus(material['id'], false),
                            // ignore: sort_child_properties_last
                            child: Text('Publikasikan'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: Size(120, 36),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteMaterial(material['id']),
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
      },
    );
  }

  // Helper functions
  String? _getYoutubeThumbnail(String? videoUrl) {
    if (videoUrl == null) return null;

    try {
      final uri = Uri.parse(videoUrl);

      // Format 1: https://www.youtube.com/watch?v=VIDEO_ID
      if (uri.host.contains('youtube.com') &&
          uri.queryParameters.containsKey('v')) {
        return 'https://img.youtube.com/vi/${uri.queryParameters['v']}/0.jpg';
      }

      // Format 2: https://youtu.be/VIDEO_ID
      if (uri.host.contains('youtu.be')) {
        final videoId =
            uri.pathSegments.isNotEmpty ? uri.pathSegments[0] : null;
        if (videoId != null) {
          return 'https://img.youtube.com/vi/$videoId/0.jpg';
        }
      }
    } catch (e) {
      // Optional: print(e);
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
        // Format URL untuk autoplay di YouTube app
        String youtubeAppUrl = "vnd.youtube:$youtubeId";
        String youtubeWebUrl =
            "https://www.youtube.com/watch?v=$youtubeId&autoplay=1";

        try {
          // Coba buka di YouTube app dulu
          if (await canLaunchUrl(Uri.parse(youtubeAppUrl))) {
            await launchUrl(
              Uri.parse(youtubeAppUrl),
              mode: LaunchMode.externalApplication,
            );
          }
          // Jika YouTube app tidak ada, buka di browser dengan autoplay
          else if (await canLaunchUrl(Uri.parse(youtubeWebUrl))) {
            await launchUrl(
              Uri.parse(youtubeWebUrl),
              mode: LaunchMode.externalApplication,
            );
          } else {
            // Fallback terakhir
            await launchUrl(
              Uri.parse(youtubeWebUrl),
              mode: LaunchMode.inAppWebView,
            );
          }
        } catch (e) {
          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Gagal membuka video: ${e.toString()}")),
          );
        }
      } else {
        // Bukan URL YouTube, gunakan cara biasa
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

  // Fungsi ekstrak YouTube ID yang lebih robust
  String extractYoutubeId(String url) {
    RegExp regExp = RegExp(
      r'(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})',
      caseSensitive: false,
    );
    Match? match = regExp.firstMatch(url);
    return match?.group(1) ?? '';
  }
}
