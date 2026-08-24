import 'dart:math';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import '../theme.dart';

class AnimatedAlbumArt extends StatefulWidget {
  final int songId;

  const AnimatedAlbumArt({super.key, required this.songId});

  @override
  State<AnimatedAlbumArt> createState() => _AnimatedAlbumArtState();
}

class _AnimatedAlbumArtState extends State<AnimatedAlbumArt>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;
  bool _wasPlaying = false;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final playing = context.read<MusicProvider>().isPlaying;
      _updateRotation(playing);
    });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  void _updateRotation(bool isPlaying) {
    if (isPlaying == _wasPlaying) return;
    _wasPlaying = isPlaying;
    if (isPlaying) {
      _rotationController.repeat();
    } else {
      _rotationController.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Selector<MusicProvider, bool>(
      selector: (_, p) => p.isPlaying,
      builder: (_, isPlaying, child) {
        _updateRotation(isPlaying);
        return child!;
      },
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Ambient Aura (Multi-layer glow) - Aislado con RepaintBoundary para rasterizar sombra en GPU
            RepaintBoundary(
              child: Container(
                width: 290,
                height: 290,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: PlayOnTheme.purplePrimary.withValues(alpha: 0.35),
                      blurRadius: 70,
                      spreadRadius: 15,
                    ),
                    BoxShadow(
                      color: PlayOnTheme.pinkAccent.withValues(alpha: 0.25),
                      blurRadius: 50,
                      spreadRadius: 5,
                    ),
                  ],
                ),
              ),
            ),

            // Spinning Vinyl Ring (Aislado en capa de textura GPU propia)
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: _rotationController,
                builder: (_, child) => Transform.rotate(
                  angle: _rotationController.value * 2 * pi,
                  child: child,
                ),
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        PlayOnTheme.purplePrimary.withValues(alpha: 0.0),
                        PlayOnTheme.purplePrimary.withValues(alpha: 0.8),
                        PlayOnTheme.pinkAccent.withValues(alpha: 0.8),
                        PlayOnTheme.cyanAccent.withValues(alpha: 0.5),
                        PlayOnTheme.purplePrimary.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Inner Vinyl Texture Ring
            Container(
              width: 268,
              height: 268,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: PlayOnTheme.bgDeep,
                border: Border.all(
                  color: PlayOnTheme.glassBorder,
                  width: 2.5,
                ),
              ),
            ),

            // Main Artwork
            Container(
              width: 254,
              height: 254,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: PlayOnTheme.bgSurface,
              ),
              clipBehavior: Clip.antiAlias,
              child: Hero(
                tag: 'album_art_${widget.songId}',
                child: QueryArtworkWidget(
                  id: widget.songId,
                  type: ArtworkType.AUDIO,
                  format: ArtworkFormat.JPEG,
                  artworkQuality: FilterQuality.medium,
                  size: 500,
                  artworkWidth: 254,
                  artworkHeight: 254,
                  artworkFit: BoxFit.cover,
                  keepOldArtwork: true,
                  nullArtworkWidget: Container(
                    width: 254,
                    height: 254,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          PlayOnTheme.purpleDim.withValues(alpha: 0.7),
                          PlayOnTheme.bgSurface,
                        ],
                      ),
                    ),
                    child: const Icon(
                      Icons.music_note_rounded,
                      size: 80,
                      color: PlayOnTheme.purpleGlow,
                    ),
                  ),
                ),
              ),
            ),

            // Center Spindle Dot (Vinyl Style)
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: PlayOnTheme.bgDeep,
                border: Border.all(color: PlayOnTheme.purpleGlow.withValues(alpha: 0.5), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.8),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
