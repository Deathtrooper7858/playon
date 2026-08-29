import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song_model.dart';
import '../providers/music_provider.dart';
import '../providers/playlist_provider.dart';
import '../services/playlist_db.dart';
import '../services/search_helper.dart';
import '../theme.dart';
import '../widgets/mini_player.dart';
import '../widgets/song_tile.dart';
import 'library_tabs/song_options_helper.dart';
import 'now_playing_screen.dart';

class PlaylistDetailScreen extends StatefulWidget {
  final CustomPlaylist playlist;

  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  late CustomPlaylist _playlist;
  String _searchQuery = '';
  bool _showSearch = false;
  final TextEditingController _searchController = TextEditingController();

  List<PlayOnSong> _songs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _playlist = widget.playlist;
    _loadSongs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSongs() async {
    if (!mounted) return;
    try {
      final prov = context.read<PlaylistProvider>();
      final songs = await prov.getSongsForPlaylist(_playlist.id);
      if (mounted) {
        setState(() {
          _songs = songs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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

  Future<void> _renameDialog(PlaylistProvider prov) async {
    final controller = TextEditingController(text: _playlist.name);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PlayOnTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Renombrar Playlist', style: TextStyle(color: PlayOnTheme.textPrimary, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: PlayOnTheme.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Nuevo nombre...',
            hintStyle: TextStyle(color: PlayOnTheme.textTertiary),
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
            child: const Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && controller.text.trim().isNotEmpty && controller.text.trim() != _playlist.name) {
      final newName = controller.text.trim();
      await prov.renamePlaylist(_playlist.id, newName);
      if (mounted) {
        setState(() {
          _playlist = CustomPlaylist(
            id: _playlist.id,
            name: newName,
            createdAt: _playlist.createdAt,
          );
        });
      }
    }
  }

  Future<void> _deleteDialog(PlaylistProvider prov) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PlayOnTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Eliminar Playlist', style: TextStyle(color: PlayOnTheme.textPrimary, fontWeight: FontWeight.bold)),
        content: Text(
          '¿Estás seguro de que deseas eliminar la playlist "${_playlist.name}"?',
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

    if (confirmed == true && mounted) {
      await prov.deletePlaylist(_playlist.id);
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  void _showAddSongsSheet(BuildContext context, PlaylistProvider playlistProv, List<PlayOnSong> currentSongs) {
    final musicProv = context.read<MusicProvider>();
    final currentIds = currentSongs.map((s) => s.id).toSet();
    final availableSongs = musicProv.allSongs.where((s) => !currentIds.contains(s.id)).toList();
    final selectedToAdd = <int>{};
    String sheetSearch = '';
    final searchController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filteredAvailable = availableSongs.where((s) {
              if (sheetSearch.trim().isEmpty) return true;
              return SearchHelper.matchesSong(s, sheetSearch);
            }).toList();

            return SafeArea(
              top: false,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.85,
                  decoration: BoxDecoration(
                    color: PlayOnTheme.bgCard,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    border: Border.all(color: PlayOnTheme.glassBorder),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(color: PlayOnTheme.divider, borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                      Row(
                        children: [
                          const Text(
                            'Añadir canciones',
                            style: TextStyle(color: PlayOnTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          if (selectedToAdd.isNotEmpty)
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: PlayOnTheme.purplePrimary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              ),
                              onPressed: () async {
                                Navigator.pop(ctx);
                                await playlistProv.addSongsToPlaylist(_playlist.id, selectedToAdd.toList());
                                await _loadSongs();
                              },
                              child: Text('Añadir (${selectedToAdd.length})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Search bar
                      Container(
                        decoration: BoxDecoration(
                          color: PlayOnTheme.bgSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: PlayOnTheme.glassBorder),
                        ),
                        child: TextField(
                          controller: searchController,
                          style: const TextStyle(color: PlayOnTheme.textPrimary, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Buscar por título, artista o álbum...',
                            hintStyle: const TextStyle(color: PlayOnTheme.textTertiary, fontSize: 13),
                            border: InputBorder.none,
                            prefixIcon: const Icon(Icons.search_rounded, color: PlayOnTheme.purpleGlow, size: 20),
                            suffixIcon: sheetSearch.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.close_rounded, size: 18, color: PlayOnTheme.textSecondary),
                                    onPressed: () {
                                      setSheetState(() {
                                        sheetSearch = '';
                                        searchController.clear();
                                      });
                                    },
                                  )
                                : null,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                          ),
                          onChanged: (v) {
                            setSheetState(() => sheetSearch = v);
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Song count & Select all button
                      if (availableSongs.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          child: Row(
                            children: [
                              Text(
                                '${filteredAvailable.length} ${filteredAvailable.length == 1 ? 'canción' : 'canciones'}',
                                style: const TextStyle(color: PlayOnTheme.textSecondary, fontSize: 12),
                              ),
                              const Spacer(),
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () {
                                  setSheetState(() {
                                    final currentFilteredIds = filteredAvailable.map((s) => s.id).toSet();
                                    if (selectedToAdd.containsAll(currentFilteredIds)) {
                                      selectedToAdd.removeAll(currentFilteredIds);
                                    } else {
                                      selectedToAdd.addAll(currentFilteredIds);
                                    }
                                  });
                                },
                                child: Text(
                                  filteredAvailable.isNotEmpty && selectedToAdd.containsAll(filteredAvailable.map((s) => s.id))
                                      ? 'Desmarcar todas'
                                      : 'Marcar visibles',
                                  style: const TextStyle(color: PlayOnTheme.purpleGlow, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: availableSongs.isEmpty
                            ? const Center(
                                child: Text('Todas tus canciones ya están en esta playlist',
                                    style: TextStyle(color: PlayOnTheme.textSecondary)),
                              )
                            : filteredAvailable.isEmpty
                                ? Center(
                                    child: Text('No hay canciones que coincidan con "$sheetSearch"',
                                        style: const TextStyle(color: PlayOnTheme.textSecondary)),
                                  )
                                : ListView.builder(
                                    physics: const BouncingScrollPhysics(),
                                    itemCount: filteredAvailable.length,
                                    itemBuilder: (context, index) {
                                      final song = filteredAvailable[index];
                                      final isSelected = selectedToAdd.contains(song.id);

                                      return Container(
                                        margin: const EdgeInsets.symmetric(vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? PlayOnTheme.purplePrimary.withValues(alpha: 0.12)
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: CheckboxListTile(
                                          value: isSelected,
                                          activeColor: PlayOnTheme.purplePrimary,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          secondary: ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: Container(
                                              width: 40,
                                              height: 40,
                                              decoration: const BoxDecoration(
                                                gradient: PlayOnTheme.primaryGradient,
                                              ),
                                              child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 20),
                                            ),
                                          ),
                                          title: Text(
                                            song.title,
                                            style: const TextStyle(color: PlayOnTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          subtitle: Text(
                                            '${song.artist} • ${song.durationFormatted}',
                                            style: const TextStyle(color: PlayOnTheme.textSecondary, fontSize: 12),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          onChanged: (val) {
                                            setSheetState(() {
                                              if (val == true) {
                                                selectedToAdd.add(song.id);
                                              } else {
                                                selectedToAdd.remove(song.id);
                                              }
                                            });
                                          },
                                        ),
                                      );
                                    },
                                  ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final playlistProv = context.watch<PlaylistProvider>();

    final filteredSongs = _songs.where((s) {
      if (_searchQuery.trim().isEmpty) return true;
      return SearchHelper.matchesSong(s, _searchQuery);
    }).toList();

    return Scaffold(
      backgroundColor: PlayOnTheme.bgDeep,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            _buildAppBar(context, playlistProv, _songs),

            // Header Card
            _buildHeaderCard(context, _songs),

            // Songs List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: PlayOnTheme.purplePrimary))
                  : filteredSongs.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.queue_music_rounded, size: 56, color: PlayOnTheme.purpleDim),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'No hay resultados para "$_searchQuery"'
                                    : 'Esta playlist está vacía',
                                style: const TextStyle(color: PlayOnTheme.textSecondary, fontSize: 15),
                              ),
                              if (_searchQuery.isEmpty) ...[
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: PlayOnTheme.purplePrimary,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  icon: const Icon(Icons.add_rounded, color: Colors.white),
                                  label: const Text('Añadir canciones', style: TextStyle(color: Colors.white)),
                                  onPressed: () => _showAddSongsSheet(context, playlistProv, _songs),
                                ),
                              ],
                            ],
                          ),
                        )
                      : Consumer<MusicProvider>(
                          builder: (context, musicProv, _) {
                            return ListView.builder(
                              padding: const EdgeInsets.only(bottom: 90),
                              physics: const BouncingScrollPhysics(),
                              itemCount: filteredSongs.length,
                              itemBuilder: (context, index) {
                                final song = filteredSongs[index];
                                final isCurrent = musicProv.currentSong?.id == song.id;

                                return SongTile(
                                  song: song,
                                  isCurrent: isCurrent,
                                  isPlaying: musicProv.isPlaying,
                                  onTap: () {
                                    final targetIndex = _songs.indexWhere((s) => s.id == song.id);
                                    if (targetIndex != -1) {
                                      musicProv.playCustomQueue(_songs, targetIndex);
                                    } else {
                                      musicProv.playCustomQueue(filteredSongs, index);
                                    }
                                  },
                                  onOptionsTap: () => SongOptionsHelper.showSongOptions(context, song),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.remove_circle_outline_rounded, size: 20),
                                    color: PlayOnTheme.textTertiary,
                                    tooltip: 'Quitar de playlist',
                                    onPressed: () async {
                                      await playlistProv.removeSongFromPlaylist(_playlist.id, song.id);
                                      await _loadSongs();
                                    },
                                  ),
                                );
                              },
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
  }

  Widget _buildAppBar(BuildContext context, PlaylistProvider playlistProv, List<PlayOnSong> songs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: PlayOnTheme.textPrimary, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          if (!_showSearch) ...[
            Expanded(
              child: Text(
                _playlist.name,
                style: const TextStyle(
                  color: PlayOnTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.search_rounded, color: PlayOnTheme.textSecondary),
              onPressed: () => setState(() => _showSearch = true),
            ),
            IconButton(
              icon: const Icon(Icons.add_rounded, color: PlayOnTheme.purpleGlow),
              tooltip: 'Añadir canciones',
              onPressed: () => _showAddSongsSheet(context, playlistProv, songs),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: PlayOnTheme.textSecondary),
              color: PlayOnTheme.bgCard,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              onSelected: (val) {
                if (val == 'rename') {
                  _renameDialog(playlistProv);
                } else if (val == 'delete') {
                  _deleteDialog(playlistProv);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'rename',
                  child: Row(
                    children: [
                      Icon(Icons.edit_rounded, color: PlayOnTheme.purpleGlow, size: 18),
                      SizedBox(width: 10),
                      Text('Renombrar playlist', style: TextStyle(color: PlayOnTheme.textPrimary)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline_rounded, color: Color(0xFFEF5350), size: 18),
                      SizedBox(width: 10),
                      Text('Eliminar playlist', style: TextStyle(color: Color(0xFFEF5350))),
                    ],
                  ),
                ),
              ],
            ),
          ] else ...[
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: PlayOnTheme.bgSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: PlayOnTheme.glassBorder),
                ),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: const TextStyle(color: PlayOnTheme.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Buscar en esta playlist...',
                    hintStyle: TextStyle(color: PlayOnTheme.textTertiary, fontSize: 13),
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.search_rounded, color: PlayOnTheme.purpleGlow, size: 20),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: PlayOnTheme.textSecondary),
              onPressed: () => setState(() {
                _showSearch = false;
                _searchQuery = '';
                _searchController.clear();
              }),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, List<PlayOnSong> songs) {
    final musicProv = context.read<MusicProvider>();

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
              gradient: PlayOnTheme.primaryGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: PlayOnTheme.glowShadow(blur: 12),
            ),
            child: const Icon(Icons.queue_music_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _playlist.name,
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
                  '${songs.length} canciones • ${_formatTotalDuration(songs)}',
                  style: const TextStyle(color: PlayOnTheme.textSecondary, fontSize: 12.5),
                ),
              ],
            ),
          ),
          if (songs.isNotEmpty) ...[
            GestureDetector(
              onTap: () {
                final shuffled = List<PlayOnSong>.from(songs)..shuffle();
                musicProv.playCustomQueue(shuffled, 0);
              },
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
              onTap: () => musicProv.playCustomQueue(songs, 0),
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
