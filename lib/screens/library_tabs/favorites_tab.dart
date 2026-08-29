import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/song_model.dart';
import '../../providers/music_provider.dart';
import '../../theme.dart';
import '../../widgets/song_tile.dart';
import 'song_options_helper.dart';

class FavoritesTab extends StatelessWidget {
  final String searchQuery;
  final VoidCallback onExploreSongs;

  const FavoritesTab({
    super.key,
    required this.searchQuery,
    required this.onExploreSongs,
  });

  List<PlayOnSong> _filter(List<PlayOnSong> favs) {
    if (searchQuery.trim().isEmpty) return favs;
    final q = searchQuery.toLowerCase().trim();
    return favs.where((s) {
      return s.title.toLowerCase().contains(q) ||
          s.artist.toLowerCase().contains(q) ||
          s.album.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MusicProvider>(
      builder: (context, provider, _) {
        final favorites = _filter(provider.favoriteSongs);

        if (favorites.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: PlayOnTheme.pinkAccent.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.favorite_rounded,
                      size: 56,
                      color: PlayOnTheme.pinkAccent,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    searchQuery.isNotEmpty ? 'Sin favoritos encontrados' : 'Aún no tienes favoritos',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    searchQuery.isNotEmpty
                        ? 'No hay canciones favoritas que coincidan con "$searchQuery"'
                        : 'Toca el corazón en cualquier canción para guardarla aquí',
                    style: const TextStyle(color: PlayOnTheme.textSecondary, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  if (searchQuery.isEmpty) ...[
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PlayOnTheme.pinkAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.library_music_rounded),
                      label: const Text('Explorar canciones'),
                      onPressed: onExploreSongs,
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
              child: Row(
                children: [
                  Text(
                    '${favorites.length} ${favorites.length == 1 ? 'favorita' : 'favoritas'}',
                    style: const TextStyle(
                      color: PlayOnTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.shuffle_rounded, size: 20),
                    color: PlayOnTheme.pinkAccent,
                    tooltip: 'Reproducir favoritos en aleatorio',
                    onPressed: () {
                      final shuffled = List<PlayOnSong>.from(favorites)..shuffle();
                      provider.playCustomQueue(shuffled, 0);
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 90),
                physics: const BouncingScrollPhysics(),
                itemCount: favorites.length,
                itemBuilder: (context, index) {
                  final song = favorites[index];
                  final isCurrent = provider.currentSong?.id == song.id;

                  return SongTile(
                    song: song,
                    isCurrent: isCurrent,
                    isPlaying: provider.isPlaying,
                    onTap: () => provider.playCustomQueue(favorites, index),
                    onOptionsTap: () => SongOptionsHelper.showSongOptions(context, song),
                    trailing: IconButton(
                      icon: const Icon(Icons.favorite_rounded, color: PlayOnTheme.pinkAccent, size: 22),
                      onPressed: () => provider.toggleFavorite(song.id),
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
}
