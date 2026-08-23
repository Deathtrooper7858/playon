import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song_model.dart';
import '../providers/music_provider.dart';
import '../services/native_tags_service.dart';
import '../theme.dart';

class EditTagsDialog extends StatefulWidget {
  final PlayOnSong song;

  const EditTagsDialog({super.key, required this.song});

  static Future<void> show(BuildContext context, PlayOnSong song) {
    return showDialog(
      context: context,
      builder: (_) => EditTagsDialog(song: song),
    );
  }

  @override
  State<EditTagsDialog> createState() => _EditTagsDialogState();
}

class _EditTagsDialogState extends State<EditTagsDialog> {
  late TextEditingController _titleController;
  late TextEditingController _artistController;
  late TextEditingController _albumController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.song.title);
    _artistController = TextEditingController(text: widget.song.artist);
    _albumController = TextEditingController(text: widget.song.album);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _albumController.dispose();
    super.dispose();
  }

  Future<void> _saveTags() async {
    final title = _titleController.text.trim();
    final artist = _artistController.text.trim();
    final album = _albumController.text.trim();

    if (title.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      await NativeTagsService.setAudioTags(
        path: widget.song.uri,
        title: title,
        artist: artist,
        album: album,
      );

      if (!mounted) return;

      // Refrescar biblioteca
      await context.read<MusicProvider>().loadSongs();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text('Metadatos actualizados con éxito'),
              ],
            ),
            backgroundColor: PlayOnTheme.emeraldActive,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar tags: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: PlayOnTheme.bgCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: PlayOnTheme.glassBorder, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: PlayOnTheme.purplePrimary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.edit_note_rounded, color: PlayOnTheme.purpleGlow, size: 22),
                ),
                const SizedBox(width: 14),
                Text(
                  'Editar Etiquetas ID3',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),

            _buildInputField('Título', _titleController, Icons.music_note_rounded),
            const SizedBox(height: 14),
            _buildInputField('Artista', _artistController, Icons.person_rounded),
            const SizedBox(height: 14),
            _buildInputField('Álbum', _albumController, Icons.album_rounded),

            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Cancelar', style: TextStyle(color: PlayOnTheme.textSecondary)),
                ),
                const SizedBox(width: 12),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: PlayOnTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: PlayOnTheme.glowShadow(blur: 12),
                  ),
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveTags,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'Guardar',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: PlayOnTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: const TextStyle(color: PlayOnTheme.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: PlayOnTheme.textTertiary, size: 18),
            filled: true,
            fillColor: PlayOnTheme.bgSurface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: PlayOnTheme.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: PlayOnTheme.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: PlayOnTheme.purplePrimary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
