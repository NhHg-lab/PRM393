import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

abstract interface class AudioServiceBase {
  bool get enabled;
  double get volume;
  Future<void> prepareEffects(Iterable<String> paths);
  Future<void> setEnabled(bool value);
  Future<void> setVolume(double value);
  Future<void> playMusic(
    String path, {
    double volume = 0.55,
    bool loop = true,
    Duration startPosition = Duration.zero,
  });
  Future<void> playEffect(String path, {double volume = 0.75});
  Future<void> stopEffects();
  Future<void> stopMusic();
  Future<void> dispose();
}

class AudioService implements AudioServiceBase {
  AudioService() {
    _musicCompleteSubscription = _musicPlayer.onPlayerComplete.listen((_) {
      if (!_enabled || !_currentMusicLoops || _currentMusic.isEmpty) return;
      unawaited(_restartLoopingMusic());
    });
  }

  final AudioPlayer _musicPlayer = AudioPlayer();
  final AudioPlayer _effectPlayer = AudioPlayer();
  final AudioContext _effectAudioContext = AudioContext(
    android: const AudioContextAndroid(
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.game,
      // UI/game effects must mix with the menu track. Requesting the default
      // focus here pauses the music player every time a button is pressed.
      audioFocus: AndroidAudioFocus.none,
    ),
  );
  final Map<String, AudioPool> _effectPools = {};
  late final StreamSubscription<void> _musicCompleteSubscription;
  Future<void> _musicOperations = Future<void>.value();
  StopFunction? _activeEffectStop;
  bool _enabled = true;
  bool _loopRestartInProgress = false;
  double _volume = 1.0;
  String _currentMusic = '';
  double _currentMusicVolume = 0.55;
  bool _currentMusicLoops = false;

  @override
  bool get enabled => _enabled;

  @override
  double get volume => _volume;

  @override
  Future<void> prepareEffects(Iterable<String> paths) async {
    for (final path in paths.where((path) => path.isNotEmpty).toSet()) {
      if (_effectPools.containsKey(path)) continue;
      try {
        _effectPools[path] = await AudioPool.create(
          source: AssetSource(_normalize(path)),
          minPlayers: 1,
          maxPlayers: 1,
          audioContext: _effectAudioContext,
        );
      } catch (error) {
        debugPrint('Unable to preload sound asset "$path": $error');
      }
    }
  }

  @override
  Future<void> setEnabled(bool value) async {
    if (_enabled == value) return;
    _enabled = value;
    if (!value) {
      final stopEffect = _activeEffectStop;
      _activeEffectStop = null;
      await Future.wait([
        _enqueueMusic(() => _musicPlayer.stop()),
        _effectPlayer.stop(),
        if (stopEffect != null) stopEffect(),
      ]);
    } else if (_currentMusic.isNotEmpty) {
      final path = _currentMusic;
      final volume = _currentMusicVolume;
      _currentMusic = '';
      await playMusic(path, volume: volume);
    }
  }

  @override
  Future<void> setVolume(double value) async {
    _volume = value.clamp(0.0, 1.0).toDouble();
    if (_musicPlayer.state != PlayerState.playing &&
        _musicPlayer.state != PlayerState.paused) {
      return;
    }
    await _enqueueMusic(
      () => _musicPlayer.setVolume(_scaled(_currentMusicVolume)),
    );
  }

  @override
  Future<void> playMusic(
    String path, {
    double volume = 0.55,
    bool loop = true,
    Duration startPosition = Duration.zero,
  }) async {
    if (path.isEmpty) return;
    // A looping track represents one audio session. Routes may call this
    // method to make sure menu music exists, but must never restart the same
    // session merely because the widget tree changed or the native player is
    // briefly preparing between states. The completion listener/watchdog is
    // responsible for replaying the track only after it actually ends.
    if (loop && _currentMusicLoops && _currentMusic == path) {
      _currentMusicVolume = volume;
      return;
    }
    _currentMusic = loop ? path : '';
    _currentMusicVolume = volume;
    _currentMusicLoops = loop;
    if (!_enabled) return;
    await _enqueueMusic(() async {
      if (!_enabled) return;
      try {
        await _musicPlayer.stop();
        // Android Emulator API 37 can leave MediaPlayer paused when native
        // looping reaches the end of an MP3. Use stop mode and replay from
        // onPlayerComplete instead; this works consistently on emulator and
        // physical devices.
        await _musicPlayer.setReleaseMode(ReleaseMode.stop);
        await _musicPlayer.play(
          AssetSource(_normalize(path)),
          volume: _scaled(volume),
          position: startPosition == Duration.zero ? null : startPosition,
        );
      } catch (error) {
        debugPrint('Unable to play music asset "$path": $error');
      }
    });
  }

  @override
  Future<void> playEffect(String path, {double volume = 0.75}) async {
    if (!_enabled || path.isEmpty) return;
    try {
      final stopEffect = _activeEffectStop;
      _activeEffectStop = null;
      if (stopEffect != null) await stopEffect();
      final pool = _effectPools[path];
      if (pool != null) {
        _activeEffectStop = await pool.start(volume: _scaled(volume));
        return;
      }
      await _effectPlayer.setAudioContext(_effectAudioContext);
      await _effectPlayer.stop();
      await _effectPlayer.play(
        AssetSource(_normalize(path)),
        volume: _scaled(volume),
      );
    } catch (error) {
      debugPrint('Unable to play sound asset "$path": $error');
    }
  }

  @override
  Future<void> stopEffects() async {
    final stopEffect = _activeEffectStop;
    _activeEffectStop = null;
    await Future.wait([
      _effectPlayer.stop(),
      if (stopEffect != null) stopEffect(),
    ]);
  }

  @override
  Future<void> stopMusic() {
    _currentMusic = '';
    _currentMusicLoops = false;
    return _enqueueMusic(() => _musicPlayer.stop());
  }

  Future<void> _restartLoopingMusic() {
    if (_loopRestartInProgress) return Future<void>.value();
    _loopRestartInProgress = true;
    final path = _currentMusic;
    final volume = _currentMusicVolume;
    return _enqueueMusic(() async {
      if (!_enabled || !_currentMusicLoops || _currentMusic != path) return;
      try {
        await _musicPlayer.stop();
        await _musicPlayer.setReleaseMode(ReleaseMode.stop);
        await _musicPlayer.play(
          AssetSource(_normalize(path)),
          volume: _scaled(volume),
        );
      } catch (error) {
        debugPrint('Unable to restart looping music asset "$path": $error');
      }
    }).whenComplete(() => _loopRestartInProgress = false);
  }

  Future<void> _enqueueMusic(Future<void> Function() operation) {
    final next = _musicOperations.then((_) => operation());
    _musicOperations = next.catchError((Object error) {
      debugPrint('Unable to update music playback: $error');
    });
    return _musicOperations;
  }

  String _normalize(String path) =>
      path.startsWith('assets/') ? path.substring('assets/'.length) : path;

  double _scaled(double sourceVolume) =>
      (sourceVolume * _volume).clamp(0.0, 1.0).toDouble();

  @override
  Future<void> dispose() async {
    final stopEffect = _activeEffectStop;
    _activeEffectStop = null;
    await _musicCompleteSubscription.cancel();
    await _musicOperations;
    await Future.wait([
      if (stopEffect != null) stopEffect(),
      _musicPlayer.dispose(),
      _effectPlayer.dispose(),
      ..._effectPools.values.map((pool) => pool.dispose()),
    ]);
    _effectPools.clear();
  }
}
