import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yte;
import '../models/video_model.dart';
import '../services/cookie_service.dart';
import '../services/native_media_scanner_service.dart';
import '../services/native_notification_service.dart';
import '../services/native_ytdlp_service.dart';
import '../services/file_management_service.dart';
import 'music_provider.dart';
import 'video_provider.dart';

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
  final bool isVideo;
  final String? lastVideoPath;
  final String? lastThumbnailPath;

  const RecentDownloadItem({
    required this.folderName,
    required this.playlistTitle,
    required this.trackCount,
    required this.date,
    this.isVideo = false,
    this.lastVideoPath,
    this.lastThumbnailPath,
  });

  Map<String, dynamic> toMap() => {
        'folderName': folderName,
        'playlistTitle': playlistTitle,
        'trackCount': trackCount,
        'date': date.millisecondsSinceEpoch,
        'isVideo': isVideo,
        'lastVideoPath': lastVideoPath,
        'lastThumbnailPath': lastThumbnailPath,
      };

  factory RecentDownloadItem.fromMap(Map<String, dynamic> map) => RecentDownloadItem(
        folderName: map['folderName']?.toString() ?? '',
        playlistTitle: map['playlistTitle']?.toString() ?? '',
        trackCount: map['trackCount'] as int? ?? 0,
        date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int? ?? 0),
        isVideo: map['isVideo'] as bool? ?? false,
        lastVideoPath: map['lastVideoPath']?.toString(),
        lastThumbnailPath: map['lastThumbnailPath']?.toString(),
      );
}

class DownloadProvider extends ChangeNotifier {
  final MusicProvider _musicProvider;
  final VideoProvider? _videoProvider;

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

  bool _isVideoDownload = false;
  String _videoQuality = 'best';
  String? _lastDownloadedVideoPath;
  String? _lastDownloadedThumbnailPath;
  String? _lastTargetFolderPath;

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
  bool get isVideoDownload => _isVideoDownload;
  String get videoQuality => _videoQuality;
  String? get lastDownloadedVideoPath => _lastDownloadedVideoPath;
  String? get lastDownloadedThumbnailPath => _lastDownloadedThumbnailPath;
  String? get lastTargetFolderPath => _lastTargetFolderPath;

  double get progress => _total > 0 ? _downloaded / _total : 0.0;
  bool get isActive =>
      _status == DownloadStatus.fetchingInfo ||
      _status == DownloadStatus.downloading;

  DownloadProvider(this._musicProvider, {VideoProvider? videoProvider})
      : _videoProvider = videoProvider {
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

  Future<void> _saveRecentDownload(
    String folderName,
    String title,
    int count, {
    bool isVideo = false,
    String? lastVideoPath,
    String? lastThumbnailPath,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final item = RecentDownloadItem(
        folderName: folderName,
        playlistTitle: title,
        trackCount: count,
        date: DateTime.now(),
        isVideo: isVideo,
        lastVideoPath: lastVideoPath,
        lastThumbnailPath: lastThumbnailPath,
      );
      _recentDownloads.removeWhere((r) => r.folderName == folderName && r.isVideo == isVideo);
      _recentDownloads.insert(0, item);
      if (_recentDownloads.length > 15) {
        _recentDownloads = _recentDownloads.sublist(0, 15);
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
    _isVideoDownload = false;
    _videoQuality = 'best';
    _lastDownloadedVideoPath = null;
    _lastDownloadedThumbnailPath = null;
    _lastTargetFolderPath = null;
    notifyListeners();
  }

  // ── Solicitar permisos de almacenamiento ──────────────────────────────────
  Future<bool> _requestStoragePermission({bool isVideo = false}) async {
    if (!Platform.isAndroid) return true;
    try {
      if (await Permission.manageExternalStorage.isGranted) return true;
      final manageStatus = await Permission.manageExternalStorage.request();
      if (manageStatus.isGranted) return true;
    } catch (_) {}

    if (isVideo) {
      try {
        if (await Permission.videos.isGranted) return true;
        await Permission.videos.request();
      } catch (_) {}
    } else {
      try {
        if (await Permission.audio.isGranted) return true;
        await Permission.audio.request();
      } catch (_) {}
    }

    try {
      if (await Permission.storage.isGranted) return true;
      final result = await Permission.storage.request();
      return result.isGranted;
    } catch (_) {}
    return true;
  }

  String? _extractVideoId(String rawUrl) {
    final clean = rawUrl.trim();
    final uri = Uri.tryParse(clean);
    if (uri != null) {
      if (uri.queryParameters.containsKey('v')) {
        return uri.queryParameters['v'];
      }
      if (uri.host.contains('youtu.be') && uri.pathSegments.isNotEmpty) {
        return uri.pathSegments.first;
      }
      if (uri.pathSegments.contains('shorts') && uri.pathSegments.length > 1) {
        final idx = uri.pathSegments.indexOf('shorts');
        if (idx + 1 < uri.pathSegments.length) {
          return uri.pathSegments[idx + 1];
        }
      }
    }
    final match = RegExp(r'(?:v=|\/|youtu\.be\/)([0-9A-Za-z_-]{11})(?:[&?]|\b|$)').firstMatch(clean);
    return match?.group(1);
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

  (String, String) _splitArtistAndTitle(String rawTitle, String rawAuthor) {
    final clean = _cleanTrackTitle(rawTitle);
    for (final sep in [' - ', ' – ', ' — ']) {
      if (clean.contains(sep)) {
        final parts = clean.split(sep);
        if (parts.length >= 2) {
          final possibleArtist = parts[0].trim();
          final possibleTitle = parts.sublist(1).join(sep).trim();
          if (possibleArtist.isNotEmpty && possibleTitle.isNotEmpty) {
            return (possibleArtist, possibleTitle);
          }
        }
      }
    }
    final safeArtist = rawAuthor.isNotEmpty ? rawAuthor : 'Artista desconocido';
    return (safeArtist, clean.isNotEmpty ? clean : 'Pista sin título');
  }

  Future<void> downloadPlaylist(
    String url,
    String? customName, {
    bool singleTrackOnly = false,
    bool isVideo = false,
    String? customBasePath,
    String videoQuality = 'best',
  }) async {
    _cancelled = false;
    _status = DownloadStatus.fetchingInfo;
    _downloaded = 0;
    _total = 0;
    _completedTracks = [];
    _errorMessage = '';
    _isVideoDownload = isVideo;
    _videoQuality = videoQuality;
    _lastDownloadedVideoPath = null;
    _lastDownloadedThumbnailPath = null;
    _lastTargetFolderPath = null;
    _statusMessage = 'Obteniendo información del enlace...';
    notifyListeners();

    await _requestStoragePermission(isVideo: isVideo);

    final cookieString = await CookieService.getCookies();
    var normalizedUrl = _normalizeUrl(url);

    // Si se solicitó solo la canción individual o si la URL es un video directo
    final extractedVid = _extractVideoId(normalizedUrl);
    if (singleTrackOnly && extractedVid != null) {
      normalizedUrl = 'https://www.youtube.com/watch?v=$extractedVid';
    }

    String resolvedPlaylistTitle = isVideo ? 'My videos' : 'Descargas';
    List<DownloadedTrack> resolvedTracks = [];

    // ── 1. Intentar resolver con youtube_explode_dart (Rápido: ~1s) ───────────
    final yt = (cookieString != null && cookieString.isNotEmpty)
        ? yte.YoutubeExplode(httpClient: _CookieHttpClient(cookieString))
        : yte.YoutubeExplode();

    try {
      try {
        if (!singleTrackOnly && normalizedUrl.contains('list=')) {
          final uri = Uri.tryParse(normalizedUrl);
          final listId = uri?.queryParameters['list'];
          if (listId != null && listId.isNotEmpty && !listId.startsWith('RD')) {
            final playlist = await yt.playlists.get(listId).timeout(const Duration(seconds: 30));
            resolvedPlaylistTitle = playlist.title;
            final videos = await yt.playlists.getVideos(playlist.id).toList().timeout(const Duration(seconds: 45));
            for (final v in videos) {
              final (artist, title) = _splitArtistAndTitle(v.title, v.author);
              resolvedTracks.add(DownloadedTrack(
                id: v.id.value,
                title: title,
                artist: artist,
                url: 'https://www.youtube.com/watch?v=${v.id.value}',
                thumbnailUrl: v.thumbnails.highResUrl,
                success: false,
              ));
            }
          }
        }

        if (resolvedTracks.isEmpty) {
          final vidId = extractedVid ?? normalizedUrl;
          final video = await yt.videos.get(yte.VideoId(vidId)).timeout(const Duration(seconds: 30));
          final (artist, title) = _splitArtistAndTitle(video.title, video.author);
          resolvedPlaylistTitle = title;
          resolvedTracks.add(DownloadedTrack(
            id: video.id.value,
            title: title,
            artist: artist,
            url: 'https://www.youtube.com/watch?v=${video.id.value}',
            thumbnailUrl: video.thumbnails.highResUrl,
            success: false,
          ));
        }
      } catch (eExplode) {
        debugPrint('youtube_explode no pudo resolver: $eExplode');
      }

      // ── 2. Fallback a yt-dlp si youtube_explode no pudo (ej: YT Music) ────────
      if (resolvedTracks.isEmpty) {
        try {
          final info = await NativeYtDlpService.getPlaylistInfo(
            normalizedUrl,
            cookies: cookieString,
            extractSingle: singleTrackOnly || (extractedVid != null && !normalizedUrl.contains('list=PL')),
          ).timeout(const Duration(seconds: 40));

          if (info.tracks.isNotEmpty) {
            resolvedPlaylistTitle = info.title;
            for (final t in info.tracks) {
              final (artist, title) = _splitArtistAndTitle(t.title, t.artist);
              resolvedTracks.add(DownloadedTrack(
                id: t.id,
                title: title,
                artist: artist,
                url: t.url,
                thumbnailUrl: t.thumbnail.isNotEmpty ? t.thumbnail : null,
                success: false,
              ));
            }
          }
        } catch (eYtdlp) {
          debugPrint('yt-dlp tampoco pudo resolver: $eYtdlp');
        }
      }
    } finally {
      yt.close();
    }

    try {
      if (_cancelled) return;

      if (resolvedTracks.isEmpty) {
        _status = DownloadStatus.error;
        _errorMessage = 'No se pudo obtener información del enlace. Verifica que la URL sea válida o que tengas conexión.';
        notifyListeners();
        return;
      }

      // ── 2. Preparar carpeta destino ──────────────────────────────────────────
      String folderName;
      String? existingFolderPath;

      if (customName != null && customName.trim().isNotEmpty) {
        folderName = customName.trim();
        if (isVideo) {
          if (_videoProvider != null) {
            for (final v in _videoProvider!.videos) {
              if (v.folderName == folderName && v.folderPath.isNotEmpty) {
                existingFolderPath = v.folderPath;
                break;
              }
            }
          }
        } else {
          for (final s in _musicProvider.allSongs) {
            if (s.folderName == folderName && s.folderPath != null && s.folderPath!.isNotEmpty) {
              existingFolderPath = s.folderPath;
              break;
            }
          }
        }
      } else {
        if (isVideo) {
          // Por defecto para videos: "My videos"
          folderName = 'My videos';
        } else {
          if (resolvedTracks.length > 1 &&
              resolvedPlaylistTitle.isNotEmpty &&
              resolvedPlaylistTitle != 'Descargas' &&
              resolvedPlaylistTitle != 'Descarga') {
            folderName = resolvedPlaylistTitle;
          } else {
            folderName = 'Descargas';
          }
        }
      }

      folderName = FileManagementService.sanitizeFileName(folderName);
      if (folderName.isEmpty || folderName == 'unnamed') {
        folderName = isVideo ? 'My videos' : 'Descargas';
      }

      _playlistName = folderName;
      _total = resolvedTracks.length;
      _status = DownloadStatus.downloading;
      notifyListeners();

      Directory targetDir;
      if (existingFolderPath != null && Directory(existingFolderPath).existsSync()) {
        targetDir = Directory(existingFolderPath);
      } else if (isVideo) {
        final baseDir = await _getVideoDirectory(customBasePath: customBasePath);
        targetDir = Directory('${baseDir.path}/$folderName');
      } else {
        final baseDir = await _getMusicDirectory();
        targetDir = Directory('${baseDir.path}/$folderName');
      }
      await targetDir.create(recursive: true);
      _lastTargetFolderPath = targetDir.path;

      final extension = isVideo ? 'mp4' : 'm4a';

      // ── 3. Descargar cada elemento (Audio o Video) ───────────────────────────
      for (int i = 0; i < resolvedTracks.length; i++) {
        if (_cancelled) break;

        final track = resolvedTracks[i];
        _currentTrack = track.title;
        _currentTrackProgress = 0.0;
        _currentSpeed = '';
        _statusMessage = 'Descargando ${i + 1} de $_total...';
        notifyListeners();

        final safeTitle = FileManagementService.sanitizeFileName(track.title);
        final fileName = resolvedTracks.length > 1
            ? '${(i + 1).toString().padLeft(3, '0')} - $safeTitle.$extension'
            : '$safeTitle.$extension';
        final filePath = '${targetDir.path}/$fileName';

        // Si ya existe (reanudación)
        if (File(filePath).existsSync() && File(filePath).lengthSync() > 1024) {
          _downloaded++;
          if (isVideo) {
            _lastDownloadedVideoPath = filePath;
            final thumbPath = filePath.replaceFirst('.mp4', '.thumb.jpg');
            if (File(thumbPath).existsSync()) {
              _lastDownloadedThumbnailPath = thumbPath;
            }
          }
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
          if (isVideo) {
            await NativeNotificationService.updateProgress(
              title: 'Descargando video "$_playlistName"',
              text: '[${track.artist}] ${track.title} (${i + 1}/$_total)',
              progress: i + 1,
              max: _total,
            );

            try {
              await NativeYtDlpService.downloadVideo(
                url: track.url,
                outPath: filePath,
                title: track.title,
                artist: track.artist,
                album: _playlistName,
                thumbnailUrl: track.thumbnailUrl,
                cookies: cookieString,
                quality: _videoQuality,
              );
            } catch (eYtdlp) {
              debugPrint('yt-dlp falló, activando fallback de video con youtube_explode_dart: $eYtdlp');
              await _downloadVideoWithYtExplode(track, filePath, cookieString, videoQuality: _videoQuality);
            }
          } else {
            await NativeNotificationService.updateProgress(
              title: 'Descargando "$_playlistName"',
              text: '[${track.artist}] ${track.title} (${i + 1}/$_total)',
              progress: i + 1,
              max: _total,
            );

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
            } catch (eYtdlp) {
              debugPrint('yt-dlp falló, activando fallback de audio con youtube_explode_dart: $eYtdlp');
              await _downloadAudioWithYtExplode(track, filePath, cookieString);
            }
          }

          final savedFile = File(filePath);
          if (savedFile.existsSync() && savedFile.lengthSync() > 1024) {
            trackSuccess = true;
            try {
              await NativeMediaScannerService.scanFile(filePath);
            } catch (_) {}

            if (isVideo) {
              _lastDownloadedVideoPath = filePath;
              final thumbPath = filePath.replaceFirst('.mp4', '.thumb.jpg');
              if (File(thumbPath).existsSync()) {
                _lastDownloadedThumbnailPath = thumbPath;
              }
              final videoObj = PlayOnVideo(
                id: track.id,
                title: track.title,
                author: track.artist,
                filePath: filePath,
                thumbnailPath: File(thumbPath).existsSync() ? thumbPath : null,
                thumbnailUrl: track.thumbnailUrl,
                duration: 0,
                fileSize: savedFile.lengthSync(),
                dateAdded: DateTime.now(),
                folderName: _playlistName,
                folderPath: targetDir.path,
              );
              await _videoProvider?.registerDownloadedVideo(videoObj);
            }
          } else {
            trackError = 'No se pudo generar el archivo';
          }
        } catch (e) {
          final errStr = e.toString().replaceFirst('Exception: ', '');
          if (errStr.contains('Sign in to confirm') || errStr.contains('bot')) {
            trackError = 'YouTube bloqueó temporalmente. Toca "Sin sesión" arriba para validar.';
          } else {
            trackError = errStr;
          }
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
        _currentTrackProgress = 0.0;
        _currentSpeed = '';
        notifyListeners();

        // Pausa breve anti rate-limit
        if (!_cancelled && i < resolvedTracks.length - 1) {
          await Future.delayed(const Duration(milliseconds: 300));
        }
      }

      // ── 4. Finalizado ───────────────────────────────────────────────────────
      if (!_cancelled) {
        _status = DownloadStatus.done;
        _statusMessage = '';
        _currentSpeed = '';
        _currentTrackProgress = 0.0;
        final successfulCount = _completedTracks.where((t) => t.success).length;
        await NativeNotificationService.finishProgress(
          title: isVideo ? 'Descarga de video finalizada' : 'Descarga finalizada',
          text: 'Se completaron $successfulCount de $_total ${isVideo ? "videos" : "canciones"} en "$_playlistName"',
        );
        if (successfulCount > 0) {
          await _saveRecentDownload(
            _playlistName,
            resolvedPlaylistTitle,
            successfulCount,
            isVideo: isVideo,
            lastVideoPath: _lastDownloadedVideoPath,
            lastThumbnailPath: _lastDownloadedThumbnailPath,
          );
          if (isVideo) {
            await _videoProvider?.loadVideos();
          } else {
            await _musicProvider.loadSongs();
          }
        }
      }
    } catch (eAll) {
      _status = DownloadStatus.error;
      _errorMessage = 'No se pudo procesar la descarga.\nDetalle: $eAll';
      NativeNotificationService.cancelNotification();
    } finally {
      notifyListeners();
    }
  }

  Future<void> retryFailedTracks() async {
    final failed = _completedTracks.where((t) => !t.success).toList();
    if (failed.isEmpty || _playlistName.isEmpty) return;

    _cancelled = false;
    _status = DownloadStatus.downloading;
    _errorMessage = '';
    notifyListeners();

    final cookieString = await CookieService.getCookies();
    final isVideo = _isVideoDownload;
    final Directory playlistDir;
    if (_lastTargetFolderPath != null && Directory(_lastTargetFolderPath!).existsSync()) {
      playlistDir = Directory(_lastTargetFolderPath!);
    } else if (isVideo) {
      final baseDir = await _getVideoDirectory();
      playlistDir = Directory('${baseDir.path}/$_playlistName');
    } else {
      final baseDir = await _getMusicDirectory();
      playlistDir = Directory('${baseDir.path}/$_playlistName');
    }

    final extension = isVideo ? 'mp4' : 'm4a';

    for (int retryIdx = 0; retryIdx < failed.length; retryIdx++) {
      if (_cancelled) break;
      final track = failed[retryIdx];

      _currentTrack = track.title;
      _currentTrackProgress = 0.0;
      _currentSpeed = '';
      _statusMessage = 'Reintentando ${retryIdx + 1} de ${failed.length}...';
      notifyListeners();

      final safeTitle = FileManagementService.sanitizeFileName(track.title);
      final index = _completedTracks.indexOf(track);
      final fileName = '${(index + 1).toString().padLeft(3, '0')} - $safeTitle.$extension';
      final filePath = '${playlistDir.path}/$fileName';
      bool success = false;
      String? error;

      try {
        await NativeNotificationService.updateProgress(
          title: 'Reintentando "$_playlistName"',
          text: '[${track.artist}] ${track.title} (${retryIdx + 1}/${failed.length})',
          progress: retryIdx + 1,
          max: failed.length,
        );

        if (isVideo) {
          try {
            await NativeYtDlpService.downloadVideo(
              url: track.url,
              outPath: filePath,
              title: track.title,
              artist: track.artist,
              album: _playlistName,
              thumbnailUrl: track.thumbnailUrl,
              cookies: cookieString,
              quality: _videoQuality,
            );
          } catch (eYtdlp) {
            debugPrint('yt-dlp falló en reintento, usando youtube_explode_dart: $eYtdlp');
            await _downloadVideoWithYtExplode(track, filePath, cookieString, videoQuality: _videoQuality);
          }
        } else {
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
          } catch (eYtdlp) {
            debugPrint('yt-dlp falló en reintento, usando youtube_explode_dart: $eYtdlp');
            await _downloadAudioWithYtExplode(track, filePath, cookieString);
          }
        }

        final savedFile = File(filePath);
        if (savedFile.existsSync() && savedFile.lengthSync() > 1024) {
          success = true;
          try {
            await NativeMediaScannerService.scanFile(filePath);
          } catch (_) {}

          if (isVideo) {
            _lastDownloadedVideoPath = filePath;
            final thumbPath = filePath.replaceFirst('.mp4', '.thumb.jpg');
            if (File(thumbPath).existsSync()) {
              _lastDownloadedThumbnailPath = thumbPath;
            }
            final videoObj = PlayOnVideo(
              id: track.id,
              title: track.title,
              author: track.artist,
              filePath: filePath,
              thumbnailPath: File(thumbPath).existsSync() ? thumbPath : null,
              thumbnailUrl: track.thumbnailUrl,
              duration: 0,
              fileSize: savedFile.lengthSync(),
              dateAdded: DateTime.now(),
              folderName: _playlistName,
              folderPath: playlistDir.path,
            );
            await _videoProvider?.registerDownloadedVideo(videoObj);
          }
        } else {
          error = 'No se pudo generar el archivo';
        }
      } catch (e) {
        final errStr = e.toString().replaceFirst('Exception: ', '');
        if (errStr.contains('Sign in to confirm') || errStr.contains('bot')) {
          error = 'Requiere sesión de YouTube para descargar.';
        } else {
          error = errStr;
        }
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
      _downloaded = _completedTracks.where((t) => t.success).length;
      notifyListeners();

      if (!_cancelled) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }

    _status = DownloadStatus.done;
    _statusMessage = '';
    _currentSpeed = '';
    _currentTrackProgress = 0.0;
    final successfulCount = _completedTracks.where((t) => t.success).length;
    await NativeNotificationService.finishProgress(
      title: 'Reintento finalizado',
      text: 'Completadas $successfulCount de $_total en "$_playlistName"',
    );
    if (successfulCount > 0) {
      await _saveRecentDownload(
        _playlistName,
        _playlistName,
        successfulCount,
        isVideo: isVideo,
        lastVideoPath: _lastDownloadedVideoPath,
        lastThumbnailPath: _lastDownloadedThumbnailPath,
      );
      if (isVideo) {
        await _videoProvider?.loadVideos();
      } else {
        await _musicProvider.loadSongs();
      }
    }
    notifyListeners();
  }

  Future<void> removeRecentDownload(String folderName, {bool isVideo = false}) async {
    _recentDownloads.removeWhere((r) => r.folderName == folderName && r.isVideo == isVideo);
    try {
      final prefs = await SharedPreferences.getInstance();
      final strList = _recentDownloads.map((r) => jsonEncode(r.toMap())).toList();
      await prefs.setStringList('recent_downloads', strList);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> clearRecentDownloads() async {
    _recentDownloads.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('recent_downloads');
      notifyListeners();
    } catch (_) {}
  }

  Future<Directory> _getMusicDirectory() async {
    if (Platform.isAndroid) {
      try {
        final List<Directory>? externalDirs = await getExternalStorageDirectories();
        if (externalDirs != null && externalDirs.isNotEmpty) {
          final root = externalDirs.first.path.split('Android/data').first;
          final separator = root.endsWith('/') ? '' : '/';
          final musicDir = Directory('$root${separator}Music');
          try {
            await musicDir.create(recursive: true);
            final testFile = File('${musicDir.path}/.playon_write_test');
            await testFile.writeAsString('ok');
            if (await testFile.exists()) {
              await testFile.delete();
            }
            return musicDir;
          } catch (_) {
            final appExternalDir = Directory('${externalDirs.first.path}/Music');
            await appExternalDir.create(recursive: true);
            return appExternalDir;
          }
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

  Future<Directory> _getVideoDirectory({String? customBasePath}) async {
    if (customBasePath != null && customBasePath.trim().isNotEmpty) {
      final dir = Directory(customBasePath.trim());
      if (!dir.existsSync()) {
        try {
          await dir.create(recursive: true);
        } catch (_) {}
      }
      if (dir.existsSync()) return dir;
    }

    if (Platform.isAndroid) {
      try {
        final moviesDir = Directory('/storage/emulated/0/Movies');
        if (moviesDir.existsSync()) {
          try {
            final testFile = File('${moviesDir.path}/.playon_write_test');
            await testFile.writeAsString('ok');
            if (await testFile.exists()) {
              await testFile.delete();
              return moviesDir;
            }
          } catch (_) {}
        }
      } catch (_) {}

      try {
        final List<Directory>? externalDirs = await getExternalStorageDirectories();
        if (externalDirs != null && externalDirs.isNotEmpty) {
          final root = externalDirs.first.path.split('Android/data').first;
          final separator = root.endsWith('/') ? '' : '/';
          final moviesDir = Directory('$root${separator}Movies');
          try {
            await moviesDir.create(recursive: true);
            final testFile = File('${moviesDir.path}/.playon_write_test');
            await testFile.writeAsString('ok');
            if (await testFile.exists()) {
              await testFile.delete();
              return moviesDir;
            }
          } catch (_) {
            final appExternalDir = Directory('${externalDirs.first.path}/Movies');
            await appExternalDir.create(recursive: true);
            return appExternalDir;
          }
        }
      } catch (e) {
        debugPrint('Error obteniendo directorio de videos: $e');
      }
    }

    final docs = await getApplicationDocumentsDirectory();
    final moviesDir = Directory('${docs.path}/Movies');
    await moviesDir.create(recursive: true);
    return moviesDir;
  }

  Future<void> _downloadVideoWithYtExplode(
    DownloadedTrack track,
    String filePath,
    String? cookieString, {
    String videoQuality = 'best',
  }) async {
    final yt = (cookieString != null && cookieString.isNotEmpty)
        ? yte.YoutubeExplode(httpClient: _CookieHttpClient(cookieString))
        : yte.YoutubeExplode();

    try {
      final manifest = await yt.videos.streamsClient.getManifest(track.id);
      final muxedStreams = manifest.muxed.sortByVideoQuality().toList();
      if (muxedStreams.isEmpty) {
        throw Exception('No hay stream de video progresivo disponible para este video.');
      }
      // En youtube_explode_dart, sortByVideoQuality() ordena de mayor a menor resolución (descendente)
      final streamInfo = (videoQuality == '360' || videoQuality == 'low')
          ? muxedStreams.last
          : muxedStreams.first;
      final stream = yt.videos.streamsClient.get(streamInfo);
      final file = File(filePath);
      final sink = file.openWrite();
      await stream.pipe(sink);
      await sink.flush();
      await sink.close();

      // Descargar miniatura compañera en alta resolución si existe
      if (track.thumbnailUrl != null && track.thumbnailUrl!.isNotEmpty) {
        try {
          final thumbFile = File(filePath.replaceFirst(RegExp(r'\.mp4$', caseSensitive: false), '.thumb.jpg'));
          final client = HttpClient();
          String thumbUrl = track.thumbnailUrl!;
          if (thumbUrl.contains('i.ytimg.com') || thumbUrl.contains('googleusercontent.com')) {
            final hq = thumbUrl.replaceAll(RegExp(r'/(?:hqdefault|mqdefault|sddefault|default)\.jpg'), '/maxresdefault.jpg');
            if (hq != thumbUrl) {
              try {
                final testReq = await client.getUrl(Uri.parse(hq));
                final testResp = await testReq.close();
                if (testResp.statusCode == 200) {
                  final thumbSink = thumbFile.openWrite();
                  await testResp.pipe(thumbSink);
                  await thumbSink.flush();
                  await thumbSink.close();
                  client.close();
                  return;
                }
              } catch (_) {}
            }
          }

          final req = await client.getUrl(Uri.parse(thumbUrl));
          final resp = await req.close();
          if (resp.statusCode == 200) {
            final thumbSink = thumbFile.openWrite();
            await resp.pipe(thumbSink);
            await thumbSink.flush();
            await thumbSink.close();
          }
          client.close();
        } catch (_) {}
      }
    } finally {
      yt.close();
    }
  }

  Future<void> _downloadAudioWithYtExplode(
    DownloadedTrack track,
    String filePath,
    String? cookieString,
  ) async {
    final yt = (cookieString != null && cookieString.isNotEmpty)
        ? yte.YoutubeExplode(httpClient: _CookieHttpClient(cookieString))
        : yte.YoutubeExplode();

    try {
      final manifest = await yt.videos.streamsClient.getManifest(track.id);
      final audioStreams = manifest.audioOnly.sortByBitrate();
      if (audioStreams.isEmpty) {
        throw Exception('No hay stream de audio disponible.');
      }
      final streamInfo = audioStreams.first;
      final stream = yt.videos.streamsClient.get(streamInfo);
      final file = File(filePath);
      final sink = file.openWrite();
      await stream.pipe(sink);
      await sink.flush();
      await sink.close();
    } finally {
      yt.close();
    }
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
