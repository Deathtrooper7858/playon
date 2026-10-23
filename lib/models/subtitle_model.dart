import 'dart:io';
import 'package:path/path.dart' as p;

class SubtitleCue {
  final Duration start;
  final Duration end;
  final String text;

  const SubtitleCue({
    required this.start,
    required this.end,
    required this.text,
  });

  bool isActiveAt(Duration position) {
    return position >= start && position <= end;
  }
}

class SubtitleTrack {
  final String id;
  final String name;
  final String language;
  final String filePath;
  final List<SubtitleCue> cues;

  const SubtitleTrack({
    required this.id,
    required this.name,
    required this.language,
    required this.filePath,
    required this.cues,
  });

  static Duration _parseTimestamp(String h, String m, String s, String ms) {
    final hours = int.tryParse(h) ?? 0;
    final minutes = int.tryParse(m) ?? 0;
    final seconds = int.tryParse(s) ?? 0;
    final millis = int.tryParse(ms.padRight(3, '0').substring(0, 3)) ?? 0;
    return Duration(
      hours: hours,
      minutes: minutes,
      seconds: seconds,
      milliseconds: millis,
    );
  }

  /// Limpia etiquetas HTML/formato comunes en SRT/VTT (ej: `<b>`, `<i>`, `<c.color>`, etc.)
  static String _cleanText(String raw) {
    var cleaned = raw.replaceAll(RegExp(r'<[^>]+>'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\{[^}]+\}'), '');
    return cleaned.trim();
  }

  /// Parsea un archivo SRT o VTT a lista de Cues
  static Future<SubtitleTrack?> fromFile(File file) async {
    try {
      if (!file.existsSync()) return null;
      final content = await file.readAsString();
      final lines = content.split(RegExp(r'\r?\n'));
      final List<SubtitleCue> cues = [];

      final timePattern = RegExp(
        r'(?:(\d{1,2}):)?(\d{2}):(\d{2})[,.](\d{2,3})\s*-->\s*(?:(\d{1,2}):)?(\d{2}):(\d{2})[,.](\d{2,3})',
      );

      Duration? currentStart;
      Duration? currentEnd;
      final List<String> currentTextLines = [];

      void commitCue() {
        if (currentStart != null && currentEnd != null && currentTextLines.isNotEmpty) {
          final fullText = _cleanText(currentTextLines.join('\n'));
          if (fullText.isNotEmpty) {
            cues.add(SubtitleCue(
              start: currentStart!,
              end: currentEnd!,
              text: fullText,
            ));
          }
        }
        currentStart = null;
        currentEnd = null;
        currentTextLines.clear();
      }

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trim();

        if (line.isEmpty) {
          commitCue();
          continue;
        }

        final match = timePattern.firstMatch(line);
        if (match != null) {
          commitCue();
          final sh = match.group(1) ?? '00';
          final sm = match.group(2)!;
          final ss = match.group(3)!;
          final sms = match.group(4)!;

          final eh = match.group(5) ?? '00';
          final em = match.group(6)!;
          final es = match.group(7)!;
          final ems = match.group(8)!;

          currentStart = _parseTimestamp(sh, sm, ss, sms);
          currentEnd = _parseTimestamp(eh, em, es, ems);
          continue;
        }

        // Si la línea es solo un número secuencial de índice de SRT (ej: '1', '2'), ignorar
        if (RegExp(r'^\d+$').hasMatch(line) && currentStart == null) {
          continue;
        }

        // Si es la cabecera WEBVTT, ignorar
        if (line.startsWith('WEBVTT') || line.startsWith('NOTE') || line.startsWith('STYLE')) {
          continue;
        }

        if (currentStart != null && currentEnd != null) {
          currentTextLines.add(line);
        }
      }
      commitCue();

      if (cues.isEmpty) return null;

      // Deducir nombre e idioma a partir del nombre de archivo
      final fileName = p.basename(file.path).toLowerCase();
      String lang = 'es';
      String name = 'Subtítulos';

      if (fileName.contains('.es.') || fileName.endsWith('.es.srt') || fileName.endsWith('.es.vtt') || fileName.contains('spanish') || fileName.contains('español')) {
        lang = 'es';
        name = 'Español';
      } else if (fileName.contains('.en.') || fileName.endsWith('.en.srt') || fileName.endsWith('.en.vtt') || fileName.contains('english') || fileName.contains('ingles')) {
        lang = 'en';
        name = 'Inglés';
      } else if (fileName.contains('.pt.') || fileName.contains('portuguese')) {
        lang = 'pt';
        name = 'Portugués';
      } else {
        name = p.basenameWithoutExtension(file.path);
      }

      return SubtitleTrack(
        id: file.path,
        name: name,
        language: lang,
        filePath: file.path,
        cues: cues,
      );
    } catch (_) {
      return null;
    }
  }

  /// Busca todos los archivos de subtítulos compañeros en el directorio del video
  static Future<List<SubtitleTrack>> findSubtitlesForVideo(String videoPath) async {
    final List<SubtitleTrack> tracks = [];
    try {
      final videoFile = File(videoPath);
      if (!videoFile.existsSync()) return tracks;

      final dir = videoFile.parent;
      if (!dir.existsSync()) return tracks;

      final baseName = p.basenameWithoutExtension(videoPath).toLowerCase();

      for (final entity in dir.listSync()) {
        if (entity is! File) continue;
        final ext = p.extension(entity.path).toLowerCase();
        if (ext != '.srt' && ext != '.vtt' && ext != '.sub') continue;

        final entBase = p.basename(entity.path).toLowerCase();
        // Si el archivo de subtítulos comienza con el nombre base del video
        if (entBase.startsWith(baseName) || entBase == '$baseName$ext') {
          final track = await SubtitleTrack.fromFile(entity);
          if (track != null) {
            tracks.add(track);
          }
        }
      }
    } catch (_) {}
    return tracks;
  }
}
