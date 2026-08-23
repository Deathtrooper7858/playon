import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/native_equalizer_service.dart';

class EqualizerProvider extends ChangeNotifier {
  bool _isAvailable = false;
  bool _enabled = false;
  int _numBands = 0;
  int _minLevel = -1500;
  int _maxLevel = 1500;
  List<int> _centerFreqs = [];
  List<String> _presets = [];
  List<int> _bandLevels = [];
  int _selectedPreset = -1; // -1 for custom
  int _bassBoost = 0; // 0 to 1000
  int? _currentAudioSessionId;

  bool get isAvailable => _isAvailable;
  bool get enabled => _enabled;
  int get numBands => _numBands;
  int get minLevel => _minLevel;
  int get maxLevel => _maxLevel;
  List<int> get centerFreqs => _centerFreqs;
  List<String> get presets => _presets;
  List<int> get bandLevels => _bandLevels;
  int get selectedPreset => _selectedPreset;
  int get bassBoost => _bassBoost;

  EqualizerProvider() {
    init();
  }

  Future<void> init({int? audioSessionId}) async {
    if (audioSessionId != null && audioSessionId == _currentAudioSessionId && _isAvailable) {
      return;
    }
    _currentAudioSessionId = audioSessionId;

    try {
      final config = await NativeEqualizerService.initEqualizer(audioSessionId: audioSessionId);
      if (config != null) {
        _isAvailable = true;
        _numBands = config.numBands;
        _minLevel = config.minLevel;
        _maxLevel = config.maxLevel;
        _centerFreqs = config.centerFreqs;
        _presets = config.presets;
        if (_bandLevels.length != _numBands) {
          _bandLevels = List.filled(_numBands, 0);
        }

        await _loadSavedState();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Equalizer not supported on this platform: $e');
      _isAvailable = false;
      notifyListeners();
    }
  }

  Future<void> _loadSavedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool('eq_enabled') ?? false;
      _bassBoost = prefs.getInt('eq_bass_boost') ?? 0;
      _selectedPreset = prefs.getInt('eq_preset') ?? -1;

      final savedLevels = prefs.getStringList('eq_bands');
      if (savedLevels != null && savedLevels.length == _numBands) {
        _bandLevels = savedLevels.map((e) => int.tryParse(e) ?? 0).toList();
      }

      await NativeEqualizerService.setEnabled(_enabled);
      await NativeEqualizerService.setBassBoost(_bassBoost);
      for (int i = 0; i < _bandLevels.length; i++) {
        await NativeEqualizerService.setBandLevel(i, _bandLevels[i]);
      }
    } catch (e) {
      debugPrint('Error loading EQ state: $e');
    }
  }

  Future<void> _saveState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('eq_enabled', _enabled);
      await prefs.setInt('eq_bass_boost', _bassBoost);
      await prefs.setInt('eq_preset', _selectedPreset);
      await prefs.setStringList('eq_bands', _bandLevels.map((e) => e.toString()).toList());
    } catch (e) {
      debugPrint('Error saving EQ state: $e');
    }
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    notifyListeners();
    try {
      await NativeEqualizerService.setEnabled(value);
      await _saveState();
    } catch (e) {
      debugPrint('Error setting EQ enabled: $e');
    }
  }

  Future<void> setBandLevel(int band, int level) async {
    if (band < 0 || band >= _bandLevels.length) return;
    _bandLevels[band] = level.clamp(_minLevel, _maxLevel);
    _selectedPreset = -1; // Switch to custom when manually changing a slider
    notifyListeners();
    try {
      await NativeEqualizerService.setBandLevel(band, _bandLevels[band]);
      await _saveState();
    } catch (e) {
      debugPrint('Error setting band level: $e');
    }
  }

  Future<void> usePreset(int presetIndex) async {
    if (presetIndex < 0 || presetIndex >= _presets.length) return;
    _selectedPreset = presetIndex;
    notifyListeners();
    try {
      await NativeEqualizerService.usePreset(presetIndex);
      await _saveState();
    } catch (e) {
      debugPrint('Error applying preset: $e');
    }
  }

  Future<void> setBassBoost(int strength) async {
    _bassBoost = strength.clamp(0, 1000);
    notifyListeners();
    try {
      await NativeEqualizerService.setBassBoost(_bassBoost);
      await _saveState();
    } catch (e) {
      debugPrint('Error setting bass boost: $e');
    }
  }

  String formatFrequency(int milliHz) {
    if (milliHz >= 1000000) {
      return '${(milliHz / 1000000).toStringAsFixed(1)} kHz';
    } else {
      return '${(milliHz / 1000).round()} Hz';
    }
  }
}
