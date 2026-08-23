import 'dart:convert';
import 'package:flutter/services.dart';

class YtDlpTrack {
  final String id;
  final String title;
  final String artist;
  final int duration;
  final String thumbnail;
  final String url;

  const YtDlpTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.duration,
    required this.thumbnail,
    required this.url,
  });

  factory YtDlpTrack.fromMap(Map<String, dynamic> map) {
    return YtDlpTrack(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      artist: map['artist']?.toString() ?? 'Artista desconocido',
      duration: map['duration'] as int? ?? 0,
      thumbnail: map['thumbnail']?.toString() ?? '',
      url: map['url']?.toString() ?? '',
    );
  }
}

class YtDlpPlaylistInfo {
  final String title;
  final List<YtDlpTrack> tracks;

  const YtDlpPlaylistInfo({
    required this.title,
    required this.tracks,
  });

  factory YtDlpPlaylistInfo.fromJson(String jsonString) {
    final Map<String, dynamic> map = jsonDecode(jsonString) as Map<String, dynamic>;
    if (map.containsKey('error')) {
      throw Exception(map['error']);
    }
    final rawTracks = (map['tracks'] as List?) ?? const [];
    final tracks = rawTracks.map((t) => YtDlpTrack.fromMap(t as Map<String, dynamic>)).toList();
    return YtDlpPlaylistInfo(
      title: map['title']?.toString() ?? 'Descarga',
      tracks: tracks,
    );
  }
}

class NativeYtDlpService {
  static const MethodChannel _channel = MethodChannel('com.playon.ytdlp');

  static Future<String> getAudioUrl(String url, {String? cookies}) async {
    final result = await _channel.invokeMethod<String>('getAudioUrl', {
      'url': url,
      'cookies': cookies ?? '',
    });
    if (result == null || result.startsWith('ERROR:')) {
      throw Exception(result ?? 'Error desconocido al obtener URL de audio');
    }
    return result;
  }

  static Future<YtDlpPlaylistInfo> getPlaylistInfo(String url, {String? cookies}) async {
    final result = await _channel.invokeMethod<String>('getPlaylistInfo', {
      'url': url,
      'cookies': cookies ?? '',
    });
    if (result == null || result.isEmpty) {
      throw Exception('No se recibió respuesta de yt-dlp');
    }
    return YtDlpPlaylistInfo.fromJson(result);
  }

  static Future<void> downloadAudio({
    required String url,
    required String outPath,
    String? title,
    String? artist,
    String? album,
    String? thumbnailUrl,
    String? cookies,
  }) async {
    final result = await _channel.invokeMethod<String>('downloadAudio', {
      'url': url,
      'outPath': outPath,
      'title': title ?? '',
      'artist': artist ?? '',
      'album': album ?? '',
      'thumbnailUrl': thumbnailUrl ?? '',
      'cookies': cookies ?? '',
    });
    if (result != 'SUCCESS') {
      throw Exception(result ?? 'Error desconocido durante la descarga');
    }
  }
}
