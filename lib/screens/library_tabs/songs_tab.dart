import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/song_model.dart';
import '../../providers/music_provider.dart';
import '../../services/file_management_service.dart';
import '../../theme.dart';
import '../../widgets/add_to_playlist_dialog.dart';
import '../../widgets/move_to_folder_sheet.dart';
import '../../widgets/song_tile.dart';
import '../../widgets/sort_filter_sheet.dart';
import 'song_options_helper.dart';

import '../../services/search_helper.dart';

class SongsTab extends StatefulWidget {
  final String searchQuery;

  const SongsTab({super.key, required this.searchQuery});

  @override
  State<SongsTab> createState() => _SongsTabState();
}

class _SongsTabState extends State<SongsTab> {
  final Set<int> _selectedSongIds = {};
  bool _isSelectionMode = false;

  void _toggleSelection(int id) {
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

  void _selectAll(List<PlayOnSong> songs) {
    setState(() {
      if (_selectedSongIds.length == songs.length) {
        _selectedSongIds.clear();
        _isSelectionMode = false;
      } else {
        _selectedSongIds.addAll(songs.map((s) => s.id));
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectedSongIds.clear();
      _isSelectionMode = false;
    });
  }

  List<PlayOnSong> _filterSongs(List<PlayOnSong> songs) {
    if (widget.searchQuery.trim().isEmpty) return songs;
    return songs.where((song) => SearchHelper.matchesSong(song, widget.searchQuery)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MusicProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: PlayOnTheme.purplePrimary),
          );
        }

        final baseSongs = provider.selectedFolder != null
            ? provider.allSongs.where((s) => s.folderName == provider.selectedFolder).toList()
            : provider.allSongs;

        final songs = _filterSongs(baseSongs);

        if (songs.isEmpty) {
          return _buildEmptyState(context, provider);
        }

        return Column(
          children: [
            // Active folder filter banner
            if (provider.selectedFolder != null && !_isSelectionMode)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 2, 16, 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: PlayOnTheme.cyanAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: PlayOnTheme.cyanAccent.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.folder_open_rounded, color: PlayOnTheme.cyanAccent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Carpeta: ${provider.selectedFolder}',
                        style: const TextStyle(
                          color: PlayOnTheme.cyanAccent,
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => provider.clearFolderFilter(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: PlayOnTheme.bgSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: PlayOnTheme.glassBorder),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Mostrar todas',
                              style: TextStyle(
                                color: PlayOnTheme.textPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.close_rounded, size: 13, color: PlayOnTheme.textSecondary),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Controls header: Count, Shuffle All, Sort & Selection Bar
            if (_isSelectionMode)
              _buildSelectionBar(context, songs, provider)
            else
              _buildHeaderControls(context, songs, provider),

            // Song list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 90),
                physics: const BouncingScrollPhysics(),
                itemCount: songs.length,
                itemBuilder: (context, index) {
                  final song = songs[index];
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
                        _toggleSelection(song.id);
                      } else {
                        final targetIndex = baseSongs.indexWhere((s) => s.id == song.id);
                        if (targetIndex != -1) {
                          provider.playCustomQueue(baseSongs, targetIndex);
                        } else {
                          provider.playCustomQueue(songs, index);
                        }
                      }
                    },
                    onSelectChanged: (_) => _toggleSelection(song.id),
                    onOptionsTap: () => SongOptionsHelper.showSongOptions(context, song),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeaderControls(
    BuildContext context,
    List<PlayOnSong> songs,
    MusicProvider provider,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
      child: Row(
        children: [
          Text(
            '${songs.length} ${songs.length == 1 ? 'canción' : 'canciones'}',
            style: const TextStyle(
              color: PlayOnTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          // Sort Button
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => SortFilterSheet.show(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: PlayOnTheme.bgSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: PlayOnTheme.glassBorder),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sort_rounded, color: PlayOnTheme.purpleGlow, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Ordenar',
                    style: TextStyle(
                      color: PlayOnTheme.purpleGlow,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Batch Select Button
          IconButton(
            icon: const Icon(Icons.checklist_rounded, size: 20),
            color: PlayOnTheme.textSecondary,
            tooltip: 'Selección múltiple',
            onPressed: () {
              setState(() => _isSelectionMode = true);
            },
          ),
          // Play Random Button
          IconButton(
            icon: const Icon(Icons.shuffle_rounded, size: 20),
            color: PlayOnTheme.pinkAccent,
            tooltip: 'Reproducción aleatoria',
            onPressed: () {
              if (songs.isNotEmpty) {
                final shuffled = List<PlayOnSong>.from(songs)..shuffle();
                provider.playCustomQueue(shuffled, 0);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionBar(
    BuildContext context,
    List<PlayOnSong> songs,
    MusicProvider provider,
  ) {
    final selectedSongs = songs.where((s) => _selectedSongIds.contains(s.id)).toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: PlayOnTheme.bgSurfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PlayOnTheme.purplePrimary.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            color: PlayOnTheme.textPrimary,
            onPressed: _exitSelectionMode,
          ),
          Text(
            '${_selectedSongIds.length} seleccionadas',
            style: const TextStyle(
              color: PlayOnTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => _selectAll(songs),
            child: Text(
              _selectedSongIds.length == songs.length ? 'Desmarcar' : 'Todas',
              style: const TextStyle(color: PlayOnTheme.purpleGlow, fontSize: 12),
            ),
          ),
          if (_selectedSongIds.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.playlist_add_rounded, color: PlayOnTheme.pinkAccent, size: 22),
              tooltip: 'Añadir a playlist',
              onPressed: () => _addSelectedToPlaylist(context, selectedSongs),
            ),
            IconButton(
              icon: const Icon(Icons.drive_file_move_rounded, color: PlayOnTheme.amberWarning, size: 22),
              tooltip: 'Mover a carpeta',
              onPressed: () => _moveSelectedToFolder(context, selectedSongs),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF5350), size: 22),
              tooltip: 'Eliminar seleccionadas',
              onPressed: () => _deleteSelectedSongs(context, selectedSongs, provider),
            ),
          ],
        ],
      ),
    );
  }

  void _addSelectedToPlaylist(BuildContext context, List<PlayOnSong> songs) {
    if (songs.isEmpty) return;
    AddToPlaylistDialog.showBatch(context, songs);
    _exitSelectionMode();
  }

  void _moveSelectedToFolder(BuildContext context, List<PlayOnSong> songs) {
    if (songs.isEmpty) return;
    MoveToFolderSheet.showBatch(context, songs: songs);
    _exitSelectionMode();
  }

  void _deleteSelectedSongs(
    BuildContext context,
    List<PlayOnSong> songs,
    MusicProvider provider,
  ) {
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PlayOnTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('¿Eliminar ${songs.length} canciones?', style: const TextStyle(color: PlayOnTheme.textPrimary)),
        content: const Text(
          'Se eliminarán físicamente los archivos seleccionados del dispositivo.',
          style: TextStyle(color: PlayOnTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: PlayOnTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF5350),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final deleted = await FileManagementService.deleteSongs(songs);
              _exitSelectionMode();
              await provider.loadSongs();
              messenger.showSnackBar(
                SnackBar(
                  content: Text('Se eliminaron $deleted canciones'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, MusicProvider provider) {
    final isFolderFiltered = provider.selectedFolder != null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: PlayOnTheme.purplePrimary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isFolderFiltered ? Icons.folder_off_rounded : Icons.music_off_rounded,
                size: 56,
                color: isFolderFiltered ? PlayOnTheme.cyanAccent : PlayOnTheme.purpleGlow,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.searchQuery.isNotEmpty
                  ? 'Sin resultados para la búsqueda'
                  : isFolderFiltered
                      ? 'No hay canciones en "${provider.selectedFolder}"'
                      : 'No se encontraron canciones',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              widget.searchQuery.isNotEmpty
                  ? 'Intenta con otro término o verifica la ortografía'
                  : isFolderFiltered
                      ? 'Esta carpeta está vacía o sus archivos fueron movidos'
                      : 'Asegúrate de otorgar permisos de almacenamiento y tener música en tu memoria',
              style: const TextStyle(color: PlayOnTheme.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (isFolderFiltered) ...[
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: PlayOnTheme.cyanAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.library_music_rounded),
                label: const Text('Mostrar todas las canciones', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => provider.clearFolderFilter(),
              ),
            ] else ...[
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: PlayOnTheme.purplePrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Volver a escanear'),
                onPressed: () => provider.loadSongs(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
