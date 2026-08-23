import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AudioMetadataTags {
  final String title;
  final String artist;
  final String album;

  const AudioMetadataTags({
    required this.title,
    required this.artist,
    required this.album,
  });

  factory AudioMetadataTags.fromJson(String jsonString) {
    try {
      final Map<String, dynamic> map = jsonDecode(jsonString) as Map<String, dynamic>;
      return AudioMetadataTags(
        title: map['title']?.toString() ?? '',
        artist: map['artist']?.toString() ?? '',
        album: map['album']?.toString() ?? '',
      );
    } catch (_) {
      return const AudioMetadataTags(title: '', artist: '', album: '');
    }
  }
}

class NativeTagsService {
  static const MethodChannel _channel = MethodChannel('com.playon.tags');

  static Future<AudioMetadataTags?> getAudioTags(String path) async {
    try {
      final jsonStr = await _channel.invokeMethod<String>('getAudioTags', {'path': path});
      if (jsonStr != null && jsonStr.isNotEmpty) {
        return AudioMetadataTags.fromJson(jsonStr);
      }
    } catch (e) {
      debugPrint('NativeTagsService.getAudioTags error: $e');
    }
    return null;
  }

  static Future<bool> setAudioTags({
    required String path,
    required String title,
    required String artist,
    required String album,
  }) async {
    try {
      final res = await _channel.invokeMethod<bool>('setAudioTags', {
        'path': path,
        'title': title,
        'artist': artist,
        'album': album,
      });
      return res ?? false;
    } catch (e) {
      debugPrint('NativeTagsService.setAudioTags error: $e');
      rethrow;
    }
  }
}
