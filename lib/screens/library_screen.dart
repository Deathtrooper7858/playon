import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song_model.dart';
import '../providers/music_provider.dart';
import '../theme.dart';
import '../widgets/mini_player.dart';
import 'library_tabs/favorites_tab.dart';
import 'library_tabs/folders_tab.dart';
import 'library_tabs/playlists_tab.dart';
import 'library_tabs/songs_tab.dart';
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
                physics: const BouncingScrollPhysics(),
                children: [
                  SongsTab(searchQuery: _searchQuery),
                  FavoritesTab(
                    searchQuery: _searchQuery,
                    onExploreSongs: () => _tabController.animateTo(0),
                  ),
                  PlaylistsTab(searchQuery: _searchQuery),
                  const FoldersTab(),
                ],
              ),
            ),
            _MiniPlayerSlot(
              onTap: () => Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (_, __, ___) => const NowPlayingScreen(),
                  transitionsBuilder: (_, animation, __, child) {
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 1),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                      child: child,
                    );
                  },
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
              tooltip: 'Buscar música',
              onPressed: () => setState(() => _showSearch = true),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              color: PlayOnTheme.textSecondary,
              tooltip: 'Actualizar biblioteca',
              onPressed: () => context.read<MusicProvider>().loadSongs(),
            ),
          ] else ...[
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: PlayOnTheme.bgSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: PlayOnTheme.glassBorder),
                ),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: const TextStyle(color: PlayOnTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Buscar canciones, artistas, álbumes...',
                    hintStyle: const TextStyle(color: PlayOnTheme.textTertiary, fontSize: 13.5),
                    border: InputBorder.none,
                    prefixIcon: const Icon(Icons.search_rounded, color: PlayOnTheme.purpleGlow),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18, color: PlayOnTheme.textSecondary),
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                                _searchController.clear();
                              });
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
        padding: const EdgeInsets.all(3),
        labelPadding: const EdgeInsets.symmetric(horizontal: 2),
        tabAlignment: TabAlignment.fill,
        isScrollable: false,
        indicator: BoxDecoration(
          gradient: PlayOnTheme.primaryGradient,
          borderRadius: BorderRadius.circular(11),
          boxShadow: PlayOnTheme.glowShadow(blur: 10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: PlayOnTheme.textSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
        tabs: const [
          Tab(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('Canciones', maxLines: 1),
            ),
          ),
          Tab(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('Favoritos', maxLines: 1),
            ),
          ),
          Tab(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('Playlists', maxLines: 1),
            ),
          ),
          Tab(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('Carpetas', maxLines: 1),
            ),
          ),
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
