import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../models/song_model.dart';
import '../providers/music_provider.dart';
import '../theme.dart';
import 'equalizer_bars.dart';

class SongTile extends StatelessWidget {
  final PlayOnSong song;
  final bool isCurrent;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback? onOptionsTap;
  final Widget? trailing;
  final bool isSelected;
  final bool isSelectionMode;
  final bool showFavoriteButton;
  final ValueChanged<bool?>? onSelectChanged;

  const SongTile({
    super.key,
    required this.song,
    required this.isCurrent,
    this.isPlaying = false,
    required this.onTap,
    this.onOptionsTap,
    this.trailing,
    this.isSelected = false,
    this.isSelectionMode = false,
    this.showFavoriteButton = true,
    this.onSelectChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      decoration: BoxDecoration(
        color: isCurrent
            ? PlayOnTheme.purplePrimary.withValues(alpha: 0.12)
            : (isSelected ? PlayOnTheme.purpleDim.withValues(alpha: 0.2) : Colors.transparent),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrent
              ? PlayOnTheme.purplePrimary.withValues(alpha: 0.45)
              : (isSelected ? PlayOnTheme.purpleGlow.withValues(alpha: 0.4) : Colors.transparent),
          width: 1.2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                if (isSelectionMode) ...[
                  Checkbox(
                    value: isSelected,
                    onChanged: onSelectChanged,
                    activeColor: PlayOnTheme.purplePrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                  ),
                  const SizedBox(width: 4),
                ],

                // Album Artwork
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: QueryArtworkWidget(
                    id: song.id,
                    type: ArtworkType.AUDIO,
                    format: ArtworkFormat.JPEG,
                    artworkQuality: FilterQuality.low,
                    size: 150,
                    artworkWidth: 48,
                    artworkHeight: 48,
                    artworkFit: BoxFit.cover,
                    keepOldArtwork: true,
                    nullArtworkWidget: Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        gradient: PlayOnTheme.primaryGradient,
                      ),
                      child: const Icon(
                        Icons.music_note_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Title & Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              song.title,
                              style: TextStyle(
                                color: isCurrent ? PlayOnTheme.purpleGlow : PlayOnTheme.textPrimary,
                                fontSize: 14,
                                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isCurrent && isPlaying) ...[
                            const SizedBox(width: 6),
                            const EqualizerBars(isPlaying: true, size: 14),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${song.artist} • ${song.durationFormatted}',
                        style: const TextStyle(
                          color: PlayOnTheme.textSecondary,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Trailing or Options Button
                if (trailing != null)
                  trailing!
                else if (!isSelectionMode) ...[
                  if (showFavoriteButton)
                    _FavoriteButton(songId: song.id),
                  if (onOptionsTap != null)
                    IconButton(
                      icon: const Icon(Icons.more_vert_rounded, size: 20),
                      color: PlayOnTheme.textSecondary,
                      onPressed: onOptionsTap,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FavoriteButton extends StatelessWidget {
  final int songId;
  const _FavoriteButton({required this.songId});

  @override
  Widget build(BuildContext context) {
    final isFav = context.select<MusicProvider, bool>((p) => p.isFavorite(songId));

    return IconButton(
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
        child: Icon(
          isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          key: ValueKey(isFav),
          size: 20,
          color: isFav ? PlayOnTheme.pinkAccent : PlayOnTheme.textTertiary,
        ),
      ),
      tooltip: isFav ? 'Quitar de favoritos' : 'Añadir a favoritos',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      onPressed: () => context.read<MusicProvider>().toggleFavorite(songId),
    );
  }
}
