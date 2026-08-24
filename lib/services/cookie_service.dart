import 'package:shared_preferences/shared_preferences.dart';

/// Servicio para persistir y recuperar las cookies de YouTube
/// que se inyectan en el HttpClient y yt-dlp para evitar rate limiting y bloqueos.
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

  /// Comprueba si el string contiene tokens de inicio de sesión de YouTube/Google
  static bool hasValidSession(String? cookieString) {
    if (cookieString == null || cookieString.trim().isEmpty) return false;
    final lower = cookieString.toLowerCase();
    return lower.contains('login_info') ||
        lower.contains('sapisid') ||
        lower.contains('__secure-3psid') ||
        lower.contains('__secure-1psid') ||
        lower.contains('ssid') ||
        lower.contains('sid=') ||
        lower.contains('visitor_info1_live');
  }

  /// Combina listas de cookies en un string plano formateado `name=value; ...`
  static String mergeCookieMaps(List<Map<String, String>> cookieMaps) {
    final combined = <String, String>{};
    for (final map in cookieMaps) {
      map.forEach((k, v) {
        if (k.isNotEmpty && v.isNotEmpty) {
          combined[k] = v;
        }
      });
    }
    return combined.entries.map((e) => '${e.key}=${e.value}').join('; ');
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

