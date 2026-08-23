import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song_model.dart';
import '../providers/music_provider.dart';
import '../theme.dart';
import '../widgets/add_to_playlist_dialog.dart';
import '../widgets/animated_album_art.dart';
import '../widgets/control_buttons.dart';
import '../widgets/edit_tags_dialog.dart';
import '../widgets/equalizer_sheet.dart';
import '../widgets/progress_bar_widget.dart';

class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({super.key});

  void _showOptionsSheet(BuildContext context, PlayOnSong song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                color: PlayOnTheme.bgCard.withValues(alpha: 0.92),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: PlayOnTheme.glassBorder, width: 1.5),
              ),
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(color: PlayOnTheme.divider, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  ListTile(
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: PlayOnTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.music_note_rounded, color: Colors.white),
                    ),
                    title: Text(song.title, style: const TextStyle(color: PlayOnTheme.textPrimary, fontWeight: FontWeight.bold)),
                    subtitle: Text('${song.artist} • ${song.album}', style: const TextStyle(color: PlayOnTheme.textSecondary)),
                  ),
                  const Divider(color: PlayOnTheme.divider),
                  ListTile(
                    leading: const Icon(Icons.equalizer_rounded, color: PlayOnTheme.purpleGlow),
                    title: const Text('Ecualizador y Bass Boost', style: TextStyle(color: PlayOnTheme.textPrimary)),
                    onTap: () {
                      Navigator.pop(context);
                      EqualizerSheet.show(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.playlist_add_rounded, color: PlayOnTheme.pinkAccent),
                    title: const Text('Añadir a Playlist', style: TextStyle(color: PlayOnTheme.textPrimary)),
                    onTap: () {
                      Navigator.pop(context);
                      AddToPlaylistDialog.show(context, song);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.edit_note_rounded, color: PlayOnTheme.cyanAccent),
                    title: const Text('Editar etiquetas ID3', style: TextStyle(color: PlayOnTheme.textPrimary)),
                    onTap: () {
                      Navigator.pop(context);
                      EditTagsDialog.show(context, song);
                    },
                  ),
                  Consumer<MusicProvider>(
                    builder: (context, provider, _) {
                      final hasTimer = provider.hasSleepTimer;
                      return ListTile(
                        leading: Icon(
                          hasTimer ? Icons.timer_rounded : Icons.timer_outlined,
                          color: hasTimer ? PlayOnTheme.pinkAccent : PlayOnTheme.textSecondary,
                        ),
                        title: Text(
                          hasTimer ? 'Temporizador activo' : 'Temporizador de apagado',
                          style: TextStyle(color: hasTimer ? PlayOnTheme.pinkAccent : PlayOnTheme.textPrimary),
                        ),
                        subtitle: hasTimer
                            ? Text(
                                '${provider.sleepTimeRemaining?.inMinutes ?? 0} min restantes',
                                style: const TextStyle(color: PlayOnTheme.textSecondary),
                              )
                            : null,
                        trailing: hasTimer
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded, color: PlayOnTheme.textSecondary),
                                onPressed: () => provider.cancelSleepTimer(),
                              )
                            : null,
                        onTap: hasTimer ? null : () {
                          Navigator.pop(context);
                          _showTimerOptions(context);
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showTimerOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              color: PlayOnTheme.bgCard.withValues(alpha: 0.9),
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Apagar música después de',
                    style: TextStyle(color: PlayOnTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ...[15, 30, 45, 60].map((mins) => ListTile(
                        title: Text('$mins Minutos', style: const TextStyle(color: PlayOnTheme.textPrimary)),
                        onTap: () {
                          context.read<MusicProvider>().setSleepTimer(Duration(minutes: mins));
                          Navigator.pop(context);
                        },
                      )),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showSpeedOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              color: PlayOnTheme.bgCard.withValues(alpha: 0.9),
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Velocidad de Reproducción',
                    style: TextStyle(color: PlayOnTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ...[0.75, 1.0, 1.25, 1.5, 1.75, 2.0].map((spd) {
                    final currentSpd = context.read<MusicProvider>().speed;
                    final isSelected = (currentSpd == spd);
                    return ListTile(
                      title: Text(
                        '${spd}x ${spd == 1.0 ? "(Normal)" : ""}',
                        style: TextStyle(
                          color: isSelected ? PlayOnTheme.purpleGlow : PlayOnTheme.textPrimary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: isSelected ? const Icon(Icons.check_rounded, color: PlayOnTheme.purplePrimary) : null,
                      onTap: () {
                        context.read<MusicProvider>().setSpeed(spd);
                        Navigator.pop(context);
                      },
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Selector<MusicProvider, PlayOnSong?>(
      selector: (_, p) => p.currentSong,
      builder: (context, song, _) {
        return Scaffold(
          backgroundColor: PlayOnTheme.bgDeep,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 34),
              color: PlayOnTheme.textSecondary,
              onPressed: () => Navigator.pop(context),
            ),
            title: const Column(
              children: [
                Text(
                  'REPRODUCIENDO',
                  style: TextStyle(
                    color: PlayOnTheme.purpleGlow,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.more_vert_rounded),
                color: PlayOnTheme.textSecondary,
                onPressed: () {
                  if (song != null) {
                    _showOptionsSheet(context, song);
                  }
                },
              ),
            ],
          ),
          body: song == null
              ? const _EmptyPlayer()
              : GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragEnd: (details) {
                    if (details.primaryVelocity == null) return;
                    if (details.primaryVelocity! < -300) {
                      context.read<MusicProvider>().next();
                    } else if (details.primaryVelocity! > 300) {
                      context.read<MusicProvider>().previous();
                    }
                  },
                  onVerticalDragEnd: (details) {
                    if (details.primaryVelocity == null) return;
                    if (details.primaryVelocity! > 300) {
                      Navigator.pop(context);
                    }
                  },
                  child: SafeArea(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 26),
                        child: Column(
                          children: [
                            const SizedBox(height: 12),

                            // Album Art
                            AnimatedAlbumArt(songId: song.id),

                            const SizedBox(height: 28),

                            // Title, Artist, and Favorite
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        song.title,
                                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        song.artist,
                                        style: const TextStyle(
                                          color: PlayOnTheme.textSecondary,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Consumer<MusicProvider>(
                                  builder: (context, provider, _) {
                                    final isFav = provider.isFavorite(song.id);
                                    return IconButton(
                                      icon: Icon(
                                        isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                        color: isFav ? PlayOnTheme.pinkAccent : PlayOnTheme.textSecondary,
                                        size: 28,
                                      ),
                                      onPressed: () => provider.toggleFavorite(song.id),
                                    );
                                  },
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),

                            // Scrubber
                            Consumer<MusicProvider>(
                              builder: (context, provider, _) => ProgressBarWidget(provider: provider),
                            ),

                            const SizedBox(height: 20),

                            // Control Buttons
                            Consumer<MusicProvider>(
                              builder: (context, provider, _) => ControlButtons(provider: provider),
                            ),

                            const SizedBox(height: 26),

                            // Bottom Quick Tools Bar
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: PlayOnTheme.bgSurface.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: PlayOnTheme.divider),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  // Equalizer Button
                                  IconButton(
                                    icon: const Icon(Icons.equalizer_rounded, color: PlayOnTheme.purpleGlow),
                                    tooltip: 'Ecualizador',
                                    onPressed: () => EqualizerSheet.show(context),
                                  ),
                                  // Speed Button
                                  IconButton(
                                    icon: const Icon(Icons.speed_rounded, color: PlayOnTheme.cyanAccent),
                                    tooltip: 'Velocidad',
                                    onPressed: () => _showSpeedOptions(context),
                                  ),
                                  // Add to Playlist Button
                                  IconButton(
                                    icon: const Icon(Icons.playlist_add_rounded, color: PlayOnTheme.pinkAccent),
                                    tooltip: 'Playlist',
                                    onPressed: () => AddToPlaylistDialog.show(context, song),
                                  ),
                                  // Sleep Timer Button
                                  IconButton(
                                    icon: const Icon(Icons.timer_outlined, color: PlayOnTheme.amberWarning),
                                    tooltip: 'Temporizador',
                                    onPressed: () => _showTimerOptions(context),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),
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
}

class _EmptyPlayer extends StatelessWidget {
  const _EmptyPlayer();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: PlayOnTheme.bgSurface,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.music_note_rounded, size: 64, color: PlayOnTheme.purpleDim),
          ),
          const SizedBox(height: 20),
          const Text('Ninguna canción seleccionada', style: TextStyle(color: PlayOnTheme.textPrimary, fontSize: 18)),
        ],
      ),
    );
  }
}
