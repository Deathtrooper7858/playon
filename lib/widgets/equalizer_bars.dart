import 'dart:math';
import 'package:flutter/material.dart';
import '../theme.dart';

class EqualizerBars extends StatefulWidget {
  final bool isPlaying;
  final Color? color;
  final double size;

  const EqualizerBars({
    super.key,
    required this.isPlaying,
    this.color,
    this.size = 18,
  });

  @override
  State<EqualizerBars> createState() => _EqualizerBarsState();
}

class _EqualizerBarsState extends State<EqualizerBars>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    if (widget.isPlaying) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant EqualizerBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
        _controller.animateTo(0.2, duration: const Duration(milliseconds: 200));
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.color ?? PlayOnTheme.purpleGlow;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final h1 = 0.3 + 0.7 * sin(t * pi);
        final h2 = 0.2 + 0.8 * sin((t + 0.35) * pi).abs();
        final h3 = 0.4 + 0.6 * sin((t + 0.7) * pi).abs();

        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildBar(h1.clamp(0.2, 1.0), activeColor),
              _buildBar(h2.clamp(0.2, 1.0), activeColor),
              _buildBar(h3.clamp(0.2, 1.0), activeColor),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBar(double factor, Color color) {
    return Container(
      width: widget.size * 0.22,
      height: widget.size * factor,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
        boxShadow: widget.isPlaying
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.6),
                  blurRadius: 4,
                ),
              ]
            : null,
      ),
    );
  }
}
