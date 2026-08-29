import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/playlist_provider.dart';
import '../../services/playlist_db.dart';
import '../../theme.dart';
import '../playlist_detail_screen.dart';

class PlaylistsTab extends StatelessWidget {
  final String searchQuery;

  const PlaylistsTab({super.key, required this.searchQuery});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlaylistProvider>(
      builder: (context, provider, _) {
        final playlists = provider.playlists.where((p) {
          if (searchQuery.trim().isEmpty) return true;
          return p.name.toLowerCase().contains(searchQuery.toLowerCase().trim());
        }).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              child: Row(
                children: [
                  Text(
                    '${playlists.length} ${playlists.length == 1 ? 'playlist' : 'playlists'}',
                    style: const TextStyle(
                      color: PlayOnTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PlayOnTheme.purplePrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Nueva', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                    onPressed: () => _showCreatePlaylistDialog(context, provider),
                  ),
                ],
              ),
            ),
            if (playlists.isEmpty)
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
                            color: PlayOnTheme.purplePrimary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.playlist_play_rounded,
                            size: 56,
                            color: PlayOnTheme.purpleGlow,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          searchQuery.isNotEmpty ? 'No se encontraron playlists' : 'Crea tu primera Playlist',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          searchQuery.isNotEmpty
                              ? 'No hay playlists que coincidan con "$searchQuery"'
                              : 'Organiza tus canciones favoritas por género, momento o artista',
                          style: const TextStyle(color: PlayOnTheme.textSecondary, fontSize: 13),
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
                  itemCount: playlists.length,
                  itemBuilder: (context, index) {
                    final playlist = playlists[index];
                    final count = provider.songCounts[playlist.id] ?? 0;

                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: PlayOnTheme.bgCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: PlayOnTheme.glassBorder),
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
                            Icons.queue_music_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        title: Text(
                          playlist.name,
                          style: const TextStyle(
                            color: PlayOnTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          '$count ${count == 1 ? 'canción' : 'canciones'}',
                          style: const TextStyle(color: PlayOnTheme.textSecondary, fontSize: 12.5),
                        ),
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert_rounded, color: PlayOnTheme.textSecondary),
                          color: PlayOnTheme.bgCard,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          onSelected: (val) {
                            if (val == 'rename') {
                              _showRenamePlaylistDialog(context, provider, playlist);
                            } else if (val == 'delete') {
                              _confirmDeletePlaylist(context, provider, playlist);
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'rename',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_rounded, color: PlayOnTheme.purpleGlow, size: 18),
                                  SizedBox(width: 10),
                                  Text('Renombrar', style: TextStyle(color: PlayOnTheme.textPrimary)),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline_rounded, color: Color(0xFFEF5350), size: 18),
                                  SizedBox(width: 10),
                                  Text('Eliminar', style: TextStyle(color: Color(0xFFEF5350))),
                                ],
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PlaylistDetailScreen(playlist: playlist),
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

  void _showCreatePlaylistDialog(BuildContext context, PlaylistProvider provider) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PlayOnTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Nueva Playlist', style: TextStyle(color: PlayOnTheme.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: PlayOnTheme.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Nombre de la playlist',
            hintStyle: TextStyle(color: PlayOnTheme.textTertiary),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: PlayOnTheme.purplePrimary),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: PlayOnTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: PlayOnTheme.purplePrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(ctx);
                await provider.createPlaylist(name);
              }
            },
            child: const Text('Crear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showRenamePlaylistDialog(BuildContext context, PlaylistProvider provider, CustomPlaylist playlist) {
    final controller = TextEditingController(text: playlist.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PlayOnTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Renombrar Playlist', style: TextStyle(color: PlayOnTheme.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: PlayOnTheme.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Nuevo nombre',
            hintStyle: TextStyle(color: PlayOnTheme.textTertiary),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: PlayOnTheme.purplePrimary),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: PlayOnTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: PlayOnTheme.purplePrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(ctx);
                await provider.renamePlaylist(playlist.id, name);
              }
            },
            child: const Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDeletePlaylist(BuildContext context, PlaylistProvider provider, CustomPlaylist playlist) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PlayOnTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('¿Eliminar playlist?', style: TextStyle(color: PlayOnTheme.textPrimary)),
        content: Text(
          'Se eliminará la lista "${playlist.name}". Las canciones permanecerán en tu dispositivo.',
          style: const TextStyle(color: PlayOnTheme.textSecondary),
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
              await provider.deletePlaylist(playlist.id);
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
