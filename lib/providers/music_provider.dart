import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:on_audio_query/on_audio_query.dart' as oaq;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song_model.dart';

enum PlayerRepeatMode { none, one, all }
enum SongSortOption { title, artist, album, duration, date }

class MusicProvider extends ChangeNotifier with WidgetsBindingObserver {
  final AudioPlayer _player = AudioPlayer();
  final oaq.OnAudioQuery _audioQuery = oaq.OnAudioQuery();

  // Stream subscriptions — stored so they can be cancelled on dispose
  final List<StreamSubscription> _subscriptions = [];

  // Debounce timer for _saveState
  Timer? _saveDebounce;

  // Sleep timer & fadeout
  Timer? _sleepTimer;
  Timer? _fadeTimer;
  DateTime? _sleepTimerEndTime;
  double _preFadeVolume = 1.0;

  // Throttle for position updates: last notified position time
  DateTime _lastPositionNotify = DateTime.fromMillisecondsSinceEpoch(0);
  static const _positionThrottleMs = 180;

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

  // Sorting
  SongSortOption _sortOption = SongSortOption.title;
  bool _sortAscending = true;

  // ── Getters ────────────────────────────────────────────────────────────────
  List<PlayOnSong> get allSongs => _allSongs;
  List<PlayOnSong> get currentQueue => _currentQueue;
  List<String> get folders => _folders;
  Map<String, int> get folderSongCounts => _folderSongCounts;
  String? get selectedFolder => _selectedFolder;
  bool get isPlaying => _isPlaying;
  bool get isShuffle => _isShuffle;
  PlayerRepeatMode get repeatMode => _repeatMode;
  Duration get position => _position;
  Duration get duration => _duration;
  bool get isLoading => _isLoading;
  bool get hasSleepTimer => _sleepTimer != null && _sleepTimer!.isActive;
  SongSortOption get sortOption => _sortOption;
  bool get sortAscending => _sortAscending;

  Duration? get sleepTimeRemaining {
    if (_sleepTimerEndTime == null) {
      return null;
    }
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
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _saveDebounce?.cancel();
      _saveState();
    }
  }

  // ── Sorting ────────────────────────────────────────────────────────────────

  void setSortOption(SongSortOption option, {bool? ascending}) {
    if (_sortOption == option && ascending == null) {
      _sortAscending = !_sortAscending;
    } else {
      _sortOption = option;
      if (ascending != null) {
        _sortAscending = ascending;
      }
    }
    _applySort();
    _scheduleSaveState();
    notifyListeners();
  }

  void _applySort() {
    _allSongs.sort((a, b) {
      int cmp = 0;
      switch (_sortOption) {
        case SongSortOption.title:
          cmp = a.title.toLowerCase().compareTo(b.title.toLowerCase());
          break;
        case SongSortOption.artist:
          cmp = a.artist.toLowerCase().compareTo(b.artist.toLowerCase());
          if (cmp == 0) {
            cmp = a.title.toLowerCase().compareTo(b.title.toLowerCase());
          }
          break;
        case SongSortOption.album:
          cmp = a.album.toLowerCase().compareTo(b.album.toLowerCase());
          if (cmp == 0) {
            cmp = a.title.toLowerCase().compareTo(b.title.toLowerCase());
          }
          break;
        case SongSortOption.duration:
          cmp = a.duration.compareTo(b.duration);
          break;
        case SongSortOption.date:
          cmp = a.id.compareTo(b.id);
          break;
      }
      return _sortAscending ? cmp : -cmp;
    });
  }

  // ── State persistence ──────────────────────────────────────────────────────

  void _scheduleSaveState() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(seconds: 1), _saveState);
  }

  Future<void> _saveState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selectedFolder', _selectedFolder ?? '');
      await prefs.setInt('currentIndex', _currentIndex);
      if (currentSong != null) {
        await prefs.setInt('lastSongId', currentSong!.id);
      }
      if (_currentQueue.isNotEmpty) {
        await prefs.setStringList(
            'queueSongIds', _currentQueue.map((s) => s.id.toString()).toList());
      }
      await prefs.setBool('isShuffle', _isShuffle);
      await prefs.setInt('repeatMode', _repeatMode.index);
      await prefs.setInt('sortOption', _sortOption.index);
      await prefs.setBool('sortAscending', _sortAscending);
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

      final sortIdx = prefs.getInt('sortOption') ?? 0;
      if (sortIdx >= 0 && sortIdx < SongSortOption.values.length) {
        _sortOption = SongSortOption.values[sortIdx];
      }
      _sortAscending = prefs.getBool('sortAscending') ?? true;
      _applySort();

      final queueIds = prefs.getStringList('queueSongIds') ?? [];
      final lastSongId = prefs.getInt('lastSongId');

      if (queueIds.isNotEmpty) {
        final songMap = {for (final s in _allSongs) s.id: s};
        final restoredQueue = queueIds
            .map((idStr) => int.tryParse(idStr))
            .where((id) => id != null && songMap.containsKey(id))
            .map((id) => songMap[id]!)
            .toList();
        if (restoredQueue.isNotEmpty) {
          _currentQueue = restoredQueue;
        } else {
          _currentQueue = _selectedFolder != null
              ? _allSongs.where((s) => s.folderName == _selectedFolder).toList()
              : List.from(_allSongs);
        }
      } else {
        _currentQueue = _selectedFolder != null
            ? _allSongs.where((s) => s.folderName == _selectedFolder).toList()
            : List.from(_allSongs);
      }

      final savedIndex = prefs.getInt('currentIndex') ?? 0;
      if (lastSongId != null && lastSongId != -1) {
        final foundIndex = _currentQueue.indexWhere((s) => s.id == lastSongId);
        _currentIndex = (foundIndex != -1)
            ? foundIndex
            : ((savedIndex >= 0 && savedIndex < _currentQueue.length) ? savedIndex : 0);
      } else {
        _currentIndex = (savedIndex >= 0 && savedIndex < _currentQueue.length) ? savedIndex : 0;
      }

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
      _position = savedPosition;

      if (_currentIndex < _currentQueue.length) {
        _duration = Duration(milliseconds: _currentQueue[_currentIndex].duration);
      }

      if (_currentQueue.isNotEmpty) {
        await _updatePlaylist(
            initialIndex: _currentIndex, position: savedPosition);
      }
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
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
    } catch (e) {
      debugPrint('Error configuring audio session: $e');
    }

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

    _subscriptions.add(
      _player.androidAudioSessionIdStream.listen((sessionId) {
        if (sessionId != null && sessionId > 0) {
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
          .where((s) => s.duration != null && s.duration! > 5000)
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
          filePath: path,
        );
      }).toList();

      _applySort();

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

  void setFolderFilter(String? folder) {
    _selectedFolder = (folder == null || folder.isEmpty || folder == 'Todas' || folder == 'all') ? null : folder;
    _scheduleSaveState();
    notifyListeners();
  }

  void clearFolderFilter() {
    setFolderFilter(null);
  }

  Future<void> playFolder(String? folder, {int initialIndex = 0, bool shuffle = false}) async {
    final targetFolder = (folder == null || folder.isEmpty || folder == 'Todas' || folder == 'all') ? null : folder;
    _selectedFolder = targetFolder;

    List<PlayOnSong> queue;
    if (targetFolder == null) {
      queue = List<PlayOnSong>.from(_allSongs);
    } else {
      queue = _allSongs.where((s) => s.folderName == targetFolder).toList();
    }

    if (queue.isEmpty) return;

    if (shuffle) {
      queue.shuffle();
    }

    final safeIndex = (initialIndex >= 0 && initialIndex < queue.length) ? initialIndex : 0;
    await playCustomQueue(queue, safeIndex);
    _scheduleSaveState();
    notifyListeners();
  }

  void selectFolder(String? folder) {
    _selectedFolder = (folder == null || folder.isEmpty || folder == 'Todas' || folder == 'all') ? null : folder;
    if (_selectedFolder == null) {
      _currentQueue = List.from(_allSongs);
    } else {
      _currentQueue = _allSongs.where((s) => s.folderName == _selectedFolder).toList();
    }
    _currentIndex = 0;
    _updatePlaylist(initialIndex: 0);
    _scheduleSaveState();
    notifyListeners();
  }

  Future<void> _updatePlaylist(
      {int initialIndex = 0, Duration? position}) async {
    if (_currentQueue.isEmpty) {
      return;
    }

    final sources = _currentQueue
        .map((song) {
          final uri = (song.uri.startsWith('content://') ||
                  song.uri.startsWith('http://') ||
                  song.uri.startsWith('https://') ||
                  song.uri.startsWith('file://'))
              ? Uri.parse(song.uri)
              : Uri.file(song.filePath.isNotEmpty ? song.filePath : song.uri);

          return AudioSource.uri(
            uri,
            tag: MediaItem(
              id: song.id.toString(),
              title: song.title,
              artist: song.artist,
              album: song.album,
              artUri: null,
              duration: Duration(milliseconds: song.duration),
              playable: true,
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

  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _currentQueue.length ||
        newIndex < 0 || newIndex > _currentQueue.length) {
      return;
    }

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = _currentQueue.removeAt(oldIndex);
    _currentQueue.insert(newIndex, item);

    if (_currentIndex == oldIndex) {
      _currentIndex = newIndex;
    } else if (oldIndex < _currentIndex && newIndex >= _currentIndex) {
      _currentIndex -= 1;
    } else if (oldIndex > _currentIndex && newIndex <= _currentIndex) {
      _currentIndex += 1;
    }

    _updatePlaylist(initialIndex: _currentIndex, position: _position);
    _scheduleSaveState();
    notifyListeners();
  }

  void removeFromQueue(int index) {
    if (index < 0 || index >= _currentQueue.length) {
      return;
    }
    if (_currentQueue.length <= 1) {
      stop();
      _currentQueue.clear();
      _currentIndex = 0;
      notifyListeners();
      return;
    }

    final removingCurrent = index == _currentIndex;
    _currentQueue.removeAt(index);
    if (index < _currentIndex) {
      _currentIndex -= 1;
    } else if (_currentIndex >= _currentQueue.length) {
      _currentIndex = _currentQueue.length - 1;
    }

    if (removingCurrent) {
      playSong(_currentIndex);
    } else {
      _updatePlaylist(initialIndex: _currentIndex, position: _position);
    }

    _scheduleSaveState();
    notifyListeners();
  }

  void addToQueue(PlayOnSong song, {bool playNext = false}) {
    if (playNext && _currentQueue.isNotEmpty && _currentIndex < _currentQueue.length) {
      _currentQueue.insert(_currentIndex + 1, song);
    } else {
      _currentQueue.add(song);
    }
    _updatePlaylist(initialIndex: _currentIndex, position: _position);
    notifyListeners();
  }

  // ── Playback controls ──────────────────────────────────────────────────────

  Future<void> playSong(int index) async {
    if (index < 0 || index >= _currentQueue.length) {
      return;
    }

    if (_player.sequence.isEmpty || _player.sequence.length != _currentQueue.length) {
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
    if (index < 0 || index >= queue.length) {
      return;
    }
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

  // ── Sleep Timer & Smooth Fade-Out ──────────────────────────────────────────

  void setSleepTimer(Duration duration, {bool fadeOut = true}) {
    _cancelSleepTimers();
    _preFadeVolume = _player.volume;
    _sleepTimerEndTime = DateTime.now().add(duration);

    const fadeDuration = Duration(seconds: 20);
    if (fadeOut && duration > fadeDuration) {
      final fadeStartTime = duration - fadeDuration;
      _fadeTimer = Timer(fadeStartTime, () {
        _startVolumeFadeOut();
      });
    }

    _sleepTimer = Timer(duration, () async {
      await stop();
      await _player.setVolume(_preFadeVolume);
      _cancelSleepTimers();
      notifyListeners();
    });

    notifyListeners();
  }

  void _startVolumeFadeOut() {
    const steps = 20;
    const interval = Duration(seconds: 1);
    int currentStep = 0;
    final initialVol = _player.volume;

    Timer.periodic(interval, (timer) {
      currentStep++;
      if (currentStep >= steps || _sleepTimer == null) {
        timer.cancel();
        return;
      }
      final newVol = (initialVol * (1.0 - (currentStep / steps))).clamp(0.0, 1.0);
      _player.setVolume(newVol);
    });
  }

  void cancelSleepTimer() {
    _cancelSleepTimers();
    _player.setVolume(_preFadeVolume);
    notifyListeners();
  }

  void _cancelSleepTimers() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _fadeTimer?.cancel();
    _fadeTimer = null;
    _sleepTimerEndTime = null;
  }

  // ── Dispose ────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _cancelSleepTimers();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    WidgetsBinding.instance.removeObserver(this);
    _player.dispose();
    super.dispose();
  }
}
