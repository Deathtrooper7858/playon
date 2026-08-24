import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/song_model.dart';
import 'native_media_scanner_service.dart';

class FileManagementService {
  /// Obtiene o deduce la ruta base estándar de música (/storage/emulated/0/Music)
  static Future<String> getDefaultMusicBaseDir(List<PlayOnSong> allSongs) async {
    // 1. Si ya tenemos canciones en carpetas conocidas, deducir la ruta padre
    for (final song in allSongs) {
      if (song.folderPath != null && song.folderPath!.isNotEmpty) {
        final dir = Directory(song.folderPath!);
        if (dir.existsSync()) {
          final parent = dir.parent.path;
          if (parent.isNotEmpty && Directory(parent).existsSync()) {
            return parent;
          }
          return song.folderPath!;
        }
      }
    }

    // 2. Intentar ruta estándar de Android /storage/emulated/0/Music
    final standardMusic = Directory('/storage/emulated/0/Music');
    if (standardMusic.existsSync()) {
      return standardMusic.path;
    }

    // 3. Fallback a directorio de almacenamiento externo
    try {
      final ext = await getExternalStorageDirectory();
      if (ext != null) return ext.path;
    } catch (_) {}

    return '/storage/emulated/0/Music';
  }

  /// Limpia nombres de archivos o carpetas eliminando caracteres inválidos
  static String sanitizeFileName(String name) {
    var cleaned = name
        .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_')
        .trim();
    // Eliminar puntos o espacios finales que dan error en Android/FAT32/exFAT
    cleaned = cleaned.replaceAll(RegExp(r'[.\s]+$'), '');
    return cleaned.isEmpty ? 'unnamed' : cleaned;
  }

  /// Mueve una canción a la carpeta especificada
  static Future<String?> moveSong({
    required PlayOnSong song,
    required String targetFolderPath,
  }) async {
    try {
      final srcFile = File(song.filePath);
      if (!srcFile.existsSync()) {
        debugPrint('File does not exist: ${song.filePath}');
        return null;
      }

      final targetDir = Directory(targetFolderPath);
      if (!targetDir.existsSync()) {
        targetDir.createSync(recursive: true);
      }

      final fileName = p.basename(song.filePath);
      String destPath = p.join(targetFolderPath, fileName);

      // Si ya existe un archivo con ese nombre en el destino, añadir sufijo numérico
      if (File(destPath).existsSync() && destPath != song.filePath) {
        final base = p.basenameWithoutExtension(fileName);
        final ext = p.extension(fileName);
        int counter = 1;
        while (File(p.join(targetFolderPath, '${base}_$counter$ext')).existsSync()) {
          counter++;
        }
        destPath = p.join(targetFolderPath, '${base}_$counter$ext');
      }

      if (destPath == song.filePath) {
        return destPath; // Ya está en ese directorio
      }

      // Intentar rename (atómico dentro del mismo sistema de archivos)
      try {
        srcFile.renameSync(destPath);
      } catch (_) {
        // Fallback para operaciones entre particiones distintas
        try {
          srcFile.copySync(destPath);
          srcFile.deleteSync();
        } catch (copyErr) {
          // Si falló a mitad del copiado, eliminar destino parcial si existe
          if (File(destPath).existsSync()) {
            try {
              File(destPath).deleteSync();
            } catch (_) {}
          }
          rethrow;
        }
      }

      // Notificar al indexador multimedia de Android
      await NativeMediaScannerService.scanFile(song.filePath);
      await NativeMediaScannerService.scanFile(destPath);

      return destPath;
    } catch (e) {
      debugPrint('Error moving song: $e');
      return null;
    }
  }

  /// Mueve un lote de canciones a la carpeta de destino
  static Future<int> moveSongs({
    required List<PlayOnSong> songs,
    required String targetFolderPath,
  }) async {
    int successCount = 0;
    for (final song in songs) {
      final res = await moveSong(song: song, targetFolderPath: targetFolderPath);
      if (res != null) {
        successCount++;
      }
    }
    return successCount;
  }

  /// Renombra el archivo físico de la canción
  static Future<String?> renameSongFile({
    required PlayOnSong song,
    required String newFileNameWithoutExtension,
  }) async {
    try {
      final srcFile = File(song.filePath);
      if (!srcFile.existsSync()) return null;

      final sanitized = sanitizeFileName(newFileNameWithoutExtension);
      if (sanitized.isEmpty) return null;

      final originalExt = p.extension(song.filePath);
      final newFileName = '$sanitized$originalExt';
      final dir = p.dirname(song.filePath);
      final destPath = p.join(dir, newFileName);

      if (destPath == song.filePath) return destPath;

      if (File(destPath).existsSync()) {
        throw Exception('Ya existe un archivo con el nombre "$newFileName"');
      }

      srcFile.renameSync(destPath);

      await NativeMediaScannerService.scanFile(song.filePath);
      await NativeMediaScannerService.scanFile(destPath);

      return destPath;
    } catch (e) {
      debugPrint('Error renaming song file: $e');
      rethrow;
    }
  }

  /// Elimina una canción físicamente del almacenamiento
  static Future<bool> deleteSong(PlayOnSong song) async {
    try {
      final file = File(song.filePath);
      if (file.existsSync()) {
        file.deleteSync();
      }
      await NativeMediaScannerService.scanFile(song.filePath);
      return true;
    } catch (e) {
      debugPrint('Error deleting song: $e');
      return false;
    }
  }

  /// Elimina un lote de canciones físicamente
  static Future<int> deleteSongs(List<PlayOnSong> songs) async {
    int deletedCount = 0;
    for (final song in songs) {
      final ok = await deleteSong(song);
      if (ok) deletedCount++;
    }
    return deletedCount;
  }

  /// Crea una nueva carpeta de música
  static Future<String?> createFolder({
    required String parentPath,
    required String folderName,
  }) async {
    try {
      final sanitized = sanitizeFileName(folderName);
      if (sanitized.isEmpty) return null;

      final fullPath = p.join(parentPath, sanitized);
      final dir = Directory(fullPath);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      return fullPath;
    } catch (e) {
      debugPrint('Error creating folder: $e');
      return null;
    }
  }

  /// Renombra una carpeta y mueve todos sus archivos a la nueva ruta
  static Future<String?> renameFolder({
    required String currentFolderPath,
    required String newFolderName,
    required List<PlayOnSong> songsInFolder,
  }) async {
    try {
      final sanitized = sanitizeFileName(newFolderName);
      if (sanitized.isEmpty) return null;

      final parent = p.dirname(currentFolderPath);
      final newFolderPath = p.join(parent, sanitized);

      if (newFolderPath == currentFolderPath) return newFolderPath;

      final newDir = Directory(newFolderPath);
      if (newDir.existsSync()) {
        throw Exception('La carpeta "$newFolderName" ya existe.');
      }

      final currentDir = Directory(currentFolderPath);
      if (currentDir.existsSync()) {
        try {
          currentDir.renameSync(newFolderPath);
        } catch (_) {
          newDir.createSync(recursive: true);
          for (final song in songsInFolder) {
            await moveSong(song: song, targetFolderPath: newFolderPath);
          }
          if (currentDir.listSync().isEmpty) {
            currentDir.deleteSync();
          }
        }
      }

      // Re-escanear canciones afectadas
      for (final song in songsInFolder) {
        final newSongPath = p.join(newFolderPath, p.basename(song.filePath));
        await NativeMediaScannerService.scanFile(song.filePath);
        await NativeMediaScannerService.scanFile(newSongPath);
      }

      return newFolderPath;
    } catch (e) {
      debugPrint('Error renaming folder: $e');
      rethrow;
    }
  }

  /// Elimina una carpeta y todas las canciones que contiene
  static Future<bool> deleteFolder({
    required String folderPath,
    required List<PlayOnSong> songsInFolder,
  }) async {
    try {
      // 1. Eliminar archivos y notificar al media scanner
      for (final song in songsInFolder) {
        await deleteSong(song);
      }

      // 2. Eliminar directorio si aún existe
      final dir = Directory(folderPath);
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }

      return true;
    } catch (e) {
      debugPrint('Error deleting folder: $e');
      return false;
    }
  }
}
