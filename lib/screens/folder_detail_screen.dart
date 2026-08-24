import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song_model.dart';
import '../providers/music_provider.dart';
import '../services/file_management_service.dart';
import '../theme.dart';
import '../widgets/add_to_playlist_dialog.dart';
import '../widgets/edit_tags_dialog.dart';
import '../widgets/equalizer_bars.dart';
import '../widgets/mini_player.dart';
import '../widgets/move_to_folder_sheet.dart';
import 'now_playing_screen.dart';

class FolderDetailScreen extends StatefulWidget {
  final String folderName;

  const FolderDetailScreen({super.key, required this.folderName});

  @override
  State<FolderDetailScreen> createState() => _FolderDetailScreenState();
}

class _FolderDetailScreenState extends State<FolderDetailScreen> {
  bool _isSelectionMode = false;
  final Set<int> _selectedSongIds = {};

  List<PlayOnSong> _getFolderSongs(MusicProvider provider) {
    return provider.allSongs.where((s) => s.folderName == widget.folderName).toList();
  }

  String _formatTotalDuration(List<PlayOnSong> songs) {
    final totalMs = songs.fold<int>(0, (sum, s) => sum + s.duration);
    final minutes = (totalMs / 60000).floor();
    final hours = (minutes / 60).floor();
    final remainingMins = minutes % 60;
    if (hours > 0) {
      return '$hours h $remainingMins min';
    }
    return '$minutes min';
  }

  void _toggleSelectAll(List<PlayOnSong> songs) {
    setState(() {
      if (_selectedSongIds.length == songs.length) {
        _selectedSongIds.clear();
      } else {
        _selectedSongIds.addAll(songs.map((s) => s.id));
      }
    });
  }

  Future<void> _renameFolderDialog(String currentPath, List<PlayOnSong> songs) async {
    final controller = TextEditingController(text: widget.folderName);
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
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: PlayOnTheme.purplePrimary)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: PlayOnTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: PlayOnTheme.purplePrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Renombrar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && controller.text.trim().isNotEmpty && controller.text.trim() != widget.folderName) {
      final newName = controller.text.trim();
      try {
        await FileManagementService.renameFolder(
          currentFolderPath: currentPath,
          newFolderName: newName,
          songsInFolder: songs,
        );
        if (!mounted) return;
        final provider = context.read<MusicProvider>();
        final navigator = Navigator.of(context);
        final messenger = ScaffoldMessenger.of(context);
        await provider.loadSongs();
        navigator.pop();
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: PlayOnTheme.bgCard,
            content: Text('Carpeta renombrada a "$newName"', style: const TextStyle(color: PlayOnTheme.textPrimary)),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: PlayOnTheme.bgCard,
            content: Text('Error al renombrar: $e', style: const TextStyle(color: PlayOnTheme.pinkAccent)),
          ),
        );
      }
    }
  }

  Future<void> _deleteFolderDialog(String currentPath, List<PlayOnSong> songs) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PlayOnTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: PlayOnTheme.pinkAccent),
            SizedBox(width: 10),
            Text('Eliminar carpeta', style: TextStyle(color: PlayOnTheme.textPrimary, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar permanentemente la carpeta "${widget.folderName}" y sus ${songs.length} canciones?',
          style: const TextStyle(color: PlayOnTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: PlayOnTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: PlayOnTheme.pinkAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FileManagementService.deleteFolder(folderPath: currentPath, songsInFolder: songs);
        if (!mounted) return;
        final provider = context.read<MusicProvider>();
        final navigator = Navigator.of(context);
        final messenger = ScaffoldMessenger.of(context);
        await provider.loadSongs();
        navigator.pop();
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: PlayOnTheme.bgCard,
            content: Text('Carpeta "${widget.folderName}" eliminada', style: const TextStyle(color: PlayOnTheme.textPrimary)),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: PlayOnTheme.bgCard,
            content: Text('Error al eliminar: $e', style: const TextStyle(color: PlayOnTheme.pinkAccent)),
          ),
        );
      }
    }
  }

  Future<void> _renameSongDialog(PlayOnSong song) async {
    final currentFileName = File(song.filePath).uri.pathSegments.last;
    final baseName = currentFileName.contains('.')
        ? currentFileName.substring(0, currentFileName.lastIndexOf('.'))
        : currentFileName;

    final controller = TextEditingController(text: baseName);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PlayOnTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Renombrar archivo', style: TextStyle(color: PlayOnTheme.textPrimary, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: PlayOnTheme.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Nuevo nombre de archivo',
            hintStyle: TextStyle(color: PlayOnTheme.textTertiary),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: PlayOnTheme.divider)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: PlayOnTheme.purplePrimary)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: PlayOnTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: PlayOnTheme.purplePrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Renombrar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && controller.text.trim().isNotEmpty) {
      try {
        await FileManagementService.renameSongFile(
          song: song,
          newFileNameWithoutExtension: controller.text.trim(),
        );
        if (!mounted) return;
        final provider = context.read<MusicProvider>();
        final messenger = ScaffoldMessenger.of(context);
        await provider.loadSongs();
        messenger.showSnackBar(
          const SnackBar(
            backgroundColor: PlayOnTheme.bgCard,
            content: Text('Archivo renombrado', style: TextStyle(color: PlayOnTheme.textPrimary)),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: PlayOnTheme.bgCard,
            content: Text('Error al renombrar: $e', style: const TextStyle(color: PlayOnTheme.pinkAccent)),
          ),
        );
      }
    }
  }

  Future<void> _deleteSongDialog(PlayOnSong song) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PlayOnTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Eliminar archivo', style: TextStyle(color: PlayOnTheme.textPrimary, fontWeight: FontWeight.bold)),
        content: Text(
          '¿Deseas eliminar permanentemente "${song.title}" de tu dispositivo?',
          style: const TextStyle(color: PlayOnTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: PlayOnTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: PlayOnTheme.pinkAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FileManagementService.deleteSong(song);
      if (!mounted) return;
      final provider = context.read<MusicProvider>();
      final messenger = ScaffoldMessenger.of(context);
      await provider.loadSongs();
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: PlayOnTheme.bgCard,
          content: Text('"${song.title}" eliminada', style: const TextStyle(color: PlayOnTheme.textPrimary)),
        ),
      );
    }
  }

  Future<void> _deleteSelectedBatch(List<PlayOnSong> allFolderSongs) async {
    final selectedSongs = allFolderSongs.where((s) => _selectedSongIds.contains(s.id)).toList();
    if (selectedSongs.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PlayOnTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Eliminar canciones', style: TextStyle(color: PlayOnTheme.textPrimary, fontWeight: FontWeight.bold)),
        content: Text(
          '¿Deseas eliminar permanentemente las ${selectedSongs.length} canciones seleccionadas?',
          style: const TextStyle(color: PlayOnTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: PlayOnTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: PlayOnTheme.pinkAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final count = await FileManagementService.deleteSongs(selectedSongs);
      if (!mounted) return;
      final provider = context.read<MusicProvider>();
      final messenger = ScaffoldMessenger.of(context);
      setState(() {
        _selectedSongIds.clear();
        _isSelectionMode = false;
      });
      await provider.loadSongs();
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: PlayOnTheme.bgCard,
          content: Text('$count canciones eliminadas', style: const TextStyle(color: PlayOnTheme.textPrimary)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MusicProvider>();
    final songs = _getFolderSongs(provider);
    final folderPath = songs.isNotEmpty && songs.first.folderPath != null ? songs.first.folderPath! : '';

    return Scaffold(
      backgroundColor: PlayOnTheme.bgDeep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: PlayOnTheme.textSecondary,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isSelectionMode ? '${_selectedSongIds.length} seleccionadas' : widget.folderName,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          if (songs.isNotEmpty) ...[
            IconButton(
              icon: Icon(
                _isSelectionMode ? Icons.close_rounded : Icons.checklist_rounded,
                color: _isSelectionMode ? PlayOnTheme.pinkAccent : PlayOnTheme.purpleGlow,
              ),
              onPressed: () {
                setState(() {
                  _isSelectionMode = !_isSelectionMode;
                  _selectedSongIds.clear();
                });
              },
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: PlayOnTheme.textSecondary),
              color: PlayOnTheme.bgCard,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              onSelected: (val) {
                if (val == 'rename') {
                  _renameFolderDialog(folderPath, songs);
                } else if (val == 'delete') {
                  _deleteFolderDialog(folderPath, songs);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'rename',
                  child: Row(
                    children: [
                      Icon(Icons.edit_rounded, color: PlayOnTheme.cyanAccent, size: 18),
                      SizedBox(width: 12),
                      Text('Renombrar carpeta', style: TextStyle(color: PlayOnTheme.textPrimary)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline_rounded, color: PlayOnTheme.pinkAccent, size: 18),
                      SizedBox(width: 12),
                      Text('Eliminar carpeta', style: TextStyle(color: PlayOnTheme.pinkAccent)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: songs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.folder_off_rounded, size: 48, color: PlayOnTheme.purpleDim),
                          const SizedBox(height: 12),
                          const Text('No hay canciones en esta carpeta', style: TextStyle(color: PlayOnTheme.textSecondary)),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: PlayOnTheme.purplePrimary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                            label: const Text('Volver a Carpetas', style: TextStyle(color: Colors.white)),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      children: [
                        // Card de Información de la Carpeta
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                PlayOnTheme.purplePrimary.withValues(alpha: 0.25),
                                PlayOnTheme.bgCard,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: PlayOnTheme.glassBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: PlayOnTheme.purplePrimary.withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(Icons.folder_rounded, color: PlayOnTheme.purpleGlow, size: 28),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          widget.folderName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${songs.length} pistas • ${_formatTotalDuration(songs)}',
                                          style: const TextStyle(color: PlayOnTheme.textSecondary, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (folderPath.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: PlayOnTheme.bgSurface.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.folder_open_rounded, color: PlayOnTheme.textTertiary, size: 14),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          folderPath,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(color: PlayOnTheme.textTertiary, fontSize: 11),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),

                              // Botones de Reproducción
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: PlayOnTheme.purplePrimary,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                                      label: const Text('Reproducir', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      onPressed: () {
                                        provider.selectFolder(widget.folderName);
                                        provider.playSong(0);
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => const NowPlayingScreen()),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: PlayOnTheme.pinkAccent,
                                        side: const BorderSide(color: PlayOnTheme.pinkAccent),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      icon: const Icon(Icons.shuffle_rounded, color: PlayOnTheme.pinkAccent),
                                      label: const Text('Aleatorio', style: TextStyle(fontWeight: FontWeight.bold)),
                                      onPressed: () {
                                        provider.selectFolder(widget.folderName);
                                        if (!provider.isShuffle) provider.toggleShuffle();
                                        provider.playSong(0);
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => const NowPlayingScreen()),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        if (_isSelectionMode) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                TextButton.icon(
                                  icon: Icon(
                                    _selectedSongIds.length == songs.length
                                        ? Icons.check_box_rounded
                                        : Icons.check_box_outline_blank_rounded,
                                    color: PlayOnTheme.purpleGlow,
                                    size: 20,
                                  ),
                                  label: Text(
                                    _selectedSongIds.length == songs.length ? 'Deseleccionar todo' : 'Seleccionar todo',
                                    style: const TextStyle(color: PlayOnTheme.purpleGlow),
                                  ),
                                  onPressed: () => _toggleSelectAll(songs),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Lista de canciones
                        ...List.generate(songs.length, (idx) {
                          final song = songs[idx];
                          final isSelected = _selectedSongIds.contains(song.id);
                          final isCurrent = provider.currentSong?.id == song.id;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? PlayOnTheme.purpleDim.withValues(alpha: 0.3)
                                  : (isCurrent ? PlayOnTheme.purplePrimary.withValues(alpha: 0.1) : PlayOnTheme.bgCard),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isCurrent
                                    ? PlayOnTheme.purplePrimary.withValues(alpha: 0.5)
                                    : PlayOnTheme.glassBorder,
                              ),
                            ),
                            child: ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                              leading: _isSelectionMode
                                  ? Checkbox(
                                      value: isSelected,
                                      activeColor: PlayOnTheme.purplePrimary,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                      onChanged: (val) {
                                        setState(() {
                                          if (val == true) {
                                            _selectedSongIds.add(song.id);
                                          } else {
                                            _selectedSongIds.remove(song.id);
                                          }
                                        });
                                      },
                                    )
                                  : Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: PlayOnTheme.bgSurface,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: isCurrent && provider.isPlaying
                                          ? const Center(child: EqualizerBars(isPlaying: true))
                                          : Center(
                                              child: Text(
                                                '${idx + 1}',
                                                style: const TextStyle(color: PlayOnTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                    ),
                              title: Text(
                                song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isCurrent ? PlayOnTheme.purpleGlow : PlayOnTheme.textPrimary,
                                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                '${song.artist} • ${song.durationFormatted}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: PlayOnTheme.textSecondary, fontSize: 11),
                              ),
                              trailing: _isSelectionMode
                                  ? null
                                  : PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert_rounded, color: PlayOnTheme.textSecondary, size: 20),
                                      color: PlayOnTheme.bgCard,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      onSelected: (val) {
                                        if (val == 'move') {
                                          MoveToFolderSheet.show(context, songs: [song]);
                                        } else if (val == 'rename') {
                                          _renameSongDialog(song);
                                        } else if (val == 'delete') {
                                          _deleteSongDialog(song);
                                        } else if (val == 'playlist') {
                                          AddToPlaylistDialog.show(context, song);
                                        } else if (val == 'tags') {
                                          EditTagsDialog.show(context, song);
                                        }
                                      },
                                      itemBuilder: (_) => [
                                        const PopupMenuItem(
                                          value: 'move',
                                          child: Row(
                                            children: [
                                              Icon(Icons.drive_file_move_rounded, color: PlayOnTheme.cyanAccent, size: 18),
                                              SizedBox(width: 12),
                                              Text('Mover a otra carpeta', style: TextStyle(color: PlayOnTheme.textPrimary)),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'rename',
                                          child: Row(
                                            children: [
                                              Icon(Icons.drive_file_rename_outline_rounded, color: PlayOnTheme.purpleGlow, size: 18),
                                              SizedBox(width: 12),
                                              Text('Renombrar archivo', style: TextStyle(color: PlayOnTheme.textPrimary)),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'playlist',
                                          child: Row(
                                            children: [
                                              Icon(Icons.playlist_add_rounded, color: PlayOnTheme.emeraldActive, size: 18),
                                              SizedBox(width: 12),
                                              Text('Añadir a Playlist', style: TextStyle(color: PlayOnTheme.textPrimary)),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'tags',
                                          child: Row(
                                            children: [
                                              Icon(Icons.edit_note_rounded, color: PlayOnTheme.amberWarning, size: 18),
                                              SizedBox(width: 12),
                                              Text('Editar etiquetas ID3', style: TextStyle(color: PlayOnTheme.textPrimary)),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete_outline_rounded, color: PlayOnTheme.pinkAccent, size: 18),
                                              SizedBox(width: 12),
                                              Text('Eliminar archivo', style: TextStyle(color: PlayOnTheme.pinkAccent)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                              onTap: () {
                                if (_isSelectionMode) {
                                  setState(() {
                                    if (isSelected) {
                                      _selectedSongIds.remove(song.id);
                                    } else {
                                      _selectedSongIds.add(song.id);
                                    }
                                  });
                                } else {
                                  provider.selectFolder(widget.folderName);
                                  provider.playSong(idx);
                                }
                              },
                            ),
                          );
                        }),
                      ],
                    ),
            ),

            // Barra inferior para selección múltiple (Batch operations)
            if (_isSelectionMode && _selectedSongIds.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: PlayOnTheme.bgCard,
                  border: const Border(top: BorderSide(color: PlayOnTheme.divider)),
                  boxShadow: PlayOnTheme.glowShadow(blur: 16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PlayOnTheme.cyanAccent,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.drive_file_move_rounded, size: 18),
                        label: Text(
                          'Mover (${_selectedSongIds.length})',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          final selectedSongs = songs.where((s) => _selectedSongIds.contains(s.id)).toList();
                          MoveToFolderSheet.show(
                            context,
                            songs: selectedSongs,
                            onMoved: () {
                              setState(() {
                                _selectedSongIds.clear();
                                _isSelectionMode = false;
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PlayOnTheme.pinkAccent.withValues(alpha: 0.2),
                        foregroundColor: PlayOnTheme.pinkAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        side: const BorderSide(color: PlayOnTheme.pinkAccent),
                      ),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('Eliminar', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () => _deleteSelectedBatch(songs),
                    ),
                  ],
                ),
              ),
            ],

            // Mini Player Slot
            Consumer<MusicProvider>(
              builder: (_, p, __) {
                if (p.currentSong == null) return const SizedBox.shrink();
                return MiniPlayer(
                  provider: p,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NowPlayingScreen()),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
