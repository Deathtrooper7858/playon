import 'package:flutter/material.dart';
import '../providers/music_provider.dart';
import '../theme.dart';

class ProgressBarWidget extends StatefulWidget {
  final MusicProvider provider;

  const ProgressBarWidget({super.key, required this.provider});

  @override
  State<ProgressBarWidget> createState() => _ProgressBarWidgetState();
}

class _ProgressBarWidgetState extends State<ProgressBarWidget> {
  bool _isDragging = false;
  double _dragValue = 0.0;
  bool _showRemaining = false;

  String _format(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final position = widget.provider.position;
    final duration = widget.provider.duration;
    final liveProgress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    final progress = _isDragging ? _dragValue : liveProgress;
    final displayPosition = _isDragging
        ? Duration(milliseconds: (_dragValue * duration.inMilliseconds).toInt())
        : position;

    final remaining = duration - displayPosition;
    final remainingFormatted = '-${_format(remaining.isNegative ? Duration.zero : remaining)}';

    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4.5,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
            activeTrackColor: PlayOnTheme.purplePrimary,
            inactiveTrackColor: PlayOnTheme.divider,
            thumbColor: Colors.white,
            overlayColor: PlayOnTheme.purplePrimary.withValues(alpha: 0.25),
          ),
          child: Slider(
            value: progress.clamp(0.0, 1.0),
            onChangeStart: (value) {
              setState(() {
                _isDragging = true;
                _dragValue = value;
              });
            },
            onChanged: (value) {
              setState(() {
                _dragValue = value;
              });
            },
            onChangeEnd: (value) {
              final ms = (value * duration.inMilliseconds).toInt();
              widget.provider.seekTo(Duration(milliseconds: ms));
              setState(() {
                _isDragging = false;
              });
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _format(displayPosition),
                style: const TextStyle(
                  color: PlayOnTheme.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _showRemaining = !_showRemaining),
                child: Text(
                  _showRemaining ? remainingFormatted : _format(duration),
                  style: const TextStyle(
                    color: PlayOnTheme.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
