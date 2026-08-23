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
  InAppWebViewController? webViewController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _extractAndSaveCookies() async {
    final cookieManager = CookieManager.instance();
    final cookies = await cookieManager.getCookies(url: WebUri("https://youtube.com"));
    
    if (cookies.isNotEmpty) {
      final cookieString = cookies.map((c) => '${c.name}=${c.value}').join('; ');
      await CookieService.saveCookies(cookieString);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sesión iniciada correctamente')),
        );
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PlayOnTheme.bgDeep,
      appBar: AppBar(
        backgroundColor: PlayOnTheme.bgDeep,
        elevation: 0,
        title: const Text('Iniciar sesión en YouTube', style: TextStyle(fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        actions: [
          TextButton(
            onPressed: _extractAndSaveCookies,
            child: const Text('Listo', style: TextStyle(color: PlayOnTheme.purplePrimary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Stack(
        children: [
          InAppWebView(
            key: webViewKey,
            initialUrlRequest: URLRequest(url: WebUri("https://accounts.google.com/ServiceLogin?service=youtube&continue=https://www.youtube.com/")),
            initialSettings: InAppWebViewSettings(
              useShouldOverrideUrlLoading: true,
              mediaPlaybackRequiresUserGesture: false,
              userAgent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            ),
            onWebViewCreated: (controller) {
              webViewController = controller;
            },
            onLoadStart: (controller, url) {
              setState(() {
                _isLoading = true;
              });
            },
            onLoadStop: (controller, url) async {
              setState(() {
                _isLoading = false;
              });
              
              if (url != null && url.toString().startsWith("https://www.youtube.com/")) {
                await _extractAndSaveCookies();
              }
            },
            onProgressChanged: (controller, progress) {
              if (progress == 100) {
                setState(() {
                  _isLoading = false;
                });
              }
            },
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: PlayOnTheme.purplePrimary),
            ),
        ],
      ),
    );
  }
}
