class Connection {
  // ===== PILIHAN ENVIRONMENT:
  // 1. Production Server:
  // ignore: constant_identifier_names
  static const String BASE_URL = "https://tbcare.umtas.ac.id/api";

  // 2. Local Development Options (uncomment sesuai target pengujian):
  // static const String BASE_URL = "http://10.0.2.2:8000/api";       // Android Emulator (AVD)
  // static const String BASE_URL = "http://127.0.0.1:8000/api";      // Device via ADB reverse / Desktop / iOS Sim
  // static const String BASE_URL = "http://192.168.2.35:8000/api";   // Device via Wi-Fi LAN

  /// Mengonversi nilai path/URL gambar dari backend menjadi URL API yang valid dan aman dari blokir Cloudflare.
  /// Konsisten dengan endpoint gambar riwayat obat (`/api/image/{filename}`).
  static String? resolveImageUrl(String? photo) {
    if (photo == null || photo.trim().isEmpty) return null;
    final trimmed = photo.trim();

    // Jika merupakan URL lengkap
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      final isTbCareServer = trimmed.contains('tbcare.umtas.ac.id') ||
          trimmed.contains('localhost') ||
          trimmed.contains('127.0.0.1') ||
          trimmed.contains('10.0.2.2') ||
          trimmed.contains('192.168.');
      final isImagesFolder =
          trimmed.contains('/images/') || trimmed.contains('/storage/');

      // Jika URL mengarah ke aset server TB Care (misal https://tbcare.umtas.ac.id/images/xxx.jpg),
      // arahkan melalui endpoint API `/image/{filename}` agar tidak diblokir Cloudflare 403.
      if (isTbCareServer || isImagesFolder) {
        final cleanPath = trimmed.split('?').first.split('#').first;
        final filename = cleanPath.split('/').last;
        return '$BASE_URL/image/$filename';
      }

      // URL eksternal pihak ketiga murni (misal thumbnail youtube atau CDN luar)
      return trimmed;
    }

    // Nama file langsung atau path relatif (misal: 'xxx.jpg' atau 'images/xxx.jpg')
    final cleanPath = trimmed.split('?').first.split('#').first;
    final filename = cleanPath.split('/').last;
    return '$BASE_URL/image/$filename';
  }
}

