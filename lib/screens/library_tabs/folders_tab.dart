import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/music_provider.dart';
import '../../services/file_management_service.dart';
import '../../services/search_helper.dart';
import '../../theme.dart';
import '../folder_detail_screen.dart';

class FoldersTab extends StatelessWidget {
  final String searchQuery;

  const FoldersTab({super.key, this.searchQuery = ''});

  @override
  Widget build(BuildContext context) {
    return Consumer<MusicProvider>(
      builder: (context, provider, _) {
        final folders = provider.folders;
        final counts = provider.folderSongCounts;
        final isSearching = searchQuery.trim().isNotEmpty;

        final filteredFolders = isSearching
            ? folders.where((f) => SearchHelper.matchesText(f, searchQuery)).toList()
            : folders;
        final showAllOption = !isSearching || SearchHelper.matchesText('Todas las canciones', searchQuery);
        final totalItems = filteredFolders.length + (showAllOption ? 1 : 0);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              child: Row(
                children: [
                  Text(
                    isSearching
                        ? '${filteredFolders.length} ${filteredFolders.length == 1 ? 'carpeta encontrada' : 'carpetas encontradas'}'
                        : '${folders.length} ${folders.length == 1 ? 'carpeta' : 'carpetas'}',
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
            else if (isSearching && totalItems == 0)
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
                            Icons.search_off_rounded,
                            size: 56,
                            color: PlayOnTheme.cyanAccent,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Sin resultados para "$searchQuery"',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Intenta con otro término o revisa la ortografía',
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
                  padding: const EdgeInsets.only(bottom: 140, left: 14, right: 14),
                  physics: const BouncingScrollPhysics(),
                  itemCount: totalItems,
                  itemBuilder: (context, index) {
                    // Index 0 is "Todas las canciones" when showAllOption is true
                    if (showAllOption && index == 0) {
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

                    final folderName = filteredFolders[showAllOption ? index - 1 : index];
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
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert_rounded, color: PlayOnTheme.textTertiary, size: 20),
                              color: PlayOnTheme.bgCard,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              onSelected: (val) {
                                final folderSongs = provider.allSongs.where((s) => s.folderName == folderName).toList();
                                final folderPath = folderSongs.isNotEmpty ? (folderSongs.first.folderPath ?? '') : '';
                                if (val == 'move') {
                                  _showMoveFolderDialog(context, provider, folderName, folderPath, folderSongs);
                                } else if (val == 'rename') {
                                  _showRenameFolderDialog(context, provider, folderName, folderPath, folderSongs);
                                } else if (val == 'delete') {
                                  _showDeleteFolderDialog(context, provider, folderName, folderPath, folderSongs);
                                }
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'move',
                                  child: Row(
                                    children: [
                                      Icon(Icons.drive_file_move_rounded, color: PlayOnTheme.cyanAccent, size: 18),
                                      SizedBox(width: 10),
                                      Text('Mover carpeta', style: TextStyle(color: PlayOnTheme.textPrimary)),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'rename',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_rounded, color: PlayOnTheme.purpleGlow, size: 18),
                                      SizedBox(width: 10),
                                      Text('Renombrar carpeta', style: TextStyle(color: PlayOnTheme.textPrimary)),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline_rounded, color: Color(0xFFEF5350), size: 18),
                                      SizedBox(width: 10),
                                      Text('Eliminar carpeta', style: TextStyle(color: Color(0xFFEF5350))),
                                    ],
                                  ),
                                ),
                              ],
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

  void _showMoveFolderDialog(BuildContext context, MusicProvider provider, String folderName, String currentPath, List<dynamic> songs) async {
    final baseDir = await FileManagementService.getDefaultMusicBaseDir(provider.allSongs);
    final srcPath = currentPath.isNotEmpty ? currentPath : '$baseDir/$folderName';
    final otherFolders = provider.folders.where((f) => f != folderName).toList();

    if (!context.mounted) return;

    final targetPath = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: PlayOnTheme.bgCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: PlayOnTheme.glassBorder),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.drive_file_move_rounded, color: PlayOnTheme.cyanAccent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Mover carpeta "$folderName"',
                    style: const TextStyle(color: PlayOnTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'Selecciona la carpeta de destino donde ubicar esta carpeta:',
              style: TextStyle(color: PlayOnTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.home_filled, color: PlayOnTheme.purpleGlow),
              title: const Text('Raíz de Música', style: TextStyle(color: PlayOnTheme.textPrimary, fontWeight: FontWeight.bold)),
              subtitle: Text(baseDir, style: const TextStyle(color: PlayOnTheme.textTertiary, fontSize: 11)),
              onTap: () => Navigator.pop(ctx, baseDir),
            ),
            const Divider(color: PlayOnTheme.divider),
            if (otherFolders.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No hay otras carpetas', style: TextStyle(color: PlayOnTheme.textTertiary, fontSize: 12)),
              )
            else
              ...otherFolders.map((f) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.folder_rounded, color: PlayOnTheme.cyanAccent),
                title: Text(f, style: const TextStyle(color: PlayOnTheme.textPrimary)),
                onTap: () => Navigator.pop(ctx, '$baseDir/$f'),
              )),
          ],
        ),
      ),
    );

    if (targetPath != null && context.mounted) {
      try {
        final songList = provider.allSongs.where((s) => s.folderName == folderName).toList();
        await FileManagementService.moveFolder(
          sourceFolderPath: srcPath,
          targetParentPath: targetPath,
          songsInFolder: songList,
        );
        await provider.loadSongs();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: PlayOnTheme.bgCard,
            content: Text('Carpeta movida exitosamente', style: TextStyle(color: PlayOnTheme.textPrimary)),
          ),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: PlayOnTheme.bgCard,
            content: Text('Error al mover carpeta: $e', style: const TextStyle(color: PlayOnTheme.pinkAccent)),
          ),
        );
      }
    }
  }

  void _showRenameFolderDialog(BuildContext context, MusicProvider provider, String folderName, String currentPath, List<dynamic> songs) async {
    final controller = TextEditingController(text: folderName);
    final baseDir = await FileManagementService.getDefaultMusicBaseDir(provider.allSongs);
    final srcPath = currentPath.isNotEmpty ? currentPath : '$baseDir/$folderName';

    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PlayOnTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Renombrar carpeta', style: TextStyle(color: PlayOnTheme.textPrimary, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: PlayOnTheme.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Nuevo nombre de carpeta',
            hintStyle: TextStyle(color: PlayOnTheme.textTertiary),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: PlayOnTheme.divider)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: PlayOnTheme.cyanAccent)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: PlayOnTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: PlayOnTheme.cyanAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Renombrar', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && controller.text.trim().isNotEmpty && controller.text.trim() != folderName) {
      final newName = controller.text.trim();
      try {
        final songList = provider.allSongs.where((s) => s.folderName == folderName).toList();
        await FileManagementService.renameFolder(
          currentFolderPath: srcPath,
          newFolderName: newName,
          songsInFolder: songList,
        );
        await provider.loadSongs();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: PlayOnTheme.bgCard,
            content: Text('Carpeta renombrada a "$newName"', style: const TextStyle(color: PlayOnTheme.textPrimary)),
          ),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: PlayOnTheme.bgCard,
            content: Text('Error al renombrar: $e', style: const TextStyle(color: PlayOnTheme.pinkAccent)),
          ),
        );
      }
    }
  }

  void _showDeleteFolderDialog(BuildContext context, MusicProvider provider, String folderName, String currentPath, List<dynamic> songs) async {
    final baseDir = await FileManagementService.getDefaultMusicBaseDir(provider.allSongs);
    final srcPath = currentPath.isNotEmpty ? currentPath : '$baseDir/$folderName';
    final songList = provider.allSongs.where((s) => s.folderName == folderName).toList();

    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PlayOnTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFEF5350)),
            SizedBox(width: 10),
            Text('Eliminar carpeta', style: TextStyle(color: PlayOnTheme.textPrimary, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar permanentemente la carpeta "$folderName" y sus ${songList.length} canciones?',
          style: const TextStyle(color: PlayOnTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: PlayOnTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF5350),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FileManagementService.deleteFolder(
          folderPath: srcPath,
          songsInFolder: songList,
        );
        await provider.loadSongs();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: PlayOnTheme.bgCard,
            content: Text('Carpeta "$folderName" eliminada', style: const TextStyle(color: PlayOnTheme.textPrimary)),
          ),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: PlayOnTheme.bgCard,
            content: Text('Error al eliminar: $e', style: const TextStyle(color: PlayOnTheme.pinkAccent)),
          ),
        );
      }
    }
  }
}
