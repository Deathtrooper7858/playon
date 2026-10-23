import 'package:flutter_test/flutter_test.dart';
import 'package:playon/providers/download_provider.dart';

void main() {
  group('DownloadedTrack & RecentDownloadItem Models', () {
    test('DownloadedTrack toMap and fromMap serialization', () {
      const track = DownloadedTrack(
        id: 'dQw4w9WgXcQ',
        title: 'Never Gonna Give You Up',
        artist: 'Rick Astley',
        url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        thumbnailUrl: 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
        success: true,
      );

      final map = track.toMap();
      final restored = DownloadedTrack.fromMap(map);

      expect(restored.id, track.id);
      expect(restored.title, track.title);
      expect(restored.artist, track.artist);
      expect(restored.url, track.url);
      expect(restored.thumbnailUrl, track.thumbnailUrl);
      expect(restored.success, isTrue);
      expect(restored.error, isNull);
    });

    test('RecentDownloadItem toMap and fromMap serialization', () {
      final now = DateTime.now();
      final item = RecentDownloadItem(
        folderName: 'Rock Classics',
        playlistTitle: 'Best Rock 80s',
        trackCount: 42,
        date: now,
      );

      final map = item.toMap();
      final restored = RecentDownloadItem.fromMap(map);

      expect(restored.folderName, 'Rock Classics');
      expect(restored.playlistTitle, 'Best Rock 80s');
      expect(restored.trackCount, 42);
      expect(restored.date.millisecondsSinceEpoch, now.millisecondsSinceEpoch);
    });
  });
}
