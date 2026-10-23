import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../models/subtitle_model.dart';
import '../models/video_model.dart';
import '../providers/music_provider.dart';
import '../providers/video_provider.dart';
import '../theme.dart';

enum VideoRepeatMode { off, all, one }

class VideoPlayerScreen extends StatefulWidget {
  final PlayOnVideo video;
  final List<PlayOnVideo>? playlist;
  final int? initialIndex;

  const VideoPlayerScreen({
    super.key,
    required this.video,
    this.playlist,
    this.initialIndex,
  });

  static Future<void> open(
    BuildContext context,
    PlayOnVideo video, {
    List<PlayOnVideo>? playlist,
    int? initialIndex,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => VideoPlayerScreen(
          video: video,
          playlist: playlist,
          initialIndex: initialIndex,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late List<PlayOnVideo> _queue;
  late int _currentIndex;

  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  String _errorMessage = '';

  // Controles y visibilidad
  bool _showControls = true;
  Timer? _hideControlsTimer;
  bool _isFullscreen = false;
  bool _isLocked = false;
  double _currentSpeed = 1.0;
  BoxFit _fitMode = BoxFit.contain;

  // Modos de reproducción
  VideoRepeatMode _repeatMode = VideoRepeatMode.off;
  bool _isShuffle = false;

  // Subtítulos
  List<SubtitleTrack> _subtitles = [];
  SubtitleTrack? _activeSubtitle;
  String _currentSubtitleText = '';
  double _subFontSize = 16.0;

  // Temporizador de apagado
  Timer? _sleepTimer;
  Timer? _sleepTicker;
  DateTime? _sleepEndTime;
  bool _sleepFadeOut = true;

  // Gestos HUD (Volumen, Brillo, Seek)
  double _volume = 1.0;
  double _screenBrightness = 1.0;
  bool _showVolumeHud = false;
  bool _showBrightnessHud = false;
  Timer? _hudDismissTimer;

  // Efecto visual doble toque (+/- 10s)
  bool _showRewindPulse = false;
  bool _showForwardPulse = false;

  PlayOnVideo get currentVideo => _queue[_currentIndex];

  @override
  void initState() {
    super.initState();
    // Pausar reproductor de música de fondo automáticamente
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        context.read<MusicProvider>().pause();
      } catch (_) {}
    });

    // Inicializar cola de reproducción
    if (widget.playlist != null && widget.playlist!.isNotEmpty) {
      _queue = List<PlayOnVideo>.from(widget.playlist!);
      _currentIndex = widget.initialIndex ?? _queue.indexWhere((v) => v.id == widget.video.id);
      if (_currentIndex == -1) _currentIndex = 0;
    } else {
      _queue = [widget.video];
      _currentIndex = 0;
    }

    _initPlayerForCurrentVideo();
  }

  Future<void> _initPlayerForCurrentVideo({Duration? initialPosition}) async {
    setState(() {
      _isInitialized = false;
      _hasError = false;
      _errorMessage = '';
      _currentSubtitleText = '';
    });

    final prevController = _controller;
    if (prevController != null) {
      prevController.removeListener(_videoListener);
      await prevController.dispose();
      _controller = null;
    }

    try {
      final file = File(currentVideo.filePath);
      if (!file.existsSync()) {
        throw Exception('El archivo de video no existe en el almacenamiento.');
      }

      final controller = VideoPlayerController.file(file);
      _controller = controller;
      await controller.initialize();
      await controller.setPlaybackSpeed(_currentSpeed);
      await controller.setVolume(_volume);

      if (initialPosition != null && initialPosition > Duration.zero) {
        await controller.seekTo(initialPosition);
      }

      controller.addListener(_videoListener);
      await controller.play();

      // Cargar subtítulos disponibles para este video
      _loadSubtitles();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        _startHideControlsTimer();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _loadSubtitles() async {
    try {
      final tracks = await SubtitleTrack.findSubtitlesForVideo(currentVideo.filePath);
      if (mounted) {
        setState(() {
          _subtitles = tracks;
          // Si hay subtítulo en español o el primer encontrado, activarlo opcionalmente
          if (tracks.isNotEmpty && _activeSubtitle == null) {
            _activeSubtitle = tracks.firstWhere(
              (t) => t.language == 'es',
              orElse: () => tracks.first,
            );
          }
        });
      }
    } catch (_) {}
  }

  void _videoListener() {
    final controller = _controller;
    if (controller == null || !mounted) return;

    final pos = controller.value.position;
    final dur = controller.value.duration;

    // Actualizar subtítulo activo
    if (_activeSubtitle != null) {
      String matching = '';
      for (final cue in _activeSubtitle!.cues) {
        if (cue.isActiveAt(pos)) {
          matching = cue.text;
          break;
        }
      }
      if (matching != _currentSubtitleText) {
        setState(() => _currentSubtitleText = matching);
      }
    } else if (_currentSubtitleText.isNotEmpty) {
      setState(() => _currentSubtitleText = '');
    }

    // Detección de fin de video
    if (controller.value.isInitialized &&
        dur > Duration.zero &&
        pos >= dur &&
        !controller.value.isPlaying) {
      _handleVideoCompleted();
    }

    setState(() {});
  }

  void _handleVideoCompleted() {
    if (_repeatMode == VideoRepeatMode.one) {
      _controller?.seekTo(Duration.zero);
      _controller?.play();
      return;
    }

    if (_currentIndex < _queue.length - 1) {
      _playNext();
    } else if (_repeatMode == VideoRepeatMode.all) {
      _playVideoAtIndex(0);
    }
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    if (_isLocked) return;
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && (_controller?.value.isPlaying ?? false)) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    if (_isLocked) {
      setState(() => _showControls = !_showControls);
      if (_showControls) {
        _hideControlsTimer?.cancel();
        _hideControlsTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) setState(() => _showControls = false);
        });
      }
      return;
    }

    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _startHideControlsTimer();
    } else {
      _hideControlsTimer?.cancel();
    }
  }

  Future<void> _toggleFullscreen() async {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });

    if (_isFullscreen) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _playVideoAtIndex(int index, {Duration? initialPosition}) {
    if (index < 0 || index >= _queue.length) return;
    setState(() {
      _currentIndex = index;
    });
    _initPlayerForCurrentVideo(initialPosition: initialPosition);
  }

  void _playNext() {
    if (_queue.isEmpty) return;
    if (_isShuffle && _queue.length > 1) {
      final nextIdx = (_currentIndex + 1 + (DateTime.now().millisecond % (_queue.length - 1))) % _queue.length;
      _playVideoAtIndex(nextIdx);
      return;
    }
    if (_currentIndex < _queue.length - 1) {
      _playVideoAtIndex(_currentIndex + 1);
    } else if (_repeatMode == VideoRepeatMode.all) {
      _playVideoAtIndex(0);
    }
  }

  void _playPrevious() {
    final pos = _controller?.value.position ?? Duration.zero;
    if (pos > const Duration(seconds: 3)) {
      _controller?.seekTo(Duration.zero);
      return;
    }
    if (_currentIndex > 0) {
      _playVideoAtIndex(_currentIndex - 1);
    } else if (_repeatMode == VideoRepeatMode.all) {
      _playVideoAtIndex(_queue.length - 1);
    }
  }

  Future<void> _seekRelative(int seconds) async {
    final ctrl = _controller;
    if (ctrl == null) return;
    final current = ctrl.value.position;
    final total = ctrl.value.duration;
    final target = current + Duration(seconds: seconds);
    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > total ? total : target);

    await ctrl.seekTo(clamped);
    _startHideControlsTimer();

    // Pulso visual
    if (seconds < 0) {
      setState(() => _showRewindPulse = true);
      Future.delayed(const Duration(milliseconds: 650), () {
        if (mounted) setState(() => _showRewindPulse = false);
      });
    } else {
      setState(() => _showForwardPulse = true);
      Future.delayed(const Duration(milliseconds: 650), () {
        if (mounted) setState(() => _showForwardPulse = false);
      });
    }
  }

  Future<void> _changePlaybackSpeed(double speed) async {
    await _controller?.setPlaybackSpeed(speed);
    setState(() => _currentSpeed = speed);
    _startHideControlsTimer();
  }

  void _toggleRepeat() {
    setState(() {
      switch (_repeatMode) {
        case VideoRepeatMode.off:
          _repeatMode = VideoRepeatMode.all;
          break;
        case VideoRepeatMode.all:
          _repeatMode = VideoRepeatMode.one;
          break;
        case VideoRepeatMode.one:
          _repeatMode = VideoRepeatMode.off;
          break;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _repeatMode == VideoRepeatMode.one
              ? 'Repetir este video'
              : (_repeatMode == VideoRepeatMode.all ? 'Repetir todos los videos' : 'Repetición desactivada'),
        ),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _toggleShuffle() {
    setState(() => _isShuffle = !_isShuffle);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isShuffle ? 'Modo aleatorio activado' : 'Modo aleatorio desactivado'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _cycleFitMode() {
    setState(() {
      if (_fitMode == BoxFit.contain) {
        _fitMode = BoxFit.cover;
      } else if (_fitMode == BoxFit.cover) {
        _fitMode = BoxFit.fill;
      } else {
        _fitMode = BoxFit.contain;
      }
    });
    final label = _fitMode == BoxFit.contain
        ? 'Ajustar a pantalla'
        : (_fitMode == BoxFit.cover ? 'Llenar pantalla (Zoom)' : 'Estirar');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(label),
        duration: const Duration(milliseconds: 900),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Temporizador de apagado ──────────────────────────────────────────────
  void _setSleepTimer(Duration duration, {bool fadeOut = true}) {
    _cancelSleepTimer();
    setState(() {
      _sleepEndTime = DateTime.now().add(duration);
      _sleepFadeOut = fadeOut;
    });

    _sleepTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_sleepEndTime != null && DateTime.now().isAfter(_sleepEndTime!)) {
        _cancelSleepTimer();
        _controller?.pause();
      } else {
        setState(() {});
      }
    });

    _sleepTimer = Timer(duration, () {
      _controller?.pause();
      _cancelSleepTimer();
    });
  }

  void _cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTicker?.cancel();
    _sleepTimer = null;
    _sleepTicker = null;
    setState(() => _sleepEndTime = null);
  }

  Duration? get _sleepTimeRemaining {
    if (_sleepEndTime == null) return null;
    final rem = _sleepEndTime!.difference(DateTime.now());
    return rem.isNegative ? Duration.zero : rem;
  }

  // ── Gestos verticales (Volumen y Brillo) ──────────────────────────────────
  void _onVerticalDragUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    if (_isLocked) return;
    final isRightSide = details.globalPosition.dx > constraints.maxWidth / 2;
    final delta = -details.primaryDelta! / constraints.maxHeight;

    if (isRightSide) {
      // Control de volumen
      final newVol = (_volume + delta * 1.5).clamp(0.0, 1.0);
      setState(() {
        _volume = newVol;
        _showVolumeHud = true;
      });
      _controller?.setVolume(newVol);
    } else {
      // Control de brillo del reproductor
      final newBri = (_screenBrightness + delta * 1.5).clamp(0.1, 1.0);
      setState(() {
        _screenBrightness = newBri;
        _showBrightnessHud = true;
      });
    }

    _hudDismissTimer?.cancel();
    _hudDismissTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() {
          _showVolumeHud = false;
          _showBrightnessHud = false;
        });
      }
    });
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _getVideoQualityLabel() {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return 'HD';
    final h = ctrl.value.size.height.toInt();
    if (h >= 1080) return '1080p FHD';
    if (h >= 720) return '720p HD';
    if (h >= 480) return '480p';
    return '360p SD';
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _hudDismissTimer?.cancel();
    _cancelSleepTimer();
    _controller?.removeListener(_videoListener);
    _controller?.dispose();

    // Restaurar orientación y barras del sistema
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: !_isFullscreen,
        bottom: !_isFullscreen,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              onTap: _toggleControls,
              behavior: HitTestBehavior.opaque,
              onVerticalDragUpdate: (details) => _onVerticalDragUpdate(details, constraints),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Capa de video con brillo y ajuste personalizado
                  Center(
                    child: _isInitialized && _controller != null
                        ? Opacity(
                            opacity: _screenBrightness,
                            child: FittedBox(
                              fit: _fitMode,
                              child: SizedBox(
                                width: _controller!.value.size.width > 0 ? _controller!.value.size.width : 1280,
                                height: _controller!.value.size.height > 0 ? _controller!.value.size.height : 720,
                                child: VideoPlayer(_controller!),
                              ),
                            ),
                          )
                        : _hasError
                            ? _buildErrorView()
                            : const CircularProgressIndicator(color: PlayOnTheme.purplePrimary),
                  ),

                  // Capa de subtítulos live sincronizados
                  if (_currentSubtitleText.isNotEmpty && !_isLocked)
                    Positioned(
                      bottom: _showControls ? 88 : 28,
                      left: 20,
                      right: 20,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                          ),
                          child: Text(
                            _currentSubtitleText,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: _subFontSize,
                              fontWeight: FontWeight.w600,
                              shadows: const [
                                Shadow(blurRadius: 3, color: Colors.black, offset: Offset(1, 1)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Gestos de doble toque para adelantar/retroceder
                  if (_isInitialized && !_isLocked)
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onDoubleTap: () => _seekRelative(-10),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onDoubleTap: () => _seekRelative(10),
                          ),
                        ),
                      ],
                    ),

                  // Pulso visual animado << 10s o 10s >>
                  if (_showRewindPulse)
                    Positioned(
                      left: 40,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.6),
                          ),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.replay_10_rounded, color: Colors.white, size: 40),
                              SizedBox(height: 4),
                              Text('-10s', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),

                  if (_showForwardPulse)
                    Positioned(
                      right: 40,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.6),
                          ),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.forward_10_rounded, color: Colors.white, size: 40),
                              SizedBox(height: 4),
                              Text('+10s', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // HUD Flotante de Volumen
                  if (_showVolumeHud)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: PlayOnTheme.glassBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _volume == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                              color: PlayOnTheme.purpleGlow,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 120,
                              child: LinearProgressIndicator(
                                value: _volume,
                                backgroundColor: Colors.white24,
                                valueColor: const AlwaysStoppedAnimation(PlayOnTheme.purpleGlow),
                                minHeight: 6,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${(_volume * 100).toInt()}%',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // HUD Flotante de Brillo
                  if (_showBrightnessHud)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: PlayOnTheme.glassBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.brightness_6_rounded, color: PlayOnTheme.cyanAccent, size: 28),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 120,
                              child: LinearProgressIndicator(
                                value: _screenBrightness,
                                backgroundColor: Colors.white24,
                                valueColor: const AlwaysStoppedAnimation(PlayOnTheme.cyanAccent),
                                minHeight: 6,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${(_screenBrightness * 100).toInt()}%',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Botón flotante para desbloquear si la pantalla está bloqueada
                  if (_isLocked && _showControls)
                    Positioned(
                      top: 24,
                      left: 24,
                      child: FloatingActionButton.small(
                        backgroundColor: PlayOnTheme.purplePrimary,
                        child: const Icon(Icons.lock_rounded, color: Colors.white),
                        onPressed: () {
                          setState(() {
                            _isLocked = false;
                            _showControls = true;
                          });
                          _startHideControlsTimer();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Pantalla desbloqueada'),
                              duration: Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                    ),

                  // Capa de Controles Superpuestos Completos
                  if (_isInitialized && _showControls && !_isLocked)
                    AnimatedOpacity(
                      opacity: _showControls ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 250),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withValues(alpha: 0.75),
                              Colors.transparent,
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.9),
                            ],
                            stops: const [0.0, 0.22, 0.65, 1.0],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildTopBar(),
                            _buildCenterControls(),
                            _buildBottomSection(),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Barra Superior de Controles ──────────────────────────────────────────
  Widget _buildTopBar() {
    final videoProv = context.watch<VideoProvider>();
    final isFav = videoProv.isFavorite(currentVideo.id);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  currentVideo.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Text(
                      currentVideo.author,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _showQualitySheet(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: PlayOnTheme.purplePrimary.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: PlayOnTheme.purpleGlow.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _getVideoQualityLabel(),
                              style: const TextStyle(color: PlayOnTheme.purpleGlow, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 2),
                            const Icon(Icons.arrow_drop_down_rounded, size: 14, color: PlayOnTheme.purpleGlow),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Botón Favorito
          IconButton(
            icon: Icon(
              isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: isFav ? PlayOnTheme.pinkAccent : Colors.white70,
              size: 24,
            ),
            tooltip: 'Favorito',
            onPressed: () => videoProv.toggleFavorite(currentVideo.id),
          ),

          // Botón Subtítulos
          IconButton(
            icon: Icon(
              _activeSubtitle != null ? Icons.subtitles_rounded : Icons.subtitles_outlined,
              color: _activeSubtitle != null ? PlayOnTheme.cyanAccent : Colors.white70,
              size: 24,
            ),
            tooltip: 'Subtítulos',
            onPressed: () => _showSubtitleSheet(context),
          ),

          // Botón Bloqueo de pantalla
          IconButton(
            icon: const Icon(Icons.lock_outline_rounded, color: Colors.white70, size: 22),
            tooltip: 'Bloquear pantalla',
            onPressed: () {
              setState(() {
                _isLocked = true;
                _showControls = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Pantalla bloqueada. Toca la pantalla para desbloquear.'),
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),

          // Menú Más Opciones
          IconButton(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 24),
            tooltip: 'Más opciones',
            onPressed: () => _showOptionsSheet(context),
          ),
        ],
      ),
    );
  }

  // ── Controles Centrales ──────────────────────────────────────────────────
  Widget _buildCenterControls() {
    final ctrl = _controller;
    final isPlaying = ctrl?.value.isPlaying ?? false;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Video anterior en cola
        IconButton(
          icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 34),
          tooltip: 'Video anterior',
          onPressed: _playPrevious,
        ),
        const SizedBox(width: 14),

        // Retroceder 10s
        IconButton(
          icon: const Icon(Icons.replay_10_rounded, color: Colors.white, size: 34),
          tooltip: 'Retroceder 10s',
          onPressed: () => _seekRelative(-10),
        ),
        const SizedBox(width: 22),

        // Botón Play / Pause gigante con glow
        GestureDetector(
          onTap: () {
            if (isPlaying) {
              ctrl?.pause();
              _hideControlsTimer?.cancel();
            } else {
              ctrl?.play();
              _startHideControlsTimer();
            }
          },
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: PlayOnTheme.primaryGradient,
              boxShadow: [
                BoxShadow(
                  color: PlayOnTheme.purplePrimary.withValues(alpha: 0.65),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 44,
            ),
          ),
        ),
        const SizedBox(width: 22),

        // Adelantar 10s
        IconButton(
          icon: const Icon(Icons.forward_10_rounded, color: Colors.white, size: 34),
          tooltip: 'Adelantar 10s',
          onPressed: () => _seekRelative(10),
        ),
        const SizedBox(width: 14),

        // Video siguiente en cola
        IconButton(
          icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 34),
          tooltip: 'Siguiente video',
          onPressed: _playNext,
        ),
      ],
    );
  }

  // ── Sección Inferior con Barra de Progreso y Herramientas ────────────────
  Widget _buildBottomSection() {
    final ctrl = _controller;
    final position = ctrl?.value.position ?? Duration.zero;
    final duration = ctrl?.value.duration ?? Duration.zero;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Slider de progreso interactivo
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3.5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: PlayOnTheme.pinkAccent,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.25),
              thumbColor: Colors.white,
            ),
            child: Slider(
              value: position.inMilliseconds
                  .clamp(0, duration.inMilliseconds)
                  .toDouble(),
              min: 0.0,
              max: duration.inMilliseconds.toDouble() > 0
                  ? duration.inMilliseconds.toDouble()
                  : 1.0,
              onChanged: (val) {
                ctrl?.seekTo(Duration(milliseconds: val.toInt()));
                _startHideControlsTimer();
              },
            ),
          ),

          // Tiempos (actual / total)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(position),
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                Text(
                  _formatDuration(duration),
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // Barra de Herramientas Rápidas estilo NowPlaying
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: PlayOnTheme.bgSurface.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: PlayOnTheme.glassBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Repetir
                IconButton(
                  icon: Icon(
                    _repeatMode == VideoRepeatMode.one ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                    color: _repeatMode != VideoRepeatMode.off ? PlayOnTheme.purpleGlow : Colors.white60,
                    size: 22,
                  ),
                  tooltip: 'Modo de repetición',
                  onPressed: _toggleRepeat,
                ),

                // Aleatorio
                IconButton(
                  icon: Icon(
                    Icons.shuffle_rounded,
                    color: _isShuffle ? PlayOnTheme.cyanAccent : Colors.white60,
                    size: 22,
                  ),
                  tooltip: 'Aleatorio',
                  onPressed: _toggleShuffle,
                ),

                // Cola de videos
                IconButton(
                  icon: const Icon(Icons.queue_play_next_rounded, color: PlayOnTheme.amberWarning, size: 22),
                  tooltip: 'Cola de videos',
                  onPressed: () => _showQueueSheet(context),
                ),

                // Velocidad
                IconButton(
                  icon: const Icon(Icons.speed_rounded, color: PlayOnTheme.cyanAccent, size: 22),
                  tooltip: 'Velocidad',
                  onPressed: () => _showSpeedOptions(context),
                ),

                // Ajuste de pantalla (Aspect Ratio)
                IconButton(
                  icon: const Icon(Icons.aspect_ratio_rounded, color: PlayOnTheme.pinkAccent, size: 22),
                  tooltip: 'Ajuste de pantalla',
                  onPressed: _cycleFitMode,
                ),

                // Temporizador
                IconButton(
                  icon: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        color: _sleepEndTime != null ? PlayOnTheme.amberWarning : Colors.white60,
                        size: 22,
                      ),
                      if (_sleepEndTime != null)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: PlayOnTheme.amberWarning,
                            ),
                          ),
                        ),
                    ],
                  ),
                  tooltip: 'Temporizador',
                  onPressed: () => _showTimerOptions(context),
                ),

                // Pantalla completa
                IconButton(
                  icon: Icon(
                    _isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                  tooltip: _isFullscreen ? 'Salir de pantalla completa' : 'Pantalla completa',
                  onPressed: _toggleFullscreen,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // ── Modal de Cola de Videos ───────────────────────────────────────────────
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
              child: StatefulBuilder(
                builder: (context, setSheetState) {
                  return Column(
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
                            const Icon(Icons.queue_play_next_rounded, color: PlayOnTheme.amberWarning, size: 24),
                            const SizedBox(width: 12),
                            const Text(
                              'Cola de Videos',
                              style: TextStyle(
                                color: PlayOnTheme.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${_queue.length} videos',
                              style: const TextStyle(color: PlayOnTheme.textSecondary, fontSize: 12.5),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Divider(color: PlayOnTheme.divider),
                      Expanded(
                        child: _queue.isEmpty
                            ? const Center(
                                child: Text('La cola está vacía', style: TextStyle(color: PlayOnTheme.textSecondary)),
                              )
                            : Theme(
                                data: Theme.of(context).copyWith(
                                  canvasColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                ),
                                child: ReorderableListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: _queue.length,
                                  onReorderItem: (oldIdx, newIdx) {
                                    setSheetState(() {
                                      final item = _queue.removeAt(oldIdx);
                                      _queue.insert(newIdx, item);
                                      if (_currentIndex == oldIdx) {
                                        _currentIndex = newIdx;
                                      } else if (oldIdx < _currentIndex && newIdx >= _currentIndex) {
                                        _currentIndex--;
                                      } else if (oldIdx > _currentIndex && newIdx <= _currentIndex) {
                                        _currentIndex++;
                                      }
                                    });
                                    setState(() {});
                                  },
                                  itemBuilder: (context, index) {
                                    final item = _queue[index];
                                    final isCurrent = index == _currentIndex;

                                    return Container(
                                      key: ValueKey('vqueue_${item.id}_$index'),
                                      margin: const EdgeInsets.symmetric(vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isCurrent
                                            ? PlayOnTheme.purplePrimary.withValues(alpha: 0.18)
                                            : PlayOnTheme.bgSurface.withValues(alpha: 0.5),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isCurrent ? PlayOnTheme.purpleGlow : Colors.transparent,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: ListTile(
                                        dense: true,
                                        leading: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: SizedBox(
                                            width: 50,
                                            height: 38,
                                            child: item.thumbnailPath != null && File(item.thumbnailPath!).existsSync()
                                                ? Image.file(File(item.thumbnailPath!), fit: BoxFit.cover)
                                                : Container(
                                                    color: PlayOnTheme.bgSurface,
                                                    child: const Icon(Icons.videocam_rounded, color: Colors.white54, size: 20),
                                                  ),
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
                                          '${item.author} • ${item.folderName}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(color: PlayOnTheme.textSecondary, fontSize: 11.5),
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (_queue.length > 1)
                                              IconButton(
                                                icon: const Icon(Icons.close_rounded, size: 18),
                                                color: PlayOnTheme.textTertiary,
                                                onPressed: () {
                                                  setSheetState(() {
                                                    _queue.removeAt(index);
                                                    if (_currentIndex >= _queue.length) {
                                                      _currentIndex = _queue.length - 1;
                                                    }
                                                  });
                                                  setState(() {});
                                                },
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
                                          Navigator.pop(ctx);
                                          _playVideoAtIndex(index);
                                        },
                                      ),
                                    );
                                  },
                                ),
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Modal de Subtítulos ───────────────────────────────────────────────────
  void _showSubtitleSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  decoration: BoxDecoration(
                    color: PlayOnTheme.bgCard.withValues(alpha: 0.96),
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
                        Row(
                          children: [
                            const Icon(Icons.subtitles_rounded, color: PlayOnTheme.cyanAccent, size: 24),
                            const SizedBox(width: 10),
                            const Text(
                              'Pistas de Subtítulos',
                              style: TextStyle(
                                color: PlayOnTheme.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            if (_subtitles.isNotEmpty)
                              Text(
                                '${_subtitles.length} encontradas',
                                style: const TextStyle(color: PlayOnTheme.textSecondary, fontSize: 12),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(color: PlayOnTheme.divider),

                        // Opción Desactivado
                        ListTile(
                          dense: true,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          tileColor: _activeSubtitle == null ? PlayOnTheme.purplePrimary.withValues(alpha: 0.15) : null,
                          leading: const Icon(Icons.subtitles_off_rounded, color: PlayOnTheme.textSecondary),
                          title: const Text('Desactivar subtítulos', style: TextStyle(color: PlayOnTheme.textPrimary)),
                          trailing: _activeSubtitle == null
                              ? const Icon(Icons.check_rounded, color: PlayOnTheme.purpleGlow)
                              : null,
                          onTap: () {
                            setState(() {
                              _activeSubtitle = null;
                              _currentSubtitleText = '';
                            });
                            Navigator.pop(ctx);
                          },
                        ),

                        // Lista de subtítulos detectados
                        if (_subtitles.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 18),
                            child: Text(
                              'No se detectaron archivos de subtítulos (.srt o .vtt) para este video.',
                              style: TextStyle(color: PlayOnTheme.textSecondary, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          )
                        else
                          ..._subtitles.map((track) {
                            final isSel = _activeSubtitle?.id == track.id;
                            return ListTile(
                              dense: true,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              tileColor: isSel ? PlayOnTheme.purplePrimary.withValues(alpha: 0.15) : null,
                              leading: const Icon(Icons.closed_caption_rounded, color: PlayOnTheme.cyanAccent),
                              title: Text(
                                track.name,
                                style: TextStyle(
                                  color: isSel ? PlayOnTheme.cyanAccent : PlayOnTheme.textPrimary,
                                  fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              subtitle: Text(
                                p.basename(track.filePath),
                                style: const TextStyle(color: PlayOnTheme.textSecondary, fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: isSel
                                  ? const Icon(Icons.check_rounded, color: PlayOnTheme.cyanAccent)
                                  : null,
                              onTap: () {
                                setState(() {
                                  _activeSubtitle = track;
                                });
                                Navigator.pop(ctx);
                              },
                            );
                          }),

                        const SizedBox(height: 12),
                        const Divider(color: PlayOnTheme.divider),

                        // Tamaño de fuente de subtítulos
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Tamaño de subtítulos', style: TextStyle(color: PlayOnTheme.textPrimary, fontSize: 13.5)),
                            Row(
                              children: [13.0, 16.0, 20.0].map((size) {
                                final isCur = _subFontSize == size;
                                final label = size == 13.0 ? 'A' : (size == 16.0 ? 'A+' : 'A++');
                                return Padding(
                                  padding: const EdgeInsets.only(left: 6),
                                  child: ChoiceChip(
                                    label: Text(label),
                                    selected: isCur,
                                    selectedColor: PlayOnTheme.purplePrimary.withValues(alpha: 0.3),
                                    backgroundColor: PlayOnTheme.bgSurface,
                                    labelStyle: TextStyle(
                                      color: isCur ? PlayOnTheme.purpleGlow : PlayOnTheme.textSecondary,
                                      fontWeight: isCur ? FontWeight.bold : FontWeight.normal,
                                    ),
                                    onSelected: (_) {
                                      setState(() => _subFontSize = size);
                                      setSheetState(() {});
                                    },
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
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

  // ── Modal de Temporizador de Apagado ──────────────────────────────────────
  void _showTimerOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final hasTimer = _sleepEndTime != null;
            final remaining = _sleepTimeRemaining;

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
                          value: _sleepFadeOut,
                          activeTrackColor: PlayOnTheme.purplePrimary,
                          onChanged: (v) {
                            setState(() => _sleepFadeOut = v);
                            setSheetState(() {});
                          },
                        ),
                        const Divider(color: PlayOnTheme.divider),
                        ...[15, 30, 45, 60, 90].map((mins) => ListTile(
                              dense: true,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              leading: const Icon(Icons.timer_outlined, color: PlayOnTheme.amberWarning),
                              title: Text('$mins minutos', style: const TextStyle(color: PlayOnTheme.textPrimary, fontSize: 14)),
                              onTap: () {
                                _setSleepTimer(Duration(minutes: mins), fadeOut: _sleepFadeOut);
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Video se detendrá en $mins min'),
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
                              _cancelSleepTimer();
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

  // ── Modal de Velocidad de Reproducción ────────────────────────────────────
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
                    ...[0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0].map((spd) {
                      final isSelected = (_currentSpeed == spd);
                      return ListTile(
                        dense: true,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        tileColor: isSelected ? PlayOnTheme.purplePrimary.withValues(alpha: 0.15) : null,
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
                          _changePlaybackSpeed(spd);
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

  // ── Modal de Calidad y Resolución ─────────────────────────────────────────
  void _showQualitySheet(BuildContext context) {
    final videoProv = context.read<VideoProvider>();
    final ctrl = _controller;
    final w = ctrl?.value.size.width.toInt() ?? 0;
    final h = ctrl?.value.size.height.toInt() ?? 0;
    final currentQuality = _getVideoQualityLabel();

    // Buscar si existen otras versiones o resoluciones de este video en el dispositivo
    final currentTitleLower = currentVideo.title.toLowerCase();
    final relatedVideos = videoProv.videos.where((v) {
      if (v.id == currentVideo.id) return false;
      final otherLower = v.title.toLowerCase();
      return otherLower.contains(currentTitleLower) || currentTitleLower.contains(otherLower);
    }).toList();

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
                color: PlayOnTheme.bgCard.withValues(alpha: 0.96),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: PlayOnTheme.glassBorder, width: 1.5),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: PlayOnTheme.purplePrimary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.high_quality_rounded, color: PlayOnTheme.cyanAccent, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Calidad y Resolución',
                                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Detalles del video en reproducción',
                                style: TextStyle(color: PlayOnTheme.textSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Tarjeta de Calidad Activa
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: PlayOnTheme.bgSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: PlayOnTheme.purpleGlow.withValues(alpha: 0.4), width: 1.5),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: PlayOnTheme.purplePrimary.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  currentQuality,
                                  style: const TextStyle(color: PlayOnTheme.cyanAccent, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Calidad Actual (Activa)',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const Spacer(),
                              const Icon(Icons.check_circle_rounded, color: PlayOnTheme.emeraldActive, size: 20),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(color: PlayOnTheme.divider, height: 1),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildQualitySpec('Resolución', '${w}x$h px'),
                              _buildQualitySpec('Tamaño', currentVideo.fileSizeFormatted),
                              _buildQualitySpec('Formato', p.extension(currentVideo.filePath).toUpperCase().replaceAll('.', '')),
                              _buildQualitySpec('Carpeta', currentVideo.folderName),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Explicación técnica de reproducción local
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: PlayOnTheme.purplePrimary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: PlayOnTheme.purplePrimary.withValues(alpha: 0.2)),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline_rounded, color: PlayOnTheme.purpleGlow, size: 18),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Los videos descargados se reproducen directamente desde tu almacenamiento en su resolución nativa original para garantizar fluidez absoluta sin cortes, sin gastar datos ni depender de WiFi.',
                              style: TextStyle(color: PlayOnTheme.textSecondary, fontSize: 12, height: 1.35),
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (relatedVideos.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Otras versiones de este video en tu dispositivo:',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ...relatedVideos.map((other) => ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            tileColor: PlayOnTheme.bgSurface,
                            leading: const Icon(Icons.video_file_rounded, color: PlayOnTheme.pinkAccent),
                            title: Text(other.title, style: const TextStyle(color: Colors.white, fontSize: 13), maxLines: 1),
                            subtitle: Text('${other.folderName} • ${other.fileSizeFormatted}', style: const TextStyle(color: PlayOnTheme.textSecondary, fontSize: 11)),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: PlayOnTheme.purplePrimary,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('Cambiar', style: TextStyle(color: Colors.white, fontSize: 11)),
                              onPressed: () {
                                final currentPos = _controller?.value.position ?? Duration.zero;
                                Navigator.pop(ctx);
                                final index = _queue.indexWhere((item) => item.id == other.id);
                                if (index != -1) {
                                  _playVideoAtIndex(index, initialPosition: currentPos);
                                } else {
                                  setState(() {
                                    _queue.add(other);
                                    _currentIndex = _queue.length - 1;
                                  });
                                  _initPlayerForCurrentVideo(initialPosition: currentPos);
                                }
                              },
                            ),
                          )),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQualitySpec(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: PlayOnTheme.textSecondary, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // ── Modal Más Opciones ───────────────────────────────────────────────────
  void _showOptionsSheet(BuildContext context) {
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
                color: PlayOnTheme.bgCard.withValues(alpha: 0.96),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: PlayOnTheme.glassBorder, width: 1.5),
              ),
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: SingleChildScrollView(
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
                        child: SizedBox(
                          width: 48,
                          height: 38,
                          child: currentVideo.thumbnailPath != null && File(currentVideo.thumbnailPath!).existsSync()
                              ? Image.file(File(currentVideo.thumbnailPath!), fit: BoxFit.cover)
                              : Container(
                                  color: PlayOnTheme.bgSurface,
                                  child: const Icon(Icons.videocam_rounded, color: Colors.white54),
                                ),
                        ),
                      ),
                      title: Text(
                        currentVideo.title,
                        style: const TextStyle(color: PlayOnTheme.textPrimary, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${currentVideo.author} • ${currentVideo.folderName} • ${_getVideoQualityLabel()}',
                        style: const TextStyle(color: PlayOnTheme.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Divider(color: PlayOnTheme.divider),
                    ListTile(
                      leading: const Icon(Icons.high_quality_rounded, color: PlayOnTheme.cyanAccent),
                      title: const Text('Calidad y Resolución', style: TextStyle(color: PlayOnTheme.textPrimary)),
                      subtitle: Text('${_getVideoQualityLabel()} • ${_controller?.value.size.width.toInt() ?? 0}x${_controller?.value.size.height.toInt() ?? 0}', style: const TextStyle(color: PlayOnTheme.textSecondary, fontSize: 12)),
                      trailing: const Icon(Icons.chevron_right_rounded, color: PlayOnTheme.textSecondary),
                      onTap: () {
                        Navigator.pop(ctx);
                        _showQualitySheet(context);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.queue_play_next_rounded, color: PlayOnTheme.amberWarning),
                      title: const Text('Ver Cola de Videos', style: TextStyle(color: PlayOnTheme.textPrimary)),
                      onTap: () {
                        Navigator.pop(ctx);
                        _showQueueSheet(context);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.subtitles_rounded, color: PlayOnTheme.cyanAccent),
                      title: const Text('Subtítulos y Pistas', style: TextStyle(color: PlayOnTheme.textPrimary)),
                      onTap: () {
                        Navigator.pop(ctx);
                        _showSubtitleSheet(context);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.speed_rounded, color: PlayOnTheme.purpleGlow),
                      title: const Text('Velocidad de Reproducción', style: TextStyle(color: PlayOnTheme.textPrimary)),
                      onTap: () {
                        Navigator.pop(ctx);
                        _showSpeedOptions(context);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.timer_outlined, color: PlayOnTheme.purplePrimary),
                      title: const Text('Temporizador de Apagado', style: TextStyle(color: PlayOnTheme.textPrimary)),
                      onTap: () {
                        Navigator.pop(ctx);
                        _showTimerOptions(context);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.drive_file_move_rounded, color: PlayOnTheme.emeraldActive),
                      title: const Text('Mover a otra carpeta', style: TextStyle(color: PlayOnTheme.textPrimary)),
                      onTap: () {
                        Navigator.pop(ctx);
                        _showMoveFolderDialog(context);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.info_outline_rounded, color: PlayOnTheme.textSecondary),
                      title: const Text('Detalles del video', style: TextStyle(color: PlayOnTheme.textPrimary)),
                      onTap: () {
                        Navigator.pop(ctx);
                        _showVideoDetailsDialog(context);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.delete_outline_rounded, color: PlayOnTheme.pinkAccent),
                      title: const Text('Eliminar video', style: TextStyle(color: PlayOnTheme.pinkAccent)),
                      onTap: () {
                        Navigator.pop(ctx);
                        _confirmDeleteVideo(context);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Diálogo de Mover a Carpeta ─────────────────────────────────────────────
  void _showMoveFolderDialog(BuildContext context) async {
    final videoProv = context.read<VideoProvider>();
    final folders = videoProv.folders;
    final folderController = TextEditingController();

    try {
      await showDialog(
        context: context,
        builder: (dialogCtx) {
          return AlertDialog(
            backgroundColor: PlayOnTheme.bgCard,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: PlayOnTheme.glassBorder)),
            title: const Text('Mover video a carpeta', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (folders.isNotEmpty) ...[
                    const Text('Carpetas existentes:', style: TextStyle(color: PlayOnTheme.textSecondary, fontSize: 12)),
                    const SizedBox(height: 8),
                    ...folders.where((f) => f != currentVideo.folderName).map((f) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.folder_rounded, color: PlayOnTheme.purpleGlow),
                          title: Text(f, style: const TextStyle(color: Colors.white)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          onTap: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            Navigator.pop(dialogCtx);
                            final targetPath = p.join(p.dirname(currentVideo.folderPath), f);
                            await videoProv.moveVideo(currentVideo, targetPath, f);
                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(content: Text('Video movido a "$f"'), behavior: SnackBarBehavior.floating),
                              );
                            }
                          },
                        )),
                    const SizedBox(height: 12),
                    const Divider(color: PlayOnTheme.divider),
                  ],
                  const Text('O escribir nueva carpeta:', style: TextStyle(color: PlayOnTheme.textSecondary, fontSize: 12)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: folderController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Nombre de carpeta',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: PlayOnTheme.bgSurface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: PlayOnTheme.purplePrimary),
                onPressed: () async {
                  final text = folderController.text.trim();
                  if (text.isNotEmpty) {
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(dialogCtx);
                    final targetPath = p.join(p.dirname(currentVideo.folderPath), text);
                    await videoProv.moveVideo(currentVideo, targetPath, text);
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('Video movido a "$text"'), behavior: SnackBarBehavior.floating),
                      );
                    }
                  }
                },
                child: const Text('Mover', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      );
    } finally {
      folderController.dispose();
    }
  }

  // ── Diálogo de Detalles del Video ─────────────────────────────────────────
  void _showVideoDetailsDialog(BuildContext context) {
    final ctrl = _controller;
    final w = ctrl?.value.size.width.toInt() ?? 0;
    final h = ctrl?.value.size.height.toInt() ?? 0;
    final dur = ctrl?.value.duration ?? Duration.zero;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: PlayOnTheme.bgCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: PlayOnTheme.glassBorder)),
          title: const Text('Detalles del Video', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Título', currentVideo.title),
              _buildDetailRow('Autor / Canal', currentVideo.author),
              _buildDetailRow('Resolución', '${w}x$h (${_getVideoQualityLabel()})'),
              _buildDetailRow('Duración', _formatDuration(dur)),
              _buildDetailRow('Tamaño', currentVideo.fileSizeFormatted),
              _buildDetailRow('Carpeta', currentVideo.folderName),
              _buildDetailRow('Ruta física', currentVideo.filePath),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cerrar', style: TextStyle(color: PlayOnTheme.purpleGlow)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: PlayOnTheme.textTertiary, fontSize: 11)),
          Text(value, style: const TextStyle(color: PlayOnTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // ── Diálogo de Confirmación para Eliminar Video ───────────────────────────
  void _confirmDeleteVideo(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: PlayOnTheme.bgCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: PlayOnTheme.glassBorder)),
          title: const Text('¿Eliminar video?', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          content: Text(
            'Se eliminará "${currentVideo.title}" permanentemente de tu dispositivo.',
            style: const TextStyle(color: PlayOnTheme.textSecondary, fontSize: 13.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF5350)),
              onPressed: () async {
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(dialogCtx);
                final prov = context.read<VideoProvider>();
                final toDelete = currentVideo;
                await prov.deleteVideo(toDelete);

                if (mounted) {
                  _queue.removeAt(_currentIndex);
                  if (_queue.isNotEmpty) {
                    if (_currentIndex >= _queue.length) _currentIndex = _queue.length - 1;
                    _playVideoAtIndex(_currentIndex);
                  } else {
                    navigator.pop();
                  }
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Video eliminado'), behavior: SnackBarBehavior.floating),
                  );
                }
              },
              child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // ── Vista de Error ────────────────────────────────────────────────────────
  Widget _buildErrorView() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFEF5350), size: 48),
          const SizedBox(height: 16),
          const Text(
            'No se pudo reproducir el video',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _initPlayerForCurrentVideo,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: PlayOnTheme.purplePrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}
