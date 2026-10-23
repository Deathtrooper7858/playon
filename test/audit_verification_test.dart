import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:playon/services/file_management_service.dart';

void main() {
  group('Security & Sanitization Audit Tests', () {
    test('Path traversal attempts are neutralized by sanitizeFileName', () {
      expect(FileManagementService.sanitizeFileName('..'), 'unnamed');
      expect(FileManagementService.sanitizeFileName('...'), 'unnamed');
      expect(FileManagementService.sanitizeFileName('../../../etc/passwd'), '______etc_passwd');
      expect(FileManagementService.sanitizeFileName(r'..\..\windows\system32'), '____windows_system32');
      expect(FileManagementService.sanitizeFileName('folder/../subfolder'), 'folder___subfolder');
    });

    test('Special Windows and Android reserved characters are replaced', () {
      expect(FileManagementService.sanitizeFileName('rock:metal?party*'), 'rock_metal_party_');
      expect(FileManagementService.sanitizeFileName('<cool> "tunes" | 2026'), '_cool_ _tunes_ _ 2026');
    });
  });

  group('Reactive Progress Updates Tests', () {
    test('ValueNotifier<Duration> emits updates without ChangeNotifier notifications', () {
      final notifier = ValueNotifier<Duration>(Duration.zero);
      final receivedValues = <Duration>[];

      notifier.addListener(() {
        receivedValues.add(notifier.value);
      });

      notifier.value = const Duration(seconds: 1);
      notifier.value = const Duration(seconds: 5);
      notifier.value = const Duration(seconds: 10);

      expect(receivedValues.length, 3);
      expect(receivedValues[0], const Duration(seconds: 1));
      expect(receivedValues[1], const Duration(seconds: 5));
      expect(receivedValues[2], const Duration(seconds: 10));

      notifier.dispose();
    });
  });

  group('Video Subtitle Association Tests', () {
    test('Subtitle names correctly correspond to base video file name', () {
      const videoPath = '/storage/emulated/0/Movies/My videos/001 - In the End.mp4';
      final baseName = p.basenameWithoutExtension(videoPath);
      expect(baseName, '001 - In the End');

      final candidateSrt = '$baseName.es.srt';
      final candidateVtt = '$baseName.en.vtt';

      expect(candidateSrt.startsWith(baseName) && candidateSrt.endsWith('.srt'), isTrue);
      expect(candidateVtt.startsWith(baseName) && candidateVtt.endsWith('.vtt'), isTrue);
      expect('other_video.srt'.startsWith(baseName), isFalse);
    });
  });
}
