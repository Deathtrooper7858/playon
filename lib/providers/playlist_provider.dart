import 'package:flutter/foundation.dart';
import '../models/song_model.dart';
import '../services/playlist_db.dart';
import 'music_provider.dart';

class PlaylistProvider extends ChangeNotifier {
  final MusicProvider _musicProvider;
  List<CustomPlaylist> _playlists = [];
  Map<int, int> _songCounts = {};
  bool _isLoading = false;

  List<CustomPlaylist> get playlists => _playlists;
  Map<int, int> get songCounts => _songCounts;
  bool get isLoading => _isLoading;

  PlaylistProvider(this._musicProvider) {
    loadPlaylists();
  }

  Future<void> loadPlaylists() async {
    _isLoading = true;
    notifyListeners();

    try {
      _playlists = await PlaylistDb.instance.getAllPlaylists();
      _songCounts = await PlaylistDb.instance.getSongCountsPerPlaylist();
    } catch (e) {
      debugPrint('Error loading playlists: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<CustomPlaylist?> createPlaylist(String name) async {
    if (name.trim().isEmpty) return null;
    try {
      final p = await PlaylistDb.instance.createPlaylist(name.trim());
      await loadPlaylists();
      return p;
    } catch (e) {
      debugPrint('Error creating playlist: $e');
      return null;
    }
  }

  Future<void> deletePlaylist(int id) async {
    try {
      await PlaylistDb.instance.deletePlaylist(id);
      await loadPlaylists();
    } catch (e) {
      debugPrint('Error deleting playlist: $e');
    }
  }

  Future<void> renamePlaylist(int id, String newName) async {
    if (newName.trim().isEmpty) return;
    try {
      await PlaylistDb.instance.renamePlaylist(id, newName.trim());
      await loadPlaylists();
    } catch (e) {
      debugPrint('Error renaming playlist: $e');
    }
  }

  Future<void> addSongToPlaylist(int playlistId, int songId) async {
    try {
      await PlaylistDb.instance.addSongToPlaylist(playlistId, songId);
      await loadPlaylists();
    } catch (e) {
      debugPrint('Error adding song to playlist: $e');
    }
  }

  Future<void> addSongsToPlaylist(int playlistId, List<int> songIds) async {
    try {
      await PlaylistDb.instance.addSongsToPlaylist(playlistId, songIds);
      await loadPlaylists();
    } catch (e) {
      debugPrint('Error adding songs to playlist: $e');
    }
  }

  Future<void> clearPlaylist(int playlistId) async {
    try {
      await PlaylistDb.instance.clearPlaylist(playlistId);
      await loadPlaylists();
    } catch (e) {
      debugPrint('Error clearing playlist: $e');
    }
  }

  Future<void> removeSongFromPlaylist(int playlistId, int songId) async {
    try {
      await PlaylistDb.instance.removeSongFromPlaylist(playlistId, songId);
      await loadPlaylists();
    } catch (e) {
      debugPrint('Error removing song from playlist: $e');
    }
  }

  Future<List<PlayOnSong>> getSongsForPlaylist(int playlistId) async {
    try {
      final songIds = await PlaylistDb.instance.getSongIdsForPlaylist(playlistId);
      final songMap = {for (var s in _musicProvider.allSongs) s.id: s};
      final list = <PlayOnSong>[];
      for (final id in songIds) {
        if (songMap.containsKey(id)) {
          list.add(songMap[id]!);
        }
      }
      return list;
    } catch (e) {
      debugPrint('Error getting songs for playlist: $e');
      return [];
    }
  }

  void playPlaylist(List<PlayOnSong> songs, int initialIndex) {
    if (songs.isEmpty) return;
    _musicProvider.playCustomQueue(songs, initialIndex);
  }
}
