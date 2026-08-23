import 'package:flutter/services.dart';

class NativeEqualizerConfig {
  final int numBands;
  final int minLevel;
  final int maxLevel;
  final List<int> centerFreqs;
  final List<String> presets;
  final bool enabled;
  final int bassBoost;

  const NativeEqualizerConfig({
    required this.numBands,
    required this.minLevel,
    required this.maxLevel,
    required this.centerFreqs,
    required this.presets,
    required this.enabled,
    required this.bassBoost,
  });

  factory NativeEqualizerConfig.fromMap(Map<String, dynamic> map) {
    return NativeEqualizerConfig(
      numBands: map['numBands'] as int? ?? 0,
      minLevel: map['minLevel'] as int? ?? -1500,
      maxLevel: map['maxLevel'] as int? ?? 1500,
      centerFreqs: (map['centerFreqs'] as List?)?.map((e) => e as int).toList() ?? const [],
      presets: (map['presets'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      enabled: map['enabled'] as bool? ?? false,
      bassBoost: map['bassBoost'] as int? ?? 0,
    );
  }
}

class NativeEqualizerService {
  static const MethodChannel _channel = MethodChannel('com.playon.equalizer');

  static Future<NativeEqualizerConfig?> initEqualizer({int? audioSessionId}) async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'initEqualizer',
        audioSessionId != null ? {'audioSessionId': audioSessionId} : null,
      );
      if (res != null) {
        return NativeEqualizerConfig.fromMap(res);
      }
    } catch (_) {}
    return null;
  }

  static Future<bool> setEnabled(bool enabled) async {
    try {
      final res = await _channel.invokeMethod<bool>('setEnabled', {'enabled': enabled});
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> setBandLevel(int band, int level) async {
    try {
      final res = await _channel.invokeMethod<bool>('setBandLevel', {'band': band, 'level': level});
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> usePreset(int presetIndex) async {
    try {
      final res = await _channel.invokeMethod<bool>('usePreset', {'preset': presetIndex});
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> setBassBoost(int strength) async {
    try {
      final res = await _channel.invokeMethod<bool>('setBassBoost', {'strength': strength});
      return res ?? false;
    } catch (_) {
      return false;
    }
  }
}
