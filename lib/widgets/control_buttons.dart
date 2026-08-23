import 'package:flutter/material.dart';
import '../providers/music_provider.dart';
import '../theme.dart';

class ControlButtons extends StatelessWidget {
  final MusicProvider provider;

  const ControlButtons({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Shuffle & Repeat Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _ToggleButton(
              icon: Icons.shuffle_rounded,
              isActive: provider.isShuffle,
              onTap: provider.toggleShuffle,
              label: 'Aleatorio',
            ),
            _ToggleButton(
              icon: provider.repeatMode == PlayerRepeatMode.one
                  ? Icons.repeat_one_rounded
                  : Icons.repeat_rounded,
              isActive: provider.repeatMode != PlayerRepeatMode.none,
              onTap: provider.toggleRepeat,
              label: provider.repeatMode == PlayerRepeatMode.one
                  ? 'Repetir 1'
                  : (provider.repeatMode == PlayerRepeatMode.all ? 'Repetir todo' : 'Repetir'),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Main Audio Controls Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Previous
            _CircleIconButton(
              icon: Icons.skip_previous_rounded,
              size: 40,
              iconSize: 28,
              onTap: provider.previous,
            ),

            // Play / Pause Giant Glow Button
            GestureDetector(
              onTap: provider.playPause,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: PlayOnTheme.primaryGradient,
                  boxShadow: [
                    BoxShadow(
                      color: PlayOnTheme.purplePrimary.withValues(alpha: 0.55),
                      blurRadius: 28,
                      spreadRadius: 3,
                    ),
                    BoxShadow(
                      color: PlayOnTheme.pinkAccent.withValues(alpha: 0.35),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Icon(
                  provider.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 42,
                ),
              ),
            ),

            // Next
            _CircleIconButton(
              icon: Icons.skip_next_rounded,
              size: 40,
              iconSize: 28,
              onTap: provider.next,
            ),
          ],
        ),
      ],
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  final String label;

  const _ToggleButton({
    required this.icon,
    required this.isActive,
    required this.onTap,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
        decoration: BoxDecoration(
          color: isActive
              ? PlayOnTheme.purplePrimary.withValues(alpha: 0.22)
              : PlayOnTheme.bgSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isActive
                ? PlayOnTheme.purplePrimary.withValues(alpha: 0.6)
                : PlayOnTheme.divider,
            width: 1.2,
          ),
          boxShadow: isActive ? PlayOnTheme.glowShadow(blur: 12) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive
                  ? PlayOnTheme.purpleGlow
                  : PlayOnTheme.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isActive
                    ? Colors.white
                    : PlayOnTheme.textSecondary,
                fontSize: 12.5,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final double iconSize;
  final VoidCallback onTap;

  const _CircleIconButton({
    required this.icon,
    required this.size,
    required this.iconSize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(size),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: PlayOnTheme.bgSurface,
          border: Border.all(color: PlayOnTheme.divider),
        ),
        child: Icon(icon, size: iconSize, color: PlayOnTheme.textPrimary),
      ),
    );
  }
}
