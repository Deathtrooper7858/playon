import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song_model.dart';
import '../providers/music_provider.dart';
import '../services/file_management_service.dart';
import '../theme.dart';

class MoveToFolderSheet extends StatefulWidget {
  final List<PlayOnSong> songs;
  final VoidCallback? onMoved;

  const MoveToFolderSheet({
    super.key,
    required this.songs,
    this.onMoved,
  });

  static Future<void> show(
    BuildContext context, {
    required List<PlayOnSong> songs,
    VoidCallback? onMoved,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MoveToFolderSheet(songs: songs, onMoved: onMoved),
    );
  }

  @override
  State<MoveToFolderSheet> createState() => _MoveToFolderSheetState();
}

class _MoveToFolderSheetState extends State<MoveToFolderSheet> {
  bool _isProcessing = false;
  final TextEditingController _newFolderController = TextEditingController();
  bool _showNewFolderInput = false;

  @override
  void dispose() {
    _newFolderController.dispose();
    super.dispose();
  }

  /// Extrae la lista de carpetas disponibles con sus rutas absolutas
  Map<String, String> _getAvailableFolders(List<PlayOnSong> allSongs) {
    final Map<String, String> folderMap = {};
    for (final song in allSongs) {
      if (song.folderName != null && song.folderPath != null) {
        folderMap[song.folderName!] = song.folderPath!;
      }
    }
    return folderMap;
  }

  Future<void> _moveTo(String targetPath, String folderName) async {
    setState(() => _isProcessing = true);
    try {
      final count = await FileManagementService.moveSongs(
        songs: widget.songs,
        targetFolderPath: targetPath,
      );

      if (!mounted) return;
      final provider = context.read<MusicProvider>();
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      await provider.loadSongs();
      widget.onMoved?.call();
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: PlayOnTheme.bgCard,
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: PlayOnTheme.emeraldActive),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.songs.length == 1
                      ? 'Canción movida a "$folderName"'
                      : '$count canciones movidas a "$folderName"',
                  style: const TextStyle(color: PlayOnTheme.textPrimary),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: PlayOnTheme.bgCard,
          content: Text('Error al mover: $e', style: const TextStyle(color: PlayOnTheme.pinkAccent)),
        ),
      );
    }
  }

  Future<void> _createNewFolderAndMove() async {
    final name = _newFolderController.text.trim();
    if (name.isEmpty) return;

    final provider = context.read<MusicProvider>();
    final baseDir = await FileManagementService.getDefaultMusicBaseDir(provider.allSongs);
    final newPath = await FileManagementService.createFolder(parentPath: baseDir, folderName: name);

    if (newPath != null) {
      await _moveTo(newPath, name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MusicProvider>();
    final folderMap = _getAvailableFolders(provider.allSongs);
    final count = widget.songs.length;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: PlayOnTheme.bgCard.withValues(alpha: 0.94),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: PlayOnTheme.glassBorder, width: 1.5),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Grab Handle
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: PlayOnTheme.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: PlayOnTheme.cyanAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.drive_file_move_rounded, color: PlayOnTheme.cyanAccent, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              count == 1 ? 'Mover a carpeta' : 'Mover $count canciones',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                  ),
                            ),
                            if (count == 1)
                              Text(
                                widget.songs.first.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: PlayOnTheme.textSecondary, fontSize: 12),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  if (_isProcessing) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 36),
                      child: Center(
                        child: CircularProgressIndicator(color: PlayOnTheme.cyanAccent),
                      ),
                    ),
                  ] else ...[
                    // Botón o campo para crear nueva carpeta
                    if (!_showNewFolderInput) ...[
                      InkWell(
                        onTap: () => setState(() => _showNewFolderInput = true),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: PlayOnTheme.bgSurface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: PlayOnTheme.divider),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.create_new_folder_rounded, color: PlayOnTheme.purpleGlow, size: 20),
                              SizedBox(width: 12),
                              Text(
                                '+ Crear nueva carpeta',
                                style: TextStyle(
                                  color: PlayOnTheme.purpleGlow,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: PlayOnTheme.bgSurface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: PlayOnTheme.purplePrimary),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.folder_rounded, color: PlayOnTheme.purplePrimary, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _newFolderController,
                                autofocus: true,
                                style: const TextStyle(color: PlayOnTheme.textPrimary, fontSize: 14),
                                decoration: const InputDecoration(
                                  hintText: 'Nombre de la nueva carpeta...',
                                  hintStyle: TextStyle(color: PlayOnTheme.textTertiary),
                                  border: InputBorder.none,
                                ),
                                onSubmitted: (_) => _createNewFolderAndMove(),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.check_rounded, color: PlayOnTheme.emeraldActive),
                              onPressed: _createNewFolderAndMove,
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: PlayOnTheme.textTertiary),
                              onPressed: () => setState(() => _showNewFolderInput = false),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    const Text(
                      'Selecciona carpeta de destino:',
                      style: TextStyle(color: PlayOnTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),

                    // Lista de carpetas existentes
                    ...folderMap.entries.map((entry) {
                      final folderName = entry.key;
                      final folderPath = entry.value;
                      final songCount = provider.folderSongCounts[folderName] ?? 0;
                      final isCurrent = widget.songs.length == 1 && widget.songs.first.folderName == folderName;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isCurrent ? PlayOnTheme.bgSurface.withValues(alpha: 0.4) : PlayOnTheme.bgSurface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isCurrent ? PlayOnTheme.divider : PlayOnTheme.glassBorder,
                          ),
                        ),
                        child: ListTile(
                          dense: true,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          leading: Icon(
                            Icons.folder_rounded,
                            color: isCurrent ? PlayOnTheme.textTertiary : PlayOnTheme.cyanAccent,
                            size: 24,
                          ),
                          title: Text(
                            folderName,
                            style: TextStyle(
                              color: isCurrent ? PlayOnTheme.textSecondary : PlayOnTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            '$songCount canciones • $folderPath',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: PlayOnTheme.textTertiary, fontSize: 11),
                          ),
                          trailing: isCurrent
                              ? const Text(
                                  'Actual',
                                  style: TextStyle(color: PlayOnTheme.textTertiary, fontSize: 12),
                                )
                              : const Icon(Icons.arrow_forward_ios_rounded, color: PlayOnTheme.textTertiary, size: 14),
                          onTap: isCurrent ? null : () => _moveTo(folderPath, folderName),
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
