import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:on_audio_query/on_audio_query.dart' as oaq;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song_model.dart';

enum PlayerRepeatMode { none, one, all }

class MusicProvider extends ChangeNotifier with WidgetsBindingObserver {
  final AudioPlayer _player = AudioPlayer();
  final oaq.OnAudioQuery _audioQuery = oaq.OnAudioQuery();

  // Stream subscriptions — stored so they can be cancelled on dispose
  final List<StreamSubscription> _subscriptions = [];

  // Debounce timer for _saveState
  Timer? _saveDebounce;

  // Sleep timer
  Timer? _sleepTimer;
  DateTime? _sleepTimerEndTime;

  // Throttle for position updates: last notified position time
  DateTime _lastPositionNotify = DateTime.fromMillisecondsSinceEpoch(0);
  static const _positionThrottleMs = 200;

  List<PlayOnSong> _allSongs = [];
  List<PlayOnSong> _currentQueue = [];
  List<String> _folders = [];

  /// Cached map of folderName → song count. Rebuilt only when _allSongs changes.
  Map<String, int> _folderSongCounts = {};

  String? _selectedFolder;
  int _currentIndex = 0;
  bool _isPlaying = false;
  bool _isShuffle = false;
  PlayerRepeatMode _repeatMode = PlayerRepeatMode.none;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isLoading = false;
  final Set<int> _favoriteIds = {};

  // ── Getters ────────────────────────────────────────────────────────────────
  List<PlayOnSong> get allSongs => _allSongs;
  List<PlayOnSong> get currentQueue => _currentQueue;
  List<String> get folders => _folders;

  /// Pre-computed map: folderName → count of songs.
  /// Avoids O(n) linear scan per folder on every rebuild.
  Map<String, int> get folderSongCounts => _folderSongCounts;

  String? get selectedFolder => _selectedFolder;
  bool get isPlaying => _isPlaying;
  bool get isShuffle => _isShuffle;
  PlayerRepeatMode get repeatMode => _repeatMode;
  Duration get position => _position;
  Duration get duration => _duration;
  bool get isLoading => _isLoading;
  bool get hasSleepTimer => _sleepTimer != null && _sleepTimer!.isActive;
  Duration? get sleepTimeRemaining {
    if (_sleepTimerEndTime == null) return null;
    final remaining = _sleepTimerEndTime!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }
  int get currentIndex => _currentIndex;

  PlayOnSong? get currentSong =>
      _currentQueue.isNotEmpty && _currentIndex < _currentQueue.length
          ? _currentQueue[_currentIndex]
          : null;

  int? get androidAudioSessionId => _player.androidAudioSessionId;
  Stream<int?> get androidAudioSessionIdStream => _player.androidAudioSessionIdStream;

  double _speed = 1.0;
  double get speed => _speed;
  List<PlayOnSong> get favoriteSongs =>
      _allSongs.where((s) => _favoriteIds.contains(s.id)).toList();

  bool isFavorite(int id) => _favoriteIds.contains(id);

  void toggleFavorite(int id) {
    HapticFeedback.selectionClick();
    if (_favoriteIds.contains(id)) {
      _favoriteIds.remove(id);
    } else {
      _favoriteIds.add(id);
    }
    _scheduleSaveState();
    notifyListeners();
  }

  Future<void> setSpeed(double newSpeed) async {
    _speed = newSpeed;
    await _player.setSpeed(newSpeed);
    notifyListeners();
  }

  MusicProvider() {
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      // Flush any pending debounced save immediately on lifecycle pause
      _saveDebounce?.cancel();
      _saveState();
    }
  }

  // ── State persistence ──────────────────────────────────────────────────────

  /// Schedules _saveState with a 1-second debounce.
  /// Prevents hammering SharedPreferences on rapid changes (song skip, seek).
  void _scheduleSaveState() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(seconds: 1), _saveState);
  }

  Future<void> _saveState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selectedFolder', _selectedFolder ?? '');
      await prefs.setInt('currentIndex', _currentIndex);
      await prefs.setBool('isShuffle', _isShuffle);
      await prefs.setInt('repeatMode', _repeatMode.index);
      await prefs.setStringList(
          'favoriteIds', _favoriteIds.map((e) => e.toString()).toList());
      await prefs.setInt('position', _position.inMilliseconds);
    } catch (e) {
      debugPrint('Error saving state: $e');
    }
  }

  Future<void> _loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _selectedFolder = prefs.getString('selectedFolder');
      if (_selectedFolder != null && _selectedFolder!.isEmpty) {
        _selectedFolder = null;
      }

      if (_selectedFolder != null) {
        _currentQueue =
            _allSongs.where((s) => s.folderName == _selectedFolder).toList();
      } else {
        _currentQueue = List.from(_allSongs);
      }

      _currentIndex = prefs.getInt('currentIndex') ?? 0;
      if (_currentIndex >= _currentQueue.length) _currentIndex = 0;

      _isShuffle = prefs.getBool('isShuffle') ?? false;
      _player.setShuffleModeEnabled(_isShuffle);

      final repeatIndex = prefs.getInt('repeatMode') ?? 0;
      _repeatMode = PlayerRepeatMode.values[repeatIndex];
      _applyRepeatMode(_repeatMode);

      final favs = prefs.getStringList('favoriteIds') ?? [];
      _favoriteIds.clear();
      _favoriteIds.addAll(favs.map((e) => int.tryParse(e) ?? 0));

      final savedPositionMs = prefs.getInt('position') ?? 0;
      final savedPosition = Duration(milliseconds: savedPositionMs);

      await _updatePlaylist(
          initialIndex: _currentIndex, position: savedPosition);
    } catch (e) {
      debugPrint('Error loading state: $e');
    }
  }

  void _applyRepeatMode(PlayerRepeatMode mode) {
    switch (mode) {
      case PlayerRepeatMode.none:
        _player.setLoopMode(LoopMode.off);
        break;
      case PlayerRepeatMode.one:
        _player.setLoopMode(LoopMode.one);
        break;
      case PlayerRepeatMode.all:
        _player.setLoopMode(LoopMode.all);
        break;
    }
  }

  // ── Init ───────────────────────────────────────────────────────────────────

  Future<void> _init() async {
    // Position stream: throttled to _positionThrottleMs to avoid rebuilding
    // UI 10× per second. Only notifies if enough time has elapsed.
    _subscriptions.add(
      _player.positionStream.listen((pos) {
        _position = pos;
        final now = DateTime.now();
        if (now.difference(_lastPositionNotify).inMilliseconds >=
            _positionThrottleMs) {
          _lastPositionNotify = now;
          notifyListeners();
        }
      }),
    );

    _subscriptions.add(
      _player.durationStream.listen((dur) {
        if (dur != null && dur != _duration) {
          _duration = dur;
          notifyListeners();
        }
      }),
    );

    _subscriptions.add(
      _player.playerStateStream.listen((state) {
        final playing = state.playing;
        if (playing != _isPlaying) {
          _isPlaying = playing;
          notifyListeners();
        }
      }),
    );

    _subscriptions.add(
      _player.currentIndexStream.listen((index) {
        if (index != null &&
            index < _currentQueue.length &&
            _currentIndex != index) {
          _currentIndex = index;
          _scheduleSaveState();
          notifyListeners();
        }
      }),
    );

    await loadSongs();
  }

  // ── Song loading ───────────────────────────────────────────────────────────

  Future<void> loadSongs() async {
    _isLoading = true;
    notifyListeners();

    try {
      final status = await Permission.audio.request();
      if (!status.isGranted) {
        await Permission.storage.request();
      }
      await Permission.notification.request();

      final songs = await _audioQuery.querySongs(
        sortType: oaq.SongSortType.TITLE,
        orderType: oaq.OrderType.ASC_OR_SMALLER,
        uriType: oaq.UriType.EXTERNAL,
        ignoreCase: true,
      );

      _allSongs = songs
          .where((s) => s.duration != null && s.duration! > 30000)
          .map((s) {
        final path = s.data;
        final parts = path.split('/');
        final folderPath = parts.length > 1
            ? parts.sublist(0, parts.length - 1).join('/')
            : '/';
        final folderName =
            parts.length > 1 ? parts[parts.length - 2] : 'Music';

        final safeArtist = (s.artist == null || s.artist == '<unknown>') ? 'Artista desconocido' : s.artist!;
        final safeAlbum = (s.album == null || s.album == '<unknown>') ? 'Álbum desconocido' : s.album!;

        return PlayOnSong(
          id: s.id,
          title: s.title,
          artist: safeArtist,
          album: safeAlbum,
          uri: s.uri?.toString() ?? s.data,
          duration: s.duration ?? 0,
          folderName: folderName,
          folderPath: folderPath,
        );
      }).toList();

      // Extract unique folders and pre-compute counts in a single pass
      final folderSet = <String>{};
      final counts = <String, int>{};
      for (final song in _allSongs) {
        if (song.folderName != null) {
          folderSet.add(song.folderName!);
          counts[song.folderName!] = (counts[song.folderName!] ?? 0) + 1;
        }
      }
      _folders = folderSet.toList()..sort();
      _folderSongCounts = counts;

      await _loadState();
    } catch (e) {
      debugPrint('Error loading songs: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  // ── Folder / queue management ──────────────────────────────────────────────

  void selectFolder(String? folder) {
    _selectedFolder = folder;
    if (folder == null) {
      _currentQueue = List.from(_allSongs);
    } else {
      _currentQueue = _allSongs.where((s) => s.folderName == folder).toList();
    }
    _currentIndex = 0;
    _updatePlaylist(initialIndex: 0);
    _scheduleSaveState();
    notifyListeners();
  }

  Future<void> _updatePlaylist(
      {int initialIndex = 0, Duration? position}) async {
    if (_currentQueue.isEmpty) return;

    final sources = _currentQueue
        .map((song) {
          // Use content URI for album art — works on Android 10+
          // Falls back to null (no artwork) rather than crashing the service
          Uri? artUri;
          try {
            artUri = Uri.parse(
              'content://media/external/audio/media/${song.id}/albumart',
            );
          } catch (_) {
            artUri = null;
          }

          return AudioSource.uri(
            Uri.parse(song.uri),
            tag: MediaItem(
              id: song.id.toString(),
              title: song.title,
              artist: song.artist,
              album: song.album,
              artUri: artUri,
            ),
          );
        })
        .toList();

    await _player.setAudioSources(
      sources,
      initialIndex: initialIndex,
      initialPosition: position,
    );
  }

  // ── Playback controls ──────────────────────────────────────────────────────

  Future<void> playSong(int index) async {
    if (index < 0 || index >= _currentQueue.length) return;

    if (_player.sequence.isEmpty) {
      await _updatePlaylist(initialIndex: index);
    }

    try {
      await _player.seek(Duration.zero, index: index);
      await _player.play();
    } catch (e) {
      debugPrint('Error playing song: $e');
    }
  }

  Future<void> playCustomQueue(List<PlayOnSong> queue, int index) async {
    if (index < 0 || index >= queue.length) return;
    _currentQueue = List.from(queue);
    _currentIndex = index;
    await _updatePlaylist(initialIndex: index);
    try {
      await _player.seek(Duration.zero, index: index);
      await _player.play();
    } catch (e) {
      debugPrint('Error playing custom queue: $e');
    }
    _scheduleSaveState();
    notifyListeners();
  }

  Future<void> playPause() async {
    HapticFeedback.lightImpact();
    if (_isPlaying) {
      await _player.pause();
      _scheduleSaveState();
    } else {
      if (currentSong == null && _currentQueue.isNotEmpty) {
        await playSong(0);
      } else {
        await _player.play();
      }
    }
  }

  Future<void> stop() async {
    await _player.stop();
    _scheduleSaveState();
  }

  Future<void> next() async {
    HapticFeedback.selectionClick();
    if (_player.hasNext) {
      await _player.seekToNext();
    } else if (_repeatMode == PlayerRepeatMode.all) {
      await _player.seek(Duration.zero, index: 0);
    }
  }

  Future<void> previous() async {
    HapticFeedback.selectionClick();
    if (_position.inSeconds > 3) {
      await seekTo(Duration.zero);
    } else if (_player.hasPrevious) {
      await _player.seekToPrevious();
    } else if (_repeatMode == PlayerRepeatMode.all) {
      await _player.seek(Duration.zero, index: _currentQueue.length - 1);
    }
  }

  Future<void> seekTo(Duration position) async {
    await _player.seek(position);
  }

  void toggleShuffle() {
    HapticFeedback.selectionClick();
    _isShuffle = !_isShuffle;
    _player.setShuffleModeEnabled(_isShuffle);
    _scheduleSaveState();
    notifyListeners();
  }

  void toggleRepeat() {
    HapticFeedback.selectionClick();
    switch (_repeatMode) {
      case PlayerRepeatMode.none:
        _repeatMode = PlayerRepeatMode.all;
        break;
      case PlayerRepeatMode.all:
        _repeatMode = PlayerRepeatMode.one;
        break;
      case PlayerRepeatMode.one:
        _repeatMode = PlayerRepeatMode.none;
        break;
    }
    _applyRepeatMode(_repeatMode);
    _scheduleSaveState();
    notifyListeners();
  }

  // ── Sleep Timer ────────────────────────────────────────────────────────────

  void setSleepTimer(Duration duration) {
    _sleepTimer?.cancel();
    _sleepTimerEndTime = DateTime.now().add(duration);
    _sleepTimer = Timer(duration, () {
      stop();
      cancelSleepTimer();
    });
    notifyListeners();
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepTimerEndTime = null;
    notifyListeners();
  }

  // ── Dispose ────────────────────────────────────────────────────────────────


  @override
  void dispose() {
    _saveDebounce?.cancel();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    WidgetsBinding.instance.removeObserver(this);
    _player.dispose();
    super.dispose();
  }
}
