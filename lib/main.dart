import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';
import 'providers/equalizer_provider.dart';
import 'providers/music_provider.dart';
import 'providers/playlist_provider.dart';
import 'providers/download_provider.dart';
import 'screens/library_screen.dart';
import 'screens/download_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Background audio & notification controls.
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.playon.audio',
    androidNotificationChannelName: 'PlayOn Audio',
    androidShowNotificationBadge: true,
    androidNotificationIcon: 'drawable/ic_notification',
    androidStopForegroundOnPause: false,
    preloadArtwork: false,
  );

  // Force portrait orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Transparent status bar
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF07070D),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const PlayOnApp());
}

class PlayOnApp extends StatelessWidget {
  const PlayOnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MusicProvider()),
        ChangeNotifierProxyProvider<MusicProvider, EqualizerProvider>(
          create: (_) => EqualizerProvider(),
          update: (_, music, prev) {
            final eq = prev ?? EqualizerProvider();
            final sessionId = music.androidAudioSessionId;
            if (sessionId != null && sessionId > 0) {
              eq.init(audioSessionId: sessionId);
            }
            return eq;
          },
        ),
        ChangeNotifierProxyProvider<MusicProvider, PlaylistProvider>(
          create: (ctx) => PlaylistProvider(ctx.read<MusicProvider>()),
          update: (_, music, prev) => prev ?? PlaylistProvider(music),
        ),
        ChangeNotifierProxyProvider<MusicProvider, DownloadProvider>(
          create: (ctx) => DownloadProvider(ctx.read<MusicProvider>()),
          update: (_, music, prev) => prev ?? DownloadProvider(music),
        ),
      ],
      child: MaterialApp(
        title: 'PlayOn',
        theme: PlayOnTheme.theme,
        debugShowCheckedModeBanner: false,
        home: const _RootScaffold(),
      ),
    );
  }
}

class _RootScaffold extends StatefulWidget {
  const _RootScaffold();

  @override
  State<_RootScaffold> createState() => _RootScaffoldState();
}

class _RootScaffoldState extends State<_RootScaffold> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PlayOnTheme.bgDeep,
      extendBody: true,
      body: Stack(
        children: [
          _buildOffstageScreen(0, const LibraryScreen()),
          _buildOffstageScreen(1, const DownloadScreen()),
        ],
      ),
      bottomNavigationBar: _buildNavBar(),
    );
  }

  Widget _buildOffstageScreen(int index, Widget screen) {
    final active = _currentIndex == index;
    return Offstage(
      offstage: !active,
      child: TickerMode(
        enabled: active,
        child: screen,
      ),
    );
  }

  Widget _buildNavBar() {
    return RepaintBoundary(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: PlayOnTheme.bgCard.withValues(alpha: 0.8),
              border: const Border(
                top: BorderSide(color: PlayOnTheme.glassBorder, width: 1),
              ),
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (i) => setState(() => _currentIndex = i),
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: PlayOnTheme.purpleGlow,
              unselectedItemColor: PlayOnTheme.textTertiary,
              selectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: 0.2,
              ),
              unselectedLabelStyle: const TextStyle(fontSize: 11.5),
              type: BottomNavigationBarType.fixed,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.library_music_outlined),
                  activeIcon: Icon(Icons.library_music_rounded),
                  label: 'Biblioteca',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.download_outlined),
                  activeIcon: Icon(Icons.download_rounded),
                  label: 'Descargas',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
