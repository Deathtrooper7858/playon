import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yte;
import '../services/cookie_service.dart';
import '../services/native_media_scanner_service.dart';
import '../services/native_notification_service.dart';
import '../services/native_ytdlp_service.dart';
import 'music_provider.dart';

enum DownloadStatus { idle, fetchingInfo, downloading, done, error }

class DownloadedTrack {
  final String id;
  final String title;
  final String artist;
  final String url;
  final String? thumbnailUrl;
  final bool success;
  final String? error;

  const DownloadedTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.url,
    this.thumbnailUrl,
    required this.success,
    this.error,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'artist': artist,
        'url': url,
        'thumbnailUrl': thumbnailUrl,
        'success': success,
        'error': error,
      };

  factory DownloadedTrack.fromMap(Map<String, dynamic> map) => DownloadedTrack(
        id: map['id']?.toString() ?? '',
        title: map['title']?.toString() ?? '',
        artist: map['artist']?.toString() ?? '',
        url: map['url']?.toString() ?? '',
        thumbnailUrl: map['thumbnailUrl']?.toString(),
        success: map['success'] as bool? ?? false,
        error: map['error']?.toString(),
      );
}

class RecentDownloadItem {
  final String folderName;
  final String playlistTitle;
  final int trackCount;
  final DateTime date;

  const RecentDownloadItem({
    required this.folderName,
    required this.playlistTitle,
    required this.trackCount,
    required this.date,
  });

  Map<String, dynamic> toMap() => {
        'folderName': folderName,
        'playlistTitle': playlistTitle,
        'trackCount': trackCount,
        'date': date.millisecondsSinceEpoch,
      };

  factory RecentDownloadItem.fromMap(Map<String, dynamic> map) => RecentDownloadItem(
        folderName: map['folderName']?.toString() ?? '',
        playlistTitle: map['playlistTitle']?.toString() ?? '',
        trackCount: map['trackCount'] as int? ?? 0,
        date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int? ?? 0),
      );
}

class DownloadProvider extends ChangeNotifier {
  final MusicProvider _musicProvider;

  DownloadStatus _status = DownloadStatus.idle;
  String _playlistName = '';
  String _currentTrack = '';
  int _downloaded = 0;
  int _total = 0;
  String _errorMessage = '';
  List<DownloadedTrack> _completedTracks = [];
  bool _cancelled = false;
  double _currentTrackProgress = 0.0;
  String _currentSpeed = '';
  String _statusMessage = '';
  List<RecentDownloadItem> _recentDownloads = [];

  // Getters
  DownloadStatus get status => _status;
  String get playlistName => _playlistName;
  String get currentTrack => _currentTrack;
  int get downloaded => _downloaded;
  int get total => _total;
  String get errorMessage => _errorMessage;
  List<DownloadedTrack> get completedTracks => List.unmodifiable(_completedTracks);
  double get currentTrackProgress => _currentTrackProgress;
  String get currentSpeed => _currentSpeed;
  String get statusMessage => _statusMessage;
  List<RecentDownloadItem> get recentDownloads => List.unmodifiable(_recentDownloads);

  double get progress => _total > 0 ? _downloaded / _total : 0.0;
  bool get isActive =>
      _status == DownloadStatus.fetchingInfo ||
      _status == DownloadStatus.downloading;

  DownloadProvider(this._musicProvider) {
    _loadRecentDownloads();
  }

  Future<void> _loadRecentDownloads() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('recent_downloads') ?? [];
      _recentDownloads = list
          .map((item) => RecentDownloadItem.fromMap(jsonDecode(item) as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _saveRecentDownload(String folderName, String title, int count) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final item = RecentDownloadItem(
        folderName: folderName,
        playlistTitle: title,
        trackCount: count,
        date: DateTime.now(),
      );
      _recentDownloads.removeWhere((r) => r.folderName == folderName);
      _recentDownloads.insert(0, item);
      if (_recentDownloads.length > 10) {
        _recentDownloads = _recentDownloads.sublist(0, 10);
      }
      final strList = _recentDownloads.map((r) => jsonEncode(r.toMap())).toList();
      await prefs.setStringList('recent_downloads', strList);
      notifyListeners();
    } catch (_) {}
  }

  void cancel() {
    _cancelled = true;
    _status = DownloadStatus.idle;
    _statusMessage = '';
    NativeNotificationService.cancelNotification();
    notifyListeners();
  }

  void reset() {
    _status = DownloadStatus.idle;
    _playlistName = '';
    _currentTrack = '';
    _downloaded = 0;
    _total = 0;
    _errorMessage = '';
    _completedTracks = [];
    _cancelled = false;
    _currentTrackProgress = 0.0;
    _currentSpeed = '';
    _statusMessage = '';
    notifyListeners();
  }

  // ── Solicitar permisos de almacenamiento ──────────────────────────────────
  Future<bool> _requestStoragePermission() async {
    if (!Platform.isAndroid) return true;
    if (await Permission.storage.isGranted) return true;
    final result = await Permission.storage.request();
    if (result.isGranted) return true;
    return true; // Scoped storage en Android 11+
  }

  String _normalizeUrl(String rawUrl) {
    var url = rawUrl.trim();
    // YouTube Music normalización
    url = url.replaceAll('music.youtube.com', 'www.youtube.com');

    // Manejar browse links de YT Music como browse/VLPLxxx -> playlist?list=PLxxx
    if (url.contains('/browse/VL')) {
      url = url.replaceAll('/browse/VL', '/playlist?list=');
    }

    return url;
  }

  String _cleanTrackTitle(String rawTitle) {
    final cleaned = rawTitle.replaceAll(
      RegExp(
        r'[\(\[\{]\s*(?:official\s*video|official\s*audio|official\s*music\s*video|video\s*oficial|audio\s*oficial|letra|lyrics|video\s*con\s*letra|videoclip|hd|4k|remastered|visualizer|audio|lyric\s*video)\s*[\)\]\}]',
        caseSensitive: false,
      ),
      '',
    );
    return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  Future<void> downloadPlaylist(String url, String? customName) async {
    _cancelled = false;
    _status = DownloadStatus.fetchingInfo;
    _downloaded = 0;
    _total = 0;
    _completedTracks = [];
    _errorMessage = '';
    _statusMessage = '';
    notifyListeners();

    await _requestStoragePermission();

    final cookieString = await CookieService.getCookies();
    final normalizedUrl = _normalizeUrl(url);
    final rng = Random();

    String resolvedPlaylistTitle = 'Descarga';
    List<DownloadedTrack> resolvedTracks = [];

    // ── 1. Intentar resolver con youtube_explode_dart ────────────────────────
    final yt = (cookieString != null && cookieString.isNotEmpty)
        ? yte.YoutubeExplode(httpClient: _CookieHttpClient(cookieString))
        : yte.YoutubeExplode();

    try {
      try {
        // Extraer si es playlist
        if (normalizedUrl.contains('list=')) {
          final uri = Uri.tryParse(normalizedUrl);
          final listId = uri?.queryParameters['list'];
          if (listId != null && listId.isNotEmpty) {
            final playlist = await yt.playlists.get(listId);
            resolvedPlaylistTitle = playlist.title;
            final videos = await yt.playlists.getVideos(playlist.id).toList();
            for (final v in videos) {
              resolvedTracks.add(DownloadedTrack(
                id: v.id.value,
                title: _cleanTrackTitle(v.title),
                artist: v.author,
                url: 'https://www.youtube.com/watch?v=${v.id.value}',
                thumbnailUrl: v.thumbnails.highResUrl,
                success: false,
              ));
            }
          }
        }

        if (resolvedTracks.isEmpty) {
          // Intentar como video individual
          final video = await yt.videos.get(yte.VideoId(normalizedUrl));
          resolvedPlaylistTitle = _cleanTrackTitle(video.title);
          resolvedTracks.add(DownloadedTrack(
            id: video.id.value,
            title: _cleanTrackTitle(video.title),
            artist: video.author,
            url: 'https://www.youtube.com/watch?v=${video.id.value}',
            thumbnailUrl: video.thumbnails.highResUrl,
            success: false,
          ));
        }
      } catch (eExplode) {
        debugPrint('youtube_explode_dart no pudo resolver, usando motor yt-dlp nativo: $eExplode');
        // Fallback a motor yt-dlp nativo
        final info = await NativeYtDlpService.getPlaylistInfo(normalizedUrl, cookies: cookieString);
        resolvedPlaylistTitle = info.title;
        for (final t in info.tracks) {
          resolvedTracks.add(DownloadedTrack(
            id: t.id,
            title: _cleanTrackTitle(t.title),
            artist: t.artist,
            url: t.url,
            thumbnailUrl: t.thumbnail.isNotEmpty ? t.thumbnail : null,
            success: false,
          ));
        }
      }
    } catch (eAll) {
      _status = DownloadStatus.error;
      _errorMessage = 'No se pudo resolver el enlace de YouTube Music.\nDetalle: $eAll';
      NativeNotificationService.cancelNotification();
      yt.close();
      notifyListeners();
      return;
    } finally {
      yt.close();
    }

    if (_cancelled) return;

    if (resolvedTracks.isEmpty) {
      _status = DownloadStatus.error;
      _errorMessage = 'No se encontraron canciones en el enlace especificado.';
      notifyListeners();
      return;
    }

    // ── 2. Preparar carpeta destino ──────────────────────────────────────────
    final rawName = (customName?.trim().isNotEmpty == true)
        ? customName!.trim()
        : resolvedPlaylistTitle;

    final folderName = rawName.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_').trim();
    _playlistName = folderName;
    _total = resolvedTracks.length;
    _status = DownloadStatus.downloading;
    notifyListeners();

    final baseDir = await _getMusicDirectory();
    final playlistDir = Directory('${baseDir.path}/$folderName');
    await playlistDir.create(recursive: true);

    // ── 3. Descargar cada canción ───────────────────────────────────────────
    for (int i = 0; i < resolvedTracks.length; i++) {
      if (_cancelled) break;

      final track = resolvedTracks[i];
      _currentTrack = track.title;
      _statusMessage = '';
      notifyListeners();

      final safeTitle = track.title.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_').trim();
      final fileName = '${(i + 1).toString().padLeft(3, '0')} - $safeTitle.m4a';
      final filePath = '${playlistDir.path}/$fileName';

      // Si ya existe (reanudación)
      if (File(filePath).existsSync() && File(filePath).lengthSync() > 1024) {
        _downloaded++;
        _completedTracks.add(DownloadedTrack(
          id: track.id,
          title: track.title,
          artist: track.artist,
          url: track.url,
          thumbnailUrl: track.thumbnailUrl,
          success: true,
        ));
        notifyListeners();
        continue;
      }

      bool trackSuccess = false;
      String? trackError;

      try {
        _statusMessage = 'Descargando audio y metadatos...';
        notifyListeners();

        await NativeNotificationService.updateProgress(
          title: 'Descargando "$_playlistName"',
          text: '[$track.artist] $track.title (${i + 1}/$_total)',
          progress: i + 1,
          max: _total,
        );

        await NativeYtDlpService.downloadAudio(
          url: track.url,
          outPath: filePath,
          title: track.title,
          artist: track.artist,
          album: _playlistName,
          thumbnailUrl: track.thumbnailUrl,
          cookies: cookieString,
        );

        trackSuccess = true;
        await NativeMediaScannerService.scanFile(filePath);
      } catch (e) {
        trackError = e.toString().replaceFirst('Exception: ', '');
        debugPrint('Error descargando "${track.title}": $e');
      }

      _completedTracks.add(DownloadedTrack(
        id: track.id,
        title: track.title,
        artist: track.artist,
        url: track.url,
        thumbnailUrl: track.thumbnailUrl,
        success: trackSuccess,
        error: trackError,
      ));
      _downloaded++;
      notifyListeners();

      // Delay anti rate-limit
      if (!_cancelled && i < resolvedTracks.length - 1) {
        int delaySecs = 1 + rng.nextInt(2);
        _statusMessage = 'Pausa breve...';
        notifyListeners();
        await Future.delayed(Duration(seconds: delaySecs));
        _statusMessage = '';
        notifyListeners();
      }
    }

    // ── 4. Finalizado ───────────────────────────────────────────────────────
    if (!_cancelled) {
      _status = DownloadStatus.done;
      _statusMessage = '';
      await NativeNotificationService.finishProgress(
        title: 'Descarga finalizada',
        text: 'Se completaron $_downloaded de $_total canciones en "$_playlistName"',
      );
      await _saveRecentDownload(_playlistName, resolvedPlaylistTitle, _downloaded);
      await _musicProvider.loadSongs();
    }
    notifyListeners();
  }

  Future<void> retryFailedTracks() async {
    final failed = _completedTracks.where((t) => !t.success).toList();
    if (failed.isEmpty || _playlistName.isEmpty) return;

    _cancelled = false;
    _status = DownloadStatus.downloading;
    _errorMessage = '';
    notifyListeners();

    final cookieString = await CookieService.getCookies();
    final baseDir = await _getMusicDirectory();
    final playlistDir = Directory('${baseDir.path}/$_playlistName');
    final rng = Random();

    for (final track in failed) {
      if (_cancelled) break;

      _currentTrack = track.title;
      _statusMessage = 'Reintentando descarga...';
      notifyListeners();

      final safeTitle = track.title.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_').trim();
      final index = _completedTracks.indexOf(track);
      final fileName = '${(index + 1).toString().padLeft(3, '0')} - $safeTitle.m4a';
      final filePath = '${playlistDir.path}/$fileName';

      bool success = false;
      String? error;

      try {
        await NativeYtDlpService.downloadAudio(
          url: track.url,
          outPath: filePath,
          title: track.title,
          artist: track.artist,
          album: _playlistName,
          thumbnailUrl: track.thumbnailUrl,
          cookies: cookieString,
        );
        success = true;
        await NativeMediaScannerService.scanFile(filePath);
      } catch (e) {
        error = e.toString().replaceFirst('Exception: ', '');
      }

      final updatedTrack = DownloadedTrack(
        id: track.id,
        title: track.title,
        artist: track.artist,
        url: track.url,
        thumbnailUrl: track.thumbnailUrl,
        success: success,
        error: error,
      );

      _completedTracks[index] = updatedTrack;
      notifyListeners();

      await Future.delayed(Duration(seconds: 1 + rng.nextInt(2)));
    }

    _status = DownloadStatus.done;
    _statusMessage = '';
    await _musicProvider.loadSongs();
    notifyListeners();
  }

  Future<Directory> _getMusicDirectory() async {
    if (Platform.isAndroid) {
      try {
        final List<Directory>? externalDirs = await getExternalStorageDirectories();
        if (externalDirs != null && externalDirs.isNotEmpty) {
          final root = externalDirs.first.path.split('Android/data').first;
          final separator = root.endsWith('/') ? '' : '/';
          final musicDir = Directory('$root${separator}Music');
          await musicDir.create(recursive: true);
          return musicDir;
        }
      } catch (e) {
        debugPrint('Error obteniendo directorio externo: $e');
      }
    }
    final docs = await getApplicationDocumentsDirectory();
    final musicDir = Directory('${docs.path}/Music');
    await musicDir.create(recursive: true);
    return musicDir;
  }
}

class _CookieHttpClient extends yte.YoutubeHttpClient {
  final String _cookieString;

  _CookieHttpClient(this._cookieString);

  @override
  Map<String, String> get headers => {
        ...yte.YoutubeHttpClient.defaultHeaders,
        'cookie': _cookieString,
      };
}
