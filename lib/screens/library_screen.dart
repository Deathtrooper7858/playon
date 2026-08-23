import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../models/song_model.dart';
import '../providers/music_provider.dart';
import '../providers/playlist_provider.dart';
import '../services/playlist_db.dart';
import '../theme.dart';
import '../widgets/add_to_playlist_dialog.dart';
import '../widgets/edit_tags_dialog.dart';
import '../widgets/equalizer_bars.dart';
import '../widgets/mini_player.dart';
import 'now_playing_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Buenos días';
    if (hour < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PlayOnTheme.bgDeep,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildTabs(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _SongsTab(searchQuery: _searchQuery),
                  _FavoritesTab(searchQuery: _searchQuery),
                  _PlaylistsTab(searchQuery: _searchQuery),
                  const _FoldersTab(),
                ],
              ),
            ),
            _MiniPlayerSlot(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NowPlayingScreen(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          if (!_showSearch) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/icons/logo.png',
                width: 38,
                height: 38,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getGreeting(),
                  style: const TextStyle(
                    color: PlayOnTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'PlayOn Music',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                ),
              ],
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.search_rounded),
              color: PlayOnTheme.textSecondary,
              onPressed: () => setState(() => _showSearch = true),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              color: PlayOnTheme.textSecondary,
              onPressed: () => context.read<MusicProvider>().loadSongs(),
            ),
          ] else ...[
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: PlayOnTheme.bgSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: PlayOnTheme.divider),
                ),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: const TextStyle(color: PlayOnTheme.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Buscar canciones, artistas...',
                    hintStyle: TextStyle(color: PlayOnTheme.textTertiary, fontSize: 14),
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.search_rounded, color: PlayOnTheme.purpleGlow),
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.close_rounded),
              color: PlayOnTheme.textSecondary,
              onPressed: () {
                setState(() {
                  _showSearch = false;
                  _searchQuery = '';
                  _searchController.clear();
                });
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 44,
      decoration: BoxDecoration(
        color: PlayOnTheme.bgSurface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PlayOnTheme.glassBorder),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: PlayOnTheme.primaryGradient,
          borderRadius: BorderRadius.circular(12),
          boxShadow: PlayOnTheme.glowShadow(blur: 10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: PlayOnTheme.textSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12.5),
        tabs: const [
          Tab(text: 'Canciones'),
          Tab(text: 'Favoritos'),
          Tab(text: 'Playlists'),
          Tab(text: 'Carpetas'),
        ],
      ),
    );
  }
}

// ── Mini Player Slot ────────────────────────────────────────────────────────

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

// ── Songs Tab ──────────────────────────────────────────────────────────────

class _SongsTab extends StatelessWidget {
  final String searchQuery;

  const _SongsTab({required this.searchQuery});

  @override
  Widget build(BuildContext context) {
    return Selector<MusicProvider, _SongsTabData>(
      selector: (_, p) => _SongsTabData(
        isLoading: p.isLoading,
        songs: p.currentQueue,
        currentSongId: p.currentSong?.id,
      ),
      shouldRebuild: (prev, next) =>
          prev.isLoading != next.isLoading ||
          prev.currentSongId != next.currentSongId ||
          prev.songs.length != next.songs.length,
      builder: (context, data, _) {
        if (data.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: PlayOnTheme.purplePrimary),
          );
        }

        final songs = _filterSongs(data.songs, searchQuery);

        if (songs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: PlayOnTheme.bgSurface,
                    shape: BoxShape.circle,
                    border: Border.all(color: PlayOnTheme.divider),
                  ),
                  child: const Icon(Icons.music_off_rounded, size: 48, color: PlayOnTheme.purpleDim),
                ),
                const SizedBox(height: 16),
                Text(
                  searchQuery.isEmpty ? 'No hay canciones en la biblioteca' : 'Sin resultados',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  searchQuery.isEmpty
                      ? 'Descarga música desde la pestaña Download o agrega archivos a tu teléfono'
                      : 'Prueba con otro término de búsqueda',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: PlayOnTheme.bgSurface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${songs.length} pistas',
                      style: const TextStyle(color: PlayOnTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Spacer(),
                  _ShuffleAllButton(songs: songs),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: PlayOnTheme.purplePrimary,
                backgroundColor: PlayOnTheme.bgCard,
                onRefresh: () => context.read<MusicProvider>().loadSongs(),
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 12),
                  itemCount: songs.length,
                  itemBuilder: (context, i) {
                    final song = songs[i];
                    final isPlaying = data.currentSongId == song.id;
                    return _SongTile(
                      song: song,
                      isPlaying: isPlaying,
                      onTap: () {
                        final provider = context.read<MusicProvider>();
                        final idx = provider.currentQueue.indexOf(song);
                        provider.playSong(idx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const NowPlayingScreen()),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static List<PlayOnSong> _filterSongs(List<PlayOnSong> songs, String query) {
    if (query.isEmpty) return songs;
    final q = query.toLowerCase();
    return songs
        .where((s) => s.title.toLowerCase().contains(q) || s.artist.toLowerCase().contains(q))
        .toList();
  }
}

// ── Favorites Tab ──────────────────────────────────────────────────────────

class _FavoritesTab extends StatelessWidget {
  final String searchQuery;

  const _FavoritesTab({required this.searchQuery});

  @override
  Widget build(BuildContext context) {
    return Selector<MusicProvider, _SongsTabData>(
      selector: (_, p) => _SongsTabData(
        isLoading: p.isLoading,
        songs: p.favoriteSongs,
        currentSongId: p.currentSong?.id,
      ),
      shouldRebuild: (prev, next) =>
          prev.isLoading != next.isLoading ||
          prev.currentSongId != next.currentSongId ||
          prev.songs.length != next.songs.length,
      builder: (context, data, _) {
        if (data.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: PlayOnTheme.purplePrimary),
          );
        }

        final songs = _SongsTab._filterSongs(data.songs, searchQuery);

        if (songs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: PlayOnTheme.bgSurface,
                    shape: BoxShape.circle,
                    border: Border.all(color: PlayOnTheme.divider),
                  ),
                  child: const Icon(Icons.favorite_rounded, size: 48, color: PlayOnTheme.pinkAccent),
                ),
                const SizedBox(height: 16),
                Text(
                  searchQuery.isEmpty ? 'Aún no tienes favoritas' : 'Sin resultados en favoritos',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Toca el icono de corazón en el reproductor para agregar canciones aquí',
                  style: TextStyle(color: PlayOnTheme.textSecondary, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: PlayOnTheme.bgSurface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${songs.length} favoritas',
                      style: const TextStyle(color: PlayOnTheme.pinkAccent, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Spacer(),
                  _ShuffleAllButton(songs: songs),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: PlayOnTheme.purplePrimary,
                backgroundColor: PlayOnTheme.bgCard,
                onRefresh: () => context.read<MusicProvider>().loadSongs(),
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 12),
                  itemCount: songs.length,
                  itemBuilder: (context, i) {
                    final song = songs[i];
                    final isPlaying = data.currentSongId == song.id;
                    return _SongTile(
                      song: song,
                      isPlaying: isPlaying,
                      onTap: () {
                        final provider = context.read<MusicProvider>();
                        provider.playCustomQueue(songs, i);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const NowPlayingScreen()),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Playlists Tab (SQLite) ─────────────────────────────────────────────────

class _PlaylistsTab extends StatelessWidget {
  final String searchQuery;

  const _PlaylistsTab({required this.searchQuery});

  void _showCreateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const _CreatePlaylistDialog(),
    );
  }

  static List<CustomPlaylist> _filterPlaylists(List<CustomPlaylist> playlists, String query) {
    if (query.isEmpty) return playlists;
    final q = query.toLowerCase();
    return playlists.where((p) => p.name.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlaylistProvider>(
      builder: (context, playlistProv, _) {
        if (playlistProv.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: PlayOnTheme.purplePrimary),
          );
        }

        final playlists = _filterPlaylists(playlistProv.playlists, searchQuery);

        if (playlists.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: PlayOnTheme.bgSurface,
                    shape: BoxShape.circle,
                    border: Border.all(color: PlayOnTheme.divider),
                  ),
                  child: const Icon(Icons.queue_music_rounded, size: 48, color: PlayOnTheme.cyanAccent),
                ),
                const SizedBox(height: 16),
                Text(
                  searchQuery.isEmpty ? 'Crea tus propias Playlists' : 'Sin resultados en playlists',
                  style: const TextStyle(color: PlayOnTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  searchQuery.isEmpty
                      ? 'Organiza tu música por géneros, estados de ánimo o listas personalizadas'
                      : 'Prueba con otro término de búsqueda',
                  style: const TextStyle(color: PlayOnTheme.textSecondary, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: PlayOnTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: PlayOnTheme.glowShadow(blur: 12),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () => _showCreateDialog(context),
                    icon: const Icon(Icons.add_rounded, color: Colors.white),
                    label: const Text('Crear Playlist', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
              child: Row(
                children: [
                  Text(
                    '${playlists.length} listas personalizadas',
                    style: const TextStyle(color: PlayOnTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _showCreateDialog(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: PlayOnTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded, size: 16, color: Colors.white),
                          SizedBox(width: 4),
                          Text('Nueva', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                itemCount: playlists.length,
                itemBuilder: (context, i) {
                  final pl = playlists[i];
                  final count = playlistProv.songCounts[pl.id] ?? 0;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: PlayOnTheme.bgCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: PlayOnTheme.divider),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: PlayOnTheme.cyanGradient,
                        ),
                        child: const Icon(Icons.queue_music_rounded, color: Colors.white, size: 28),
                      ),
                      title: Text(
                        pl.name,
                        style: const TextStyle(color: PlayOnTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '$count canciones',
                        style: const TextStyle(color: PlayOnTheme.textSecondary, fontSize: 13),
                      ),
                      trailing: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded, color: PlayOnTheme.textSecondary),
                        color: PlayOnTheme.bgSurface,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        onSelected: (action) async {
                          if (action == 'play') {
                            final songs = await playlistProv.getSongsForPlaylist(pl.id);
                            if (songs.isNotEmpty && context.mounted) {
                              playlistProv.playPlaylist(songs, 0);
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const NowPlayingScreen()));
                            }
                          } else if (action == 'delete') {
                            await playlistProv.deletePlaylist(pl.id);
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                            value: 'play',
                            child: Row(
                              children: [
                                Icon(Icons.play_arrow_rounded, color: PlayOnTheme.purpleGlow),
                                SizedBox(width: 10),
                                Text('Reproducir', style: TextStyle(color: PlayOnTheme.textPrimary)),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_rounded, color: Colors.redAccent),
                                SizedBox(width: 10),
                                Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      onTap: () async {
                        final songs = await playlistProv.getSongsForPlaylist(pl.id);
                        if (context.mounted) {
                          _showPlaylistDetailSheet(context, pl, songs, playlistProv);
                        }
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

  void _showPlaylistDetailSheet(
      BuildContext context, CustomPlaylist playlist, List<PlayOnSong> songs, PlaylistProvider prov) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.75,
        decoration: const BoxDecoration(
          color: PlayOnTheme.bgCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: PlayOnTheme.divider, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), gradient: PlayOnTheme.cyanGradient),
                  child: const Icon(Icons.queue_music_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(playlist.name, style: const TextStyle(color: PlayOnTheme.textPrimary, fontSize: 19, fontWeight: FontWeight.bold)),
                      Text('${songs.length} canciones', style: const TextStyle(color: PlayOnTheme.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
                if (songs.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.play_circle_fill_rounded, size: 42, color: PlayOnTheme.purplePrimary),
                    onPressed: () {
                      prov.playPlaylist(songs, 0);
                      Navigator.pop(ctx);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const NowPlayingScreen()));
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: PlayOnTheme.divider),
            if (songs.isEmpty)
              const Expanded(
                child: Center(
                  child: Text('Esta playlist está vacía. Añade canciones desde el menú de cualquier pista.',
                      style: TextStyle(color: PlayOnTheme.textSecondary, fontSize: 13), textAlign: TextAlign.center),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: songs.length,
                  itemBuilder: (context, i) {
                    final song = songs[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: QueryArtworkWidget(
                          id: song.id,
                          type: ArtworkType.AUDIO,
                          format: ArtworkFormat.JPEG,
                          artworkQuality: FilterQuality.medium,
                          size: 150,
                          artworkWidth: 44,
                          artworkHeight: 44,
                          nullArtworkWidget: Container(
                            width: 44,
                            height: 44,
                            color: PlayOnTheme.bgSurface,
                            child: const Icon(Icons.music_note_rounded, color: PlayOnTheme.purpleDim),
                          ),
                        ),
                      ),
                      title: Text(song.title, style: const TextStyle(color: PlayOnTheme.textPrimary, fontSize: 14), maxLines: 1),
                      subtitle: Text(song.artist, style: const TextStyle(color: PlayOnTheme.textSecondary, fontSize: 12), maxLines: 1),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.redAccent, size: 20),
                        onPressed: () async {
                          await prov.removeSongFromPlaylist(playlist.id, song.id);
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                      ),
                      onTap: () {
                        prov.playPlaylist(songs, i);
                        Navigator.pop(ctx);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const NowPlayingScreen()));
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Folders Tab ────────────────────────────────────────────────────────────

class _FoldersTab extends StatelessWidget {
  const _FoldersTab();

  @override
  Widget build(BuildContext context) {
    return Selector<MusicProvider, _FoldersTabData>(
      selector: (_, p) => _FoldersTabData(
        isLoading: p.isLoading,
        folders: p.folders,
        selectedFolder: p.selectedFolder,
        allCount: p.allSongs.length,
        folderCounts: p.folderSongCounts,
      ),
      shouldRebuild: (prev, next) =>
          prev.isLoading != next.isLoading ||
          prev.selectedFolder != next.selectedFolder ||
          prev.folders.length != next.folders.length ||
          prev.allCount != next.allCount,
      builder: (context, data, _) {
        if (data.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: PlayOnTheme.purplePrimary),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _FolderCard(
              name: 'Todas las carpetas',
              count: data.allCount,
              isSelected: data.selectedFolder == null,
              onTap: () => context.read<MusicProvider>().selectFolder(null),
              icon: Icons.library_music_rounded,
            ),
            const SizedBox(height: 8),
            ...data.folders.map((folder) {
              final count = data.folderCounts[folder] ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _FolderCard(
                  name: folder,
                  count: count,
                  isSelected: data.selectedFolder == folder,
                  onTap: () => context.read<MusicProvider>().selectFolder(folder),
                  icon: Icons.folder_rounded,
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _FoldersTabData {
  final bool isLoading;
  final List<String> folders;
  final String? selectedFolder;
  final int allCount;
  final Map<String, int> folderCounts;

  const _FoldersTabData({
    required this.isLoading,
    required this.folders,
    required this.selectedFolder,
    required this.allCount,
    required this.folderCounts,
  });
}

class _FolderCard extends StatelessWidget {
  final String name;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData icon;

  const _FolderCard({
    required this.name,
    required this.count,
    required this.isSelected,
    required this.onTap,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? PlayOnTheme.purpleDim.withValues(alpha: 0.35)
              : PlayOnTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? PlayOnTheme.purplePrimary : PlayOnTheme.divider,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected ? PlayOnTheme.glowShadow(blur: 12) : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? PlayOnTheme.purplePrimary : PlayOnTheme.bgSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: isSelected ? Colors.white : PlayOnTheme.purpleGlow, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: isSelected ? Colors.white : PlayOnTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$count canciones',
                    style: const TextStyle(color: PlayOnTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: PlayOnTheme.purpleGlow, size: 20),
          ],
        ),
      ),
    );
  }
}

class _SongsTabData {
  final bool isLoading;
  final List<PlayOnSong> songs;
  final int? currentSongId;

  const _SongsTabData({
    required this.isLoading,
    required this.songs,
    required this.currentSongId,
  });
}

class _ShuffleAllButton extends StatelessWidget {
  final List<PlayOnSong> songs;

  const _ShuffleAllButton({required this.songs});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final provider = context.read<MusicProvider>();
        if (!provider.isShuffle) provider.toggleShuffle();
        provider.playSong(0);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NowPlayingScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          gradient: PlayOnTheme.primaryGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: PlayOnTheme.glowShadow(blur: 10),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shuffle_rounded, size: 16, color: Colors.white),
            SizedBox(width: 6),
            Text(
              'Aleatorio',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SongTile extends StatelessWidget {
  final PlayOnSong song;
  final bool isPlaying;
  final VoidCallback onTap;

  const _SongTile({required this.song, required this.isPlaying, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      decoration: BoxDecoration(
        color: isPlaying ? PlayOnTheme.purpleDim.withValues(alpha: 0.25) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: isPlaying ? Border.all(color: PlayOnTheme.purplePrimary.withValues(alpha: 0.45)) : null,
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: PlayOnTheme.bgSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: QueryArtworkWidget(
                  id: song.id,
                  type: ArtworkType.AUDIO,
                  format: ArtworkFormat.JPEG,
                  artworkQuality: FilterQuality.medium,
                  size: 150,
                  nullArtworkWidget: Container(
                    decoration: const BoxDecoration(
                      gradient: PlayOnTheme.surfaceGradient,
                    ),
                    child: Icon(
                      Icons.music_note_rounded,
                      color: isPlaying ? PlayOnTheme.purpleGlow : PlayOnTheme.purpleDim,
                      size: 24,
                    ),
                  ),
                  artworkWidth: 48,
                  artworkHeight: 48,
                  keepOldArtwork: true,
                ),
              ),
            ),
            if (isPlaying)
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: EqualizerBars(isPlaying: true, color: Colors.white, size: 20),
                ),
              ),
          ],
        ),
        title: Text(
          song.title,
          style: TextStyle(
            color: isPlaying ? PlayOnTheme.purpleGlow : PlayOnTheme.textPrimary,
            fontSize: 14.5,
            fontWeight: isPlaying ? FontWeight.w700 : FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          song.artist,
          style: const TextStyle(
            color: PlayOnTheme.textSecondary,
            fontSize: 12.5,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              song.durationFormatted,
              style: const TextStyle(color: PlayOnTheme.textTertiary, fontSize: 11.5),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: PlayOnTheme.textTertiary, size: 20),
              color: PlayOnTheme.bgSurface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              onSelected: (action) {
                if (action == 'playlist') {
                  AddToPlaylistDialog.show(context, song);
                } else if (action == 'tags') {
                  EditTagsDialog.show(context, song);
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'playlist',
                  child: Row(
                    children: [
                      Icon(Icons.playlist_add_rounded, color: PlayOnTheme.pinkAccent),
                      SizedBox(width: 10),
                      Text('Añadir a Playlist', style: TextStyle(color: PlayOnTheme.textPrimary, fontSize: 13.5)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'tags',
                  child: Row(
                    children: [
                      Icon(Icons.edit_note_rounded, color: PlayOnTheme.purpleGlow),
                      SizedBox(width: 10),
                      Text('Editar Etiquetas ID3', style: TextStyle(color: PlayOnTheme.textPrimary, fontSize: 13.5)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CreatePlaylistDialog extends StatefulWidget {
  const _CreatePlaylistDialog();

  @override
  State<_CreatePlaylistDialog> createState() => _CreatePlaylistDialogState();
}

class _CreatePlaylistDialogState extends State<_CreatePlaylistDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: PlayOnTheme.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Nueva Playlist', style: TextStyle(color: PlayOnTheme.textPrimary, fontSize: 18)),
      content: TextField(
        controller: _controller,
        autofocus: true,
        style: const TextStyle(color: PlayOnTheme.textPrimary),
        decoration: InputDecoration(
          hintText: 'Nombre de la playlist...',
          hintStyle: const TextStyle(color: PlayOnTheme.textTertiary),
          filled: true,
          fillColor: PlayOnTheme.bgSurface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: PlayOnTheme.divider),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: PlayOnTheme.textSecondary)),
        ),
        ElevatedButton(
          onPressed: () async {
            final name = _controller.text.trim();
            if (name.isNotEmpty) {
              await context.read<PlaylistProvider>().createPlaylist(name);
              if (context.mounted) Navigator.pop(context);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: PlayOnTheme.purplePrimary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Crear', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

