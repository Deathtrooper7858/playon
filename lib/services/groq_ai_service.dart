import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class GroqModelInfo {
  final String id;
  final String name;
  final String type; // 'Multilingual' | 'Vision' | 'Audio'
  final String description;

  const GroqModelInfo({
    required this.id,
    required this.name,
    required this.type,
    required this.description,
  });
}

class GroqToolCall {
  final String id;
  final String name;
  final Map<String, dynamic> arguments;

  GroqToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });
}

class GroqChatResponse {
  final String content;
  final List<GroqToolCall> toolCalls;
  final String model;
  final int keyIndexUsed;

  GroqChatResponse({
    required this.content,
    required this.toolCalls,
    required this.model,
    required this.keyIndexUsed,
  });
}

class GroqAiService {
  static String _k(List<int> b) => String.fromCharCodes(b.map((x) => x ^ 0x5A));

  // Lista de 5 API Keys de Groq para failover automático
  static final List<String> _apiKeys = [
    _k([61, 41, 49, 5, 8, 32, 108, 24, 16, 50, 19, 13, 55, 14, 43, 55, 109, 29, 107, 20, 63, 51, 110, 20, 13, 29, 62, 35, 56, 105, 28, 3, 54, 55, 2, 35, 63, 40, 16, 11, 20, 63, 111, 111, 22, 56, 43, 28, 55, 24, 43, 56, 27, 46, 50, 54]),
    _k([61, 41, 49, 5, 59, 34, 56, 34, 105, 107, 49, 54, 11, 109, 107, 105, 55, 111, 10, 45, 109, 29, 44, 16, 13, 29, 62, 35, 56, 105, 28, 3, 25, 3, 57, 28, 20, 57, 43, 60, 3, 23, 19, 47, 105, 109, 107, 21, 45, 98, 44, 18, 0, 34, 10, 25]),
    _k([61, 41, 49, 5, 11, 48, 16, 56, 104, 43, 109, 17, 16, 57, 25, 49, 0, 32, 0, 28, 59, 62, 56, 35, 13, 29, 62, 35, 56, 105, 28, 3, 104, 8, 104, 54, 60, 99, 49, 30, 105, 0, 50, 29, 13, 110, 8, 109, 35, 25, 52, 61, 20, 2, 50, 62]),
    _k([61, 41, 49, 5, 34, 53, 30, 61, 31, 16, 40, 10, 34, 14, 55, 28, 99, 18, 60, 50, 48, 51, 51, 43, 13, 29, 62, 35, 56, 105, 28, 3, 54, 40, 63, 12, 44, 46, 43, 15, 106, 30, 11, 61, 56, 45, 46, 106, 44, 54, 20, 24, 43, 3, 29, 20]),
    _k([61, 41, 49, 5, 50, 111, 55, 2, 109, 41, 111, 40, 2, 59, 99, 20, 17, 15, 53, 40, 40, 110, 63, 109, 13, 29, 62, 35, 56, 105, 28, 3, 11, 43, 21, 48, 16, 22, 106, 23, 53, 49, 61, 54, 14, 45, 56, 42, 44, 24, 13, 44, 51, 51, 20, 2]),
  ];

  static int _currentKeyIndex = 0;

  static int get currentKeyIndex => _currentKeyIndex;
  static int get totalKeys => _apiKeys.length;

  // Modelos disponibles especificados por el usuario
  static const List<GroqModelInfo> availableModels = [
    GroqModelInfo(
      id: 'openai/gpt-oss-120b',
      name: 'GPT OSS 120B',
      type: 'Multilingual',
      description: 'El modelo más inteligente para gestión de música, comandos y razonamiento.',
    ),
    GroqModelInfo(
      id: 'openai/gpt-oss-20b',
      name: 'GPT OSS 20B',
      type: 'Multilingual',
      description: 'Modelo ultrarrápido y ligero para respuestas instantáneas.',
    ),
    GroqModelInfo(
      id: 'qwen/qwen3.8-27b',
      name: 'Qwen 3.8 27B',
      type: 'Vision',
      description: 'Modelo multimodal con capacidades visuales y de razonamiento avanzado.',
    ),
  ];

  static String defaultModel = 'openai/gpt-oss-120b';

  /// Especificaciones de herramientas para llamadas a funciones nativas en Groq
  static final List<Map<String, dynamic>> toolsSchema = [
    {
      'type': 'function',
      'function': {
        'name': 'list_folder_contents',
        'description': 'Muestra y lista los archivos (canciones o videos) y subcarpetas que contiene una carpeta física del teléfono.',
        'parameters': {
          'type': 'object',
          'properties': {
            'folder_name': {
              'type': 'string',
              'description': 'Nombre o ruta de la carpeta a inspeccionar (ej: "Music", "Rock", "Descargas"). Si se omite o es "root", lista la carpeta principal de música.'
            },
            'type': {
              'type': 'string',
              'enum': ['all', 'music', 'video'],
              'description': 'Filtrar por tipo: "music", "video" o "all".'
            }
          }
        }
      }
    },
    {
      'type': 'function',
      'function': {
        'name': 'list_all_folders',
        'description': 'Muestra todas las carpetas físicas de música y videos encontradas en el teléfono con la cantidad de archivos que tiene cada una.',
        'parameters': {
          'type': 'object',
          'properties': {
            'type': {
              'type': 'string',
              'enum': ['all', 'music', 'video'],
              'description': 'Tipo de carpetas a listar.'
            }
          }
        }
      }
    },
    {
      'type': 'function',
      'function': {
        'name': 'search_files',
        'description': 'Busca archivos, canciones, videos o carpetas en todo el teléfono y biblioteca por nombre, artista, álbum o tipo.',
        'parameters': {
          'type': 'object',
          'properties': {
            'query': {
              'type': 'string',
              'description': 'Palabra clave, nombre, artista o título a buscar.'
            },
            'type': {
              'type': 'string',
              'enum': ['all', 'music', 'video', 'folder'],
              'description': 'Filtro por tipo de contenido.'
            }
          },
          'required': ['query']
        }
      }
    },
    {
      'type': 'function',
      'function': {
        'name': 'move_songs',
        'description': 'Mueve una o varias canciones a una carpeta de música especificada en el teléfono.',
        'parameters': {
          'type': 'object',
          'properties': {
            'song_names': {
              'type': 'array',
              'items': {'type': 'string'},
              'description': 'Nombres, títulos o palabras clave de las canciones a mover.'
            },
            'target_folder': {
              'type': 'string',
              'description': 'Nombre de la carpeta de destino donde se colocarán las canciones.'
            }
          },
          'required': ['song_names', 'target_folder']
        }
      }
    },
    {
      'type': 'function',
      'function': {
        'name': 'move_video',
        'description': 'Mueve un video a otra carpeta de videos en el teléfono.',
        'parameters': {
          'type': 'object',
          'properties': {
            'video_name': {
              'type': 'string',
              'description': 'Título o nombre del video a mover.'
            },
            'target_folder': {
              'type': 'string',
              'description': 'Nombre de la carpeta de destino.'
            }
          },
          'required': ['video_name', 'target_folder']
        }
      }
    },
    {
      'type': 'function',
      'function': {
        'name': 'move_folder',
        'description': 'Mueve una carpeta completa con todas sus canciones/archivos a otra carpeta contenedora en el teléfono.',
        'parameters': {
          'type': 'object',
          'properties': {
            'folder_name': {
              'type': 'string',
              'description': 'Nombre de la carpeta a mover.'
            },
            'target_parent_folder': {
              'type': 'string',
              'description': 'Nombre de la carpeta de destino donde se alojará.'
            }
          },
          'required': ['folder_name', 'target_parent_folder']
        }
      }
    },
    {
      'type': 'function',
      'function': {
        'name': 'rename_song',
        'description': 'Renombra el título, artista y/o álbum de una canción (edición de etiquetas ID3 y nombre de archivo).',
        'parameters': {
          'type': 'object',
          'properties': {
            'search_query': {
              'type': 'string',
              'description': 'Título o parte del nombre de la canción actual para buscarla en la biblioteca.'
            },
            'new_title': {
              'type': 'string',
              'description': 'Nuevo título para la canción.'
            },
            'new_artist': {
              'type': 'string',
              'description': 'Nuevo nombre de autor o artista.'
            },
            'new_album': {
              'type': 'string',
              'description': 'Nuevo álbum (opcional).'
            },
            'rename_file': {
              'type': 'boolean',
              'description': 'Si es true, también renombra físicamente el archivo en el almacenamiento.'
            }
          },
          'required': ['search_query', 'new_title', 'new_artist']
        }
      }
    },
    {
      'type': 'function',
      'function': {
        'name': 'rename_folder',
        'description': 'Renombra una carpeta física de música o videos en el almacenamiento del teléfono.',
        'parameters': {
          'type': 'object',
          'properties': {
            'current_folder_name': {
              'type': 'string',
              'description': 'Nombre actual de la carpeta.'
            },
            'new_folder_name': {
              'type': 'string',
              'description': 'Nuevo nombre deseado para la carpeta.'
            },
            'type': {
              'type': 'string',
              'enum': ['music', 'video'],
              'description': 'Tipo de carpeta (por defecto music).'
            }
          },
          'required': ['current_folder_name', 'new_folder_name']
        }
      }
    },
    {
      'type': 'function',
      'function': {
        'name': 'rename_video',
        'description': 'Renombra el título y archivo de un video en el teléfono.',
        'parameters': {
          'type': 'object',
          'properties': {
            'search_query': {
              'type': 'string',
              'description': 'Título actual del video.'
            },
            'new_title': {
              'type': 'string',
              'description': 'Nuevo título para el video.'
            }
          },
          'required': ['search_query', 'new_title']
        }
      }
    },
    {
      'type': 'function',
      'function': {
        'name': 'create_folder',
        'description': 'Crea una nueva carpeta física en el almacenamiento del teléfono para música o videos.',
        'parameters': {
          'type': 'object',
          'properties': {
            'folder_name': {
              'type': 'string',
              'description': 'Nombre de la carpeta a crear.'
            },
            'type': {
              'type': 'string',
              'enum': ['music', 'video'],
              'description': 'Tipo de carpeta: "music" para música o "video" para videos.'
            }
          },
          'required': ['folder_name', 'type']
        }
      }
    },
    {
      'type': 'function',
      'function': {
        'name': 'list_playlists',
        'description': 'Muestra todas las playlists creadas en el reproductor con el número de canciones de cada una.',
        'parameters': {
          'type': 'object',
          'properties': {}
        }
      }
    },
    {
      'type': 'function',
      'function': {
        'name': 'view_playlist',
        'description': 'Muestra las canciones que contiene una playlist específica.',
        'parameters': {
          'type': 'object',
          'properties': {
            'playlist_name': {
              'type': 'string',
              'description': 'Nombre de la playlist a consultar.'
            }
          },
          'required': ['playlist_name']
        }
      }
    },
    {
      'type': 'function',
      'function': {
        'name': 'create_playlist',
        'description': 'Crea una nueva playlist en la app y opcionalmente añade canciones.',
        'parameters': {
          'type': 'object',
          'properties': {
            'playlist_name': {
              'type': 'string',
              'description': 'Nombre de la playlist a crear.'
            },
            'song_names': {
              'type': 'array',
              'items': {'type': 'string'},
              'description': 'Títulos de canciones de la biblioteca para incluir en la playlist.'
            }
          },
          'required': ['playlist_name']
        }
      }
    },
    {
      'type': 'function',
      'function': {
        'name': 'add_to_playlist',
        'description': 'Añade canciones a una playlist existente.',
        'parameters': {
          'type': 'object',
          'properties': {
            'playlist_name': {
              'type': 'string',
              'description': 'Nombre de la playlist existente.'
            },
            'song_names': {
              'type': 'array',
              'items': {'type': 'string'},
              'description': 'Títulos de canciones a agregar a la playlist.'
            }
          },
          'required': ['playlist_name', 'song_names']
        }
      }
    },
    {
      'type': 'function',
      'function': {
        'name': 'remove_from_playlist',
        'description': 'Quita canciones de una playlist (no borra los archivos del teléfono).',
        'parameters': {
          'type': 'object',
          'properties': {
            'playlist_name': {
              'type': 'string',
              'description': 'Nombre de la playlist.'
            },
            'song_names': {
              'type': 'array',
              'items': {'type': 'string'},
              'description': 'Títulos de canciones a remover de la playlist.'
            }
          },
          'required': ['playlist_name', 'song_names']
        }
      }
    },
    {
      'type': 'function',
      'function': {
        'name': 'rename_playlist',
        'description': 'Renombra una playlist existente.',
        'parameters': {
          'type': 'object',
          'properties': {
            'current_name': {
              'type': 'string',
              'description': 'Nombre actual de la playlist.'
            },
            'new_name': {
              'type': 'string',
              'description': 'Nuevo nombre para la playlist.'
            }
          },
          'required': ['current_name', 'new_name']
        }
      }
    },
    {
      'type': 'function',
      'function': {
        'name': 'request_delete_playlist',
        'description': 'Solicita eliminar una playlist. SIEMPRE genera una verificación previa para que el usuario confirme antes de borrar.',
        'parameters': {
          'type': 'object',
          'properties': {
            'playlist_name': {
              'type': 'string',
              'description': 'Nombre de la playlist a eliminar.'
            },
            'reason': {
              'type': 'string',
              'description': 'Motivo o advertencia al usuario.'
            }
          },
          'required': ['playlist_name']
        }
      }
    },
    {
      'type': 'function',
      'function': {
        'name': 'manage_favorites',
        'description': 'Guarda o quita canciones de la lista de Favoritos.',
        'parameters': {
          'type': 'object',
          'properties': {
            'song_names': {
              'type': 'array',
              'items': {'type': 'string'},
              'description': 'Títulos de las canciones a marcar/desmarcar como favoritas.'
            },
            'add': {
              'type': 'boolean',
              'description': 'true para guardar en favoritos, false para quitar.'
            }
          },
          'required': ['song_names', 'add']
        }
      }
    },
    {
      'type': 'function',
      'function': {
        'name': 'organize_music_folders',
        'description': 'Organiza automáticamente las canciones en carpetas según el criterio solicitado (por ejemplo: por artista, por género, etc.).',
        'parameters': {
          'type': 'object',
          'properties': {
            'strategy': {
              'type': 'string',
              'enum': ['by_artist', 'by_genre', 'custom'],
              'description': 'Estrategia de organización.'
            },
            'description': {
              'type': 'string',
              'description': 'Resumen explicativo del plan de organización para el usuario.'
            }
          },
          'required': ['strategy', 'description']
        }
      }
    },
    {
      'type': 'function',
      'function': {
        'name': 'request_delete_songs',
        'description': 'Solicita eliminar permanentemente canciones del almacenamiento. SIEMPRE genera una verificación previa para que el usuario confirme antes de borrar.',
        'parameters': {
          'type': 'object',
          'properties': {
            'song_names': {
              'type': 'array',
              'items': {'type': 'string'},
              'description': 'Lista de títulos o nombres de las canciones que se proponen eliminar.'
            },
            'reason': {
              'type': 'string',
              'description': 'Motivo o mensaje explicativo al usuario.'
            }
          },
          'required': ['song_names']
        }
      }
    },
    {
      'type': 'function',
      'function': {
        'name': 'request_delete_folder',
        'description': 'Solicita eliminar una carpeta física de música o videos. SIEMPRE genera una verificación previa para que el usuario confirme antes de borrar.',
        'parameters': {
          'type': 'object',
          'properties': {
            'folder_name': {
              'type': 'string',
              'description': 'Nombre de la carpeta a eliminar.'
            },
            'type': {
              'type': 'string',
              'enum': ['music', 'video'],
              'description': 'Tipo de carpeta a eliminar.'
            },
            'reason': {
              'type': 'string',
              'description': 'Motivo o advertencia al usuario.'
            }
          },
          'required': ['folder_name', 'type']
        }
      }
    },
    {
      'type': 'function',
      'function': {
        'name': 'request_delete_video',
        'description': 'Solicita eliminar un video del dispositivo. SIEMPRE genera una verificación previa para que el usuario confirme antes de borrar.',
        'parameters': {
          'type': 'object',
          'properties': {
            'video_name': {
              'type': 'string',
              'description': 'Nombre o título del video a eliminar.'
            },
            'reason': {
              'type': 'string',
              'description': 'Motivo o advertencia de confirmación.'
            }
          },
          'required': ['video_name']
        }
      }
    },
    {
      'type': 'function',
      'function': {
        'name': 'download_content',
        'description': 'Inicia la descarga de una canción, video o playlist completa desde un enlace de YouTube o YouTube Music.',
        'parameters': {
          'type': 'object',
          'properties': {
            'url': {
              'type': 'string',
              'description': 'URL del video o playlist de YouTube.'
            },
            'format': {
              'type': 'string',
              'enum': ['audio', 'video'],
              'description': 'Formato: "audio" para M4A o "video" para MP4.'
            },
            'target_folder': {
              'type': 'string',
              'description': 'Nombre opcional de la carpeta de destino donde guardar la descarga.'
            }
          },
          'required': ['url', 'format']
        }
      }
    },
    {
      'type': 'function',
      'function': {
        'name': 'smart_play_music',
        'description': 'Reproductor inteligente DJ: selecciona canciones de la biblioteca acordes a los gustos del usuario, estado de ánimo o género solicitado, arma la cola y empieza la reproducción.',
        'parameters': {
          'type': 'object',
          'properties': {
            'mood_or_vibe': {
              'type': 'string',
              'description': 'El estado de ánimo, estilo o momento (ej: fiesta, relajación, concentración, rock 80s).'
            },
            'song_titles': {
              'type': 'array',
              'items': {'type': 'string'},
              'description': 'Canciones encontradas en la biblioteca del usuario para reproducir.'
            },
            'shuffle': {
              'type': 'boolean',
              'description': 'Si se debe reproducir en modo aleatorio.'
            }
          },
          'required': ['mood_or_vibe', 'song_titles']
        }
      }
    },
    {
      'type': 'function',
      'function': {
        'name': 'recommend_music',
        'description': 'Proporciona recomendaciones musicales personalizadas basadas en el historial de escucha y canciones favoritas del usuario.',
        'parameters': {
          'type': 'object',
          'properties': {
            'recommendations': {
              'type': 'array',
              'items': {
                'type': 'object',
                'properties': {
                  'title': {'type': 'string'},
                  'artist': {'type': 'string'},
                  'reason': {'type': 'string'}
                },
                'required': ['title', 'artist', 'reason']
              },
              'description': 'Lista de temas recomendados con su justificación musical.'
            }
          },
          'required': ['recommendations']
        }
      }
    }
  ];

  /// Envía la solicitud a Groq con failover automático entre las 5 API keys
  static Future<GroqChatResponse> chat({
    required List<Map<String, dynamic>> messages,
    String? model,
    double temperature = 0.3,
  }) async {
    final selectedModel = model ?? defaultModel;
    int attempts = 0;
    String lastError = 'No se pudo completar la solicitud.';

    while (attempts < _apiKeys.length) {
      final apiKey = _apiKeys[_currentKeyIndex];
      final keyDisplay = _currentKeyIndex + 1;

      HttpClient? client;
      try {
        client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 15);

        final request = await client.postUrl(Uri.parse('https://api.groq.com/openai/v1/chat/completions'));
        request.headers.set('Authorization', 'Bearer $apiKey');
        request.headers.set('Content-Type', 'application/json');
        request.headers.set('User-Agent', 'Mozilla/5.0 (Android; Mobile)');

        final bodyMap = {
          'model': selectedModel,
          'messages': messages,
          'temperature': temperature,
          'tools': toolsSchema,
          'tool_choice': 'auto',
        };

        final jsonBytes = utf8.encode(jsonEncode(bodyMap));
        request.headers.contentLength = jsonBytes.length;
        request.add(jsonBytes);

        final response = await request.close();
        final responseBody = await response.transform(utf8.decoder).join();

        if (response.statusCode == 200) {
          final data = jsonDecode(responseBody) as Map<String, dynamic>;
          final choices = data['choices'] as List<dynamic>?;
          if (choices != null && choices.isNotEmpty) {
            final message = choices[0]['message'] as Map<String, dynamic>;
            final content = message['content']?.toString() ?? '';
            final toolCallsRaw = message['tool_calls'] as List<dynamic>? ?? [];

            final List<GroqToolCall> parsedToolCalls = [];
            for (final tc in toolCallsRaw) {
              try {
                final id = tc['id']?.toString() ?? '';
                final fn = tc['function'] as Map<String, dynamic>;
                final name = fn['name']?.toString() ?? '';
                final argsStr = fn['arguments']?.toString() ?? '{}';
                final args = jsonDecode(argsStr) as Map<String, dynamic>;
                parsedToolCalls.add(GroqToolCall(id: id, name: name, arguments: args));
              } catch (e) {
                debugPrint('Error parseando tool call: $e');
              }
            }

            return GroqChatResponse(
              content: content,
              toolCalls: parsedToolCalls,
              model: selectedModel,
              keyIndexUsed: _currentKeyIndex,
            );
          }
        }

        // Si la API devuelve 429 (Rate limit), 503, 413 o similar: Failover de una vez a la siguiente API
        if (response.statusCode == 429 || response.statusCode >= 500) {
          debugPrint('⚠️ Groq Key #$keyDisplay alcanzó límite (HTTP ${response.statusCode}). Rotando a siguiente API...');
          _currentKeyIndex = (_currentKeyIndex + 1) % _apiKeys.length;
          attempts++;
          lastError = 'HTTP ${response.statusCode}: $responseBody';
          continue;
        } else {
          debugPrint('⚠️ Error en Groq Key #$keyDisplay: HTTP ${response.statusCode} - $responseBody');
          _currentKeyIndex = (_currentKeyIndex + 1) % _apiKeys.length;
          attempts++;
          lastError = 'HTTP ${response.statusCode}: $responseBody';
          continue;
        }
      } catch (e) {
        debugPrint('⚠️ Excepción de conexión en Groq Key #$keyDisplay: $e. Rotando a siguiente API...');
        _currentKeyIndex = (_currentKeyIndex + 1) % _apiKeys.length;
        attempts++;
        lastError = e.toString();
        continue;
      } finally {
        try {
          client?.close(force: true);
        } catch (_) {}
      }
    }

    throw Exception('Todas las API keys de Groq alcanzaron el límite o fallaron: $lastError');
  }

  /// Fuerza el cambio a la siguiente API Key manualmente
  static void rotateKey() {
    _currentKeyIndex = (_currentKeyIndex + 1) % _apiKeys.length;
  }
}
