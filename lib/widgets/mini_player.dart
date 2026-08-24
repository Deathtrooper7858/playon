import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import '../theme.dart';
import 'equalizer_bars.dart';

class MiniPlayer extends StatelessWidget {
  final MusicProvider provider;
  final VoidCallback onTap;

  const MiniPlayer({super.key, required this.provider, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final song = provider.currentSong;
    if (song == null) return const SizedBox.shrink();

    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity == null) return;
          if (details.primaryVelocity! < -300) {
            provider.next();
          } else if (details.primaryVelocity! > 300) {
            provider.previous();
          }
        },
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity == null) return;
          if (details.primaryVelocity! < -300) {
            onTap(); // Swipe up to expand
          } else if (details.primaryVelocity! > 300) {
            provider.stop(); // Swipe down to dismiss
          }
        },
        child: Container(
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: PlayOnTheme.purplePrimary.withValues(alpha: 0.25),
                blurRadius: 24,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 15,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                decoration: BoxDecoration(
                  color: PlayOnTheme.bgCard.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: PlayOnTheme.glassBorder, width: 1.2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Progress line at top (aislado con Selector para ahorro de CPU/GPU)
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      child: Selector<MusicProvider, double>(
                        selector: (_, p) => (p.duration.inMilliseconds > 0)
                            ? (p.position.inMilliseconds / p.duration.inMilliseconds).clamp(0.0, 1.0)
                            : 0.0,
                        builder: (_, prog, __) {
                          return LinearProgressIndicator(
                            value: prog,
                            backgroundColor: PlayOnTheme.divider,
                            valueColor: const AlwaysStoppedAnimation(PlayOnTheme.purplePrimary),
                            minHeight: 2.5,
                          );
                        },
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
                      child: Row(
                        children: [
                          // Album Art
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Hero(
                              tag: 'album_art_${song.id}',
                              child: QueryArtworkWidget(
                                id: song.id,
                                type: ArtworkType.AUDIO,
                                format: ArtworkFormat.JPEG,
                                artworkQuality: FilterQuality.low,
                                size: 150,
                                artworkWidth: 46,
                                artworkHeight: 46,
                                artworkFit: BoxFit.cover,
                                keepOldArtwork: true,
                                nullArtworkWidget: Container(
                                  width: 46,
                                  height: 46,
                                  decoration: const BoxDecoration(
                                    gradient: PlayOnTheme.primaryGradient,
                                  ),
                                  child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 24),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Title and Artist
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        song.title,
                                        style: const TextStyle(
                                          color: PlayOnTheme.textPrimary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Selector<MusicProvider, bool>(
                                      selector: (_, p) => p.isPlaying,
                                      builder: (_, isPlaying, __) {
                                        if (!isPlaying) return const SizedBox.shrink();
                                        return const Padding(
                                          padding: EdgeInsets.only(left: 6),
                                          child: EqualizerBars(isPlaying: true, size: 14),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  song.artist,
                                  style: const TextStyle(
                                    color: PlayOnTheme.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),

                          // Controls
                          IconButton(
                            icon: const Icon(Icons.skip_previous_rounded),
                            color: PlayOnTheme.textSecondary,
                            iconSize: 26,
                            onPressed: provider.previous,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          ),
                          Selector<MusicProvider, bool>(
                            selector: (_, p) => p.isPlaying,
                            builder: (_, isPlaying, __) {
                              return GestureDetector(
                                onTap: provider.playPause,
                                child: Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: PlayOnTheme.primaryGradient,
                                    boxShadow: PlayOnTheme.glowShadow(blur: 10),
                                  ),
                                  child: Icon(
                                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.skip_next_rounded),
                            color: PlayOnTheme.textSecondary,
                            iconSize: 26,
                            onPressed: provider.next,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
