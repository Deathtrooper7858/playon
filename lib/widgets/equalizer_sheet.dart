import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/equalizer_provider.dart';
import '../theme.dart';

class EqualizerSheet extends StatelessWidget {
  const EqualizerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const EqualizerSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EqualizerProvider>(
      builder: (context, eq, _) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: PlayOnTheme.bgCard.withValues(alpha: 0.9),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: PlayOnTheme.glassBorder, width: 1.5),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Grab handle
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

                  // Header with ON/OFF switch
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: PlayOnTheme.purplePrimary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: PlayOnTheme.purplePrimary.withValues(alpha: 0.3)),
                        ),
                        child: const Icon(
                          Icons.equalizer_rounded,
                          color: PlayOnTheme.purpleGlow,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Audio Equalizer',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 19,
                                  ),
                            ),
                            Text(
                              eq.enabled ? 'Efectos de audio activos' : 'Desactivado',
                              style: TextStyle(
                                color: eq.enabled ? PlayOnTheme.emeraldActive : PlayOnTheme.textTertiary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: eq.enabled,
                        activeThumbColor: Colors.white,
                        activeTrackColor: PlayOnTheme.purplePrimary,
                        inactiveThumbColor: PlayOnTheme.textTertiary,
                        inactiveTrackColor: PlayOnTheme.bgSurface,
                        onChanged: (val) => eq.setEnabled(val),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  if (!eq.isAvailable) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: PlayOnTheme.bgSurface,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: PlayOnTheme.amberWarning),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'El ecualizador de audio nativo se activará automáticamente al reproducir una pista en Android.',
                              style: TextStyle(color: PlayOnTheme.textSecondary, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Preset Chips
                    SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _PresetChip(
                            label: 'Custom',
                            isSelected: eq.selectedPreset == -1,
                            onTap: () {},
                          ),
                          const SizedBox(width: 8),
                          ...List.generate(eq.presets.length, (idx) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _PresetChip(
                                label: eq.presets[idx],
                                isSelected: eq.selectedPreset == idx,
                                onTap: () => eq.usePreset(idx),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Frequency Sliders (5 Bands)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                      decoration: BoxDecoration(
                        color: PlayOnTheme.bgSurface.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: PlayOnTheme.divider),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(eq.numBands, (band) {
                          final freq = band < eq.centerFreqs.length ? eq.centerFreqs[band] : 0;
                          final level = band < eq.bandLevels.length ? eq.bandLevels[band] : 0;
                          final min = eq.minLevel.toDouble();
                          final max = eq.maxLevel.toDouble();

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${(level / 100).round() > 0 ? "+" : ""}${(level / 100).round()} dB',
                                style: const TextStyle(
                                  color: PlayOnTheme.purpleGlow,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                height: 140,
                                width: 44,
                                child: RotatedBox(
                                  quarterTurns: 3,
                                  child: SliderTheme(
                                    data: SliderThemeData(
                                      trackHeight: 4,
                                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                                      activeTrackColor: eq.enabled ? PlayOnTheme.purplePrimary : PlayOnTheme.textTertiary,
                                      inactiveTrackColor: PlayOnTheme.divider,
                                      thumbColor: Colors.white,
                                    ),
                                    child: Slider(
                                      value: level.toDouble().clamp(min, max),
                                      min: min,
                                      max: max,
                                      onChanged: eq.enabled
                                          ? (v) => eq.setBandLevel(band, v.round())
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                eq.formatFrequency(freq),
                                style: const TextStyle(
                                  color: PlayOnTheme.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Bass Boost Slider
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: PlayOnTheme.bgSurface.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: PlayOnTheme.divider),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.speaker_rounded, color: PlayOnTheme.pinkAccent, size: 22),
                          const SizedBox(width: 12),
                          const Text(
                            'Bass Boost',
                            style: TextStyle(
                              color: PlayOnTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 4,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                                activeTrackColor: eq.enabled ? PlayOnTheme.pinkAccent : PlayOnTheme.textTertiary,
                                inactiveTrackColor: PlayOnTheme.divider,
                                thumbColor: Colors.white,
                              ),
                              child: Slider(
                                value: eq.bassBoost.toDouble(),
                                min: 0,
                                max: 1000,
                                onChanged: eq.enabled
                                    ? (v) => eq.setBassBoost(v.round())
                                    : null,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: PlayOnTheme.bgSurfaceElevated,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${(eq.bassBoost / 10).round()}%',
                              style: const TextStyle(
                                color: PlayOnTheme.pinkAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PresetChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? PlayOnTheme.purplePrimary.withValues(alpha: 0.25)
              : PlayOnTheme.bgSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? PlayOnTheme.purplePrimary : PlayOnTheme.divider,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected ? PlayOnTheme.glowShadow(blur: 10) : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : PlayOnTheme.textSecondary,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
