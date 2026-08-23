import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NativeMediaScannerService {
  static const MethodChannel _channel = MethodChannel('com.playon.media_scanner');

  static Future<String?> scanFile(String path) async {
    try {
      final res = await _channel.invokeMethod<String>('scanFile', {'path': path});
      return res;
    } catch (e) {
      debugPrint('NativeMediaScannerService.scanFile error: $e');
      return null;
    }
  }
}
