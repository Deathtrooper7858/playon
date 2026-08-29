import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../providers/download_provider.dart';
import '../providers/music_provider.dart';
import '../services/cookie_service.dart';
import '../theme.dart';
import 'now_playing_screen.dart';
import 'youtube_login_screen.dart';

class DownloadScreen extends StatefulWidget {
  const DownloadScreen({super.key});

  @override
  State<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen> {
  final _urlController = TextEditingController();
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _lastError;
  bool _hasCookies = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DownloadProvider>().addListener(_onProviderChange);
    });
    _loadCookieState();
  }

  Future<void> _loadCookieState() async {
    final c = await CookieService.getCookies();
    if (mounted) setState(() => _hasCookies = c != null && c.isNotEmpty);
  }

  void _onProviderChange() {
    if (!mounted) return;
    final provider = context.read<DownloadProvider>();
    if (provider.status == DownloadStatus.error && provider.errorMessage.isNotEmpty) {
      if (_lastError != provider.errorMessage) {
        _lastError = provider.errorMessage;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              provider.errorMessage,
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: const Color(0xFFEF5350),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } else if (provider.status != DownloadStatus.error) {
      _lastError = null;
    }
  }

  @override
  void dispose() {
    context.read<DownloadProvider>().removeListener(_onProviderChange);
    _urlController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _startDownload(DownloadProvider provider) {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    provider.downloadPlaylist(
      _urlController.text.trim(),
      _nameController.text.trim().isEmpty ? null : _nameController.text.trim(),
    );
  }

  Future<void> _showCookieSheet() async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _CookieSheet(),
    );
    if (updated == true) {
      _loadCookieState();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DownloadProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: PlayOnTheme.bgDeep,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),

                  if (!provider.isActive && provider.status != DownloadStatus.done) ...[
                    _buildForm(provider),
                  ] else if (provider.isActive) ...[
                    _buildDownloadingState(provider),
                  ] else if (provider.status == DownloadStatus.done) ...[
                    _buildDoneState(provider),
                  ],

                  if (provider.status == DownloadStatus.error) ...[
                    const SizedBox(height: 20),
                    _buildErrorCard(provider),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.asset(
                'assets/icons/logo.png',
                width: 44,
                height: 44,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Download',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontSize: 26),
                  ),
                  const Text(
                    'YouTube Music & Video → tu biblioteca',
                    style: TextStyle(color: PlayOnTheme.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            // Botón de sesión de YouTube
            GestureDetector(
              onTap: _showCookieSheet,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _hasCookies
                      ? const Color(0xFF1B3A2A)
                      : PlayOnTheme.bgSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _hasCookies
                        ? const Color(0xFF4CAF50)
                        : PlayOnTheme.divider,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _hasCookies ? Icons.verified_user_rounded : Icons.no_accounts_rounded,
                      size: 13,
                      color: _hasCookies ? const Color(0xFF4CAF50) : PlayOnTheme.textSecondary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _hasCookies ? 'Sesión activa' : 'Sin sesión',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _hasCookies ? const Color(0xFF4CAF50) : PlayOnTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0);
  }

  Widget _buildForm(DownloadProvider provider) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // URL field
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: _buildLabel('URL DE YOUTUBE MUSIC O YOUTUBE')),
              GestureDetector(
                onTap: () async {
                  final data = await Clipboard.getData(Clipboard.kTextPlain);
                  if (data != null && data.text != null && data.text!.isNotEmpty) {
                    var cleaned = data.text!.trim();
                    // Limpiar parámetros de tracking si los hay
                    if (cleaned.contains('?si=') || cleaned.contains('&si=')) {
                      cleaned = cleaned.replaceAll(RegExp(r'[?&]si=[^&]+'), '');
                    }
                    if (cleaned.contains('&feature=')) {
                      cleaned = cleaned.replaceAll(RegExp(r'&feature=[^&]+'), '');
                    }
                    _urlController.text = cleaned;
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Row(
                            children: [
                              Icon(Icons.content_paste_rounded, color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Text('Enlace pegado y optimizado'),
                            ],
                          ),
                          backgroundColor: PlayOnTheme.purplePrimary,
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: PlayOnTheme.purplePrimary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: PlayOnTheme.purplePrimary.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.content_paste_rounded, size: 14, color: PlayOnTheme.purpleGlow),
                      SizedBox(width: 4),
                      Text(
                        'Pegar enlace',
                        style: TextStyle(
                          color: PlayOnTheme.purpleGlow,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _urlController,
            hint: 'https://music.youtube.com/playlist?list=...',
            icon: Icons.link_rounded,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Ingresa una URL';
              if (!v.contains('youtube') && !v.contains('youtu.be')) {
                return 'Debe ser una URL de YouTube o YouTube Music';
              }
              return null;
            },
          ),

          const SizedBox(height: 18),

          // Name field
          _buildLabel('NOMBRE DE CARPETA (OPCIONAL)'),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _nameController,
            hint: 'Ej: Favoritas 2026 (vacío = nombre de la playlist)',
            icon: Icons.folder_rounded,
            validator: null,
          ),

          const SizedBox(height: 24),

          // Info card
          _buildInfoCard(),

          const SizedBox(height: 24),

          // Download button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [PlayOnTheme.purplePrimary, PlayOnTheme.pinkAccent],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: PlayOnTheme.purplePrimary.withValues(alpha: 0.4),
                    blurRadius: 20,
                    spreadRadius: 1,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: provider.status == DownloadStatus.fetchingInfo
                    ? null
                    : () => _startDownload(provider),
                icon: provider.status == DownloadStatus.fetchingInfo
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.download_rounded, color: Colors.white),
                label: Text(
                  provider.status == DownloadStatus.fetchingInfo
                      ? 'Analizando enlace...'
                      : 'Descargar Música',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),

          // Recent downloads section
          if (provider.recentDownloads.isNotEmpty) ...[
            const SizedBox(height: 32),
            _buildLabel('DESCARGAS RECIENTES'),
            const SizedBox(height: 10),
            ...provider.recentDownloads.map((item) => _buildRecentDownloadTile(item)),
          ],
        ],
      ).animate().fadeIn(duration: 500.ms, delay: 100.ms).slideY(begin: 0.05, end: 0),
    );
  }

  Widget _buildRecentDownloadTile(RecentDownloadItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: PlayOnTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PlayOnTheme.divider),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: PlayOnTheme.bgSurface,
            borderRadius: BorderRadius.circular(10),
            gradient: PlayOnTheme.cyanGradient,
          ),
          child: const Icon(Icons.folder_special_rounded, color: Colors.white, size: 22),
        ),
        title: Text(
          item.folderName,
          style: const TextStyle(color: PlayOnTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${item.trackCount} canciones guardadas',
          style: const TextStyle(color: PlayOnTheme.textSecondary, fontSize: 12),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.play_circle_fill_rounded, color: PlayOnTheme.purpleGlow, size: 32),
          tooltip: 'Reproducir carpeta',
          onPressed: () {
            final musicProv = context.read<MusicProvider>();
            final songs = musicProv.allSongs.where((s) => s.folderName == item.folderName).toList();
            if (songs.isNotEmpty) {
              musicProv.playCustomQueue(songs, 0);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const NowPlayingScreen()));
            }
          },
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: PlayOnTheme.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      style: const TextStyle(color: PlayOnTheme.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: PlayOnTheme.textTertiary, fontSize: 13),
        prefixIcon: Icon(icon, color: PlayOnTheme.purpleDim, size: 20),
        filled: true,
        fillColor: PlayOnTheme.bgCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: PlayOnTheme.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: PlayOnTheme.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: PlayOnTheme.purplePrimary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFEF5350)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFEF5350), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PlayOnTheme.purplePrimary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PlayOnTheme.purplePrimary.withValues(alpha: 0.25)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome_rounded, color: PlayOnTheme.purpleGlow, size: 18),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Descarga con metadatos y carátulas',
                  style: TextStyle(
                    color: PlayOnTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'El motor extrae automáticamente artista, título y carátula en alta definición para tu biblioteca.',
                  style: TextStyle(color: PlayOnTheme.textSecondary, fontSize: 11.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadingState(DownloadProvider provider) {
    return Column(
      children: [
        // Waveform icon
        Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: PlayOnTheme.purplePrimary.withValues(alpha: 0.1),
                ),
              )
                  .animate(onPlay: (c) => c.repeat())
                  .scale(begin: const Offset(1, 1), end: const Offset(1.3, 1.3), duration: 900.ms)
                  .fadeOut(begin: 1, duration: 900.ms),
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [PlayOnTheme.purplePrimary, PlayOnTheme.pinkAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: PlayOnTheme.purplePrimary.withValues(alpha: 0.5),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: const Icon(Icons.downloading_rounded, color: Colors.white, size: 32),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Playlist name
        Text(
          provider.playlistName.isEmpty ? 'Analizando contenido...' : provider.playlistName,
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),

        const SizedBox(height: 6),

        // Track count
        Text(
          '${provider.downloaded} de ${provider.total} canciones',
          style: const TextStyle(color: PlayOnTheme.purpleGlow, fontSize: 14, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 20),

        // Progress bar (Playlist)
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: provider.progress,
            backgroundColor: PlayOnTheme.bgSurface,
            valueColor: const AlwaysStoppedAnimation(PlayOnTheme.purplePrimary),
            minHeight: 6,
          ),
        ),

        const SizedBox(height: 14),

        // Current track
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            key: ValueKey(provider.currentTrack),
            provider.currentTrack.isEmpty ? 'Iniciando descarga...' : provider.currentTrack,
            style: const TextStyle(color: PlayOnTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),

        if (provider.statusMessage.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(PlayOnTheme.pinkAccent),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                provider.statusMessage,
                style: const TextStyle(
                  color: PlayOnTheme.textSecondary,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: 28),

        // Cancel button
        OutlinedButton.icon(
          onPressed: provider.cancel,
          icon: const Icon(Icons.stop_rounded, size: 18),
          label: const Text('Cancelar descarga'),
          style: OutlinedButton.styleFrom(
            foregroundColor: PlayOnTheme.textSecondary,
            side: const BorderSide(color: PlayOnTheme.divider),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
          ),
        ),

        if (provider.completedTracks.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildTrackList(provider),
        ],
      ],
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildDoneState(DownloadProvider provider) {
    final successful = provider.completedTracks.where((t) => t.success).length;
    final failed = provider.completedTracks.where((t) => !t.success).length;

    return Column(
      children: [
        // Success icon
        Center(
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF43A047), Color(0xFF66BB6A)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF43A047).withValues(alpha: 0.4),
                  blurRadius: 20,
                ),
              ],
            ),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 38),
          ).animate().scale(
                begin: const Offset(0.5, 0.5),
                end: const Offset(1, 1),
                curve: Curves.elasticOut,
                duration: 600.ms,
              ),
        ),

        const SizedBox(height: 20),

        Text(
          '¡Descarga finalizada!',
          style: Theme.of(context).textTheme.headlineMedium,
        ),

        const SizedBox(height: 6),

        Text(
          '$successful canciones descargadas${failed > 0 ? ' · $failed fallidas' : ''}',
          style: const TextStyle(color: PlayOnTheme.textSecondary, fontSize: 13.5),
        ),

        const SizedBox(height: 6),

        Text(
          provider.playlistName,
          style: const TextStyle(color: PlayOnTheme.purpleGlow, fontSize: 14, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 24),

        // Action buttons
        Row(
          children: [
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: PlayOnTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: PlayOnTheme.glowShadow(blur: 14),
                ),
                child: ElevatedButton.icon(
                  onPressed: () {
                    final musicProv = context.read<MusicProvider>();
                    final songs = musicProv.allSongs.where((s) => s.folderName == provider.playlistName).toList();
                    if (songs.isNotEmpty) {
                      musicProv.playCustomQueue(songs, 0);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const NowPlayingScreen()));
                    }
                  },
                  icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                  label: const Text(
                    'Reproducir',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  provider.reset();
                  _urlController.clear();
                  _nameController.clear();
                },
                icon: const Icon(Icons.add_rounded, color: PlayOnTheme.textPrimary),
                label: const Text('Nueva', style: TextStyle(color: PlayOnTheme.textPrimary, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: PlayOnTheme.divider),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),

        if (failed > 0) ...[
          const SizedBox(height: 12),
          // Banner de solución rápida si fallaron canciones
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1B2A3A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: PlayOnTheme.cyanAccent.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.shield_outlined, color: PlayOnTheme.cyanAccent, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '¿Canciones bloqueadas por YouTube?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Si YouTube solicita verificación ("Sign in to confirm you are not a bot"), inicia sesión una sola vez para desbloquear todas las descargas.',
                  style: TextStyle(color: PlayOnTheme.textSecondary, fontSize: 11.5),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const YoutubeLoginScreen()),
                      );
                      if (result == true && mounted) {
                        _loadCookieState();
                        provider.retryFailedTracks();
                      }
                    },
                    icon: const Icon(Icons.login_rounded, size: 16, color: Colors.white),
                    label: const Text(
                      'Iniciar sesión y reintentar',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PlayOnTheme.purplePrimary,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => provider.retryFailedTracks(),
              icon: const Icon(Icons.replay_rounded, color: PlayOnTheme.amberWarning, size: 18),
              label: Text('Reintentar canciones fallidas ($failed)', style: const TextStyle(color: PlayOnTheme.amberWarning)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: PlayOnTheme.amberWarning),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],

        const SizedBox(height: 24),

        _buildTrackList(provider),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildTrackList(DownloadProvider provider) {
    final tracks = provider.completedTracks;
    final animatedThreshold = tracks.length - 5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('DETALLE DE PISTAS'),
        const SizedBox(height: 10),
        ...tracks.indexed.map(
          (entry) => _TrackRow(
            track: entry.$2,
            animate: entry.$1 >= animatedThreshold,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorCard(DownloadProvider provider) {
    final isBotError = provider.errorMessage.contains('bot') ||
        provider.errorMessage.contains('Sign in') ||
        provider.errorMessage.contains('bloqueó');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEF5350).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEF5350).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Color(0xFFEF9A9A), size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  provider.errorMessage,
                  style: const TextStyle(color: Color(0xFFEF9A9A), fontSize: 13),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Color(0xFFEF9A9A), size: 20),
                onPressed: provider.reset,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          if (isBotError) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const YoutubeLoginScreen()),
                  );
                  if (result == true && mounted) {
                    _loadCookieState();
                  }
                },
                icon: const Icon(Icons.account_circle_rounded, size: 16, color: Colors.white),
                label: const Text(
                  'Iniciar sesión en YouTube para desbloquear',
                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B3A2A),
                  side: const BorderSide(color: Color(0xFF4CAF50)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TrackRow extends StatelessWidget {
  final DownloadedTrack track;
  final bool animate;

  const _TrackRow({required this.track, this.animate = true});

  @override
  Widget build(BuildContext context) {
    final child = Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: PlayOnTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PlayOnTheme.divider),
      ),
      child: Row(
        children: [
          Icon(
            track.success
                ? Icons.check_circle_rounded
                : Icons.error_outline_rounded,
            color: track.success
                ? const Color(0xFF66BB6A)
                : const Color(0xFFEF9A9A),
            size: 16,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
                  style: const TextStyle(
                    color: PlayOnTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  track.artist,
                  style: const TextStyle(
                      color: PlayOnTheme.textSecondary, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!track.success)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      (track.error != null && track.error!.trim().isNotEmpty)
                          ? track.error!.trim()
                          : 'Error al descargar pista',
                      style: const TextStyle(color: Color(0xFFEF9A9A), fontSize: 10.5),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    if (!animate) return child;

    return child
        .animate()
        .fadeIn(duration: 300.ms)
        .slideX(begin: 0.05, end: 0);
  }
}

class _CookieSheet extends StatefulWidget {
  const _CookieSheet();

  @override
  State<_CookieSheet> createState() => _CookieSheetState();
}

class _CookieSheetState extends State<_CookieSheet> {
  late final TextEditingController _controller;
  bool _showAdvanced = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _loadCookies();
  }

  Future<void> _loadCookies() async {
    final existing = await CookieService.getCookies();
    if (mounted && existing != null) {
      _controller.text = existing;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: PlayOnTheme.bgCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: PlayOnTheme.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B3A2A),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.verified_user_rounded, color: Color(0xFF4CAF50), size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sesión de YouTube',
                        style: TextStyle(
                          color: PlayOnTheme.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Evita bloqueos y descarga tus playlists',
                        style: TextStyle(color: PlayOnTheme.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Opción 1 (Recomendada): Iniciar sesión en navegador
            SizedBox(
              width: double.infinity,
              height: 52,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: PlayOnTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: PlayOnTheme.glowShadow(blur: 14),
                ),
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const YoutubeLoginScreen()),
                    );
                    if (result == true && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Sesión guardada correctamente'),
                          backgroundColor: Color(0xFF43A047),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.open_in_browser_rounded, color: Colors.white, size: 20),
                  label: const Text(
                    'Iniciar sesión en YouTube (Recomendado)',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Botón para borrar sesión si ya existe
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await CookieService.clearCookies();
                      if (context.mounted) Navigator.pop(context, true);
                    },
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    label: const Text('Cerrar / Borrar sesión', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: PlayOnTheme.textSecondary,
                      side: const BorderSide(color: PlayOnTheme.divider),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => setState(() => _showAdvanced = !_showAdvanced),
                  child: Text(
                    _showAdvanced ? 'Ocultar cookies' : 'Manual...',
                    style: const TextStyle(color: PlayOnTheme.textTertiary, fontSize: 11.5),
                  ),
                ),
              ],
            ),

            // Opción 2: Pegar cookies manuales (colapsable)
            if (_showAdvanced) ...[
              const SizedBox(height: 16),
              const Text(
                'Pegar cookies manualmente (Formato Netscape o Header):',
                style: TextStyle(color: PlayOnTheme.textSecondary, fontSize: 11.5, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _controller,
                maxLines: 3,
                style: const TextStyle(color: PlayOnTheme.textPrimary, fontSize: 11.5, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  hintText: 'VISITOR_INFO1_LIVE=...; YSC=...; SID=...',
                  hintStyle: const TextStyle(color: PlayOnTheme.textTertiary, fontSize: 11),
                  filled: true,
                  fillColor: PlayOnTheme.bgSurface,
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: PlayOnTheme.divider),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final text = _controller.text.trim();
                    await CookieService.saveCookies(text);
                    if (context.mounted) Navigator.pop(context, true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PlayOnTheme.bgSurface,
                    foregroundColor: PlayOnTheme.textPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: PlayOnTheme.divider),
                    ),
                  ),
                  child: const Text('Guardar texto manual'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
