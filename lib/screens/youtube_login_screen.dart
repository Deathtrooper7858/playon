import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../services/cookie_service.dart';
import '../theme.dart';

class YoutubeLoginScreen extends StatefulWidget {
  const YoutubeLoginScreen({super.key});

  @override
  State<YoutubeLoginScreen> createState() => _YoutubeLoginScreenState();
}

class _YoutubeLoginScreenState extends State<YoutubeLoginScreen> {
  final GlobalKey webViewKey = GlobalKey();
  InAppWebViewController? _webViewController;
  bool _isLoading = true;
  int _cookieCount = 0;
  bool _hasDetectedSession = false;
  String _currentUrl = '';

  // URLs clave para extraer cookies
  static final List<WebUri> _cookieEndpoints = [
    WebUri("https://www.youtube.com"),
    WebUri("https://m.youtube.com"),
    WebUri("https://youtube.com"),
    WebUri("https://music.youtube.com"),
    WebUri("https://accounts.google.com"),
    WebUri("https://google.com"),
  ];

  @override
  void initState() {
    super.initState();
  }

  Future<String?> _collectAllCookies() async {
    final cookieManager = CookieManager.instance();
    final Map<String, String> allCookies = {};

    // 1. Obtener cookies desde CookieManager
    for (final endpoint in _cookieEndpoints) {
      try {
        final cookies = await cookieManager.getCookies(url: endpoint);
        for (final c in cookies) {
          if (c.name.isNotEmpty && c.value != null && c.value.toString().isNotEmpty) {
            allCookies[c.name] = c.value.toString();
          }
        }
      } catch (_) {}
    }

    // 2. Extraer cookies directamente desde el contexto de la página activa
    try {
      if (_webViewController != null) {
        final docCookies = await _webViewController!.evaluateJavascript(source: "document.cookie");
        if (docCookies != null && docCookies is String && docCookies.isNotEmpty) {
          for (final part in docCookies.split(';')) {
            final trimmed = part.trim();
            if (trimmed.contains('=')) {
              final idx = trimmed.indexOf('=');
              final name = trimmed.substring(0, idx).trim();
              final val = trimmed.substring(idx + 1).trim();
              if (name.isNotEmpty && val.isNotEmpty) {
                allCookies[name] = val;
              }
            }
          }
        }
      }
    } catch (_) {}

    if (allCookies.isEmpty) return null;
    return allCookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  Future<void> _checkSessionStatus() async {
    final cookieString = await _collectAllCookies();
    if (cookieString != null && cookieString.isNotEmpty) {
      final count = cookieString.split(';').length;
      final isValid = CookieService.hasValidSession(cookieString);
      if (mounted) {
        setState(() {
          _cookieCount = count;
          _hasDetectedSession = isValid;
        });
      }
    }
  }

  Future<void> _saveAndExit() async {
    final cookieString = await _collectAllCookies();
    if (cookieString == null || cookieString.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se detectaron cookies aún. Por favor inicia sesión primero.'),
            backgroundColor: Color(0xFFEF5350),
          ),
        );
      }
      return;
    }

    await CookieService.saveCookies(cookieString);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _hasDetectedSession
                      ? '¡Sesión de YouTube guardada exitosamente!'
                      : 'Cookies guardadas ($_cookieCount elementos)',
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF43A047),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop(true);
    }
  }

  void _navigateTo(String url) {
    _webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PlayOnTheme.bgDeep,
      appBar: AppBar(
        backgroundColor: PlayOnTheme.bgDeep,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Iniciar sesión en YouTube',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              _hasDetectedSession
                  ? '✓ Sesión detectada ($_cookieCount cookies)'
                  : (_cookieCount > 0
                      ? '$_cookieCount cookies encontradas'
                      : (_currentUrl.isNotEmpty
                          ? (Uri.tryParse(_currentUrl)?.host ?? 'Cargando...')
                          : 'Esperando credenciales...')),
              style: TextStyle(
                fontSize: 11,
                color: _hasDetectedSession ? const Color(0xFF4CAF50) : PlayOnTheme.textSecondary,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Recargar página',
            onPressed: () => _webViewController?.reload(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: ElevatedButton(
              onPressed: _saveAndExit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _hasDetectedSession ? const Color(0xFF43A047) : PlayOnTheme.purplePrimary,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text(
                'Guardar',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de accesos rápidos
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: PlayOnTheme.bgDeep,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.music_note_rounded, size: 16, color: PlayOnTheme.pinkAccent),
                    label: const Text('YouTube Music', style: TextStyle(fontSize: 11.5)),
                    backgroundColor: PlayOnTheme.bgCard,
                    side: const BorderSide(color: PlayOnTheme.divider),
                    onPressed: () => _navigateTo("https://music.youtube.com"),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(Icons.play_circle_fill_rounded, size: 16, color: Color(0xFFFF0000)),
                    label: const Text('YouTube Móvil', style: TextStyle(fontSize: 11.5)),
                    backgroundColor: PlayOnTheme.bgCard,
                    side: const BorderSide(color: PlayOnTheme.divider),
                    onPressed: () => _navigateTo("https://m.youtube.com"),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(Icons.account_circle, size: 16, color: PlayOnTheme.purpleGlow),
                    label: const Text('Acceder con Google', style: TextStyle(fontSize: 11.5)),
                    backgroundColor: PlayOnTheme.bgCard,
                    side: const BorderSide(color: PlayOnTheme.divider),
                    onPressed: () => _navigateTo("https://accounts.google.com/ServiceLogin?service=youtube&continue=https%3A%2F%2Fm.youtube.com%2F"),
                  ),
                ],
              ),
            ),
          ),

          // Banner de ayuda intuitivo
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: PlayOnTheme.bgCard,
            child: Row(
              children: [
                Icon(
                  _hasDetectedSession ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded,
                  size: 18,
                  color: _hasDetectedSession ? const Color(0xFF4CAF50) : PlayOnTheme.purpleGlow,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _hasDetectedSession
                        ? 'Tu cuenta está conectada. Pulsa "Guardar" para activar descargas sin límites.'
                        : 'Inicia sesión con tu cuenta. Cuando veas tu avatar o la página principal, pulsa "Guardar".',
                    style: const TextStyle(color: PlayOnTheme.textSecondary, fontSize: 11.5),
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            const LinearProgressIndicator(
              backgroundColor: PlayOnTheme.bgSurface,
              valueColor: AlwaysStoppedAnimation(PlayOnTheme.purplePrimary),
              minHeight: 2.5,
            ),
          Expanded(
            child: Stack(
              children: [
                InAppWebView(
                  key: webViewKey,
                  initialUrlRequest: URLRequest(
                    url: WebUri("https://m.youtube.com/"),
                  ),
                  initialSettings: InAppWebViewSettings(
                    useShouldOverrideUrlLoading: true,
                    mediaPlaybackRequiresUserGesture: false,
                    javaScriptEnabled: true,
                    domStorageEnabled: true,
                    thirdPartyCookiesEnabled: true,
                    cacheEnabled: true,
                    useHybridComposition: true,
                    transparentBackground: false,
                    userAgent: "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36",
                  ),
                  onWebViewCreated: (controller) {
                    _webViewController = controller;
                  },
                  onRenderProcessGone: (controller, detail) async {
                    debugPrint('WebView renderer crash recuperado: $detail');
                    await controller.reload();
                  },
                  onReceivedError: (controller, request, error) {
                    debugPrint('WebView error: ${error.description}');
                    setState(() {
                      _isLoading = false;
                    });
                  },
                  onLoadStart: (controller, url) {
                    setState(() {
                      _isLoading = true;
                      _currentUrl = url?.toString() ?? '';
                    });
                  },
                  onLoadStop: (controller, url) async {
                    setState(() {
                      _isLoading = false;
                      _currentUrl = url?.toString() ?? '';
                    });
                    await _checkSessionStatus();
                  },
                  onUpdateVisitedHistory: (controller, url, isReload) async {
                    _currentUrl = url?.toString() ?? '';
                    await _checkSessionStatus();
                  },
                  onProgressChanged: (controller, progress) {
                    if (progress == 100) {
                      setState(() {
                        _isLoading = false;
                      });
                    }
                  },
                ),
                if (_hasDetectedSession)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B3A2A),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF4CAF50), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.verified_user_rounded, color: Color(0xFF4CAF50), size: 24),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '¡Sesión detectada con éxito!',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  'Pulsa aquí para guardar y volver',
                                  style: TextStyle(color: Color(0xFFA5D6A7), fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: _saveAndExit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4CAF50),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text(
                              'Listo',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

