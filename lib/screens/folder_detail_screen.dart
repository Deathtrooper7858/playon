import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song_model.dart';
import '../providers/music_provider.dart';
import '../services/file_management_service.dart';
import '../theme.dart';
import '../widgets/add_to_playlist_dialog.dart';
import '../widgets/mini_player.dart';
import '../widgets/move_to_folder_sheet.dart';
import '../widgets/song_tile.dart';
import 'library_tabs/song_options_helper.dart';
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

  void _toggleSongSelection(int id) {
    setState(() {
      if (_selectedSongIds.contains(id)) {
        _selectedSongIds.remove(id);
        if (_selectedSongIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedSongIds.add(id);
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
            Icon(Icons.warning_amber_rounded, color: Color(0xFFEF5350)),
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
              backgroundColor: const Color(0xFFEF5350),
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
        await FileManagementService.deleteFolder(
          folderPath: currentPath,
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

  @override
  Widget build(BuildContext context) {
    return Consumer<MusicProvider>(
      builder: (context, provider, _) {
        final folderSongs = _getFolderSongs(provider);
        final folderPath = folderSongs.isNotEmpty ? (folderSongs.first.folderPath ?? '') : '';

        return Scaffold(
          backgroundColor: PlayOnTheme.bgDeep,
          body: SafeArea(
            child: Column(
              children: [
                // Top Custom App Bar
                _buildAppBar(context, folderPath, folderSongs),

                // Folder Header Card
                _buildHeaderCard(context, folderSongs, folderPath, provider),

                // Songs List
                Expanded(
                  child: folderSongs.isEmpty
                      ? const Center(
                          child: Text(
                            'Esta carpeta no contiene canciones',
                            style: TextStyle(color: PlayOnTheme.textSecondary),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 90),
                          physics: const BouncingScrollPhysics(),
                          itemCount: folderSongs.length,
                          itemBuilder: (context, index) {
                            final song = folderSongs[index];
                            final isCurrent = provider.currentSong?.id == song.id;
                            final isSelected = _selectedSongIds.contains(song.id);

                            return SongTile(
                              song: song,
                              isCurrent: isCurrent,
                              isPlaying: provider.isPlaying,
                              isSelectionMode: _isSelectionMode,
                              isSelected: isSelected,
                              onTap: () {
                                if (_isSelectionMode) {
                                  _toggleSongSelection(song.id);
                                } else {
                                  provider.playFolder(widget.folderName, initialIndex: index);
                                }
                              },
                              onSelectChanged: (_) => _toggleSongSelection(song.id),
                              onOptionsTap: () => SongOptionsHelper.showSongOptions(context, song),
                            );
                          },
                        ),
                ),

                // Mini Player
                _MiniPlayerSlot(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NowPlayingScreen()),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppBar(BuildContext context, String folderPath, List<PlayOnSong> folderSongs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: PlayOnTheme.textPrimary, size: 20),
            onPressed: () {
              if (_isSelectionMode) {
                setState(() {
                  _isSelectionMode = false;
                  _selectedSongIds.clear();
                });
              } else {
                Navigator.pop(context);
              }
            },
          ),
          Expanded(
            child: Text(
              _isSelectionMode ? '${_selectedSongIds.length} seleccionadas' : widget.folderName,
              style: const TextStyle(
                color: PlayOnTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_isSelectionMode) ...[
            TextButton(
              onPressed: () => _toggleSelectAll(folderSongs),
              child: Text(
                _selectedSongIds.length == folderSongs.length ? 'Desmarcar' : 'Todas',
                style: const TextStyle(color: PlayOnTheme.purpleGlow),
              ),
            ),
            if (_selectedSongIds.isNotEmpty) ...[
              IconButton(
                icon: const Icon(Icons.playlist_add_rounded, color: PlayOnTheme.pinkAccent),
                onPressed: () {
                  final selected = folderSongs.where((s) => _selectedSongIds.contains(s.id)).toList();
                  AddToPlaylistDialog.showBatch(context, selected);
                  setState(() => _isSelectionMode = false);
                },
              ),
              IconButton(
                icon: const Icon(Icons.drive_file_move_rounded, color: PlayOnTheme.amberWarning),
                onPressed: () {
                  final selected = folderSongs.where((s) => _selectedSongIds.contains(s.id)).toList();
                  MoveToFolderSheet.showBatch(context, songs: selected);
                  setState(() => _isSelectionMode = false);
                },
              ),
            ],
          ] else ...[
            IconButton(
              icon: const Icon(Icons.checklist_rounded, color: PlayOnTheme.textSecondary),
              tooltip: 'Selección múltiple',
              onPressed: () => setState(() => _isSelectionMode = true),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: PlayOnTheme.textSecondary),
              color: PlayOnTheme.bgCard,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              onSelected: (val) {
                if (val == 'rename' && folderPath.isNotEmpty) {
                  _renameFolderDialog(folderPath, folderSongs);
                } else if (val == 'delete' && folderPath.isNotEmpty) {
                  _deleteFolderDialog(folderPath, folderSongs);
                }
              },
              itemBuilder: (_) => [
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
        ],
      ),
    );
  }

  Widget _buildHeaderCard(
    BuildContext context,
    List<PlayOnSong> folderSongs,
    String folderPath,
    MusicProvider provider,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PlayOnTheme.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PlayOnTheme.glassBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: PlayOnTheme.cyanGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: PlayOnTheme.glowShadow(color: PlayOnTheme.cyanAccent, blur: 12),
            ),
            child: const Icon(Icons.folder_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.folderName,
                  style: const TextStyle(
                    color: PlayOnTheme.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '${folderSongs.length} canciones • ${_formatTotalDuration(folderSongs)}',
                  style: const TextStyle(color: PlayOnTheme.textSecondary, fontSize: 12.5),
                ),
              ],
            ),
          ),
          if (folderSongs.isNotEmpty) ...[
            GestureDetector(
              onTap: () => provider.playFolder(widget.folderName, shuffle: true),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: PlayOnTheme.bgSurface,
                  shape: BoxShape.circle,
                  border: Border.all(color: PlayOnTheme.glassBorder),
                ),
                child: const Icon(Icons.shuffle_rounded, color: PlayOnTheme.pinkAccent, size: 20),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => provider.playFolder(widget.folderName, initialIndex: 0),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: PlayOnTheme.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: PlayOnTheme.glowShadow(blur: 10),
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniPlayerSlot extends StatelessWidget {
  final VoidCallback onTap;
  const _MiniPlayerSlot({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Selector<MusicProvider, PlayOnSong?>(
      selector: (_, p) => p.currentSong,
      builder: (_, song, __) {
        if (song == null) return const SizedBox.shrink();
        return MiniPlayer(
          provider: context.read<MusicProvider>(),
          onTap: onTap,
        );
      },
    );
  }
}
