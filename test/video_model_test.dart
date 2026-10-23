import 'package:flutter_test/flutter_test.dart';
import 'package:playon/models/video_model.dart';

void main() {
  group('PlayOnVideo Model Tests', () {
    test('Calculates durationFormatted correctly', () {
      final video1 = PlayOnVideo(
        id: '1',
        title: 'Video 1',
        author: 'Canal',
        filePath: '/storage/emulated/0/Movies/My videos/Video 1.mp4',
        duration: 215000, // 3m 35s
        fileSize: 15 * 1024 * 1024,
        dateAdded: DateTime.now(),
        folderName: 'My videos',
        folderPath: '/storage/emulated/0/Movies/My videos',
      );

      expect(video1.durationFormatted, '3:35');

      final videoHour = video1.copyWith(duration: 3665000); // 1h 1m 5s
      expect(videoHour.durationFormatted, '1:01:05');

      final videoZero = video1.copyWith(duration: 0);
      expect(videoZero.durationFormatted, '');
    });

    test('Calculates fileSizeFormatted correctly', () {
      final video = PlayOnVideo(
        id: '2',
        title: 'Sample Video',
        author: 'Uploader',
        filePath: '/path/video.mp4',
        duration: 60000,
        fileSize: 25 * 1024 * 1024, // 25 MB
        dateAdded: DateTime.now(),
        folderName: 'My videos',
        folderPath: '/path',
      );

      expect(video.fileSizeFormatted, '25.0 MB');

      final smallVideo = video.copyWith(fileSize: 512 * 1024);
      expect(smallVideo.fileSizeFormatted, '512.0 KB');
    });

    test('Serialization toMap and fromMap preserves all fields', () {
      final now = DateTime.fromMillisecondsSinceEpoch(1700000000000);
      final original = PlayOnVideo(
        id: 'yt_123',
        title: 'Amazing Flutter Tutorial',
        author: 'DevChannel',
        filePath: '/storage/emulated/0/Movies/My videos/Amazing Flutter Tutorial.mp4',
        thumbnailPath: '/storage/emulated/0/Movies/My videos/Amazing Flutter Tutorial.thumb.jpg',
        thumbnailUrl: 'https://i.ytimg.com/vi/yt_123/hqdefault.jpg',
        duration: 360000,
        fileSize: 42000000,
        dateAdded: now,
        folderName: 'My videos',
        folderPath: '/storage/emulated/0/Movies/My videos',
      );

      final map = original.toMap();
      final restored = PlayOnVideo.fromMap(map);

      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.author, original.author);
      expect(restored.filePath, original.filePath);
      expect(restored.thumbnailPath, original.thumbnailPath);
      expect(restored.thumbnailUrl, original.thumbnailUrl);
      expect(restored.duration, original.duration);
      expect(restored.fileSize, original.fileSize);
      expect(restored.dateAdded.millisecondsSinceEpoch, original.dateAdded.millisecondsSinceEpoch);
      expect(restored.folderName, original.folderName);
      expect(restored.folderPath, original.folderPath);
    });

    test('Default folder name defaults to My videos when absent', () {
      final video = PlayOnVideo.fromMap({
        'id': 'abc',
        'title': 'Test',
      });
      expect(video.folderName, 'My videos');
    });
  });
}
