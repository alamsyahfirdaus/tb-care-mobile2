import 'dart:convert';
import 'package:apk_tb_care/connection.dart';
import 'package:apk_tb_care/values/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';

class MateriDetailPage extends StatefulWidget {
  final int materialId;

  const MateriDetailPage({super.key, required this.materialId});

  @override
  State<MateriDetailPage> createState() => _MateriDetailPageState();
}

class _MateriDetailPageState extends State<MateriDetailPage> {
  Map<String, dynamic> material = {};
  bool isLoading = true;
  bool isError = false;
  String _token = '';

  @override
  void initState() {
    super.initState();
    _loadTokenAndFetch();
  }

  Future<void> _loadTokenAndFetch() async {
    final session = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _token = session.getString('token') ?? '';
      });
    }
    await _fetchMaterialDetail();
  }

  Future<void> _fetchMaterialDetail() async {
    try {
      final response = await http.get(
        Uri.parse('${Connection.BASE_URL}/education/${widget.materialId}/show'),
        headers: {'Authorization': 'Bearer $_token'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> dataJson = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            material = dataJson['data'] ?? {};
            isLoading = false;
            isError = false;
          });
        }
      } else {
        throw Exception("Failed to load material details");
      }
    } catch (e) {
      debugPrint("FETCH DETAIL ERROR: $e");
      if (mounted) {
        setState(() {
          isError = true;
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Gagal memuat detail materi")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.blue)),
      );
    }

    if (isError || material.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            "Detail Materi",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          elevation: 0.5,
          backgroundColor: AppColors.primary,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
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
                  "Gagal Memuat Detail",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Materi mungkin telah dihapus oleh admin atau terjadi masalah koneksi.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: Text(
                    "Kembali",
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final materialType = material['material_type'];
    final title = material['title_material'] ?? 'Materi Edukasi';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "Detail Edukasi",
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.white),
        // actions: [
        //   IconButton(
        //     icon: const Icon(Icons.share_outlined, color: Colors.white),
        //     onPressed: () => _shareMaterial(context),
        //   ),
        // ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ================= MEDIA HEADER =================
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    color: Colors.grey[100],
                    child: _buildMediaHeader(materialType),
                  ),
                ),
              ),
            ),

            // ================= CONTENT BODY =================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 14,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatCreatedAt(material['created_at']),
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          materialType == 'video' ? 'Video' : 'Gambar',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.blue[700],
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32, thickness: 1),

                  // Description
                  if (material['description'] != null &&
                      material['description'].isNotEmpty)
                    SelectableLinkify(
                      text: material['description'],
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        height: 1.6,
                        color: Colors.black87, // Clean dark grey
                      ),
                      linkStyle: GoogleFonts.plusJakartaSans(
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                      onOpen: (link) async {
                        final uri = Uri.parse(link.url);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Tidak dapat membuka link"),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  const SizedBox(height: 32),

                  // Bottom Action Buttons
                  if (materialType == 'video' && material['video_url'] != null)
                    ElevatedButton.icon(
                      onPressed: () => _openVideo(material['video_url']),
                      icon: const Icon(
                        Icons.play_circle_outline_rounded,
                        size: 24,
                        color: Colors.white,
                      ),
                      label: Text(
                        "Tonton Video Sekarang",
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  if (materialType == 'image' && material['photo'] != null)
                    ElevatedButton.icon(
                      onPressed: () => _viewFullImage(material['photo']),
                      icon: const Icon(
                        Icons.fullscreen_rounded,
                        size: 24,
                        color: Colors.white,
                      ),
                      label: Text(
                        "Lihat Gambar Penuh",
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaHeader(String? materialType) {
    if (materialType == 'image' && material['photo'] != null) {
      return CachedNetworkImage(
        imageUrl: '${Connection.BASE_URL}/image/${material['photo']}',
        httpHeaders: {'Authorization': 'Bearer $_token'},
        fit: BoxFit.cover,
        width: double.infinity,
        placeholder:
            (context, url) =>
                const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        errorWidget:
            (context, url, error) =>
                const Icon(Icons.broken_image, size: 60, color: Colors.grey),
      );
    }

    if (materialType == 'video' && material['video_url'] != null) {
      final thumb = _getYoutubeThumbnail(material['video_url']);
      return Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          if (thumb != null)
            CachedNetworkImage(
              imageUrl: thumb,
              fit: BoxFit.cover,
              width: double.infinity,
              placeholder:
                  (context, url) => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              errorWidget:
                  (context, url, error) => const Icon(
                    Icons.video_library,
                    size: 60,
                    color: Colors.grey,
                  ),
            )
          else
            const Icon(Icons.video_library, size: 60, color: Colors.grey),

          // Play button circle
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                // ignore: deprecated_member_use
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                size: 40,
                color: Colors.white,
              ),
            ),
          ),
          // Clickable overlay for playing
          Material(
            color: Colors.transparent,
            child: InkWell(onTap: () => _openVideo(material['video_url'])),
          ),
        ],
      );
    }

    return const Icon(Icons.insert_drive_file, size: 60, color: Colors.grey);
  }

  String _formatCreatedAt(String? createdAt) {
    if (createdAt == null) return 'Tanggal tidak tersedia';
    try {
      final dateTime = DateTime.parse(createdAt);
      return DateFormat('dd MMMM yyyy', 'id_ID').format(dateTime);
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
    } catch (e) {
      // ignore
    }

    return null;
  }

  // ignore: unused_element
  void _shareMaterial(BuildContext context) async {
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
      await SharePlus.instance.share(
        ShareParams(text: shareText, subject: title),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal membagikan materi: $e')));
      }
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Gagal membuka video')));
      }
    }
  }

  void _viewFullImage(String photo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(
                backgroundColor: Colors.black,
                elevation: 0,
                iconTheme: const IconThemeData(color: Colors.white),
              ),
              body: Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: CachedNetworkImage(
                    imageUrl: '${Connection.BASE_URL}/image/$photo',
                    httpHeaders: {'Authorization': 'Bearer $_token'},
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                    placeholder:
                        (context, url) => const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                    errorWidget:
                        (context, url, error) => const Icon(
                          Icons.broken_image,
                          color: Colors.white,
                          size: 60,
                        ),
                  ),
                ),
              ),
            ),
      ),
    );
  }
}
