import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../providers/ai_assistant_provider.dart';
import '../services/groq_ai_service.dart';
import '../theme.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage(AiAssistantProvider aiProv) {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    aiProv.sendMessage(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AiAssistantProvider>(
      builder: (context, aiProv, _) {
        return Scaffold(
          backgroundColor: PlayOnTheme.bgDeep,
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(context, aiProv),
                if (!aiProv.hasStoragePermission)
                  _buildPermissionBanner(context, aiProv),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    itemCount: aiProv.messages.length + (aiProv.isGenerating ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == aiProv.messages.length && aiProv.isGenerating) {
                        return _buildThinkingIndicator();
                      }
                      final msg = aiProv.messages[index];
                      return _buildMessageBubble(context, msg, aiProv);
                    },
                  ),
                ),
                _buildInputArea(context, aiProv),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, AiAssistantProvider aiProv) {
    final activeKey = aiProv.activeKeyIndex + 1;
    final modelName = GroqAiService.availableModels
        .firstWhere((m) => m.id == aiProv.selectedModel, orElse: () => GroqAiService.availableModels.first)
        .name;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: PlayOnTheme.bgCard.withValues(alpha: 0.8),
        border: const Border(bottom: BorderSide(color: PlayOnTheme.glassBorder)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: PlayOnTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: PlayOnTheme.glowShadow(blur: 10),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Text(
                          'PlayOn IA',
                          style: TextStyle(
                            color: PlayOnTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'PRO',
                          style: TextStyle(
                            color: PlayOnTheme.cyanAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Groq Rotación Inteligente • API #$activeKey/5',
                      style: const TextStyle(color: PlayOnTheme.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              // Estado y acción de permisos de almacenamiento
              IconButton(
                icon: Icon(
                  aiProv.hasStoragePermission ? Icons.folder_special_rounded : Icons.folder_off_rounded,
                  color: aiProv.hasStoragePermission ? PlayOnTheme.emeraldActive : const Color(0xFFFFB74D),
                  size: 20,
                ),
                tooltip: aiProv.hasStoragePermission
                    ? 'Permisos de archivos: Concedido'
                    : 'Permisos de archivos: Pendiente (Toca para conceder)',
                onPressed: () async {
                  if (!aiProv.hasStoragePermission) {
                    await aiProv.requestStoragePermission();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ La IA tiene permisos completos sobre los archivos del teléfono.'),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
              // Selector de Modelo
              PopupMenuButton<String>(
                color: PlayOnTheme.bgCard,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                onSelected: (modelId) => aiProv.setModel(modelId),
                itemBuilder: (ctx) => GroqAiService.availableModels.map((m) {
                  final isSelected = m.id == aiProv.selectedModel;
                  return PopupMenuItem(
                    value: m.id,
                    child: Row(
                      children: [
                        Icon(
                          m.type == 'Vision' ? Icons.remove_red_eye_rounded : Icons.psychology_rounded,
                          size: 18,
                          color: isSelected ? PlayOnTheme.purpleGlow : PlayOnTheme.textSecondary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                m.name,
                                style: TextStyle(
                                  color: isSelected ? PlayOnTheme.purpleGlow : PlayOnTheme.textPrimary,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                ),
                              ),
                              Text(
                                m.type,
                                style: const TextStyle(color: PlayOnTheme.textTertiary, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_rounded, color: PlayOnTheme.purpleGlow, size: 18),
                      ],
                    ),
                  );
                }).toList(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: PlayOnTheme.bgSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: PlayOnTheme.glassBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        modelName,
                        style: const TextStyle(color: PlayOnTheme.textPrimary, fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down_rounded, color: PlayOnTheme.purpleGlow, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Botón de rotación manual de API
              IconButton(
                icon: const Icon(Icons.sync_rounded, color: PlayOnTheme.cyanAccent, size: 20),
                tooltip: 'Rotar API Key (Actual: #$activeKey)',
                onPressed: () {
                  aiProv.rotateKey();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Cambiado a Groq API #${aiProv.activeKeyIndex + 1} de 5'),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.cleaning_services_rounded, color: PlayOnTheme.textSecondary, size: 19),
                tooltip: 'Limpiar chat',
                onPressed: () => aiProv.clearChat(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionBanner(BuildContext context, AiAssistantProvider aiProv) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PlayOnTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PlayOnTheme.cyanAccent.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: PlayOnTheme.cyanAccent.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: PlayOnTheme.cyanAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.folder_special_rounded, color: PlayOnTheme.cyanAccent, size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Permisos de Archivos del Teléfono',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Concede acceso a los archivos para que la IA pueda mover, ver, buscar, renombrar y crear carpetas y playlists en tu teléfono.',
            style: TextStyle(color: PlayOnTheme.textSecondary, fontSize: 12, height: 1.3),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => aiProv.requestStoragePermission(),
                  icon: const Icon(Icons.lock_open_rounded, size: 15),
                  label: const Text(
                    'Conceder Acceso',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PlayOnTheme.cyanAccent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => openAppSettings(),
                icon: const Icon(Icons.settings_outlined, size: 15),
                label: const Text('Ajustes', style: TextStyle(fontSize: 11.5)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: PlayOnTheme.textSecondary,
                  side: const BorderSide(color: PlayOnTheme.glassBorder),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.05, end: 0);
  }

  Widget _buildMessageBubble(BuildContext context, AiChatMessage msg, AiAssistantProvider aiProv) {
    final isUser = msg.sender == AiMessageSender.user;
    final isSystem = msg.sender == AiMessageSender.system;

    if (isSystem) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: PlayOnTheme.bgSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: PlayOnTheme.glassBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: PlayOnTheme.cyanAccent, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg.text,
                style: const TextStyle(color: PlayOnTheme.textSecondary, fontSize: 12.5),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                Container(
                  width: 30,
                  height: 30,
                  margin: const EdgeInsets.only(right: 8, top: 4),
                  decoration: BoxDecoration(
                    gradient: PlayOnTheme.primaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: PlayOnTheme.glowShadow(blur: 6),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 15),
                ),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: isUser ? PlayOnTheme.primaryGradient : null,
                    color: isUser ? null : PlayOnTheme.bgCard,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isUser ? 18 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 18),
                    ),
                    border: Border.all(
                      color: isUser ? Colors.transparent : PlayOnTheme.glassBorder,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        msg.text,
                        style: TextStyle(
                          color: isUser ? Colors.white : PlayOnTheme.textPrimary,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      if (msg.verificationAction != null) ...[
                        const SizedBox(height: 12),
                        _buildVerificationCard(context, msg.verificationAction!, aiProv),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (msg.quickSuggestions != null && msg.quickSuggestions!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: msg.quickSuggestions!.map((sug) {
                return GestureDetector(
                  onTap: () {
                    _textController.text = sug;
                    _sendMessage(aiProv);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: PlayOnTheme.purplePrimary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: PlayOnTheme.purplePrimary.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      sug,
                      style: const TextStyle(color: PlayOnTheme.purpleGlow, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.05, end: 0);
  }

  /// Tarjeta de confirmación previa para eliminación de canciones, carpetas, playlists o videos
  Widget _buildVerificationCard(
    BuildContext context,
    AiVerificationAction action,
    AiAssistantProvider aiProv,
  ) {
    final isPending = action.isConfirmed == null;
    final isConfirmed = action.isConfirmed == true;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEF5350).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEF5350).withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF5350), size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  action.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            action.description,
            style: const TextStyle(color: PlayOnTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          if (isPending) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => aiProv.cancelAction(action),
                  style: TextButton.styleFrom(
                    foregroundColor: PlayOnTheme.textSecondary,
                  ),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => aiProv.confirmAction(action),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF5350),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  icon: const Icon(Icons.delete_forever_rounded, size: 16),
                  label: const Text('Confirmar Eliminación', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
          ] else if (isConfirmed) ...[
            const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: PlayOnTheme.emeraldActive, size: 16),
                SizedBox(width: 6),
                Text('Acción confirmada y ejecutada', style: TextStyle(color: PlayOnTheme.emeraldActive, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ] else ...[
            const Row(
              children: [
                Icon(Icons.cancel_rounded, color: PlayOnTheme.textTertiary, size: 16),
                SizedBox(width: 6),
                Text('Acción cancelada', style: TextStyle(color: PlayOnTheme.textTertiary, fontSize: 12)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildThinkingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              gradient: PlayOnTheme.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 15),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: PlayOnTheme.bgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: PlayOnTheme.glassBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: PlayOnTheme.purpleGlow),
                ),
                const SizedBox(width: 10),
                Text(
                  'Pensando y ejecutando comando...',
                  style: TextStyle(color: PlayOnTheme.purpleGlow.withValues(alpha: 0.9), fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(BuildContext context, AiAssistantProvider aiProv) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: PlayOnTheme.bgCard,
        border: const Border(top: BorderSide(color: PlayOnTheme.glassBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: PlayOnTheme.bgSurface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: PlayOnTheme.divider),
              ),
              child: TextField(
                controller: _textController,
                style: const TextStyle(color: PlayOnTheme.textPrimary, fontSize: 14),
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _sendMessage(aiProv),
                decoration: const InputDecoration(
                  hintText: 'Pídele a la IA (ej: Organiza por artista, busca rock, crea playlist)...',
                  hintStyle: TextStyle(color: PlayOnTheme.textTertiary, fontSize: 13),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              _sendMessage(aiProv);
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: PlayOnTheme.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: PlayOnTheme.glowShadow(blur: 10),
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
