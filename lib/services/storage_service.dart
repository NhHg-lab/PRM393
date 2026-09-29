import 'package:shared_preferences/shared_preferences.dart';

import '../config/game_config.dart';
import '../models/player.dart';

class StorageService {
  SharedPreferences? _preferences;

  Future<void> initialize() async {
    _preferences ??= await SharedPreferences.getInstance();
  }

  SharedPreferences get _prefs {
    final value = _preferences;
    if (value == null) {
      throw StateError('StorageService.initialize() must be called first.');
    }
    return value;
  }

  Player loadPlayer() {
    return Player(
      name: _prefs.getString('playerName') ?? 'Player',
      balance: _prefs.getInt('balance') ?? GameConfig.initialBalance,
      totalRaces: _prefs.getInt('totalRaces') ?? 0,
      wins: _prefs.getInt('wins') ?? 0,
      losses: _prefs.getInt('losses') ?? 0,
      draws: _prefs.getInt('draws') ?? 0,
      totalBet: _prefs.getInt('totalBet') ?? 0,
      totalPayout: _prefs.getInt('totalPayout') ?? 0,
      biggestWin: _prefs.getInt('biggestWin') ?? 0,
      lastWinner: _prefs.getString('lastWinner') ?? '',
    );
  }

  bool loadSoundEnabled() => _prefs.getBool('soundEnabled') ?? true;

  double loadSoundVolume() {
    final value =
        _prefs.getDouble('soundVolume') ?? GameConfig.defaultSoundVolume;
    return value.clamp(0.0, 1.0).toDouble();
  }

  DateTime? loadBailoutAvailableAt() {
    final milliseconds = _prefs.getInt('bailoutAvailableAt');
    return milliseconds == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(milliseconds);
  }

  Future<void> saveBailoutAvailableAt(DateTime value) =>
      _prefs.setInt('bailoutAvailableAt', value.millisecondsSinceEpoch);

  Future<void> clearBailoutAvailableAt() =>
      _prefs.remove('bailoutAvailableAt');

  Future<void> applyTestingBalanceGrant(Player player) async {
    final appliedVersion = _prefs.getInt('testingBalanceGrantVersion') ?? 0;
    if (appliedVersion >= GameConfig.testingBalanceGrantVersion) return;
    if (player.balance < GameConfig.testingBalance) {
      player.balance = GameConfig.testingBalance;
      await savePlayer(player);
    }
    await _prefs.setInt(
      'testingBalanceGrantVersion',
      GameConfig.testingBalanceGrantVersion,
    );
  }

  Future<void> savePlayer(Player player) async {
    await Future.wait([
      _prefs.setString('playerName', player.name),
      _prefs.setInt('balance', player.balance),
      _prefs.setInt('totalRaces', player.totalRaces),
      _prefs.setInt('wins', player.wins),
      _prefs.setInt('losses', player.losses),
      _prefs.setInt('draws', player.draws),
      _prefs.setInt('totalBet', player.totalBet),
      _prefs.setInt('totalPayout', player.totalPayout),
      _prefs.setInt('biggestWin', player.biggestWin),
      _prefs.setString('lastWinner', player.lastWinner),
    ]);
  }

  Future<void> saveSoundEnabled(bool enabled) =>
      _prefs.setBool('soundEnabled', enabled);

  Future<void> saveSoundVolume(double volume) =>
      _prefs.setDouble(
        'soundVolume',
        volume.clamp(0.0, 1.0).toDouble(),
      );
}
