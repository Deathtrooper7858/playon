import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import '../models/song_model.dart';
import '../models/video_model.dart';
import '../providers/download_provider.dart';
import '../providers/music_provider.dart';
import '../providers/playlist_provider.dart';
import '../providers/video_provider.dart';
import '../services/file_management_service.dart';
import '../services/groq_ai_service.dart';
import '../services/playlist_db.dart';
import '../services/search_helper.dart';

enum AiMessageSender { user, assistant, system }

enum AiActionType {
  deleteSongs,
  deleteFolder,
  deleteVideo,
  deletePlaylist,
  smartPlay,
  organizeFolders,
  info,
}

class AiVerificationAction {
  final String id;
  final AiActionType type;
  final String title;
  final String description;
  final Map<String, dynamic> data;
  bool? isConfirmed; // null: pendiente, true: ejecutado, false: cancelado

  AiVerificationAction({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.data,
    this.isConfirmed,
  });
}

class AiChatMessage {
  final String id;
  final AiMessageSender sender;
  final String text;
  final DateTime timestamp;
  final AiVerificationAction? verificationAction;
  final List<String>? quickSuggestions;

  AiChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
    this.verificationAction,
    this.quickSuggestions,
  });
}

class AiAssistantProvider extends ChangeNotifier {
  final MusicProvider _musicProvider;
  final VideoProvider _videoProvider;
  final PlaylistProvider _playlistProvider;
  final DownloadProvider _downloadProvider;

  final List<AiChatMessage> _messages = [];
  bool _isGenerating = false;
  String _selectedModel = GroqAiService.defaultModel;
  bool _hasStoragePermission = false;

  List<AiChatMessage> get messages => _messages;
  bool get isGenerating => _isGenerating;
  String get selectedModel => _selectedModel;
  int get activeKeyIndex => GroqAiService.currentKeyIndex;
  bool get hasStoragePermission => _hasStoragePermission;

  AiAssistantProvider({
    required MusicProvider musicProvider,
    required VideoProvider videoProvider,
    required PlaylistProvider playlistProvider,
    required DownloadProvider downloadProvider,
  })  : _musicProvider = musicProvider,
        _videoProvider = videoProvider,
        _playlistProvider = playlistProvider,
        _downloadProvider = downloadProvider {
    _initWelcomeMessage();
    checkStoragePermission();
  }

  void _initWelcomeMessage() {
    _messages.add(
      AiChatMessage(
        id: 'welcome',
        sender: AiMessageSender.assistant,
        text: '¡Hola! Soy tu Asistente IA de PlayOn 🎵✨\n\n'
            'Tengo permisos directos para gestionar todos los archivos multimedia de tu teléfono:\n'
            '• 📂 **Ver y explorar**: Carpetas, canciones y videos en el almacenamiento.\n'
            '• 🔍 **Buscar**: Cualquier archivo, artista o álbum rápidamente.\n'
            '• 📁 **Mover**: Canciones, videos o carpetas enteras a donde tú elijas.\n'
            '• ✏️ **Renombrar**: Archivos, canciones (títulos/autores), carpetas y playlists.\n'
            '• 🎶 **Playlists**: Crear nuevas, añadir canciones, reorganizarlas o eliminarlas.\n'
            '• 🎧 **Modo DJ Inteligente & Descargas**: Reproducción según tu vibra y descargas directas.\n\n'
            '¿Qué te gustaría hacer hoy?',
        timestamp: DateTime.now(),
        quickSuggestions: [
          '📂 Ver carpetas de música del teléfono',
          '🔍 Buscar canciones en el dispositivo',
          '🎶 Crear una nueva playlist',
          '📁 Mover canciones a una carpeta',
          '✏️ Renombrar una canción o autor',
          '🎵 Modo DJ: Pon música según mi estado de ánimo',
        ],
      ),
    );
  }

  // ── GESTIÓN DE PERMISOS DE ALMACENAMIENTO Y ARCHIVOS ─────────────────────

  /// Verifica el estado actual de los permisos de archivos
  Future<bool> checkStoragePermission() async {
    if (!Platform.isAndroid) {
      _hasStoragePermission = true;
      notifyListeners();
      return true;
    }

    bool granted = false;
    try {
      if (await Permission.manageExternalStorage.isGranted) {
        granted = true;
      } else if (await Permission.storage.isGranted) {
        granted = true;
      } else if (await Permission.audio.isGranted && await Permission.videos.isGranted) {
        granted = true;
      }
    } catch (e) {
      debugPrint('Error verificando permisos de almacenamiento: $e');
    }

    _hasStoragePermission = granted;
    notifyListeners();
    return granted;
  }

  /// Solicita explícitamente los permisos de acceso a todos los archivos
  Future<bool> requestStoragePermission() async {
    if (!Platform.isAndroid) {
      _hasStoragePermission = true;
      notifyListeners();
      return true;
    }

    bool granted = false;
    try {
      final manageStatus = await Permission.manageExternalStorage.request();
      if (manageStatus.isGranted) {
        granted = true;
      }
    } catch (_) {}

    if (!granted) {
      try {
        final audioStatus = await Permission.audio.request();
        final videoStatus = await Permission.videos.request();
        final storageStatus = await Permission.storage.request();
        if (storageStatus.isGranted || (audioStatus.isGranted && videoStatus.isGranted)) {
          granted = true;
        }
      } catch (_) {}
    }

    _hasStoragePermission = granted;
    if (granted) {
      await _musicProvider.loadSongs();
      await _videoProvider.loadVideos();
      await _playlistProvider.loadPlaylists();
    }
    notifyListeners();
    return granted;
  }

  /// Asegura que los permisos estén concedidos antes de cualquier operación sobre el sistema de archivos
  Future<bool> ensureStoragePermission() async {
    if (_hasStoragePermission) return true;
    final granted = await requestStoragePermission();
    if (!granted) {
      _messages.add(
        AiChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sender: AiMessageSender.system,
          text: '🔐 **Permiso de almacenamiento requerido**\n'
              'Para que la IA pueda ver, mover, renombrar o crear archivos y carpetas en tu teléfono, '
              'es necesario conceder acceso a los archivos (`MANAGE_EXTERNAL_STORAGE`).\n'
              'Puedes activarlo desde los Ajustes del sistema.',
          timestamp: DateTime.now(),
        ),
      );
      notifyListeners();
      return false;
    }
    return true;
  }

  void setModel(String modelId) {
    _selectedModel = modelId;
    notifyListeners();
  }

  void rotateKey() {
    GroqAiService.rotateKey();
    notifyListeners();
  }

  void clearChat() {
    _messages.clear();
    _initWelcomeMessage();
    notifyListeners();
  }

  /// Construye el mensaje de sistema inyectando el estado real y vivo de la biblioteca y permisos
  Map<String, dynamic> _buildSystemPrompt() {
    final allSongs = _musicProvider.allSongs;
    final totalSongs = allSongs.length;
    final folders = _musicProvider.folders;
    final favCount = _musicProvider.favoriteSongs.length;
    final currentPlaying = _musicProvider.currentSong;
    final videos = _videoProvider.videos;
    final playlists = _playlistProvider.playlists;

    // Extraer muestra representativa de artistas y títulos
    final artistsSet = <String>{};
    for (final s in allSongs) {
      if (s.artist != 'Artista desconocido' && s.artist.isNotEmpty) {
        artistsSet.add(s.artist);
      }
    }
    final sampleArtists = artistsSet.take(25).join(', ');
    final sampleSongs = allSongs
        .take(15)
        .map((s) => '"${s.title}" de ${s.artist} [Carpeta: ${s.folderName ?? 'Raíz'}]')
        .join('; ');

    final promptText = '''
Eres el Copiloto Inteligente de PlayOn, un reproductor y gestor de medios personal de vanguardia.
Tienes acceso y permisos directos sobre el sistema de archivos local del teléfono del usuario (almacenamiento interno / tarjeta SD), bibliotecas de música, videos, carpetas y playlists.

ESTADO ACTUAL DEL DISPOSITIVO DEL USUARIO:
- Permisos de archivos concedidos: ${_hasStoragePermission ? "SÍ (Acceso total)" : "PENDIENTE DE VERIFICACIÓN"}
- Total de canciones: $totalSongs
- Artistas destacados en biblioteca: $sampleArtists
- Carpetas de música existentes: ${folders.join(', ')}
- Muestra de canciones: $sampleSongs
- Canciones en Favoritos: $favCount
- Canción en reproducción ahora: ${currentPlaying != null ? '"${currentPlaying.title}" de ${currentPlaying.artist}' : 'Ninguna'}
- Total de videos: ${videos.length} (Carpetas de video: ${_videoProvider.folders.join(', ')})
- Playlists existentes: ${playlists.map((p) => p.name).join(', ')}

HERRAMIENTAS DISPONIBLES:
1. VER Y EXPLORAR ARCHIVOS Y CARPETAS:
   - `list_folder_contents`: Muestra los archivos y subcarpetas que contiene una carpeta física (por ejemplo "Music", o cualquier subcarpeta).
   - `list_all_folders`: Lista todas las carpetas físicas de música y videos encontradas en el teléfono con sus conteos.
   - `list_playlists`: Muestra todas las playlists creadas con sus conteos de canciones.
   - `view_playlist`: Muestra las canciones dentro de una playlist específica.
2. BUSCAR ARCHIVOS:
   - `search_files`: Busca canciones, videos o carpetas en todo el teléfono y biblioteca por palabra clave, título, autor o carpeta.
3. MOVER ARCHIVOS:
   - `move_songs`: Mueve canciones a una carpeta física especificada.
   - `move_video`: Mueve un video a otra carpeta de videos.
   - `move_folder`: Mueve una carpeta completa con sus archivos a otra carpeta contenedora.
4. RENOMBRAR:
   - `rename_song`: Renombra el título, artista, álbum y/o el archivo físico de una canción.
   - `rename_folder`: Renombra una carpeta física en el almacenamiento del teléfono.
   - `rename_video`: Renombra el título y archivo de un video.
   - `rename_playlist`: Renombra una playlist existente en la base de datos.
5. CREAR:
   - `create_folder`: Crea una nueva carpeta física en el almacenamiento para música o videos.
   - `create_playlist`: Crea una playlist y añade canciones.
   - `add_to_playlist`: Añade canciones a una playlist existente.
   - `remove_from_playlist`: Quita canciones de una playlist.
6. ELIMINAR (SIEMPRE CON VERIFICACIÓN PREVIA):
   - `request_delete_songs`: Solicita confirmación antes de eliminar canciones del teléfono.
   - `request_delete_folder`: Solicita confirmación antes de borrar una carpeta física.
   - `request_delete_video`: Solicita confirmación antes de borrar un video.
   - `request_delete_playlist`: Solicita confirmación antes de eliminar una playlist.
7. OTROS:
   - `organize_music_folders`: Organiza canciones en carpetas automáticamente (ej: por artista).
   - `smart_play_music`: Modo DJ para reproducir temas según estado de ánimo o género.
   - `download_content`: Descarga de YouTube.
   - `manage_favorites`: Guarda o quita de favoritos.

REGLAS ESENCIALES:
- NUNCA elimines silenciosamente. Para borrar archivos o carpetas, SIEMPRE usa las herramientas `request_delete_*`.
- Responde siempre en español, de forma cálida, concisa, moderna y amigable en formato Markdown.
''';

    return {'role': 'system', 'content': promptText};
  }

  /// Envía un mensaje a la IA y ejecuta las acciones / tools resultantes
  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isGenerating) return;

    final userMsg = AiChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sender: AiMessageSender.user,
      text: trimmed,
      timestamp: DateTime.now(),
    );
    _messages.add(userMsg);
    _isGenerating = true;
    notifyListeners();

    try {
      // Preparar historial de chat para la API
      final List<Map<String, dynamic>> apiMessages = [_buildSystemPrompt()];

      // Tomar los últimos 8 mensajes del historial para contexto
      final recentHistory = _messages.skip(_messages.length > 8 ? _messages.length - 8 : 0);
      for (final m in recentHistory) {
        if (m.sender == AiMessageSender.user) {
          apiMessages.add({'role': 'user', 'content': m.text});
        } else if (m.sender == AiMessageSender.assistant) {
          apiMessages.add({'role': 'assistant', 'content': m.text});
        }
      }

      final response = await GroqAiService.chat(
        messages: apiMessages,
        model: _selectedModel,
      );

      // Si hay llamadas a herramientas (Tool Calls)
      if (response.toolCalls.isNotEmpty) {
        for (final tool in response.toolCalls) {
          await _handleToolCall(tool, response.content);
        }
      } else {
        // Respuesta textual normal
        _messages.add(
          AiChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            sender: AiMessageSender.assistant,
            text: response.content.isNotEmpty ? response.content : '¡Entendido! ¿En qué más te puedo ayudar?',
            timestamp: DateTime.now(),
          ),
        );
      }
    } catch (e) {
      _messages.add(
        AiChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sender: AiMessageSender.system,
          text: '⚠️ No se pudo comunicar con el servicio IA: $e\nPuedes rotar de API Key o reintentar.',
          timestamp: DateTime.now(),
        ),
      );
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
  }

  /// Ejecuta o procesa cada tool call generado por el LLM
  Future<void> _handleToolCall(GroqToolCall tool, String fallbackText) async {
    final name = tool.name;
    final args = tool.arguments;

    switch (name) {
      case 'list_folder_contents':
        final folderName = args['folder_name']?.toString();
        final type = args['type']?.toString();
        await _executeListFolderContents(folderName, type);
        break;

      case 'list_all_folders':
        final type = args['type']?.toString();
        await _executeListAllFolders(type);
        break;

      case 'search_files':
        final query = args['query']?.toString() ?? '';
        final type = args['type']?.toString();
        await _executeSearchFiles(query, type);
        break;

      case 'move_songs':
        final songNames = (args['song_names'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
        final targetFolder = args['target_folder']?.toString() ?? 'Organizadas';
        await _executeMoveSongs(songNames, targetFolder);
        break;

      case 'move_video':
        final videoName = args['video_name']?.toString() ?? '';
        final targetFolder = args['target_folder']?.toString() ?? 'Organizados';
        await _executeMoveVideo(videoName, targetFolder);
        break;

      case 'move_folder':
        final folderName = args['folder_name']?.toString() ?? '';
        final targetParent = args['target_parent_folder']?.toString() ?? 'Music';
        await _executeMoveFolder(folderName, targetParent);
        break;

      case 'rename_song':
        final query = args['search_query']?.toString() ?? '';
        final newTitle = args['new_title']?.toString() ?? '';
        final newArtist = args['new_artist']?.toString() ?? '';
        final newAlbum = args['new_album']?.toString();
        final renameFile = args['rename_file'] != false;
        await _executeRenameSong(query, newTitle, newArtist, newAlbum, renameFile);
        break;

      case 'rename_folder':
        final currentName = args['current_folder_name']?.toString() ?? '';
        final newName = args['new_folder_name']?.toString() ?? '';
        final type = args['type']?.toString();
        await _executeRenameFolder(currentName, newName, type);
        break;

      case 'rename_video':
        final query = args['search_query']?.toString() ?? '';
        final newTitle = args['new_title']?.toString() ?? '';
        await _executeRenameVideo(query, newTitle);
        break;

      case 'create_folder':
        final folderName = args['folder_name']?.toString() ?? '';
        final type = args['type']?.toString() ?? 'music';
        await _executeCreateFolder(folderName, type);
        break;

      case 'list_playlists':
        await _executeListPlaylists();
        break;

      case 'view_playlist':
        final plName = args['playlist_name']?.toString() ?? '';
        await _executeViewPlaylist(plName);
        break;

      case 'create_playlist':
        final playlistName = args['playlist_name']?.toString() ?? '';
        final songNames = (args['song_names'] as List<dynamic>?)?.map((e) => e.toString()).toList();
        await _executeCreatePlaylist(playlistName, songNames);
        break;

      case 'add_to_playlist':
        final plName = args['playlist_name']?.toString() ?? '';
        final songNames = (args['song_names'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
        await _executeAddToPlaylist(plName, songNames);
        break;

      case 'remove_from_playlist':
        final plName = args['playlist_name']?.toString() ?? '';
        final songNames = (args['song_names'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
        await _executeRemoveFromPlaylist(plName, songNames);
        break;

      case 'rename_playlist':
        final currentName = args['current_name']?.toString() ?? '';
        final newName = args['new_name']?.toString() ?? '';
        await _executeRenamePlaylist(currentName, newName);
        break;

      case 'request_delete_playlist':
        final plName = args['playlist_name']?.toString() ?? '';
        final reason = args['reason']?.toString() ?? 'Eliminación solicitada por el usuario';
        _prepareDeletePlaylistVerification(plName, reason);
        break;

      case 'request_delete_songs':
        final songNames = (args['song_names'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
        final reason = args['reason']?.toString() ?? 'Eliminación permanente solicitada';
        _prepareDeleteSongsVerification(songNames, reason);
        break;

      case 'request_delete_folder':
        final folderName = args['folder_name']?.toString() ?? '';
        final type = args['type']?.toString() ?? 'music';
        final reason = args['reason']?.toString() ?? 'Eliminación permanente de carpeta';
        _prepareDeleteFolderVerification(folderName, type, reason);
        break;

      case 'request_delete_video':
        final videoName = args['video_name']?.toString() ?? '';
        final reason = args['reason']?.toString() ?? 'Eliminación permanente de video';
        _prepareDeleteVideoVerification(videoName, reason);
        break;

      case 'manage_favorites':
        final songNames = (args['song_names'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
        final add = args['add'] == true;
        await _executeManageFavorites(songNames, add);
        break;

      case 'organize_music_folders':
        final strategy = args['strategy']?.toString() ?? 'by_artist';
        final description = args['description']?.toString() ?? '';
        await _executeOrganizeFolders(strategy, description);
        break;

      case 'download_content':
        final url = args['url']?.toString() ?? '';
        final format = args['format']?.toString() ?? 'audio';
        final targetFolder = args['target_folder']?.toString();
        await _executeDownloadContent(url, format, targetFolder);
        break;

      case 'smart_play_music':
        final mood = args['mood_or_vibe']?.toString() ?? 'Recomendado';
        final songTitles = (args['song_titles'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
        final shuffle = args['shuffle'] == true;
        await _executeSmartPlay(mood, songTitles, shuffle);
        break;

      case 'recommend_music':
        final recs = args['recommendations'] as List<dynamic>? ?? [];
        _showRecommendations(recs, fallbackText);
        break;

      default:
        _messages.add(
          AiChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            sender: AiMessageSender.assistant,
            text: fallbackText.isNotEmpty ? fallbackText : 'Acción completada: $name',
            timestamp: DateTime.now(),
          ),
        );
    }
  }

  // ── 1. VER Y LISTAR ARCHIVOS Y CARPETAS ───────────────────────────────────

  Future<void> _executeListFolderContents(String? folderName, String? type) async {
    await ensureStoragePermission();

    final name = folderName?.trim();
    String path;

    if (name == null || name.isEmpty || name.toLowerCase() == 'root' || name.toLowerCase() == 'music') {
      path = await FileManagementService.getDefaultMusicBaseDir(_musicProvider.allSongs);
    } else if (name.toLowerCase() == 'movies' || name.toLowerCase() == 'video' || name.toLowerCase() == 'videos') {
      path = '/storage/emulated/0/Movies';
    } else if (name.startsWith('/')) {
      path = name;
    } else {
      // Buscar entre carpetas existentes de canciones
      final matchSong = _musicProvider.allSongs
          .where((s) => s.folderName != null && SearchHelper.normalize(s.folderName!).contains(SearchHelper.normalize(name)))
          .firstOrNull;

      if (matchSong != null && matchSong.folderPath != null && matchSong.folderPath!.isNotEmpty) {
        path = matchSong.folderPath!;
      } else {
        final baseDir = await FileManagementService.getDefaultMusicBaseDir(_musicProvider.allSongs);
        path = p.join(baseDir, name);
      }
    }

    final inspection = await FileManagementService.inspectFolder(path);
    if (inspection['exists'] != true) {
      // Si la carpeta física aún no tiene esa ruta exacta, buscar por canciones registradas con ese folderName
      final songsInFolder = _musicProvider.allSongs
          .where((s) => s.folderName != null && SearchHelper.normalize(s.folderName!) == SearchHelper.normalize(name ?? ''))
          .toList();

      if (songsInFolder.isNotEmpty) {
        final buffer = StringBuffer('📂 **Carpeta "$name"** (en biblioteca PlayOn):\n');
        buffer.writeln('Total: **${songsInFolder.length} canciones**\n');
        for (final s in songsInFolder.take(20)) {
          buffer.writeln('• 🎵 "${s.title}" - ${s.artist} [${s.durationFormatted}]');
        }
        if (songsInFolder.length > 20) {
          buffer.writeln('\n*...y ${songsInFolder.length - 20} canciones más.*');
        }
        _messages.add(
          AiChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            sender: AiMessageSender.assistant,
            text: buffer.toString(),
            timestamp: DateTime.now(),
          ),
        );
        return;
      }

      _messages.add(
        AiChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sender: AiMessageSender.assistant,
          text: '⚠️ No se encontró la carpeta física o biblioteca: `$path`.',
          timestamp: DateTime.now(),
        ),
      );
      return;
    }

    final subdirs = inspection['subdirs'] as List<String>;
    final files = inspection['files'] as List<Map<String, dynamic>>;

    final buffer = StringBuffer('📂 **Contenido de "${p.basename(path)}"** (`$path`):\n\n');

    if (subdirs.isNotEmpty) {
      buffer.writeln('📁 **Subcarpetas (${subdirs.length}):**');
      for (final dir in subdirs.take(15)) {
        buffer.writeln('  • 📁 **$dir**');
      }
      if (subdirs.length > 15) buffer.writeln('  *...y ${subdirs.length - 15} subcarpetas más.*');
      buffer.writeln();
    }

    if (files.isNotEmpty) {
      buffer.writeln('📄 **Archivos (${files.length}):**');
      for (final f in files.take(25)) {
        final sizeBytes = f['size'] as int? ?? 0;
        final sizeFormatted = (sizeBytes / (1024 * 1024)).toStringAsFixed(1);
        final fileName = f['name'] as String;
        final ext = f['extension'] as String? ?? '';
        final isAudio = ['.mp3', '.m4a', '.wav', '.flac', '.ogg', '.aac'].contains(ext);
        final isVideo = ['.mp4', '.mkv', '.webm', '.avi'].contains(ext);
        final icon = isAudio ? '🎵' : (isVideo ? '🎬' : '📄');
        buffer.writeln('  • $icon $fileName *($sizeFormatted MB)*');
      }
      if (files.length > 25) buffer.writeln('  *...y ${files.length - 25} archivos más.*');
    } else {
      buffer.writeln('*(Esta carpeta no contiene archivos directamente).*');
    }

    _messages.add(
      AiChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sender: AiMessageSender.assistant,
        text: buffer.toString(),
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> _executeListAllFolders(String? type) async {
    await ensureStoragePermission();

    final showMusic = type == null || type == 'all' || type == 'music';
    final showVideo = type == null || type == 'all' || type == 'video';

    final buffer = StringBuffer('📂 **Carpetas encontradas en el teléfono:**\n\n');

    if (showMusic) {
      final musicFolders = _musicProvider.folders;
      final songCounts = _musicProvider.folderSongCounts;
      buffer.writeln('🎵 **Carpetas de Música (${musicFolders.length}):**');
      if (musicFolders.isEmpty) {
        buffer.writeln('  *(Sin carpetas de música escaneadas)*');
      } else {
        for (final f in musicFolders) {
          final count = songCounts[f] ?? 0;
          buffer.writeln('  • 📁 **$f** ($count canción${count == 1 ? '' : 'es'})');
        }
      }
      buffer.writeln();
    }

    if (showVideo) {
      final videoFolders = _videoProvider.folders;
      final videoCounts = _videoProvider.folderCounts;
      buffer.writeln('🎬 **Carpetas de Video (${videoFolders.length}):**');
      if (videoFolders.isEmpty) {
        buffer.writeln('  *(Sin carpetas de video escaneadas)*');
      } else {
        for (final f in videoFolders) {
          final count = videoCounts[f] ?? 0;
          buffer.writeln('  • 📁 **$f** ($count video${count == 1 ? '' : 's'})');
        }
      }
    }

    _messages.add(
      AiChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sender: AiMessageSender.assistant,
        text: buffer.toString(),
        timestamp: DateTime.now(),
      ),
    );
  }

  // ── 2. BUSCAR ARCHIVOS EN EL DISPOSITIVO ───────────────────────────────────

  Future<void> _executeSearchFiles(String query, String? type) async {
    if (query.trim().isEmpty) return;
    final q = query.trim();
    final filterType = type ?? 'all';

    final matchedSongs = (filterType == 'all' || filterType == 'music')
        ? _musicProvider.allSongs.where((s) => SearchHelper.matchesSong(s, q)).toList()
        : <PlayOnSong>[];

    final matchedVideos = (filterType == 'all' || filterType == 'video')
        ? _videoProvider.videos.where((v) => SearchHelper.matchesVideo(v, q)).toList()
        : <PlayOnVideo>[];

    final matchedFolders = (filterType == 'all' || filterType == 'folder')
        ? _musicProvider.folders.where((f) => SearchHelper.matchesText(f, q)).toList()
        : <String>[];

    final totalFound = matchedSongs.length + matchedVideos.length + matchedFolders.length;
    if (totalFound == 0) {
      _messages.add(
        AiChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sender: AiMessageSender.assistant,
          text: '🔍 No se encontraron archivos, canciones ni carpetas que coincidan con **"$q"**.',
          timestamp: DateTime.now(),
        ),
      );
      return;
    }

    final buffer = StringBuffer('🔍 **Resultados de búsqueda para "$q":**\n\n');

    if (matchedFolders.isNotEmpty) {
      buffer.writeln('📁 **Carpetas (${matchedFolders.length}):**');
      for (final f in matchedFolders) {
        final count = _musicProvider.folderSongCounts[f] ?? 0;
        buffer.writeln('  • 📁 **$f** ($count canciones)');
      }
      buffer.writeln();
    }

    if (matchedSongs.isNotEmpty) {
      buffer.writeln('🎵 **Canciones (${matchedSongs.length}):**');
      for (final s in matchedSongs.take(15)) {
        buffer.writeln('  • 🎵 "${s.title}" de **${s.artist}** [📁 ${s.folderName ?? 'Raíz'}]');
      }
      if (matchedSongs.length > 15) buffer.writeln('  *...y ${matchedSongs.length - 15} canciones más.*');
      buffer.writeln();
    }

    if (matchedVideos.isNotEmpty) {
      buffer.writeln('🎬 **Videos (${matchedVideos.length}):**');
      for (final v in matchedVideos.take(10)) {
        buffer.writeln('  • 🎬 "${v.title}" [📁 ${v.folderName}] (${v.durationFormatted})');
      }
      if (matchedVideos.length > 10) buffer.writeln('  *...y ${matchedVideos.length - 10} videos más.*');
    }

    _messages.add(
      AiChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sender: AiMessageSender.assistant,
        text: buffer.toString(),
        timestamp: DateTime.now(),
      ),
    );
  }

  // ── 3. MOVER ARCHIVOS Y CARPETAS ──────────────────────────────────────────

  Future<void> _executeMoveSongs(List<String> songNames, String targetFolder) async {
    await ensureStoragePermission();

    final matchedSongs = <PlayOnSong>[];
    for (final name in songNames) {
      final s = _findSongByQuery(name);
      if (s != null && !matchedSongs.contains(s)) {
        matchedSongs.add(s);
      }
    }

    if (matchedSongs.isEmpty) {
      _messages.add(
        AiChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sender: AiMessageSender.assistant,
          text: 'No encontré canciones en tu biblioteca que coincidan con "${songNames.join(', ')}".',
          timestamp: DateTime.now(),
        ),
      );
      return;
    }

    final baseDir = await FileManagementService.getDefaultMusicBaseDir(_musicProvider.allSongs);
    final targetPath = p.join(baseDir, targetFolder);

    final movedCount = await FileManagementService.moveSongs(
      songs: matchedSongs,
      targetFolderPath: targetPath,
    );
    await _musicProvider.loadSongs();

    final songsList = matchedSongs.map((s) => '• "${s.title}" - ${s.artist}').join('\n');
    _messages.add(
      AiChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sender: AiMessageSender.assistant,
        text: '✅ **¡Listo!** Moví **$movedCount canciones** a la carpeta **"$targetFolder"**:\n$songsList',
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> _executeMoveVideo(String videoName, String targetFolder) async {
    await ensureStoragePermission();
    final video = _findVideoByQuery(videoName);
    if (video == null) {
      _messages.add(
        AiChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sender: AiMessageSender.assistant,
          text: 'No encontré ningún video que coincida con "$videoName".',
          timestamp: DateTime.now(),
        ),
      );
      return;
    }

    final baseDir = '/storage/emulated/0/Movies';
    final targetPath = p.join(baseDir, targetFolder);

    final ok = await _videoProvider.moveVideo(video, targetPath, targetFolder);
    _messages.add(
      AiChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sender: AiMessageSender.assistant,
        text: ok
            ? '✅ Video **"${video.title}"** movido exitosamente a la carpeta **"$targetFolder"**.'
            : '⚠️ No se pudo mover el video a "$targetFolder".',
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> _executeMoveFolder(String folderName, String targetParentFolder) async {
    await ensureStoragePermission();
    final songsInFolder = _musicProvider.allSongs
        .where((s) => s.folderName != null && SearchHelper.normalize(s.folderName!) == SearchHelper.normalize(folderName))
        .toList();

    if (songsInFolder.isEmpty) {
      _messages.add(
        AiChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sender: AiMessageSender.assistant,
          text: 'No encontré la carpeta "$folderName" o está vacía.',
          timestamp: DateTime.now(),
        ),
      );
      return;
    }

    final sourcePath = songsInFolder.first.folderPath!;
    final baseDir = await FileManagementService.getDefaultMusicBaseDir(_musicProvider.allSongs);
    final targetPath = p.join(baseDir, targetParentFolder);

    try {
      final res = await FileManagementService.moveFolder(
        sourceFolderPath: sourcePath,
        targetParentPath: targetPath,
        songsInFolder: songsInFolder,
      );
      await _musicProvider.loadSongs();
      _messages.add(
        AiChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sender: AiMessageSender.assistant,
          text: '✅ Carpeta **"$folderName"** (${songsInFolder.length} canciones) movida con éxito dentro de **"$targetParentFolder"**.\nNueva ruta: `$res`',
          timestamp: DateTime.now(),
        ),
      );
    } catch (e) {
      _messages.add(
        AiChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sender: AiMessageSender.assistant,
          text: '⚠️ Error al mover la carpeta: $e',
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  // ── 4. RENOMBRAR ARCHIVOS, METADATOS, CARPETAS Y PLAYLISTS ────────────────

  Future<void> _executeRenameSong(
    String query,
    String newTitle,
    String newArtist,
    String? newAlbum,
    bool renameFile,
  ) async {
    await ensureStoragePermission();
    final song = _findSongByQuery(query);
    if (song == null) {
      _messages.add(
        AiChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sender: AiMessageSender.assistant,
          text: 'No encontré ninguna canción con el nombre "$query" para renombrar.',
          timestamp: DateTime.now(),
        ),
      );
      return;
    }

    try {
      // 1. Renombrar archivo físico en disco si se solicita
      if (renameFile && newTitle.trim().isNotEmpty) {
        try {
          await FileManagementService.renameSongFile(
            song: song,
            newFileNameWithoutExtension: newTitle,
          );
        } catch (e) {
          debugPrint('Advertencia renombrando archivo físico: $e');
        }
      }

      // 2. Actualizar metadatos ID3 y MediaStore
      await _musicProvider.updateSongMetadata(
        song: song,
        title: newTitle,
        artist: newArtist,
        album: newAlbum ?? song.album,
      );

      _messages.add(
        AiChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sender: AiMessageSender.assistant,
          text: '✅ **Canción renombrada con éxito**:\n'
              '• **Título:** $newTitle\n'
              '• **Artista:** $newArtist\n'
              '• **Álbum:** ${newAlbum ?? song.album}\n'
              'Las etiquetas ID3 y el archivo físico han sido actualizados en el teléfono.',
          timestamp: DateTime.now(),
        ),
      );
    } catch (e) {
      _messages.add(
        AiChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sender: AiMessageSender.assistant,
          text: '⚠️ Hubo un error al renombrar la canción: $e',
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  Future<void> _executeRenameFolder(String currentName, String newName, String? type) async {
    await ensureStoragePermission();
    final songsInFolder = _musicProvider.allSongs
        .where((s) => s.folderName != null && SearchHelper.normalize(s.folderName!) == SearchHelper.normalize(currentName))
        .toList();

    if (songsInFolder.isEmpty) {
      _messages.add(
        AiChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sender: AiMessageSender.assistant,
          text: 'No encontré la carpeta de música "$currentName" para renombrar.',
          timestamp: DateTime.now(),
        ),
      );
      return;
    }

    final sourcePath = songsInFolder.first.folderPath!;
    try {
      final newPath = await FileManagementService.renameFolder(
        currentFolderPath: sourcePath,
        newFolderName: newName,
        songsInFolder: songsInFolder,
      );
      await _musicProvider.loadSongs();
      _messages.add(
        AiChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sender: AiMessageSender.assistant,
          text: '✅ Carpeta renombrada con éxito a **"$newName"** (${songsInFolder.length} canciones actualizadas).\nNueva ruta: `$newPath`',
          timestamp: DateTime.now(),
        ),
      );
    } catch (e) {
      _messages.add(
        AiChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sender: AiMessageSender.assistant,
          text: '⚠️ No se pudo renombrar la carpeta: $e',
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  Future<void> _executeRenameVideo(String query, String newTitle) async {
    await ensureStoragePermission();
    final video = _findVideoByQuery(query);
    if (video == null) {
      _messages.add(
        AiChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sender: AiMessageSender.assistant,
          text: 'No encontré ningún video con el nombre "$query" para renombrar.',
          timestamp: DateTime.now(),
        ),
      );
      return;
    }

    try {
      await _videoProvider.renameVideo(video, newTitle);
      _messages.add(
        AiChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sender: AiMessageSender.assistant,
          text: '✅ Video renombrado exitosamente:\n• Anterior: "${video.title}"\n• Nuevo título: **"$newTitle"**',
          timestamp: DateTime.now(),
        ),
      );
    } catch (e) {
      _messages.add(
        AiChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sender: AiMessageSender.assistant,
          text: '⚠️ Error al renombrar el video: $e',
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  Future<void> _executeRenamePlaylist(String currentName, String newName) async {
    final p = _findPlaylistByName(currentName);
    if (p == null) {
      _messages.add(
        AiChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sender: AiMessageSender.assistant,
          text: 'No encontré ninguna playlist llamada "$currentName".',
          timestamp: DateTime.now(),
        ),
      );
      return;
    }

    await _playlistProvider.renamePlaylist(p.id, newName);
    _messages.add(
      AiChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sender: AiMessageSender.assistant,
        text: '✅ Playlist renombrada de **"${p.name}"** a **"$newName"**.',
        timestamp: DateTime.now(),
      ),
    );
  }

  // ── 5. CREAR CARPETAS ─────────────────────────────────────────────────────

  Future<void> _executeCreateFolder(String folderName, String type) async {
    if (folderName.trim().isEmpty) return;
    await ensureStoragePermission();

    if (type == 'video') {
      const baseDir = '/storage/emulated/0/Movies';
      final path = await FileManagementService.createFolder(parentPath: baseDir, folderName: folderName);
      await _videoProvider.loadVideos();
      _messages.add(
        AiChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sender: AiMessageSender.assistant,
          text: path != null
              ? '✅ Carpeta de videos **"$folderName"** creada con éxito en Movies.'
              : '⚠️ No se pudo crear la carpeta de videos.',
          timestamp: DateTime.now(),
        ),
      );
    } else {
      final baseDir = await FileManagementService.getDefaultMusicBaseDir(_musicProvider.allSongs);
      final path = await FileManagementService.createFolder(parentPath: baseDir, folderName: folderName);
      await _musicProvider.loadSongs();
      _messages.add(
        AiChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sender: AiMessageSender.assistant,
          text: path != null
              ? '✅ Carpeta de música **"$folderName"** creada con éxito en:\n`$path`'
              : '⚠️ No se pudo crear la carpeta de música.',
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  // ── 6. GESTIÓN COMPLETA DE PLAYLISTS ──────────────────────────────────────

  Future<void> _executeListPlaylists() async {
    await _playlistProvider.loadPlaylists();
    final playlists = _playlistProvider.playlists;
    final counts = _playlistProvider.songCounts;

    if (playlists.isEmpty) {
      _messages.add(
        AiChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sender: AiMessageSender.assistant,
          text: '🎶 No tienes playlists creadas todavía. Dime: *"Crea una playlist llamada Favoritas 2026"* y la creo de inmediato.',
          timestamp: DateTime.now(),
        ),
      );
      return;
    }

    final buffer = StringBuffer('🎶 **Tus Playlists en PlayOn (${playlists.length}):**\n\n');
    for (final p in playlists) {
      final count = counts[p.id] ?? 0;
      buffer.writeln('• 🎵 **${p.name}** ($count canciones)');
    }

    _messages.add(
      AiChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sender: AiMessageSender.assistant,
        text: buffer.toString(),
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> _executeViewPlaylist(String playlistName) async {
    final p = _findPlaylistByName(playlistName);
    if (p == null) {
      _messages.add(
        AiChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sender: AiMessageSender.assistant,
          text: 'No encontré la playlist "$playlistName".',
          timestamp: DateTime.now(),
        ),
      );
      return;
    }

    final songs = await _playlistProvider.getSongsForPlaylist(p.id);
    if (songs.isEmpty) {
      _messages.add(
        AiChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sender: AiMessageSender.assistant,
          text: '🎶 La playlist **"${p.name}"** está actualmente vacía.',
          timestamp: DateTime.now(),
        ),
      );
      return;
    }

    final buffer = StringBuffer('🎶 **Playlist "${p.name}"** (${songs.length} canciones):\n\n');
    for (int i = 0; i < songs.length && i < 20; i++) {
      final s = songs[i];
      buffer.writeln('${i + 1}. 🎵 "${s.title}" - ${s.artist} [${s.durationFormatted}]');
    }
    if (songs.length > 20) {
      buffer.writeln('\n*... y ${songs.length - 20} canciones más.*');
    }

    _messages.add(
      AiChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sender: AiMessageSender.assistant,
        text: buffer.toString(),
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> _executeCreatePlaylist(String name, List<String>? songNames) async {
    final playlist = await _playlistProvider.createPlaylist(name);
    if (playlist == null) {
      _messages.add(
        AiChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sender: AiMessageSender.assistant,
          text: '⚠️ No se pudo crear la playlist "$name".',
          timestamp: DateTime.now(),
        ),
      );
      return;
    }

    int added = 0;
    if (songNames != null && songNames.isNotEmpty) {
      for (final sName in songNames) {
        final s = _findSongByQuery(sName);
        if (s != null) {
          await _playlistProvider.addSongToPlaylist(playlist.id, s.id);
          added++;
        }
      }
    }

    _messages.add(
      AiChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sender: AiMessageSender.assistant,
        text: '🎉 **Playlist creada exitosamente**:\n• Nombre: **"$name"**\n• Canciones añadidas: **$added**',
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> _executeAddToPlaylist(String playlistName, List<String> songNames) async {
    final p = _findPlaylistByName(playlistName);
    if (p == null) {
      _messages.add(
        AiChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sender: AiMessageSender.assistant,
          text: 'No encontré la playlist "$playlistName". ¿Deseas que la cree primero?',
          timestamp: DateTime.now(),
        ),
      );
      return;
    }

    int added = 0;
    final addedTitles = <String>[];
    for (final sName in songNames) {
      final s = _findSongByQuery(sName);
      if (s != null) {
        await _playlistProvider.addSongToPlaylist(p.id, s.id);
        added++;
        addedTitles.add('• "${s.title}" - ${s.artist}');
      }
    }

    _messages.add(
      AiChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sender: AiMessageSender.assistant,
        text: '✅ Se añadieron **$added canción(es)** a la playlist **"${p.name}"**:\n${addedTitles.join('\n')}',
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> _executeRemoveFromPlaylist(String playlistName, List<String> songNames) async {
    final p = _findPlaylistByName(playlistName);
    if (p == null) {
      _messages.add(
        AiChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sender: AiMessageSender.assistant,
          text: 'No encontré la playlist "$playlistName".',
          timestamp: DateTime.now(),
        ),
      );
      return;
    }

    int removed = 0;
    for (final sName in songNames) {
      final s = _findSongByQuery(sName);
      if (s != null) {
        await _playlistProvider.removeSongFromPlaylist(p.id, s.id);
        removed++;
      }
    }

    _messages.add(
      AiChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sender: AiMessageSender.assistant,
        text: '✅ Se quitaron **$removed canción(es)** de la playlist **"${p.name}"**.',
        timestamp: DateTime.now(),
      ),
    );
  }

  void _prepareDeletePlaylistVerification(String playlistName, String reason) {
    final p = _findPlaylistByName(playlistName);
    if (p == null) {
      _messages.add(
        AiChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sender: AiMessageSender.assistant,
          text: 'No encontré la playlist "$playlistName" para eliminar.',
          timestamp: DateTime.now(),
        ),
      );
      return;
    }

    final action = AiVerificationAction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: AiActionType.deletePlaylist,
      title: '¿Eliminar playlist "${p.name}"?',
      description: '$reason\n\n*(Nota: Las canciones NO se borrarán de tu teléfono, solo se eliminará la lista de reproducción).*',
      data: {'playlist': p},
    );

    _messages.add(
      AiChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sender: AiMessageSender.assistant,
        text: '⚠️ **Se requiere confirmación para eliminar la playlist:**',
        timestamp: DateTime.now(),
        verificationAction: action,
      ),
    );
  }

  // ── 7. FAVORITOS Y ORGANIZACIÓN AUTOMÁTICA ───────────────────────────────

  Future<void> _executeManageFavorites(List<String> songNames, bool add) async {
    int count = 0;
    for (final sName in songNames) {
      final s = _findSongByQuery(sName);
      if (s != null) {
        final isFav = _musicProvider.isFavorite(s.id);
        if (add && !isFav) {
          _musicProvider.toggleFavorite(s.id);
          count++;
        } else if (!add && isFav) {
          _musicProvider.toggleFavorite(s.id);
          count++;
        }
      }
    }

    _messages.add(
      AiChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sender: AiMessageSender.assistant,
        text: add
            ? '❤️ Se añadieron **$count canciones** a tus Favoritos.'
            : '💔 Se removieron **$count canciones** de tus Favoritos.',
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> _executeOrganizeFolders(String strategy, String description) async {
    await ensureStoragePermission();
    final allSongs = _musicProvider.allSongs;
    final baseDir = await FileManagementService.getDefaultMusicBaseDir(allSongs);
    int movedCount = 0;

    if (strategy == 'by_artist') {
      final Map<String, List<PlayOnSong>> artistMap = {};
      for (final song in allSongs) {
        final artist = song.artist.trim().isEmpty || song.artist == 'Artista desconocido'
            ? 'Varios Artistas'
            : song.artist;
        artistMap.putIfAbsent(artist, () => []).add(song);
      }

      for (final entry in artistMap.entries) {
        final artistName = FileManagementService.sanitizeFileName(entry.key);
        final targetPath = p.join(baseDir, artistName);
        final count = await FileManagementService.moveSongs(
          songs: entry.value,
          targetFolderPath: targetPath,
        );
        movedCount += count;
      }
    }

    await _musicProvider.loadSongs();

    _messages.add(
      AiChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sender: AiMessageSender.assistant,
        text: '✨ **Biblioteca reorganizada exitosamente**\n$description\n\n'
            '📁 Se organizaron **$movedCount canciones** en sus carpetas correspondientes en `$baseDir`.',
        timestamp: DateTime.now(),
      ),
    );
  }

  // ── 8. DESCARGAS Y MODO DJ INTELIGENTE ─────────────────────────────────────

  Future<void> _executeDownloadContent(String url, String format, String? targetFolder) async {
    await ensureStoragePermission();
    final isVideo = format == 'video';
    _downloadProvider.downloadPlaylist(
      url,
      targetFolder,
      singleTrackOnly: !url.contains('list='),
      isVideo: isVideo,
    );

    _messages.add(
      AiChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sender: AiMessageSender.assistant,
        text: '📥 **Descarga iniciada**:\n'
            '• Tipo: ${isVideo ? 'Video (MP4)' : 'Audio (M4A)'}\n'
            '• Destino: ${targetFolder ?? 'Automático'}\n'
            'Puedes ver el progreso en tiempo real en la pestaña **Descargas**.',
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> _executeSmartPlay(String mood, List<String> songTitles, bool shuffle) async {
    final matchedSongs = <PlayOnSong>[];
    for (final title in songTitles) {
      final s = _findSongByQuery(title);
      if (s != null && !matchedSongs.contains(s)) {
        matchedSongs.add(s);
      }
    }

    if (matchedSongs.isEmpty) {
      matchedSongs.addAll(_musicProvider.allSongs.take(10));
    }

    if (shuffle) {
      _musicProvider.toggleShuffle();
    }
    await _musicProvider.playCustomQueue(matchedSongs, 0);

    final songsListText = matchedSongs.take(5).map((s) => '▶️ "${s.title}" - ${s.artist}').join('\n');
    final moreText = matchedSongs.length > 5 ? '\n... y más en la cola.' : '';

    _messages.add(
      AiChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sender: AiMessageSender.assistant,
        text: '🎧 **¡Modo DJ Activado!** 🎶\n'
            'Estado de ánimo / Vibe: **"$mood"**\n'
            'Reproduciendo ${matchedSongs.length} temas seleccionados especialmente para ti:\n$songsListText$moreText',
        timestamp: DateTime.now(),
      ),
    );
  }

  void _showRecommendations(List<dynamic> recs, String fallback) {
    final buffer = StringBuffer('✨ **Recomendaciones para ti:**\n\n');
    for (final r in recs) {
      final title = r['title'] ?? '';
      final artist = r['artist'] ?? '';
      final reason = r['reason'] ?? '';
      buffer.writeln('🎵 **$title** - $artist');
      buffer.writeln('   *$reason*\n');
    }

    _messages.add(
      AiChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sender: AiMessageSender.assistant,
        text: buffer.toString(),
        timestamp: DateTime.now(),
      ),
    );
  }

  // ── 9. VERIFICACIÓN Y CONFIRMACIÓN PREVIA PARA ELIMINACIONES ──────────────

  void _prepareDeleteSongsVerification(List<String> songNames, String reason) {
    final matchedSongs = <PlayOnSong>[];
    for (final name in songNames) {
      final s = _findSongByQuery(name);
      if (s != null && !matchedSongs.contains(s)) {
        matchedSongs.add(s);
      }
    }

    if (matchedSongs.isEmpty) {
      _messages.add(
        AiChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sender: AiMessageSender.assistant,
          text: 'No encontré canciones para eliminar coincidentes con "${songNames.join(', ')}".',
          timestamp: DateTime.now(),
        ),
      );
      return;
    }

    final songsList = matchedSongs.map((s) => '• "${s.title}" - ${s.artist}').join('\n');
    final action = AiVerificationAction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: AiActionType.deleteSongs,
      title: '¿Confirmar eliminación de ${matchedSongs.length} canción(es)?',
      description: '$reason\n\nCanciones a borrar físicamente:\n$songsList',
      data: {'songs': matchedSongs},
    );

    _messages.add(
      AiChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sender: AiMessageSender.assistant,
        text: '⚠️ **Se requiere confirmación antes de borrar:**',
        timestamp: DateTime.now(),
        verificationAction: action,
      ),
    );
  }

  void _prepareDeleteFolderVerification(String folderName, String type, String reason) {
    final songsInFolder = _musicProvider.allSongs
        .where((s) => s.folderName != null && SearchHelper.normalize(s.folderName!) == SearchHelper.normalize(folderName))
        .toList();

    final action = AiVerificationAction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: AiActionType.deleteFolder,
      title: '¿Eliminar carpeta "$folderName"?',
      description: '⚠️ **ADVERTENCIA**: $reason.\n\nEsta acción eliminará físicamente la carpeta y todas las canciones o archivos contenidos (${songsInFolder.length} canciones).',
      data: {'folderName': folderName, 'type': type, 'songs': songsInFolder},
    );

    _messages.add(
      AiChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sender: AiMessageSender.assistant,
        text: '⚠️ **Se requiere confirmación de seguridad para eliminar la carpeta:**',
        timestamp: DateTime.now(),
        verificationAction: action,
      ),
    );
  }

  void _prepareDeleteVideoVerification(String videoName, String reason) {
    final video = _findVideoByQuery(videoName);
    if (video == null) {
      _messages.add(
        AiChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sender: AiMessageSender.assistant,
          text: 'No encontré ningún video con el nombre "$videoName" para eliminar.',
          timestamp: DateTime.now(),
        ),
      );
      return;
    }

    final action = AiVerificationAction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: AiActionType.deleteVideo,
      title: '¿Eliminar video "${video.title}"?',
      description: 'Se eliminará permanentemente el archivo de video y sus miniaturas asociadas.\n$reason',
      data: {'video': video},
    );

    _messages.add(
      AiChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sender: AiMessageSender.assistant,
        text: '⚠️ **Se requiere confirmación para eliminar el video:**',
        timestamp: DateTime.now(),
        verificationAction: action,
      ),
    );
  }

  Future<void> confirmAction(AiVerificationAction action) async {
    action.isConfirmed = true;
    notifyListeners();

    try {
      await ensureStoragePermission();

      if (action.type == AiActionType.deleteSongs) {
        final songs = action.data['songs'] as List<PlayOnSong>;
        final deleted = await FileManagementService.deleteSongs(songs);
        await _musicProvider.loadSongs();
        _messages.add(
          AiChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            sender: AiMessageSender.system,
            text: '🗑️ **$deleted canción(es) eliminada(s) permanentemente** del almacenamiento.',
            timestamp: DateTime.now(),
          ),
        );
      } else if (action.type == AiActionType.deleteFolder) {
        final folderName = action.data['folderName'] as String;
        final songs = action.data['songs'] as List<PlayOnSong>;
        final baseDir = await FileManagementService.getDefaultMusicBaseDir(_musicProvider.allSongs);
        final folderPath = p.join(baseDir, folderName);

        await FileManagementService.deleteFolder(
          folderPath: folderPath,
          songsInFolder: songs,
        );
        await _musicProvider.loadSongs();
        _messages.add(
          AiChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            sender: AiMessageSender.system,
            text: '🗑️ **Carpeta "$folderName" eliminada** con éxito del teléfono.',
            timestamp: DateTime.now(),
          ),
        );
      } else if (action.type == AiActionType.deleteVideo) {
        final video = action.data['video'] as PlayOnVideo;
        await _videoProvider.deleteVideo(video);
        _messages.add(
          AiChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            sender: AiMessageSender.system,
            text: '🗑️ **Video "${video.title}" eliminado** con éxito.',
            timestamp: DateTime.now(),
          ),
        );
      } else if (action.type == AiActionType.deletePlaylist) {
        final pl = action.data['playlist'] as CustomPlaylist;
        await _playlistProvider.deletePlaylist(pl.id);
        _messages.add(
          AiChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            sender: AiMessageSender.system,
            text: '🗑️ **Playlist "${pl.name}" eliminada** con éxito.',
            timestamp: DateTime.now(),
          ),
        );
      }
    } catch (e) {
      _messages.add(
        AiChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sender: AiMessageSender.system,
          text: '⚠️ Error al ejecutar la acción: $e',
          timestamp: DateTime.now(),
        ),
      );
    }
    notifyListeners();
  }

  void cancelAction(AiVerificationAction action) {
    action.isConfirmed = false;
    _messages.add(
      AiChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sender: AiMessageSender.system,
        text: '❌ Acción cancelada. Ningún archivo o elemento fue modificado.',
        timestamp: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  // ── HELPERS DE BÚSQUEDA INTERNA ───────────────────────────────────────────

  CustomPlaylist? _findPlaylistByName(String name) {
    final norm = SearchHelper.normalize(name);
    for (final p in _playlistProvider.playlists) {
      if (SearchHelper.normalize(p.name) == norm || SearchHelper.matchesText(p.name, name)) {
        return p;
      }
    }
    return null;
  }

  PlayOnSong? _findSongByQuery(String query) {
    if (query.trim().isEmpty) return null;
    final normalizedQ = SearchHelper.normalize(query);
    // 1. Intento con búsqueda tokenizada y tolerante a acentos
    for (final s in _musicProvider.allSongs) {
      if (SearchHelper.matchesSong(s, query)) {
        return s;
      }
    }
    // 2. Fallback de coincidencia parcial normalizada
    for (final s in _musicProvider.allSongs) {
      final titleNorm = SearchHelper.normalize(s.title);
      final artistNorm = SearchHelper.normalize(s.artist);
      if (titleNorm.contains(normalizedQ) ||
          artistNorm.contains(normalizedQ) ||
          (normalizedQ.length >= 3 && normalizedQ.contains(titleNorm))) {
        return s;
      }
    }
    return null;
  }

  PlayOnVideo? _findVideoByQuery(String query) {
    if (query.trim().isEmpty) return null;
    final normalizedQ = SearchHelper.normalize(query);
    // 1. Intento con búsqueda tolerante a acentos
    for (final v in _videoProvider.videos) {
      if (SearchHelper.matchesVideo(v, query)) {
        return v;
      }
    }
    // 2. Fallback de coincidencia parcial normalizada
    for (final v in _videoProvider.videos) {
      final titleNorm = SearchHelper.normalize(v.title);
      if (titleNorm.contains(normalizedQ) ||
          (normalizedQ.length >= 3 && normalizedQ.contains(titleNorm))) {
        return v;
      }
    }
    return null;
  }
}
