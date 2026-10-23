import 'package:flutter_test/flutter_test.dart';
import 'package:playon/models/song_model.dart';
import 'package:playon/models/video_model.dart';
import 'package:playon/services/search_helper.dart';

void main() {
  group('SearchHelper Tests', () {
    final song = PlayOnSong(
      id: 1,
      title: 'Canción del Corazón',
      artist: 'Shakira & Maluma',
      album: 'Éxitos Latinos 2026',
      folderName: 'Música Pop',
      uri: '/storage/music/song.mp3',
      duration: 210000,
    );

    test('Normalize strips accents and lowercases', () {
      expect(SearchHelper.normalize('ÁéÍóÚñÜ'), 'aeiounu');
      expect(SearchHelper.normalize('  CANCiÓN  '), 'cancion');
    });

    test('Exact and case-insensitive matching', () {
      expect(SearchHelper.matchesSong(song, 'cancion'), isTrue);
      expect(SearchHelper.matchesSong(song, 'CANCIÓN'), isTrue);
      expect(SearchHelper.matchesSong(song, 'shakira'), isTrue);
      expect(SearchHelper.matchesSong(song, 'maluma'), isTrue);
    });

    test('Accent-tolerant matching', () {
      expect(SearchHelper.matchesSong(song, 'corazon'), isTrue);
      expect(SearchHelper.matchesSong(song, 'exitos'), isTrue);
      expect(SearchHelper.matchesSong(song, 'musica'), isTrue);
    });

    test('Multi-token queries in any order', () {
      expect(SearchHelper.matchesSong(song, 'shakira corazon'), isTrue);
      expect(SearchHelper.matchesSong(song, 'latinos cancion shakira'), isTrue);
      expect(SearchHelper.matchesSong(song, 'pop maluma'), isTrue);
    });

    test('Non-matching query returns false', () {
      expect(SearchHelper.matchesSong(song, 'Metallica'), isFalse);
      expect(SearchHelper.matchesSong(song, 'shakira rock'), isFalse);
    });

    test('Empty query returns true', () {
      expect(SearchHelper.matchesSong(song, ''), isTrue);
      expect(SearchHelper.matchesSong(song, '   '), isTrue);
    });

    test('matchesText test for playlists/folders', () {
      expect(SearchHelper.matchesText('Favoritas de Verano', 'verano'), isTrue);
      expect(SearchHelper.matchesText('Canciones Clásicas', 'clasicas'), isTrue);
      expect(SearchHelper.matchesText('Rock en Español', 'espanol'), isTrue);
      expect(SearchHelper.matchesText('Jazz Night', 'metal'), isFalse);
    });

    test('matchesVideo test with accent-tolerance and multi-tokens', () {
      final video = PlayOnVideo(
        id: 'vid1',
        title: 'Videoclip Oficial de Música Latina',
        author: 'Sebastián Yatra',
        filePath: '/storage/movies/video.mp4',
        duration: 180000,
        fileSize: 45000000,
        dateAdded: DateTime.now(),
        folderName: 'Conciertos en Vivo',
        folderPath: '/storage/movies',
      );

      expect(SearchHelper.matchesVideo(video, 'musica'), isTrue);
      expect(SearchHelper.matchesVideo(video, 'MÚSICA'), isTrue);
      expect(SearchHelper.matchesVideo(video, 'sebastian'), isTrue);
      expect(SearchHelper.matchesVideo(video, 'yatra latina'), isTrue);
      expect(SearchHelper.matchesVideo(video, 'conciertos'), isTrue);
      expect(SearchHelper.matchesVideo(video, 'rock pesado'), isFalse);
      expect(SearchHelper.matchesVideo(video, ''), isTrue);
    });
  });
}
