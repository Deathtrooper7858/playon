import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../../models/song_model.dart';
import '../../providers/music_provider.dart';
import '../../services/file_management_service.dart';
import '../../theme.dart';
import '../../widgets/add_to_playlist_dialog.dart';
import '../../widgets/edit_tags_dialog.dart';
import '../../widgets/move_to_folder_sheet.dart';

class SongOptionsHelper {
  static void showSongOptions(BuildContext context, PlayOnSong song) {
    final musicProvider = context.read<MusicProvider>();
    final isFav = musicProvider.isFavorite(song.id);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                decoration: BoxDecoration(
                  color: PlayOnTheme.bgCard.withValues(alpha: 0.96),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  border: Border.all(color: PlayOnTheme.glassBorder, width: 1.5),
                ),
                padding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
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
                      ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: QueryArtworkWidget(
                            id: song.id,
                            type: ArtworkType.AUDIO,
                            format: ArtworkFormat.JPEG,
                            artworkQuality: FilterQuality.low,
                            size: 150,
                            artworkWidth: 44,
                            artworkHeight: 44,
                            keepOldArtwork: true,
                            nullArtworkWidget: Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(
                                gradient: PlayOnTheme.primaryGradient,
                              ),
                              child: const Icon(Icons.music_note_rounded, color: Colors.white),
                            ),
                          ),
                        ),
                        title: Text(
                          song.title,
                          style: const TextStyle(
                            color: PlayOnTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${song.artist} • ${song.durationFormatted}',
                          style: const TextStyle(color: PlayOnTheme.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Divider(color: PlayOnTheme.divider),
                      ListTile(
                        leading: Icon(
                          isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: isFav ? PlayOnTheme.pinkAccent : PlayOnTheme.purpleGlow,
                        ),
                        title: Text(
                          isFav ? 'Eliminar de Favoritos' : 'Añadir a Favoritos',
                          style: TextStyle(
                            color: isFav ? PlayOnTheme.pinkAccent : PlayOnTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          musicProvider.toggleFavorite(song.id);
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(isFav ? 'Eliminada de Favoritos' : 'Añadida a Favoritos ❤️'),
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.play_circle_outline_rounded, color: PlayOnTheme.purpleGlow),
                        title: const Text('Reproducir siguiente', style: TextStyle(color: PlayOnTheme.textPrimary)),
                        onTap: () {
                          Navigator.pop(ctx);
                          musicProvider.addToQueue(song, playNext: true);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Se reproducirá a continuación'),
                              behavior: SnackBarBehavior.floating,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                  ListTile(
                    leading: const Icon(Icons.queue_music_rounded, color: PlayOnTheme.cyanAccent),
                    title: const Text('Añadir a la cola', style: TextStyle(color: PlayOnTheme.textPrimary)),
                    onTap: () {
                      Navigator.pop(ctx);
                      musicProvider.addToQueue(song, playNext: false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Añadido a la cola de reproducción'),
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.playlist_add_rounded, color: PlayOnTheme.pinkAccent),
                    title: const Text('Añadir a Playlist', style: TextStyle(color: PlayOnTheme.textPrimary)),
                    onTap: () {
                      Navigator.pop(ctx);
                      AddToPlaylistDialog.show(context, song);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.drive_file_move_outline, color: PlayOnTheme.amberWarning),
                    title: const Text('Mover a carpeta', style: TextStyle(color: PlayOnTheme.textPrimary)),
                    onTap: () {
                      Navigator.pop(ctx);
                      MoveToFolderSheet.show(context, song: song);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.edit_note_rounded, color: PlayOnTheme.purpleGlow),
                    title: const Text('Editar etiquetas ID3', style: TextStyle(color: PlayOnTheme.textPrimary)),
                    onTap: () {
                      Navigator.pop(ctx);
                      EditTagsDialog.show(context, song);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF5350)),
                    title: const Text('Eliminar del dispositivo', style: TextStyle(color: Color(0xFFEF5350))),
                    onTap: () {
                      Navigator.pop(ctx);
                      _confirmDelete(context, song);
                    },
                  ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static void _confirmDelete(BuildContext context, PlayOnSong song) {
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<MusicProvider>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PlayOnTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('¿Eliminar canción?', style: TextStyle(color: PlayOnTheme.textPrimary)),
        content: Text(
          'Se eliminará permanentemente el archivo "${song.title}" del almacenamiento.',
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
              final success = await FileManagementService.deleteSong(song);
              if (success) {
                await provider.loadSongs();
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Canción eliminada'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } else {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('No se pudo eliminar el archivo'),
                    backgroundColor: Color(0xFFEF5350),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
