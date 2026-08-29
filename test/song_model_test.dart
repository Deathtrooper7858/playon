import 'package:flutter_test/flutter_test.dart';
import 'package:playon/models/song_model.dart';

void main() {
  group('PlayOnSong Model Tests', () {
    test('Calculates durationFormatted correctly', () {
      final song1 = PlayOnSong(
        id: 1,
        title: 'Song 1',
        artist: 'Artist 1',
        album: 'Album 1',
        uri: '/path/song1.mp3',
        duration: 185000, // 3 mins 5 secs
      );

      expect(song1.durationFormatted, '3:05');

      final song2 = PlayOnSong(
        id: 2,
        title: 'Song 2',
        artist: 'Artist 2',
        album: 'Album 2',
        uri: '/path/song2.mp3',
        duration: 62000, // 1 min 2 secs
      );

      expect(song2.durationFormatted, '1:02');
    });

    test('copyWith updates properties properly', () {
      final song = PlayOnSong(
        id: 1,
        title: 'Original Title',
        artist: 'Original Artist',
        album: 'Original Album',
        uri: '/path/song.mp3',
        duration: 120000,
      );

      final updated = song.copyWith(title: 'New Title', artist: 'New Artist');

      expect(updated.id, 1);
      expect(updated.title, 'New Title');
      expect(updated.artist, 'New Artist');
      expect(updated.album, 'Original Album');
    });

    test('Equality and hashcode comparison', () {
      final songA = PlayOnSong(
        id: 1,
        title: 'Song',
        artist: 'Artist',
        album: 'Album',
        uri: '/path/song.mp3',
        duration: 100000,
      );

      final songB = PlayOnSong(
        id: 1,
        title: 'Song',
        artist: 'Artist',
        album: 'Album',
        uri: '/path/song.mp3',
        duration: 100000,
      );

      expect(songA == songB, isTrue);
      expect(songA.hashCode, equals(songB.hashCode));
    });
  });
}
