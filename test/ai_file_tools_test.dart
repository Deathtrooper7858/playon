import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:playon/services/file_management_service.dart';
import 'package:playon/services/groq_ai_service.dart';

void main() {
  group('AI File Management & Permissions Tools Tests', () {
    test('Verifica que todas las herramientas de archivos y playlists requeridas están en GroqAiService.toolsSchema', () {
      final toolNames = GroqAiService.toolsSchema
          .map((t) => (t['function'] as Map<String, dynamic>)['name'] as String)
          .toSet();

      final expectedTools = [
        'list_folder_contents',
        'list_all_folders',
        'search_files',
        'move_songs',
        'move_video',
        'move_folder',
        'rename_song',
        'rename_folder',
        'rename_video',
        'create_folder',
        'list_playlists',
        'view_playlist',
        'create_playlist',
        'add_to_playlist',
        'remove_from_playlist',
        'rename_playlist',
        'request_delete_playlist',
        'request_delete_songs',
        'request_delete_folder',
        'request_delete_video',
        'manage_favorites',
        'organize_music_folders',
        'download_content',
        'smart_play_music',
      ];

      for (final tool in expectedTools) {
        expect(toolNames.contains(tool), isTrue, reason: 'Herramienta $tool debe estar registrada en toolsSchema');
      }
    });

    test('FileManagementService.inspectFolder analiza correctamente directorios', () async {
      final tempDir = await Directory.systemTemp.createTemp('playon_test_inspect_');
      try {
        final subDir = Directory('${tempDir.path}/SubFolder');
        await subDir.create();
        final testFile = File('${tempDir.path}/test_song.mp3');
        await testFile.writeAsString('dummy mp3 content');

        final inspection = await FileManagementService.inspectFolder(tempDir.path);
        expect(inspection['exists'], isTrue);
        expect((inspection['subdirs'] as List).contains('SubFolder'), isTrue);
        expect((inspection['files'] as List).any((f) => f['name'] == 'test_song.mp3'), isTrue);
      } finally {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    });
  });
}
