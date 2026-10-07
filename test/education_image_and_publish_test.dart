import 'package:flutter_test/flutter_test.dart';
import 'package:apk_tb_care/connection.dart';

void main() {
  group('Connection.resolveImageUrl Tests', () {
    test('resolves raw image filename to API image endpoint', () {
      final url = Connection.resolveImageUrl('f4yU8tmJg0hRk84AaPdH.jpg');
      expect(url, '${Connection.BASE_URL}/image/f4yU8tmJg0hRk84AaPdH.jpg');
    });

    test('resolves production full image URL to bypass Cloudflare 403', () {
      final url = Connection.resolveImageUrl(
        'https://tbcare.umtas.ac.id/images/f4yU8tmJg0hRk84AaPdH.jpg',
      );
      expect(url, '${Connection.BASE_URL}/image/f4yU8tmJg0hRk84AaPdH.jpg');
    });

    test('resolves localhost / 127.0.0.1 image URL to API endpoint', () {
      final url1 = Connection.resolveImageUrl(
        'http://localhost/images/f4yU8tmJg0hRk84AaPdH.jpg',
      );
      final url2 = Connection.resolveImageUrl(
        'http://127.0.0.1:8000/images/f4yU8tmJg0hRk84AaPdH.jpg',
      );
      expect(url1, '${Connection.BASE_URL}/image/f4yU8tmJg0hRk84AaPdH.jpg');
      expect(url2, '${Connection.BASE_URL}/image/f4yU8tmJg0hRk84AaPdH.jpg');
    });

    test('resolves relative path images/xxx.jpg to API endpoint', () {
      final url = Connection.resolveImageUrl('images/f4yU8tmJg0hRk84AaPdH.jpg');
      expect(url, '${Connection.BASE_URL}/image/f4yU8tmJg0hRk84AaPdH.jpg');
    });

    test('strips query parameters and hashes from filename', () {
      final url = Connection.resolveImageUrl(
        'https://tbcare.umtas.ac.id/images/f4yU8tmJg0hRk84AaPdH.jpg?v=123#preview',
      );
      expect(url, '${Connection.BASE_URL}/image/f4yU8tmJg0hRk84AaPdH.jpg');
    });

    test('preserves genuine external 3rd-party URLs (e.g. YouTube CDN)', () {
      final extUrl = 'https://img.youtube.com/vi/LCKNA68iDxI/hqdefault.jpg';
      final url = Connection.resolveImageUrl(extUrl);
      expect(url, extUrl);
    });

    test('returns null for empty or null inputs', () {
      expect(Connection.resolveImageUrl(null), isNull);
      expect(Connection.resolveImageUrl(''), isNull);
      expect(Connection.resolveImageUrl('   '), isNull);
    });
  });

  group('Education is_publish Multi-Type Resilience Tests', () {
    bool isItemPublished(dynamic isPublish) {
      if (isPublish == null) return false;
      return isPublish == 1 || isPublish == true || isPublish == '1';
    }

    test('identifies boolean true as published', () {
      expect(isItemPublished(true), isTrue);
    });

    test('identifies integer 1 as published', () {
      expect(isItemPublished(1), isTrue);
    });

    test('identifies string "1" as published', () {
      expect(isItemPublished('1'), isTrue);
    });

    test('identifies boolean false, integer 0, string "0", and null as unpublished', () {
      expect(isItemPublished(false), isFalse);
      expect(isItemPublished(0), isFalse);
      expect(isItemPublished('0'), isFalse);
      expect(isItemPublished(null), isFalse);
    });

    test('filters API materials where is_publish is boolean true correctly', () {
      final materials = [
        {'id': 1, 'material_type': 'image', 'is_publish': true},
        {'id': 2, 'material_type': 'video', 'is_publish': true},
        {'id': 3, 'material_type': 'image', 'is_publish': false},
        {'id': 4, 'material_type': 'image', 'is_publish': 1},
      ];

      final imagePublished = materials
          .where((m) => m['material_type'] == 'image' && isItemPublished(m['is_publish']))
          .toList();

      final videoPublished = materials
          .where((m) => m['material_type'] == 'video' && isItemPublished(m['is_publish']))
          .toList();

      final drafts = materials
          .where((m) => !isItemPublished(m['is_publish']))
          .toList();

      expect(imagePublished.length, 2);
      expect(imagePublished.map((m) => m['id']), [1, 4]);
      expect(videoPublished.length, 1);
      expect(videoPublished.first['id'], 2);
      expect(drafts.length, 1);
      expect(drafts.first['id'], 3);
    });
  });
}
