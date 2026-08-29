import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/music_provider.dart';
import '../../services/file_management_service.dart';
import '../../theme.dart';
import '../folder_detail_screen.dart';

class FoldersTab extends StatelessWidget {
  const FoldersTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MusicProvider>(
      builder: (context, provider, _) {
        final folders = provider.folders;
        final counts = provider.folderSongCounts;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              child: Row(
                children: [
                  Text(
                    '${folders.length} ${folders.length == 1 ? 'carpeta' : 'carpetas'}',
                    style: const TextStyle(
                      color: PlayOnTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PlayOnTheme.bgSurface,
                      foregroundColor: PlayOnTheme.purpleGlow,
                      side: const BorderSide(color: PlayOnTheme.glassBorder),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.create_new_folder_rounded, size: 18),
                    label: const Text('Nueva carpeta', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                    onPressed: () => _showCreateFolderDialog(context, provider),
                  ),
                ],
              ),
            ),
            if (folders.isEmpty && provider.allSongs.isEmpty)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: PlayOnTheme.cyanAccent.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.folder_off_rounded,
                            size: 56,
                            color: PlayOnTheme.cyanAccent,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'No se encontraron carpetas de música',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Tus canciones aparecerán organizadas por las carpetas en las que se encuentren',
                          style: TextStyle(color: PlayOnTheme.textSecondary, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 90, left: 14, right: 14),
                  physics: const BouncingScrollPhysics(),
                  itemCount: folders.length + 1, // +1 for "Todas las canciones"
                  itemBuilder: (context, index) {
                    // Index 0 is "Todas las canciones"
                    if (index == 0) {
                      final isAllActive = provider.selectedFolder == null;
                      final isPlayingAll = isAllActive && provider.isPlaying;

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: isAllActive
                              ? PlayOnTheme.purplePrimary.withValues(alpha: 0.15)
                              : PlayOnTheme.bgCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isAllActive
                                ? PlayOnTheme.purplePrimary.withValues(alpha: 0.8)
                                : PlayOnTheme.glassBorder,
                            width: isAllActive ? 1.5 : 1.0,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: PlayOnTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: PlayOnTheme.glowShadow(blur: 8),
                            ),
                            child: const Icon(
                              Icons.library_music_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          title: Row(
                            children: [
                              const Text(
                                'Todas las canciones',
                                style: TextStyle(
                                  color: PlayOnTheme.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              if (isAllActive) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: PlayOnTheme.purplePrimary.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Todas',
                                    style: TextStyle(
                                      color: PlayOnTheme.purpleGlow,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            '${provider.allSongs.length} canciones en total',
                            style: const TextStyle(color: PlayOnTheme.textSecondary, fontSize: 12.5),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  isPlayingAll ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                                  color: PlayOnTheme.purpleGlow,
                                  size: 34,
                                ),
                                tooltip: isPlayingAll ? 'Pausar' : 'Reproducir todas',
                                onPressed: () {
                                  if (isPlayingAll) {
                                    provider.playPause();
                                  } else {
                                    provider.playFolder(null);
                                  }
                                },
                              ),
                            ],
                          ),
                          onTap: () {
                            provider.setFolderFilter(null);
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Mostrando todas las canciones en la pestaña Canciones'),
                                behavior: SnackBarBehavior.floating,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                      );
                    }

                    final folderName = folders[index - 1];
                    final count = counts[folderName] ?? 0;
                    final isFolderActive = provider.selectedFolder == folderName;
                    final isFolderPlaying = isFolderActive && provider.isPlaying;

                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: isFolderActive
                            ? PlayOnTheme.cyanAccent.withValues(alpha: 0.12)
                            : PlayOnTheme.bgCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isFolderActive
                              ? PlayOnTheme.cyanAccent.withValues(alpha: 0.8)
                              : PlayOnTheme.glassBorder,
                          width: isFolderActive ? 1.5 : 1.0,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: PlayOnTheme.cyanGradient,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: PlayOnTheme.glowShadow(color: PlayOnTheme.cyanAccent, blur: 8),
                          ),
                          child: const Icon(
                            Icons.folder_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                folderName,
                                style: const TextStyle(
                                  color: PlayOnTheme.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isFolderActive) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: PlayOnTheme.cyanAccent.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isFolderPlaying ? 'Reproduciendo' : 'Seleccionada',
                                  style: const TextStyle(
                                    color: PlayOnTheme.cyanAccent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          '$count ${count == 1 ? 'canción' : 'canciones'}',
                          style: const TextStyle(color: PlayOnTheme.textSecondary, fontSize: 12.5),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                isFolderPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                                color: PlayOnTheme.cyanAccent,
                                size: 34,
                              ),
                              tooltip: isFolderPlaying ? 'Pausar' : 'Reproducir carpeta',
                              onPressed: () {
                                if (isFolderPlaying) {
                                  provider.playPause();
                                } else {
                                  provider.playFolder(folderName);
                                }
                              },
                            ),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: PlayOnTheme.textTertiary,
                              size: 14,
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FolderDetailScreen(folderName: folderName),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  void _showCreateFolderDialog(BuildContext context, MusicProvider provider) async {
    final controller = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    final baseDir = await FileManagementService.getDefaultMusicBaseDir(provider.allSongs);

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PlayOnTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Nueva Carpeta', style: TextStyle(color: PlayOnTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Se creará dentro de: $baseDir', style: const TextStyle(color: PlayOnTheme.textSecondary, fontSize: 12)),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: PlayOnTheme.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Nombre de la carpeta',
                hintStyle: TextStyle(color: PlayOnTheme.textTertiary),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: PlayOnTheme.cyanAccent),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: PlayOnTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: PlayOnTheme.cyanAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(ctx);
                final res = await FileManagementService.createFolder(parentPath: baseDir, folderName: name);
                if (res != null) {
                  await provider.loadSongs();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Carpeta "$name" creada'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } else {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('No se pudo crear la carpeta'),
                      backgroundColor: Color(0xFFEF5350),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: const Text('Crear', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
