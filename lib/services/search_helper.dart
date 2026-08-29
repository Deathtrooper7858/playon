import '../models/song_model.dart';

class SearchHelper {
  static const Map<String, String> _diacriticsMap = {
    'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a', 'å': 'a', 'ā': 'a', 'ă': 'a', 'ą': 'a',
    'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e', 'ē': 'e', 'ĕ': 'e', 'ė': 'e', 'ę': 'e', 'ě': 'e',
    'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i', 'ĩ': 'i', 'ī': 'i', 'ĭ': 'i',
    'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o', 'ø': 'o', 'ō': 'o', 'ŏ': 'o', 'ő': 'o',
    'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u', 'ũ': 'u', 'ū': 'u', 'ŭ': 'u', 'ů': 'u', 'ű': 'u',
    'ý': 'y', 'ÿ': 'y',
    'ñ': 'n',
    'ç': 'c',
  };

  /// Normaliza una cadena quitando acentos, diacríticos y caracteres especiales para búsqueda tolerante.
  static String normalize(String input) {
    if (input.isEmpty) return '';
    final buffer = StringBuffer();
    final lower = input.toLowerCase().trim();
    for (int i = 0; i < lower.length; i++) {
      final char = lower[i];
      buffer.write(_diacriticsMap[char] ?? char);
    }
    return buffer.toString();
  }

  /// Verifica si una canción coincide con la consulta de búsqueda multitérrmino y sin distinción de acentos.
  static bool matchesSong(PlayOnSong song, String query) {
    if (query.trim().isEmpty) return true;
    final normalizedQuery = normalize(query);
    final tokens = normalizedQuery.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty) return true;

    final title = normalize(song.title);
    final artist = normalize(song.artist);
    final album = normalize(song.album);
    final folder = normalize(song.folderName ?? '');
    final combined = '$title $artist $album $folder';

    return tokens.every((token) => combined.contains(token));
  }

  /// Verifica si un texto genérico (como el nombre de una playlist o carpeta) coincide con la búsqueda.
  static bool matchesText(String text, String query) {
    if (query.trim().isEmpty) return true;
    final normalizedQuery = normalize(query);
    final tokens = normalizedQuery.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty) return true;

    final target = normalize(text);
    return tokens.every((token) => target.contains(token));
  }
}
