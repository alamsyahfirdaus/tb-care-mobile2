import 'dart:convert';
// ignore: unnecessary_import
import 'dart:typed_data';
import 'package:apk_tb_care/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class MateriDetailPage extends StatefulWidget {
  final int materialId;

  const MateriDetailPage({super.key, required this.materialId});

  @override
  State<MateriDetailPage> createState() => _MateriDetailPageState();
}

class _MateriDetailPageState extends State<MateriDetailPage> {
  late Map<String, dynamic> material = {};
  bool isLoading = true;
  bool isError = false;

  @override
  void initState() {
    super.initState();
    _fetchMaterialDetail();
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

  Future<void> _fetchMaterialDetail() async {
    final session = await SharedPreferences.getInstance();
    final token = session.getString('token') ?? '';

    try {
      final response = await http.get(
        Uri.parse('${Connection.BASE_URL}/education/${widget.materialId}/show'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> dataJson = jsonDecode(response.body);
        setState(() {
          material = dataJson['data'] ?? {};
          isLoading = false;
        });
      } else {
        throw Exception("Failed to load material details");
      }
    } catch (e) {
      setState(() {
        isError = true;
        isLoading = false;
      });
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to load material details")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (isError || material.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text("Detail Materi")),
        body: const Center(child: Text("Gagal memuat detail materi")),
      );
    }

    final materialType = material['material_type'];

    return Scaffold(
      appBar: AppBar(
        title: Text(material['title_material'] ?? 'Detail Materi'),
        // actions: [
        //   IconButton(
        //     icon: const Icon(Icons.share),
        //     onPressed: () => _shareMaterial(context),
        //   ),
        // ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================= MEDIA PREVIEW =================
            if (materialType == 'image' && material['photo'] != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 220,
                  color: Colors.grey[200],
                  child: FutureBuilder<Uint8List?>(
                    future: fetchEducationImage(material['photo']),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (!snapshot.hasData) {
                        return const Icon(Icons.broken_image, size: 60);
                      }

                      return Image.memory(
                        snapshot.data!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      );
                    },
                  ),
                ),
              ),

            if (materialType == 'video' && material['video_url'] != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CachedNetworkImage(
                      imageUrl:
                          _getYoutubeThumbnail(material['video_url']) ?? '',
                      height: 220,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorWidget:
                          (_, __, ___) => Container(
                            height: 220,
                            color: Colors.grey[300],
                            child: const Icon(Icons.video_library, size: 60),
                          ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        // ignore: deprecated_member_use
                        color: Colors.black.withOpacity(0.4),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.play_arrow,
                          size: 50,
                          color: Colors.white,
                        ),
                        onPressed: () => _openVideo(material['video_url']),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Text(
              material['title_material'] ?? 'Judul tidak tersedia',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Diunggah pada: ${_formatCreatedAt(material['created_at'])}",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            if (material['description'] != null &&
                material['description'].isNotEmpty)
              SelectableLinkify(
                text: material['description'],
                style: const TextStyle(fontSize: 16),
                linkStyle: const TextStyle(
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
                onOpen: (link) async {
                  final uri = Uri.parse(link.url);

                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } else {
                    // ignore: use_build_context_synchronously
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Tidak dapat membuka link")),
                    );
                  }
                },
              ),
            const SizedBox(height: 24),
            if (materialType == 'video' && material['video_url'] != null)
              ElevatedButton.icon(
                onPressed: () => _openVideo(material['video_url']),
                icon: const Icon(Icons.play_arrow),
                label: const Text("Tonton Video"),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            if (materialType == 'image' && material['photo'] != null)
              ElevatedButton.icon(
                onPressed: () => _viewFullImage(material['photo']),
                icon: const Icon(Icons.fullscreen),
                label: const Text("Lihat Gambar Penuh"),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatCreatedAt(String? createdAt) {
    if (createdAt == null) return 'Tanggal tidak tersedia';
    try {
      final dateTime = DateTime.parse(createdAt);
      return DateFormat('dd MMMM yyyy').format(dateTime);
    } catch (e) {
      return 'Tanggal tidak valid';
    }
  }

  String? _getYoutubeThumbnail(String? videoUrl) {
    if (videoUrl == null) return null;

    try {
      final uri = Uri.parse(videoUrl);

      if (uri.host.contains('youtube.com') &&
          uri.queryParameters.containsKey('v')) {
        return 'https://img.youtube.com/vi/${uri.queryParameters['v']}/0.jpg';
      }

      if (uri.host.contains('youtu.be')) {
        final videoId =
            uri.pathSegments.isNotEmpty ? uri.pathSegments[0] : null;

        if (videoId != null) {
          return 'https://img.youtube.com/vi/$videoId/0.jpg';
        }
      }
      // ignore: empty_catches
    } catch (e) {}

    return null;
  }

  // ignore: unused_element
  void _shareMaterial(BuildContext context) {
    if (material.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Materi belum siap untuk dibagikan')),
      );
      return;
    }

    final String title = material['title_material'] ?? 'Materi Edukasi TB Care';
    final String description = material['description'] ?? '';
    final String type = material['material_type'] ?? '';

    String shareText = title;

    if (description.isNotEmpty) {
      shareText += '\n\n$description';
    }

    if (type == 'video' && material['video_url'] != null) {
      shareText += '\n\nTonton video:\n${material['video_url']}';
    }

    shareText += '\n\nDibagikan dari Aplikasi TB Care';

    try {
      // ignore: deprecated_member_use
      Share.share(shareText, subject: title);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal membagikan materi: $e')));
    }
  }

  void _openVideo(String videoUrl) async {
    try {
      final Uri url = Uri.parse(videoUrl);

      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw Exception("Cannot launch video");
      }
    } catch (e) {
      ScaffoldMessenger.of(
        // ignore: use_build_context_synchronously
        context,
      ).showSnackBar(const SnackBar(content: Text('Gagal membuka video')));
    }
  }

  void _viewFullImage(String photo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => Scaffold(
              appBar: AppBar(),
              body: Center(
                child: FutureBuilder<Uint8List?>(
                  future: fetchEducationImage(photo),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const CircularProgressIndicator();
                    }

                    if (!snapshot.hasData) {
                      return const Icon(Icons.broken_image, size: 60);
                    }

                    return InteractiveViewer(
                      child: Image.memory(snapshot.data!),
                    );
                  },
                ),
              ),
            ),
      ),
    );
  }
}
