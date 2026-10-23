// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:playon/services/groq_ai_service.dart';

void main() {
  group('GroqAiService Diagnostic Tests', () {
    test('Verifica las 5 API Keys de reserva y failover automático', () async {
      expect(GroqAiService.totalKeys, 5);

      // Probar cada una de las 5 llaves individualmente rotando
      for (int i = 0; i < 5; i++) {
        final initialIndex = GroqAiService.currentKeyIndex;
        print('\n--- Probando API Key #${initialIndex + 1} ---');

        final response = await GroqAiService.chat(
          messages: [
            {'role': 'user', 'content': 'Di la palabra "FUNCIONANDO"'}
          ],
          model: 'openai/gpt-oss-120b',
        );

        print('Respuesta Key #${response.keyIndexUsed + 1} (${response.model}): ${response.content.trim()}');
        expect(response.content.isNotEmpty, true);
        expect(response.keyIndexUsed, initialIndex);

        // Rotar a la siguiente llave para probarla
        GroqAiService.rotateKey();
      }
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('Verifica soporte de herramientas (Tool Calling / Function Calling)', () async {
      final response = await GroqAiService.chat(
        messages: [
          {
            'role': 'user',
            'content': 'Mueve la canción "Blinding Lights" a la carpeta "Synthwave"'
          }
        ],
        model: 'openai/gpt-oss-120b',
      );

      print('\n--- Probando Tool Calling ---');
      print('Tool calls recibidos: ${response.toolCalls.length}');
      for (final tc in response.toolCalls) {
        print('Tool: ${tc.name}, Args: ${tc.arguments}');
      }

      expect(response.toolCalls.isNotEmpty, true);
      expect(response.toolCalls.first.name, 'move_songs');
      expect(response.toolCalls.first.arguments['target_folder'], 'Synthwave');
    }, timeout: const Timeout(Duration(minutes: 1)));

    test('Verifica modelos disponibles en la app', () async {
      for (final model in GroqAiService.availableModels) {
        print('\n--- Probando modelo: ${model.name} (${model.id}) ---');
        final response = await GroqAiService.chat(
          messages: [
            {'role': 'user', 'content': 'Responde solo "OK"'}
          ],
          model: model.id,
        );
        print('Modelo ${model.id} respondió: ${response.content.trim()}');
        expect(response.content.isNotEmpty, true);
      }
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
