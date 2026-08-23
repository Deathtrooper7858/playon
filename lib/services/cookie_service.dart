import 'package:shared_preferences/shared_preferences.dart';

/// Servicio para persistir y recuperar las cookies de YouTube
/// que se inyectan en el HttpClient para evitar el rate limiting.
class CookieService {
  static const _key = 'youtube_cookies';

  /// Devuelve el string de cookies almacenado, o null si no hay ninguno.
  static Future<String?> getCookies() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }

  /// Guarda el string de cookies.
  static Future<void> saveCookies(String cookies) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, cookies.trim());
  }

  /// Elimina las cookies guardadas.
  static Future<void> clearCookies() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  /// Convierte un string de cookies (formato header `Name=Value; ...`)
  /// al `Map` que necesita YoutubeHttpClient.
  static Map<String, String> parseCookies(String cookieString) {
    final result = <String, String>{};
    for (final part in cookieString.split(';')) {
      final trimmed = part.trim();
      final idx = trimmed.indexOf('=');
      if (idx < 1) continue;
      final name = trimmed.substring(0, idx).trim();
      final value = trimmed.substring(idx + 1).trim();
      if (name.isNotEmpty) result[name] = value;
    }
    return result;
  }
}
