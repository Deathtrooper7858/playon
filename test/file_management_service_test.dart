import 'package:flutter_test/flutter_test.dart';
import 'package:playon/services/file_management_service.dart';

void main() {
  group('FileManagementService.sanitizeFileName', () {
    test('cleans normal names correctly', () {
      expect(FileManagementService.sanitizeFileName('My Song Title'), 'My Song Title');
    });

    test('replaces illegal characters with underscores', () {
      expect(
        FileManagementService.sanitizeFileName('Song/Title:With*Illegal?Chars"<>|'),
        'Song_Title_With_Illegal_Chars____',
      );
    });

    test('trims trailing dots and spaces', () {
      expect(FileManagementService.sanitizeFileName('Music Folder. . .'), 'Music Folder');
      expect(FileManagementService.sanitizeFileName('Track Name.mp3...'), 'Track Name.mp3');
    });

    test('returns "unnamed" for empty or all-illegal strings', () {
      expect(FileManagementService.sanitizeFileName(''), 'unnamed');
      expect(FileManagementService.sanitizeFileName('   '), 'unnamed');
      expect(FileManagementService.sanitizeFileName('...'), 'unnamed');
      expect(FileManagementService.sanitizeFileName(':::'), 'unnamed');
    });

    test('preserves unicode characters (Spanish accents, emojis, Japanese, etc.)', () {
      expect(
        FileManagementService.sanitizeFileName('Canción de Éxito 🎵 - 日本語'),
        'Canción de Éxito 🎵 - 日本語',
      );
    });
  });
}
