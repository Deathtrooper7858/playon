import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../models/song_model.dart';
import '../providers/music_provider.dart';
import '../theme.dart';
import '../widgets/add_to_playlist_dialog.dart';
import '../widgets/animated_album_art.dart';
import '../widgets/control_buttons.dart';
import '../widgets/edit_tags_dialog.dart';
import '../widgets/equalizer_sheet.dart';
import '../widgets/move_to_folder_sheet.dart';
import '../widgets/progress_bar_widget.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  bool _isPopping = false;
  double _dragDistance = 0;

  void _safePop() {
    if (_isPopping || !mounted) return;
    _isPopping = true;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _showOptionsSheet(BuildContext context, PlayOnSong song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                color: PlayOnTheme.bgCard.withValues(alpha: 0.95),
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
                        nullArtworkWidget: Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            gradient: PlayOnTheme.primaryGradient,
                          ),
                          child: const Icon(Icons.music_note_rounded, color: Colors.white),
                        ),
                        keepOldArtwork: true,
                      ),
                    ),
                    title: Text(
                      song.title,
                      style: const TextStyle(color: PlayOnTheme.textPrimary, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${song.artist} • ${song.album}',
                      style: const TextStyle(color: PlayOnTheme.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Divider(color: PlayOnTheme.divider),
                  ListTile(
                    leading: const Icon(Icons.queue_music_rounded, color: PlayOnTheme.amberWarning),
                    title: const Text('Ver Cola de Reproducción', style: TextStyle(color: PlayOnTheme.textPrimary)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showQueueSheet(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.equalizer_rounded, color: PlayOnTheme.purpleGlow),
                    title: const Text('Ecualizador y Bass Boost', style: TextStyle(color: PlayOnTheme.textPrimary)),
                    onTap: () {
                      Navigator.pop(ctx);
                      EqualizerSheet.show(context);
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
                    leading: const Icon(Icons.drive_file_move_rounded, color: PlayOnTheme.cyanAccent),
                    title: const Text('Mover a carpeta', style: TextStyle(color: PlayOnTheme.textPrimary)),
                    onTap: () {
                      Navigator.pop(ctx);
                      MoveToFolderSheet.show(context, song: song);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.edit_note_rounded, color: PlayOnTheme.purplePrimary),
                    title: const Text('Editar etiquetas ID3', style: TextStyle(color: PlayOnTheme.textPrimary)),
                    onTap: () {
                      Navigator.pop(ctx);
                      EditTagsDialog.show(context, song);
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

  void _showQueueSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: PlayOnTheme.bgCard.withValues(alpha: 0.96),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: PlayOnTheme.glassBorder, width: 1.5),
              ),
              padding: const EdgeInsets.fromLTRB(0, 16, 0, 10),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(color: PlayOnTheme.divider, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        const Icon(Icons.queue_music_rounded, color: PlayOnTheme.amberWarning, size: 24),
                        const SizedBox(width: 12),
                        const Text(
                          'Cola de Reproducción',
                          style: TextStyle(
                            color: PlayOnTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Consumer<MusicProvider>(
                          builder: (_, p, __) => Text(
                            '${p.currentQueue.length} canciones',
                            style: const TextStyle(color: PlayOnTheme.textSecondary, fontSize: 12.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Divider(color: PlayOnTheme.divider),
                  Expanded(
                    child: Consumer<MusicProvider>(
                      builder: (context, provider, _) {
                        final queue = provider.currentQueue;
                        if (queue.isEmpty) {
                          return const Center(
                            child: Text('La cola está vacía', style: TextStyle(color: PlayOnTheme.textSecondary)),
                          );
                        }

                        return Theme(
                          data: Theme.of(context).copyWith(
                            canvasColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                          ),
                          child: ReorderableListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            physics: const BouncingScrollPhysics(),
                            itemCount: queue.length,
                            onReorderItem: (oldIdx, newIdx) {
                              provider.reorderQueue(oldIdx, newIdx);
                            },
                            itemBuilder: (context, index) {
                              final item = queue[index];
                              final isCurrent = provider.currentSong?.id == item.id;

                              return Container(
                                key: ValueKey('queue_item_${item.id}_$index'),
                                margin: const EdgeInsets.symmetric(vertical: 3),
                                decoration: BoxDecoration(
                                  color: isCurrent
                                      ? PlayOnTheme.purplePrimary.withValues(alpha: 0.15)
                                      : PlayOnTheme.bgSurface.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isCurrent ? PlayOnTheme.purpleGlow : Colors.transparent,
                                  ),
                                ),
                                child: ListTile(
                                  dense: true,
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: QueryArtworkWidget(
                                      id: item.id,
                                      type: ArtworkType.AUDIO,
                                      format: ArtworkFormat.JPEG,
                                      artworkQuality: FilterQuality.low,
                                      size: 100,
                                      artworkWidth: 38,
                                      artworkHeight: 38,
                                      nullArtworkWidget: Container(
                                        width: 38,
                                        height: 38,
                                        decoration: const BoxDecoration(gradient: PlayOnTheme.primaryGradient),
                                        child: Center(
                                          child: Text('${index + 1}',
                                              style: const TextStyle(color: Colors.white, fontSize: 11)),
                                        ),
                                      ),
                                      keepOldArtwork: true,
                                    ),
                                  ),
                                  title: Text(
                                    item.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isCurrent ? PlayOnTheme.purpleGlow : PlayOnTheme.textPrimary,
                                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  subtitle: Text(
                                    item.artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: PlayOnTheme.textSecondary, fontSize: 11.5),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.close_rounded, size: 18),
                                        color: PlayOnTheme.textTertiary,
                                        onPressed: () => provider.removeFromQueue(index),
                                      ),
                                      ReorderableDragStartListener(
                                        index: index,
                                        child: const Icon(
                                          Icons.drag_handle_rounded,
                                          color: PlayOnTheme.textSecondary,
                                          size: 22,
                                        ),
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    provider.playSong(index);
                                  },
                                ),
                              );
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
  }

  void _showTimerOptions(BuildContext context) {
    bool fadeOut = true;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final provider = context.watch<MusicProvider>();
            final hasTimer = provider.hasSleepTimer;
            final remaining = provider.sleepTimeRemaining;

            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  decoration: BoxDecoration(
                    color: PlayOnTheme.bgCard.withValues(alpha: 0.95),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    border: Border.all(color: PlayOnTheme.glassBorder, width: 1.5),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: SafeArea(
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Temporizador de Apagado',
                              style: TextStyle(
                                color: PlayOnTheme.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (hasTimer && remaining != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: PlayOnTheme.amberWarning.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${remaining.inMinutes}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}',
                                  style: const TextStyle(
                                    color: PlayOnTheme.amberWarning,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Desvanecimiento suave (Fade-out)', style: TextStyle(color: PlayOnTheme.textPrimary, fontSize: 13.5)),
                          subtitle: const Text('Atenúa el volumen progresivamente antes de apagar', style: TextStyle(color: PlayOnTheme.textTertiary, fontSize: 11.5)),
                          value: fadeOut,
                          activeTrackColor: PlayOnTheme.purplePrimary,
                          onChanged: (v) => setSheetState(() => fadeOut = v),
                        ),
                        const Divider(color: PlayOnTheme.divider),
                        ...[15, 30, 45, 60, 90].map((mins) => ListTile(
                              dense: true,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              leading: const Icon(Icons.timer_outlined, color: PlayOnTheme.amberWarning),
                              title: Text('$mins minutos', style: const TextStyle(color: PlayOnTheme.textPrimary, fontSize: 14)),
                              onTap: () {
                                provider.setSleepTimer(Duration(minutes: mins), fadeOut: fadeOut);
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Música se apagará en $mins min${fadeOut ? ' con fade-out' : ''}'),
                                    backgroundColor: PlayOnTheme.bgSurface,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                            )),
                        if (hasTimer) ...[
                          ListTile(
                            dense: true,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            leading: const Icon(Icons.timer_off_outlined, color: PlayOnTheme.pinkAccent),
                            title: const Text('Cancelar Temporizador', style: TextStyle(color: PlayOnTheme.pinkAccent, fontSize: 14)),
                            onTap: () {
                              provider.cancelSleepTimer();
                              Navigator.pop(ctx);
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSpeedOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                color: PlayOnTheme.bgCard.withValues(alpha: 0.95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: PlayOnTheme.glassBorder, width: 1.5),
              ),
              padding: const EdgeInsets.all(20),
              child: SafeArea(
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
                    const Text(
                      'Velocidad de Reproducción',
                      style: TextStyle(
                        color: PlayOnTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...[0.75, 1.0, 1.25, 1.5, 1.75, 2.0].map((spd) {
                      final currentSpd = context.read<MusicProvider>().speed;
                      final isSelected = (currentSpd == spd);
                      return ListTile(
                        dense: true,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        tileColor: isSelected ? PlayOnTheme.purplePrimary.withValues(alpha: 0.12) : null,
                        title: Text(
                          '${spd}x ${spd == 1.0 ? "(Normal)" : ""}',
                          style: TextStyle(
                            color: isSelected ? PlayOnTheme.purpleGlow : PlayOnTheme.textPrimary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 15,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_rounded, color: PlayOnTheme.purplePrimary, size: 22)
                            : null,
                        onTap: () {
                          context.read<MusicProvider>().setSpeed(spd);
                          Navigator.pop(ctx);
                        },
                      );
                    }),
                  ],
                ),
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
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onVerticalDragStart: (_) => _dragDistance = 0,
          onVerticalDragUpdate: (details) {
            if (details.delta.dy > 0) {
              _dragDistance += details.delta.dy;
              if (_dragDistance > 70) {
                _safePop();
              }
            }
          },
          onVerticalDragEnd: (details) {
            if (details.primaryVelocity != null && details.primaryVelocity! > 120) {
              _safePop();
            }
            _dragDistance = 0;
          },
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity == null) return;
            if (details.primaryVelocity! < -300) {
              context.read<MusicProvider>().next();
            } else if (details.primaryVelocity! > 300) {
              context.read<MusicProvider>().previous();
            }
          },
          child: Scaffold(
            backgroundColor: PlayOnTheme.bgDeep,
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(kToolbarHeight),
              child: AppBar(
                backgroundColor: Colors.transparent,
                leading: IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 34),
                  color: PlayOnTheme.textSecondary,
                  onPressed: _safePop,
                ),
                title: const Text(
                  'REPRODUCIENDO',
                  style: TextStyle(
                    color: PlayOnTheme.purpleGlow,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3,
                  ),
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
            ),
            body: song == null
                ? const _EmptyPlayer()
                : SafeArea(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
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
                                  // Queue Sheet Button
                                  IconButton(
                                    icon: const Icon(Icons.queue_music_rounded, color: PlayOnTheme.amberWarning),
                                    tooltip: 'Cola de reproducción',
                                    onPressed: () => _showQueueSheet(context),
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
                                    icon: const Icon(Icons.timer_outlined, color: PlayOnTheme.purplePrimary),
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
            decoration: const BoxDecoration(
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
