import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song_model.dart';
import '../providers/playlist_provider.dart';
import '../theme.dart';

class AddToPlaylistDialog extends StatelessWidget {
  final PlayOnSong song;

  const AddToPlaylistDialog({super.key, required this.song});

  static Future<void> show(BuildContext context, PlayOnSong song) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddToPlaylistDialog(song: song),
    );
  }

  void _showNewPlaylistDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _CreateAndAddPlaylistDialog(
        songId: song.id,
        onAdded: () => Navigator.pop(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: PlayOnTheme.bgCard.withValues(alpha: 0.92),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: PlayOnTheme.glassBorder, width: 1.5),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: PlayOnTheme.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: PlayOnTheme.pinkAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.playlist_add_rounded, color: PlayOnTheme.pinkAccent, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Añadir a Playlist',
                          style: TextStyle(
                            color: PlayOnTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          song.title,
                          style: const TextStyle(color: PlayOnTheme.textSecondary, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_rounded, color: PlayOnTheme.purpleGlow),
                    tooltip: 'Nueva Playlist',
                    onPressed: () => _showNewPlaylistDialog(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: PlayOnTheme.divider),
              Consumer<PlaylistProvider>(
                builder: (context, provider, _) {
                  if (provider.isLoading) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(color: PlayOnTheme.purplePrimary),
                      ),
                    );
                  }

                  if (provider.playlists.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          children: [
                            const Icon(Icons.queue_music_rounded, size: 48, color: PlayOnTheme.textTertiary),
                            const SizedBox(height: 12),
                            const Text(
                              'Aún no has creado playlists',
                              style: TextStyle(color: PlayOnTheme.textSecondary, fontSize: 14),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () => _showNewPlaylistDialog(context),
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('Crear Primera Playlist'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: PlayOnTheme.purplePrimary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.4,
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: provider.playlists.length,
                      itemBuilder: (context, index) {
                        final pl = provider.playlists[index];
                        final count = provider.songCounts[pl.id] ?? 0;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: PlayOnTheme.bgSurface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: PlayOnTheme.divider),
                            ),
                            child: const Icon(Icons.queue_music_rounded, color: PlayOnTheme.purpleGlow, size: 22),
                          ),
                          title: Text(
                            pl.name,
                            style: const TextStyle(color: PlayOnTheme.textPrimary, fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '$count canciones',
                            style: const TextStyle(color: PlayOnTheme.textTertiary, fontSize: 12),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded, color: PlayOnTheme.textTertiary),
                          onTap: () async {
                            await provider.addSongToPlaylist(pl.id, song.id);
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Añadida a "${pl.name}"'),
                                  backgroundColor: PlayOnTheme.emeraldActive,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateAndAddPlaylistDialog extends StatefulWidget {
  final int songId;
  final VoidCallback onAdded;

  const _CreateAndAddPlaylistDialog({
    required this.songId,
    required this.onAdded,
  });

  @override
  State<_CreateAndAddPlaylistDialog> createState() => _CreateAndAddPlaylistDialogState();
}

class _CreateAndAddPlaylistDialogState extends State<_CreateAndAddPlaylistDialog> {
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
              final pl = await context.read<PlaylistProvider>().createPlaylist(name);
              if (pl != null && context.mounted) {
                await context.read<PlaylistProvider>().addSongToPlaylist(pl.id, widget.songId);
                if (context.mounted) {
                  Navigator.pop(context); // pop dialog
                  widget.onAdded(); // pop bottomsheet
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Añadida a "$name"'),
                      backgroundColor: PlayOnTheme.emeraldActive,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: PlayOnTheme.purplePrimary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Crear y añadir', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

