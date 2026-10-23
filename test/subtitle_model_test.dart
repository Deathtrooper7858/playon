import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:playon/models/subtitle_model.dart';

void main() {
  group('SubtitleModel Tests', () {
    test('SubtitleCue isActiveAt calculates correctly', () {
      const cue = SubtitleCue(
        start: Duration(seconds: 10),
        end: Duration(seconds: 15),
        text: 'Hola mundo',
      );

      expect(cue.isActiveAt(const Duration(seconds: 9)), isFalse);
      expect(cue.isActiveAt(const Duration(seconds: 10)), isTrue);
      expect(cue.isActiveAt(const Duration(seconds: 12)), isTrue);
      expect(cue.isActiveAt(const Duration(seconds: 15)), isTrue);
      expect(cue.isActiveAt(const Duration(seconds: 16)), isFalse);
    });

    test('SubtitleTrack.fromFile parses SRT correctly', () async {
      final tempDir = Directory.systemTemp.createTempSync('sub_test_');
      final srtFile = File('${tempDir.path}/test_video.es.srt');
      await srtFile.writeAsString('''
1
00:00:01,500 --> 00:00:04,200
<b>Bienvenido</b> a PlayOn

2
00:00:05,000 --> 00:00:08,123
Disfruta de tus videos en alta definición
''');

      final track = await SubtitleTrack.fromFile(srtFile);
      expect(track, isNotNull);
      expect(track!.language, equals('es'));
      expect(track.name, equals('Español'));
      expect(track.cues.length, equals(2));

      // Test Cue 1
      expect(track.cues[0].start, equals(const Duration(seconds: 1, milliseconds: 500)));
      expect(track.cues[0].end, equals(const Duration(seconds: 4, milliseconds: 200)));
      expect(track.cues[0].text, equals('Bienvenido a PlayOn')); // Cleaned HTML

      // Test Cue 2
      expect(track.cues[1].start, equals(const Duration(seconds: 5)));
      expect(track.cues[1].end, equals(const Duration(seconds: 8, milliseconds: 123)));
      expect(track.cues[1].text, equals('Disfruta de tus videos en alta definición'));

      tempDir.deleteSync(recursive: true);
    });

    test('SubtitleTrack.fromFile parses WEBVTT correctly', () async {
      final tempDir = Directory.systemTemp.createTempSync('sub_vtt_');
      final vttFile = File('${tempDir.path}/test_video.en.vtt');
      await vttFile.writeAsString('''
WEBVTT

00:00:02.000 --> 00:00:05.500
Hello and welcome

00:00:06.100 --> 00:00:09.000
Enjoy video playback
''');

      final track = await SubtitleTrack.fromFile(vttFile);
      expect(track, isNotNull);
      expect(track!.language, equals('en'));
      expect(track.name, equals('Inglés'));
      expect(track.cues.length, equals(2));
      expect(track.cues[0].text, equals('Hello and welcome'));

      tempDir.deleteSync(recursive: true);
    });
  });
}
