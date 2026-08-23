import 'package:flutter/services.dart';

class NativeNotificationService {
  static const MethodChannel _channel = MethodChannel('com.playon.download_notification');

  static Future<void> updateProgress({
    required String title,
    required String text,
    required int progress,
    required int max,
  }) async {
    try {
      await _channel.invokeMethod('updateProgress', {
        'title': title,
        'text': text,
        'progress': progress,
        'max': max,
      });
    } catch (_) {}
  }

  static Future<void> finishProgress({
    required String title,
    required String text,
  }) async {
    try {
      await _channel.invokeMethod('finishProgress', {
        'title': title,
        'text': text,
      });
    } catch (_) {}
  }

  static Future<void> cancelNotification() async {
    try {
      await _channel.invokeMethod('cancelNotification');
    } catch (_) {}
  }
}
