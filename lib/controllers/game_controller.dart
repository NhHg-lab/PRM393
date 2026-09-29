import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../config/asset_paths.dart';
import '../config/game_config.dart';
import '../models/bet.dart';
import '../models/player.dart';
import '../models/race_result.dart';
import '../models/runner.dart';
import '../services/audio_service.dart';
import '../services/storage_service.dart';

class GameController extends ChangeNotifier {
  GameController({
    required this.storage,
    required this.audio,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final StorageService storage;
  final AudioServiceBase audio;
  final DateTime Function() _now;
  Timer? _bailoutTimer;
  DateTime? _bailoutAvailableAt;
  bool _grantingBailout = false;

  late Player player;
  bool soundEnabled = true;
  double soundVolume = GameConfig.defaultSoundVolume;
  bool loggedIn = false;
  Bet? currentBet;
  RaceResult? currentResult;

  DateTime? get bailoutAvailableAt => _bailoutAvailableAt;

  Duration get bailoutRemaining {
    final availableAt = _bailoutAvailableAt;
    if (availableAt == null || player.balance > 0) return Duration.zero;
    final remaining = availableAt.difference(_now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  String get bailoutCountdownLabel {
    final seconds = (bailoutRemaining.inMilliseconds / 1000).ceil();
    final minutesPart = seconds ~/ 60;
    final secondsPart = seconds % 60;
    return '$minutesPart:${secondsPart.toString().padLeft(2, '0')}';
  }

  Future<void> initialize() async {
    player = storage.loadPlayer();
    await storage.applyTestingBalanceGrant(player);
    soundEnabled = storage.loadSoundEnabled();
    soundVolume = storage.loadSoundVolume();
    await audio.prepareEffects([
      AssetPaths.clickSound,
      AssetPaths.winSound,
      AssetPaths.loseSound,
    ]);
    await audio.setVolume(soundVolume);
    await audio.setEnabled(soundEnabled);
    _bailoutAvailableAt = storage.loadBailoutAvailableAt();
    await _syncBailoutState();
  }

  String? login(String username, String password) {
    final cleanUsername = username.trim();
    if (cleanUsername.isEmpty || password.isEmpty) {
      return 'Vui lòng nhập đầy đủ tài khoản và mật khẩu.';
    }
    if (cleanUsername != 'admin' || password != '123456') {
      return 'Tài khoản hoặc mật khẩu không chính xác.';
    }
    player.name = cleanUsername;
    loggedIn = true;
    storage.savePlayer(player);
    notifyListeners();
    return null;
  }

  void logout() {
    loggedIn = false;
    currentBet = null;
    currentResult = null;
    notifyListeners();
  }

  String? placeBets(Map<int, int> stakes) {
    if (currentBet != null) return 'Một lượt cược đang được xử lý.';
    if (stakes.isEmpty) return 'Bạn chưa chọn vận động viên.';
    final validIds = GameConfig.runnerProfiles
        .map((runner) => runner.id)
        .toSet();
    if (stakes.keys.any((runnerId) => !validIds.contains(runnerId))) {
      return 'Vận động viên không hợp lệ.';
    }
    if (stakes.values.any((amount) => amount <= 0)) {
      return 'Tiền cược của mỗi runner phải lớn hơn 0.';
    }
    final totalAmount = stakes.values.fold<int>(
      0,
      (total, amount) => total + amount,
    );
    if (totalAmount > player.balance) return 'Tổng tiền cược vượt quá số dư.';

    player.balance -= totalAmount;
    currentBet = Bet(stakes: stakes);
    currentResult = null;
    storage.savePlayer(player);
    notifyListeners();
    return null;
  }

  Future<RaceResult> settleRace(List<Runner> ranking) async {
    final bet = currentBet;
    if (bet == null) throw StateError('Cannot settle a race without a bet.');
    if (ranking.length != 4) throw StateError('Race ranking is incomplete.');
    if (bet.settled) {
      final result = currentResult;
      if (result == null) throw StateError('Settled bet has no result.');
      return result;
    }

    bet.settled = true;
    final winningStake = bet.amountFor(ranking.first.id);
    final payout = winningStake * GameConfig.winnerPayoutMultiplier;
    final profit = payout - bet.totalAmount;
    final won = profit > 0;
    player.balance += payout;
    player.totalRaces += 1;
    player.totalBet += bet.totalAmount;
    player.totalPayout += payout;
    player.lastWinner = ranking.first.name;
    if (won) {
      player.wins += 1;
      player.biggestWin = math.max(player.biggestWin, profit);
    } else if (profit < 0) {
      player.losses += 1;
    } else {
      player.draws += 1;
    }

    currentResult = RaceResult(
      ranking: List<Runner>.unmodifiable(ranking),
      stakes: bet.stakes,
      totalBetAmount: bet.totalAmount,
      winningStake: winningStake,
      playerWon: won,
      payout: payout,
      profit: profit,
      balanceAfter: player.balance,
    );
    await storage.savePlayer(player);
    await _syncBailoutState();
    notifyListeners();
    return currentResult!;
  }

  void prepareNextRound() {
    currentBet = null;
    currentResult = null;
    notifyListeners();
  }

  Future<void> toggleSound() async {
    soundEnabled = !soundEnabled;
    if (soundEnabled && soundVolume == 0) {
      soundVolume = GameConfig.defaultSoundVolume;
      await audio.setVolume(soundVolume);
      await storage.saveSoundVolume(soundVolume);
    }
    await audio.setEnabled(soundEnabled);
    await storage.saveSoundEnabled(soundEnabled);
    notifyListeners();
  }

  Future<void> setSoundVolume(double value) async {
    soundVolume = value.clamp(0.0, 1.0).toDouble();
    final shouldEnable = soundVolume > 0;
    soundEnabled = shouldEnable;
    await audio.setVolume(soundVolume);
    await audio.setEnabled(shouldEnable);
    await Future.wait([
      storage.saveSoundVolume(soundVolume),
      storage.saveSoundEnabled(soundEnabled),
    ]);
    notifyListeners();
  }

  /// Keeps one shared menu-music session alive across all non-race routes.
  /// AudioService ignores this request when the same session is already active.
  Future<void> ensureMenuMusic() => audio.playMusic(
    AssetPaths.menuMusic,
    volume: GameConfig.menuMusicVolume,
  );
  Future<void> playRaceMusic() =>
      audio.playMusic(AssetPaths.raceMusic, volume: GameConfig.raceMusicVolume);

  Future<void> playClick() =>
      audio.playEffect(AssetPaths.clickSound, volume: GameConfig.clickVolume);

  Future<void> _syncBailoutState() async {
    if (player.balance > 0) {
      _bailoutTimer?.cancel();
      _bailoutTimer = null;
      if (_bailoutAvailableAt != null) {
        _bailoutAvailableAt = null;
        await storage.clearBailoutAvailableAt();
      }
      return;
    }

    _bailoutAvailableAt ??= _now().add(GameConfig.bailoutDelay);
    await storage.saveBailoutAvailableAt(_bailoutAvailableAt!);
    if (!_now().isBefore(_bailoutAvailableAt!)) {
      await _grantBailout();
      return;
    }
    _startBailoutTimer();
  }

  void _startBailoutTimer() {
    if (_bailoutTimer?.isActive ?? false) return;
    _bailoutTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final availableAt = _bailoutAvailableAt;
      if (availableAt == null || player.balance > 0) {
        await _syncBailoutState();
        return;
      }
      if (!_now().isBefore(availableAt)) {
        await _grantBailout();
      } else {
        notifyListeners();
      }
    });
  }

  Future<void> _grantBailout() async {
    if (_grantingBailout || player.balance > 0) return;
    _grantingBailout = true;
    _bailoutTimer?.cancel();
    _bailoutTimer = null;
    player.balance += GameConfig.bailoutAmount;
    _bailoutAvailableAt = null;
    await Future.wait([
      storage.savePlayer(player),
      storage.clearBailoutAvailableAt(),
    ]);
    _grantingBailout = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _bailoutTimer?.cancel();
    super.dispose();
  }
}
