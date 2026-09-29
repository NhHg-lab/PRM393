import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_project/app.dart';
import 'package:runner_project/config/asset_paths.dart';
import 'package:runner_project/config/game_config.dart';
import 'package:runner_project/controllers/game_controller.dart';
import 'package:runner_project/controllers/race_controller.dart';
import 'package:runner_project/models/runner.dart';
import 'package:runner_project/screens/betting_screen.dart';
import 'package:runner_project/screens/home_screen.dart';
import 'package:runner_project/screens/login_screen.dart';
import 'package:runner_project/screens/race_screen.dart';
import 'package:runner_project/screens/result_screen.dart';
import 'package:runner_project/screens/statistics_screen.dart';
import 'package:runner_project/services/audio_service.dart';
import 'package:runner_project/services/storage_service.dart';
import 'package:runner_project/widgets/runner_avatar.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<GameController> createGame() async {
  SharedPreferences.setMockInitialValues({
    'testingBalanceGrantVersion': GameConfig.testingBalanceGrantVersion,
  });
  final storage = StorageService();
  await storage.initialize();
  final game = GameController(storage: storage, audio: FakeAudioService());
  await game.initialize();
  return game;
}

Future<Duration> animationDuration(String assetPath) async {
  final data = await rootBundle.load(assetPath);
  final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
  var duration = Duration.zero;
  for (var frameIndex = 0; frameIndex < codec.frameCount; frameIndex++) {
    final frame = await codec.getNextFrame();
    duration += frame.duration;
    frame.image.dispose();
  }
  codec.dispose();
  return duration;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('login fits a 1920x1080 landscape screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(960, 540));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final game = await createGame();
    await tester.pumpWidget(
      GameScope(
        controller: game,
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('RUN BET'), findsOneWidget);
    expect(find.text('LOGIN'), findsOneWidget);
    expect(find.text('Demo: admin / 123456'), findsOneWidget);
    expect(find.byKey(const ValueKey('sound-volume-slider')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('all configured audio assets are bundled and non-empty', () async {
    const paths = [
      AssetPaths.menuMusic,
      AssetPaths.raceMusic,
      AssetPaths.clickSound,
      AssetPaths.countdownSound,
      AssetPaths.winSound,
      AssetPaths.loseSound,
    ];
    for (final path in paths) {
      final data = await rootBundle.load(path);
      expect(data.lengthInBytes, greaterThan(1000), reason: path);
    }
  });

  testWidgets('combined 3 2 1 GO sound plays once per race', (tester) async {
    SharedPreferences.setMockInitialValues({
      'testingBalanceGrantVersion': GameConfig.testingBalanceGrantVersion,
    });
    final storage = StorageService();
    await storage.initialize();
    final audio = RecordingAudioService();
    final game = GameController(storage: storage, audio: audio);
    await game.initialize();
    expect(game.placeBets({1: 100}), isNull);

    await tester.pumpWidget(
      GameScope(
        controller: game,
        child: const MaterialApp(home: RaceScreen()),
      ),
    );
    await tester.pump();

    expect(audio.musicPaths, [AssetPaths.countdownSound]);
    expect(audio.musicLoops, [false]);

    for (var frame = 0; frame < 50; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(audio.musicPaths, [AssetPaths.countdownSound]);

    for (var frame = 0; frame < 30; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump();

    expect(audio.musicPaths, [AssetPaths.countdownSound, AssetPaths.raceMusic]);
    expect(audio.musicLoops, [false, true]);
    expect(audio.musicVolumes, [
      GameConfig.countdownVolume,
      GameConfig.raceMusicVolume,
    ]);
    expect(audio.musicStartPositions, [
      GameConfig.countdownAudioStartOffset,
      Duration.zero,
    ]);
    expect(audio.events, [
      'stopEffects',
      'stopMusic',
      'music:${AssetPaths.countdownSound}:false',
      'stopMusic',
      'music:${AssetPaths.raceMusic}',
    ]);
    await tester.pumpWidget(const SizedBox.shrink());
    game.dispose();
  });

  testWidgets('visual countdown waits until countdown audio starts', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'testingBalanceGrantVersion': GameConfig.testingBalanceGrantVersion,
    });
    final storage = StorageService();
    await storage.initialize();
    final audio = BlockingCountdownAudioService();
    final game = GameController(storage: storage, audio: audio);
    await game.initialize();
    expect(game.placeBets({1: 100}), isNull);

    await tester.pumpWidget(
      GameScope(
        controller: game,
        child: const MaterialApp(home: RaceScreen()),
      ),
    );
    await tester.pump();

    expect(audio.countdownRequested.isCompleted, isTrue);
    expect(find.text('3'), findsNothing);
    audio.allowPlayback.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('3'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    game.dispose();
  });

  test('bet validation and settlement update balance exactly once', () async {
    final game = await createGame();

    expect(game.placeBets({}), isNotNull);
    expect(game.placeBets({999: 100}), isNotNull);
    expect(game.placeBets({1: 0}), isNotNull);
    expect(game.placeBets({1: 600, 2: 500}), isNotNull);
    expect(game.placeBets({1: 100, 2: 200}), isNull);
    expect(game.player.balance, 700);

    final ranking = GameConfig.runnerProfiles.map((profile) {
      return Runner(id: profile.id, name: profile.name, color: profile.color)
        ..rank = profile.id
        ..state = RunnerState.finished;
    }).toList();

    final firstResult = await game.settleRace(ranking);
    final secondResult = await game.settleRace(ranking);
    expect(firstResult.playerWon, isTrue);
    expect(firstResult.payout, 400);
    expect(firstResult.profit, 100);
    expect(game.player.balance, 1100);
    expect(game.player.totalRaces, 1);
    expect(identical(firstResult, secondResult), isTrue);
  });

  test('bankrupt player receives one persisted bailout after five minutes', () async {
    var now = DateTime(2026, 9, 29, 12);
    SharedPreferences.setMockInitialValues({
      'testingBalanceGrantVersion': GameConfig.testingBalanceGrantVersion,
      'balance': 50,
    });
    final storage = StorageService();
    await storage.initialize();
    final game = GameController(
      storage: storage,
      audio: FakeAudioService(),
      now: () => now,
    );
    await game.initialize();
    expect(game.placeBets({2: 50}), isNull);

    final ranking = GameConfig.runnerProfiles.map((profile) {
      return Runner(id: profile.id, name: profile.name, color: profile.color)
        ..rank = profile.id
        ..state = RunnerState.finished;
    }).toList();
    await game.settleRace(ranking);

    expect(game.player.balance, 0);
    expect(game.bailoutCountdownLabel, '5:00');
    expect(
      storage.loadBailoutAvailableAt(),
      now.add(GameConfig.bailoutDelay),
    );
    game.dispose();

    now = now.add(GameConfig.bailoutDelay);
    final restoredGame = GameController(
      storage: storage,
      audio: FakeAudioService(),
      now: () => now,
    );
    await restoredGame.initialize();
    expect(restoredGame.player.balance, GameConfig.bailoutAmount);
    expect(storage.loadBailoutAvailableAt(), isNull);
    restoredGame.dispose();
  });

  test('testing bankroll is granted once without resetting later balance', () async {
    SharedPreferences.setMockInitialValues({'balance': 150});
    final storage = StorageService();
    await storage.initialize();
    final firstLaunch = GameController(
      storage: storage,
      audio: FakeAudioService(),
    );
    await firstLaunch.initialize();
    expect(firstLaunch.player.balance, GameConfig.testingBalance);

    firstLaunch.player.balance = 9000;
    await storage.savePlayer(firstLaunch.player);
    firstLaunch.dispose();

    final secondLaunch = GameController(
      storage: storage,
      audio: FakeAudioService(),
    );
    await secondLaunch.initialize();
    expect(secondLaunch.player.balance, 9000);
    secondLaunch.dispose();
  });

  test('race finishes all runners and handles every obstacle once', () {
    final race = RaceController(random: Random(42));
    race.start();

    var ticks = 0;
    while (race.phase != RacePhase.complete && ticks < 5000) {
      race.update(1 / 60);
      ticks++;
    }

    expect(race.phase, RacePhase.complete);
    expect(race.ranking.length, 4);
    expect(race.ranking.map((runner) => runner.rank), [1, 2, 3, 4]);
    for (final runner in race.runners) {
      expect(runner.distance, GameConfig.raceLength);
      expect(runner.handledObstacleIds, {1, 2, 3});
      expect(runner.state, RunnerState.finished);
    }
    race.dispose();
  });

  test('fall sequence does not replay the procedural jump first', () {
    final race = RaceController(random: _ZeroRandom());
    race.start();

    var ticks = 0;
    final runner = race.runners.first;
    while (runner.handledObstacleIds.isEmpty && ticks < 5000) {
      race.update(1 / 60);
      ticks++;
    }

    expect(runner.handledObstacleIds, isNotEmpty);
    expect(runner.state, RunnerState.falling);
    expect(runner.jumpHeight, 0);
    expect(runner.pendingObstacleOutcome, isNull);

    final fallStartDistance = runner.distance;
    var movingFrames = 0;
    var previousDistance = fallStartDistance;
    double? halfSecondDistance;
    while (runner.state == RunnerState.falling && ticks < 5000) {
      race.update(1 / 60);
      expect(runner.distance, greaterThanOrEqualTo(previousDistance));
      if (runner.distance > previousDistance) movingFrames++;
      if (halfSecondDistance == null && runner.stateElapsed >= 0.5) {
        halfSecondDistance = runner.distance;
      }
      previousDistance = runner.distance;
      ticks++;
    }

    expect(runner.state, RunnerState.recovering);
    expect(
      runner.distance,
      closeTo(fallStartDistance + GameConfig.fallTravelDistance, 0.01),
    );
    expect(halfSecondDistance, isNotNull);
    expect(halfSecondDistance! - fallStartDistance, greaterThan(35));
    expect(movingFrames, greaterThan(10));

    while (runner.state == RunnerState.recovering && ticks < 5000) {
      race.update(1 / 60);
      expect(runner.state, isNot(RunnerState.falling));
      ticks++;
    }
    expect(runner.state, RunnerState.running);
    race.dispose();
  });

  test(
    'multi-bet outcome uses net profit for win loss and break even',
    () async {
      final profiles = GameConfig.runnerProfiles;
      List<Runner> rankingWithWinner(int winnerId) {
        final ids = [
          winnerId,
          ...profiles
              .map((profile) => profile.id)
              .where((id) => id != winnerId),
        ];
        return [
          for (var index = 0; index < ids.length; index++)
            Runner(
                id: ids[index],
                name: profiles
                    .firstWhere((profile) => profile.id == ids[index])
                    .name,
                color: profiles
                    .firstWhere((profile) => profile.id == ids[index])
                    .color,
              )
              ..rank = index + 1
              ..state = RunnerState.finished,
        ];
      }

      final losingGame = await createGame();
      expect(losingGame.placeBets({1: 50, 2: 200}), isNull);
      final loss = await losingGame.settleRace(rankingWithWinner(1));
      expect(loss.profit, -50);
      expect(loss.playerLost, isTrue);

      final evenGame = await createGame();
      expect(evenGame.placeBets({1: 100, 2: 100, 3: 100, 4: 100}), isNull);
      final even = await evenGame.settleRace(rankingWithWinner(3));
      expect(even.profit, 0);
      expect(even.brokeEven, isTrue);
      expect(evenGame.player.draws, 1);
    },
  );

  testWidgets('race header does not overflow during narrow orientation frame', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final game = await createGame();
    expect(game.placeBets({1: 100, 2: 100}), isNull);

    await tester.pumpWidget(
      GameScope(
        controller: game,
        child: const MaterialApp(home: RaceScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    for (var lane = 1; lane <= 4; lane++) {
      for (var obstacleId = 1; obstacleId <= 3; obstacleId++) {
        expect(
          find.byKey(ValueKey('hurdle-$lane-$obstacleId')),
          findsOneWidget,
        );
      }
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('multi-bet cards fit a 1920x1080 landscape screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(960, 540));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final game = await createGame();

    await tester.pumpWidget(
      GameScope(
        controller: game,
        child: const MaterialApp(home: BettingScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Red Rocket'), findsOneWidget);
    expect(find.text('Blue Flash'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home panel fits a 1920x1080 landscape screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(960, 540));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final game = await createGame();

    await tester.pumpWidget(
      GameScope(
        controller: game,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('START GAME'), findsOneWidget);
    expect(find.text('CHOOSE YOUR ACTION'), findsOneWidget);
    expect(find.byKey(const ValueKey('sound-volume-slider')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'menu music stays in one session through login, home, stats and how-to',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(960, 540));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      SharedPreferences.setMockInitialValues({
        'testingBalanceGrantVersion': GameConfig.testingBalanceGrantVersion,
      });
      final storage = StorageService();
      await storage.initialize();
      final audio = RecordingAudioService();
      final game = GameController(storage: storage, audio: audio);
      await game.initialize();

      await tester.pumpWidget(
        GameScope(
          controller: game,
          child: const MaterialApp(home: LoginScreen()),
        ),
      );
      await tester.pump();

      expect(audio.musicPaths, [AssetPaths.menuMusic]);

      await tester.pumpWidget(
        GameScope(
          controller: game,
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      await tester.pump();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(audio.musicPaths, [AssetPaths.menuMusic]);
      expect(audio.events, isNot(contains('stopMusic')));

      await tester.pumpWidget(
        GameScope(
          controller: game,
          child: const MaterialApp(home: StatisticsScreen()),
        ),
      );
      await tester.pump();
      expect(find.byType(StatisticsScreen), findsOneWidget);
      expect(audio.musicPaths, [AssetPaths.menuMusic]);

      await tester.pumpWidget(
        GameScope(
          controller: game,
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('HOW TO PLAY'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('How to play'), findsOneWidget);
      expect(audio.musicPaths, [AssetPaths.menuMusic]);
      expect(audio.musicVolumes, [GameConfig.menuMusicVolume]);

      game.logout();
      expect(audio.events, isNot(contains('stopMusic')));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test('sound volume is adjustable and persisted', () async {
    SharedPreferences.setMockInitialValues({
      'testingBalanceGrantVersion': GameConfig.testingBalanceGrantVersion,
    });
    final storage = StorageService();
    await storage.initialize();
    final audio = FakeAudioService();
    final game = GameController(storage: storage, audio: audio);
    await game.initialize();

    expect(game.soundVolume, GameConfig.defaultSoundVolume);
    expect(audio.volume, GameConfig.defaultSoundVolume);

    await game.setSoundVolume(0.6);
    expect(game.soundEnabled, isTrue);
    expect(audio.enabled, isTrue);
    expect(audio.volume, 0.6);
    expect(storage.loadSoundVolume(), 0.6);

    await game.setSoundVolume(0);
    expect(game.soundEnabled, isFalse);
    expect(audio.enabled, isFalse);

    await game.toggleSound();
    expect(game.soundEnabled, isTrue);
    expect(game.soundVolume, GameConfig.defaultSoundVolume);
  });

  testWidgets('race track fits a 1920x1080 landscape screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(960, 540));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final game = await createGame();
    expect(game.placeBets({1: 100}), isNull);

    await tester.pumpWidget(
      GameScope(
        controller: game,
        child: const MaterialApp(home: RaceScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('HUMAN RACE'), findsOneWidget);
    expect(find.byKey(const ValueKey('hurdle-1-1')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('statistics fit a 1920x1080 landscape screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(960, 540));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final game = await createGame();

    await tester.pumpWidget(
      GameScope(
        controller: game,
        child: const MaterialApp(home: StatisticsScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('GAME SUMMARY'), findsOneWidget);
    expect(find.text('BACK'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all runner fall and recovery animations load', (tester) async {
    for (var runnerId = 1; runnerId <= 4; runnerId++) {
      for (final state in [RunnerState.falling, RunnerState.recovering]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RunnerAvatar(
                runnerId: runnerId,
                color: Colors.amber,
                state: state,
                size: 100,
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(Image), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('new fall animations cannot loop before their state ends', () async {
    final fallStateDuration = Duration(
      milliseconds: (GameConfig.fallDuration * 1000).ceil(),
    );
    final recoverStateDuration = Duration(
      milliseconds: (GameConfig.recoverDuration * 1000).ceil(),
    );

    for (final runnerId in [1, 2, 4]) {
      final media = AssetPaths.runners[runnerId - 1];
      expect(
        await animationDuration(media.fall),
        greaterThan(fallStateDuration),
        reason: 'Runner $runnerId fall GIF must not restart while falling',
      );
      expect(
        await animationDuration(media.recover),
        greaterThan(recoverStateDuration),
        reason: 'Runner $runnerId recovery GIF must not restart while recovering',
      );
    }
  });

  testWidgets('result summary and actions fit a 1920x1080 landscape screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(960, 540));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final game = await createGame();
    expect(game.placeBets({1: 100, 2: 100}), isNull);
    final ranking = GameConfig.runnerProfiles.map((profile) {
      return Runner(id: profile.id, name: profile.name, color: profile.color)
        ..rank = profile.id
        ..state = RunnerState.finished;
    }).toList();
    await game.settleRace(ranking);

    await tester.pumpWidget(
      GameScope(
        controller: game,
        child: const MaterialApp(home: ResultScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('PLAY AGAIN'), findsOneWidget);
    expect(find.text('SUMMARY'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class FakeAudioService implements AudioServiceBase {
  bool _enabled = true;
  double _volume = 1.0;

  @override
  bool get enabled => _enabled;

  @override
  double get volume => _volume;

  @override
  Future<void> prepareEffects(Iterable<String> paths) async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<void> playEffect(String path, {double volume = 0.75}) async {}

  @override
  Future<void> playMusic(
    String path, {
    double volume = 0.55,
    bool loop = true,
    Duration startPosition = Duration.zero,
  }) async {}

  @override
  Future<void> setEnabled(bool value) async => _enabled = value;

  @override
  Future<void> setVolume(double value) async {
    _volume = value.clamp(0.0, 1.0).toDouble();
  }

  @override
  Future<void> stopMusic() async {}

  @override
  Future<void> stopEffects() async {}
}

class RecordingAudioService extends FakeAudioService {
  final List<String> effectPaths = [];
  final List<double> effectVolumes = [];
  final List<String> musicPaths = [];
  final List<double> musicVolumes = [];
  final List<bool> musicLoops = [];
  final List<Duration> musicStartPositions = [];
  final List<String> events = [];
  String? _loopingMusicPath;

  @override
  Future<void> playEffect(String path, {double volume = 0.75}) async {
    effectPaths.add(path);
    effectVolumes.add(volume);
    events.add('effect:$path');
  }

  @override
  Future<void> playMusic(
    String path, {
    double volume = 0.55,
    bool loop = true,
    Duration startPosition = Duration.zero,
  }) async {
    if (loop && _loopingMusicPath == path) return;
    _loopingMusicPath = loop ? path : null;
    musicPaths.add(path);
    musicVolumes.add(volume);
    musicLoops.add(loop);
    musicStartPositions.add(startPosition);
    events.add(loop ? 'music:$path' : 'music:$path:false');
  }

  @override
  Future<void> stopEffects() async {
    events.add('stopEffects');
  }

  @override
  Future<void> stopMusic() async {
    _loopingMusicPath = null;
    events.add('stopMusic');
  }
}

class BlockingCountdownAudioService extends FakeAudioService {
  final Completer<void> countdownRequested = Completer<void>();
  final Completer<void> allowPlayback = Completer<void>();

  @override
  Future<void> playMusic(
    String path, {
    double volume = 0.55,
    bool loop = true,
    Duration startPosition = Duration.zero,
  }) async {
    if (path != AssetPaths.countdownSound) return;
    countdownRequested.complete();
    await allowPlayback.future;
  }
}

class _ZeroRandom implements Random {
  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;

  @override
  int nextInt(int max) => 0;
}
