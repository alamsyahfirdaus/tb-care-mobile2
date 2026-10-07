/// Helper terpusat untuk memformat alamat lengkap pasien di aplikasi TB Care.
/// Menggabungkan field terstruktur menjadi satu kalimat alamat yang rapi dan mudah dibaca.
/// Format standar:
/// {address}, RT {rt}, RW {rw}, {village}, {subdistrict}, {district}, {province}
String formatFullAddress({
  String? address,
  String? rt,
  String? rw,
  String? village,
  String? subdistrict,
  String? district,
  String? province,
}) {
  final List<String> parts = [];

  // 1. Alamat Jalan / Detail Rumah
  if (address != null) {
    final cleanAddress = address.trim();
    if (cleanAddress.isNotEmpty && cleanAddress != '-') {
      parts.add(cleanAddress);
    }
  }

  // 2. RT
  if (rt != null) {
    final cleanRt = rt.trim();
    if (cleanRt.isNotEmpty && cleanRt != '-') {
      if (cleanRt.toUpperCase().startsWith('RT')) {
        parts.add(cleanRt);
      } else {
        parts.add('RT $cleanRt');
      }
    }
  }

  // 3. RW
  if (rw != null) {
    final cleanRw = rw.trim();
    if (cleanRw.isNotEmpty && cleanRw != '-') {
      if (cleanRw.toUpperCase().startsWith('RW')) {
        parts.add(cleanRw);
      } else {
        parts.add('RW $cleanRw');
      }
    }
  }

  // 4. Desa / Kelurahan
  if (village != null) {
    final cleanVillage = village.trim();
    if (cleanVillage.isNotEmpty && cleanVillage != '-') {
      parts.add(cleanVillage);
    }
  }

  // 5. Kecamatan
  if (subdistrict != null) {
    final cleanSub = subdistrict.trim();
    if (cleanSub.isNotEmpty && cleanSub != '-') {
      parts.add(cleanSub);
    }
  }

  // 6. Kabupaten / Kota
  if (district != null) {
    final cleanDist = district.trim();
    if (cleanDist.isNotEmpty && cleanDist != '-') {
      parts.add(cleanDist);
    }
  }

  // 7. Provinsi
  if (province != null) {
    final cleanProv = province.trim();
    if (cleanProv.isNotEmpty && cleanProv != '-') {
      parts.add(cleanProv);
    }
  }

  return parts.join(', ');
}

/// Data kelas pembungkus untuk nama Puskesmas dan keterangan lokasinya (Kecamatan - Kabupaten/Kota)
class PuskesmasDisplayInfo {
  final String name;
  final String location;

  const PuskesmasDisplayInfo({
    required this.name,
    required this.location,
  });
}

/// Helper untuk mengekstrak dan memformat nama bersih Puskesmas dan lokasinya
/// Title: Nama Puskesmas (misal: "Kawalu" atau "Puskesmas Kawalu")
/// Subtitle: "Kecamatan - Kabupaten/Kota" (misal: "Kawalu - Kota Tasikmalaya")
PuskesmasDisplayInfo formatPuskesmasDisplay({
  String? rawName,
  String? formattedName,
  String? subdistrictName,
  String? districtName,
  String? location,
  Map<String, dynamic>? puskesmasMap,
}) {
  String name = '';
  String loc = '';

  // 1. Ambil nama Puskesmas
  if (rawName != null && rawName.trim().isNotEmpty && rawName.trim() != '-') {
    name = rawName.trim();
  } else if (puskesmasMap != null &&
      puskesmasMap['raw_name'] != null &&
      puskesmasMap['raw_name'].toString().trim().isNotEmpty &&
      puskesmasMap['raw_name'].toString().trim() != '-') {
    name = puskesmasMap['raw_name'].toString().trim();
  } else if (puskesmasMap != null &&
      puskesmasMap['name'] != null &&
      puskesmasMap['name'].toString().trim().isNotEmpty &&
      puskesmasMap['name'].toString().trim() != '-') {
    name = puskesmasMap['name'].toString().trim();
  } else if (formattedName != null && formattedName.trim().isNotEmpty && formattedName.trim() != '-') {
    name = formattedName.trim();
  }

  // Jika nama mengandung tanda kurung seperti "Kawalu (Kawalu, Kota Tasikmalaya)",
  // pisahkan nama asli dan lokasinya
  if (name.contains('(') && name.contains(')')) {
    final openIndex = name.indexOf('(');
    final closeIndex = name.lastIndexOf(')');
    final inside = name.substring(openIndex + 1, closeIndex).trim();
    final cleanName = name.substring(0, openIndex).trim();
    if (cleanName.isNotEmpty) {
      name = cleanName;
    }
    if (loc.isEmpty && inside.isNotEmpty) {
      loc = inside.replaceAll(', ', ' - ').replaceAll(',', ' - ');
    }
  }

  // 2. Ambil lokasi Puskesmas (Kecamatan - Kabupaten/Kota)
  if (location != null && location.trim().isNotEmpty && location.trim() != '-') {
    loc = location.trim();
  } else if (subdistrictName != null &&
      districtName != null &&
      subdistrictName.trim().isNotEmpty &&
      districtName.trim().isNotEmpty &&
      subdistrictName.trim() != '-' &&
      districtName.trim() != '-') {
    loc = '${subdistrictName.trim()} - ${districtName.trim()}';
  } else if (puskesmasMap != null) {
    final sub = puskesmasMap['subdistrict'] is Map
        ? puskesmasMap['subdistrict']['name']?.toString()
        : puskesmasMap['subdistrict_name']?.toString();
    final dist = puskesmasMap['subdistrict'] is Map && puskesmasMap['subdistrict']['district'] is Map
        ? puskesmasMap['subdistrict']['district']['name']?.toString()
        : puskesmasMap['district_name']?.toString();

    if (sub != null && dist != null && sub.trim().isNotEmpty && dist.trim().isNotEmpty) {
      loc = '${sub.trim()} - ${dist.trim()}';
    } else if (sub != null && sub.trim().isNotEmpty) {
      loc = sub.trim();
    } else if (dist != null && dist.trim().isNotEmpty) {
      loc = dist.trim();
    }
  }

  return PuskesmasDisplayInfo(
    name: name,
    location: loc,
  );
}
