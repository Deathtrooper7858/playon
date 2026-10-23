import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/video_model.dart';

class VideoProvider extends ChangeNotifier {
  List<PlayOnVideo> _videos = [];
  bool _isLoading = false;
  String? _selectedFolder;
  List<String> _folders = [];
  final Map<String, int> _folderCounts = {};
  final Set<String> _favoriteVideoIds = {};

  List<PlayOnVideo> get videos => _videos;
  bool get isLoading => _isLoading;
  String? get selectedFolder => _selectedFolder;
  List<String> get folders => _folders;
  Map<String, int> get folderCounts => _folderCounts;
  List<PlayOnVideo> get favoriteVideos => _videos.where((v) => _favoriteVideoIds.contains(v.id)).toList();

  bool isFavorite(String videoId) => _favoriteVideoIds.contains(videoId);

  Future<void> toggleFavorite(String videoId) async {
    if (_favoriteVideoIds.contains(videoId)) {
      _favoriteVideoIds.remove(videoId);
    } else {
      _favoriteVideoIds.add(videoId);
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('playon_favorite_videos', _favoriteVideoIds.toList());
    } catch (_) {}
  }

  List<PlayOnVideo> get filteredVideos {
    if (_selectedFolder == null || _selectedFolder!.isEmpty) {
      return _videos;
    }
    return _videos.where((v) => v.folderName == _selectedFolder).toList();
  }

  VideoProvider() {
    loadVideos();
  }

  void selectFolder(String? folder) {
    _selectedFolder = folder;
    notifyListeners();
  }

  /// Solicitar permisos necesarios para acceder a videos
  Future<bool> _requestVideoPermissions() async {
    if (!Platform.isAndroid) return true;
    try {
      if (await Permission.manageExternalStorage.isGranted) return true;
      final manageStatus = await Permission.manageExternalStorage.request();
      if (manageStatus.isGranted) return true;
    } catch (_) {}

    try {
      if (await Permission.videos.isGranted) return true;
      await Permission.videos.request();
    } catch (_) {}

    try {
      if (await Permission.storage.isGranted) return true;
      final status = await Permission.storage.request();
      return status.isGranted;
    } catch (_) {}

    return true;
  }

  /// Carga videos guardados y escanea carpetas de video estándar
  Future<void> loadVideos() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _requestVideoPermissions();

      final prefs = await SharedPreferences.getInstance();
      final favList = prefs.getStringList('playon_favorite_videos') ?? [];
      _favoriteVideoIds.clear();
      _favoriteVideoIds.addAll(favList);
      final savedMetaRaw = prefs.getStringList('playon_video_metadata_list') ?? [];
      final Map<String, PlayOnVideo> metaByPath = {};

      for (final raw in savedMetaRaw) {
        try {
          final map = jsonDecode(raw) as Map<String, dynamic>;
          final v = PlayOnVideo.fromMap(map);
          if (v.filePath.isNotEmpty) {
            metaByPath[v.filePath] = v;
          }
        } catch (_) {}
      }

      final List<Directory> scanDirs = await _getVideoScanDirectories();
      final List<PlayOnVideo> discovered = [];
      final Set<String> seenPaths = {};

      for (final dir in scanDirs) {
        if (!dir.existsSync()) continue;
        try {
          final entities = dir.listSync(recursive: true, followLinks: false);
          for (final entity in entities) {
            if (entity is! File) continue;
            final ext = p.extension(entity.path).toLowerCase();
            if (ext != '.mp4' && ext != '.mkv' && ext != '.webm' && ext != '.3gp') continue;

            if (seenPaths.contains(entity.path)) continue;
            seenPaths.add(entity.path);

            final filePath = entity.path;
            final file = entity;
            final stat = file.statSync();

            // Buscar miniatura compañera (.thumb.jpg o .jpg)
            final baseNameNoExt = p.withoutExtension(filePath);
            String? thumbPath;
            final candidateThumb1 = '$baseNameNoExt.thumb.jpg';
            final candidateThumb2 = '$baseNameNoExt.jpg';
            if (File(candidateThumb1).existsSync()) {
              thumbPath = candidateThumb1;
            } else if (File(candidateThumb2).existsSync()) {
              thumbPath = candidateThumb2;
            }

            final folderPath = p.dirname(filePath);
            final folderName = p.basename(folderPath);

            if (metaByPath.containsKey(filePath)) {
              final saved = metaByPath[filePath]!;
              discovered.add(saved.copyWith(
                fileSize: stat.size,
                thumbnailPath: thumbPath ?? saved.thumbnailPath,
                folderName: folderName,
                folderPath: folderPath,
              ));
            } else {
              // Extraer título y autor del nombre de archivo
              final fileName = p.basenameWithoutExtension(filePath);
              String title = fileName;
              String author = 'PlayOn Video';

              if (fileName.contains(' - ')) {
                final parts = fileName.split(' - ');
                author = parts[0].trim();
                title = parts.sublist(1).join(' - ').trim();
              }

              final video = PlayOnVideo(
                id: filePath.hashCode.toString(),
                title: title,
                author: author,
                filePath: filePath,
                thumbnailPath: thumbPath,
                thumbnailUrl: null,
                duration: 0,
                fileSize: stat.size,
                dateAdded: stat.modified,
                folderName: folderName.isEmpty ? 'My videos' : folderName,
                folderPath: folderPath,
              );
              discovered.add(video);
            }
          }
        } catch (e) {
          debugPrint('Error escaneando directorio de videos: $e');
        }
      }

      // Ordenar por fecha más reciente
      discovered.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
      _videos = discovered;

      // Calcular carpetas y conteos
      final Set<String> folderSet = {};
      final Map<String, int> counts = {};
      for (final v in _videos) {
        folderSet.add(v.folderName);
        counts[v.folderName] = (counts[v.folderName] ?? 0) + 1;
      }
      _folders = folderSet.toList()..sort();
      _folderCounts.clear();
      _folderCounts.addAll(counts);

      // Sincronizar metadata en prefs eliminando archivos borrados
      final validMeta = _videos.map((v) => jsonEncode(v.toMap())).toList();
      await prefs.setStringList('playon_video_metadata_list', validMeta);
    } catch (e) {
      debugPrint('Error en loadVideos: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Registra un nuevo video descargado por la app
  Future<void> registerDownloadedVideo(PlayOnVideo video) async {
    _videos.removeWhere((v) => v.filePath == video.filePath);
    _videos.insert(0, video);

    final folder = video.folderName;
    if (!_folders.contains(folder)) {
      _folders.add(folder);
      _folders.sort();
    }
    _folderCounts[folder] = (_folderCounts[folder] ?? 0) + 1;

    try {
      final prefs = await SharedPreferences.getInstance();
      final validMeta = _videos.map((v) => jsonEncode(v.toMap())).toList();
      await prefs.setStringList('playon_video_metadata_list', validMeta);
    } catch (_) {}

    notifyListeners();
  }

  /// Elimina un video y su miniatura del almacenamiento
  Future<bool> deleteVideo(PlayOnVideo video) async {
    try {
      final file = File(video.filePath);
      if (file.existsSync()) {
        file.deleteSync();
      }

      if (video.thumbnailPath != null) {
        final thumb = File(video.thumbnailPath!);
        if (thumb.existsSync()) {
          thumb.deleteSync();
        }
      }

      // Eliminar subtítulos huérfanos asociados al video
      final videoDir = Directory(video.folderPath);
      final baseVideoName = p.basenameWithoutExtension(video.filePath);
      if (videoDir.existsSync()) {
        try {
          for (final ent in videoDir.listSync()) {
            if (ent is File) {
              final entName = p.basename(ent.path);
              if (entName.startsWith(baseVideoName) && (entName.endsWith('.srt') || entName.endsWith('.vtt'))) {
                try { ent.deleteSync(); } catch (_) {}
              }
            }
          }
        } catch (_) {}
      }

      _videos.removeWhere((v) => v.filePath == video.filePath);

      final count = _folderCounts[video.folderName] ?? 1;
      if (count <= 1) {
        _folderCounts.remove(video.folderName);
        _folders.remove(video.folderName);
      } else {
        _folderCounts[video.folderName] = count - 1;
      }

      final prefs = await SharedPreferences.getInstance();
      final validMeta = _videos.map((v) => jsonEncode(v.toMap())).toList();
      await prefs.setStringList('playon_video_metadata_list', validMeta);

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error eliminando video: $e');
      return false;
    }
  }

  /// Mueve un video y sus archivos adjuntos (miniatura y subtitulos) a otra carpeta
  Future<bool> moveVideo(PlayOnVideo video, String targetFolderPath, String targetFolderName) async {
    try {
      final srcFile = File(video.filePath);
      if (!srcFile.existsSync()) return false;

      final targetDir = Directory(targetFolderPath);
      if (!targetDir.existsSync()) {
        targetDir.createSync(recursive: true);
      }

      final fileName = p.basename(video.filePath);
      final newFilePath = p.join(targetFolderPath, fileName);

      if (newFilePath == video.filePath) return true;

      // Mover archivo de video principal (con soporte para particiones cruzadas)
      try {
        srcFile.renameSync(newFilePath);
      } catch (_) {
        try {
          srcFile.copySync(newFilePath);
          srcFile.deleteSync();
        } catch (copyErr) {
          if (File(newFilePath).existsSync()) {
            try { File(newFilePath).deleteSync(); } catch (_) {}
          }
          rethrow;
        }
      }

      // Mover miniatura si existe
      String? newThumbPath;
      if (video.thumbnailPath != null && File(video.thumbnailPath!).existsSync()) {
        final thumbFile = File(video.thumbnailPath!);
        final thumbName = p.basename(video.thumbnailPath!);
        newThumbPath = p.join(targetFolderPath, thumbName);
        try {
          thumbFile.renameSync(newThumbPath);
        } catch (_) {
          newThumbPath = video.thumbnailPath;
        }
      }

      // Mover subtitulos si existen en la misma carpeta
      final srcDir = Directory(video.folderPath);
      final baseSrcName = p.basenameWithoutExtension(video.filePath);
      if (srcDir.existsSync()) {
        for (final ent in srcDir.listSync()) {
          if (ent is File) {
            final entName = p.basename(ent.path);
            if (entName.startsWith(baseSrcName) && (entName.endsWith('.srt') || entName.endsWith('.vtt'))) {
              try {
                final targetSubPath = p.join(targetFolderPath, entName);
                ent.renameSync(targetSubPath);
              } catch (_) {}
            }
          }
        }
      }

      await loadVideos();
      return true;
    } catch (e) {
      debugPrint('Error moviendo video: $e');
      return false;
    }
  }

  /// Obtiene los directorios base para escanear videos
  Future<List<Directory>> _getVideoScanDirectories() async {
    final List<Directory> dirs = [];

    if (Platform.isAndroid) {
      // 1. /storage/emulated/0/Movies
      final moviesDir = Directory('/storage/emulated/0/Movies');
      if (moviesDir.existsSync()) dirs.add(moviesDir);

      // 2. /storage/emulated/0/Download
      final downloadDir = Directory('/storage/emulated/0/Download');
      if (downloadDir.existsSync()) dirs.add(downloadDir);

      // 3. /storage/emulated/0/DCIM
      final dcimDir = Directory('/storage/emulated/0/DCIM');
      if (dcimDir.existsSync()) dirs.add(dcimDir);

      // 4. Almacenamiento externo propio de la app
      try {
        final List<Directory>? externalDirs = await getExternalStorageDirectories();
        if (externalDirs != null && externalDirs.isNotEmpty) {
          final root = externalDirs.first.path.split('Android/data').first;
          final separator = root.endsWith('/') ? '' : '/';
          final extMovies = Directory('$root${separator}Movies');
          if (extMovies.existsSync() && !dirs.any((d) => d.path == extMovies.path)) {
            dirs.add(extMovies);
          }
          final appMovies = Directory('${externalDirs.first.path}/Movies');
          if (appMovies.existsSync() && !dirs.any((d) => d.path == appMovies.path)) {
            dirs.add(appMovies);
          }
        }
      } catch (_) {}
    }

    try {
      final docs = await getApplicationDocumentsDirectory();
      final docsMovies = Directory('${docs.path}/Movies');
      if (docsMovies.existsSync() && !dirs.any((d) => d.path == docsMovies.path)) {
        dirs.add(docsMovies);
      }
    } catch (_) {}

    return dirs;
  }
}
