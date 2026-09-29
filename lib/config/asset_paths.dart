import '../models/runner.dart';

/// Optional media assets. Empty paths use built-in Flutter fallbacks.
/// Put files in the declared asset folders, then update only this file.
abstract final class AssetPaths {
  static const String loginBackground =
      'assets/images/backgrounds/loginBackground.png';
  static const String homeBackground = 'assets/images/backgrounds/home.png';
  static const String homeRunner =
      'assets/images/backgrounds/runnerHomeTransparent.png';
  static const String bettingBackground =
      'assets/images/backgrounds/betting.png';
  static const String raceBackground = 'assets/images/backgrounds/race.png';
  static const String hurdle = 'assets/images/backgrounds/hangrao.png';
  static const String winBackground =
      'assets/images/backgrounds/winBackground.png';
  static const String loseBackground =
      'assets/images/backgrounds/loseBackground.png';

  // The supplied pack has no dedicated neutral/statistics art, so these
  // screens safely reuse the home stadium background.
  static const String breakEvenBackground = homeBackground;
  static const String statisticsBackground = homeBackground;

  /// GIF, animated WebP, or static PNG are supported.
  /// Fill the seven paths for each runner; blank state paths fall back to
  /// that runner's `run`, then `idle`, then the built-in Material icon.
  static const List<RunnerMedia> runners = [
    RunnerMedia(
      run: 'assets/images/runners/runner1.webp',
      fall: 'assets/images/runners/runner1_fall.gif',
      recover: 'assets/images/runners/runner1_recover.gif',
    ),
    RunnerMedia(
      run: 'assets/images/runners/runner2.webp',
      fall: 'assets/images/runners/runner2_fall.gif',
      recover: 'assets/images/runners/runner2_recover.gif',
    ),
    RunnerMedia(
      run: 'assets/images/runners/runner3.webp',
      fall: 'assets/images/runners/runner3_fall.webp',
      recover: 'assets/images/runners/runner3_recover.webp',
    ),
    RunnerMedia(
      run: 'assets/images/runners/runner4.webp',
      fall: 'assets/images/runners/runner4_fall.gif',
      recover: 'assets/images/runners/runner4_recover.gif',
    ),
  ];

  static const String menuMusic = 'assets/sounds/menu_background.mp3';
  static const String raceMusic = 'assets/sounds/race_background.mp3';
  static const String clickSound = 'assets/sounds/click_button.mp3';
  // One combined clip containing 3, 2, 1 and GO. Play exactly once when the
  // countdown begins; do not replay it for every displayed number.
  static const String countdownSound =
      'assets/sounds/countdown_321_go.mp3';
  static const String goSound = '';
  static const String jumpSound = '';
  static const String fallSound = '';
  static const String winSound = 'assets/sounds/win.mp3';
  static const String loseSound = 'assets/sounds/lose.mp3';
  static const String breakEvenSound = '';
}

class RunnerMedia {
  const RunnerMedia({
    this.idle = '',
    this.run = '',
    this.jump = '',
    this.stumble = '',
    this.fall = '',
    this.recover = '',
    this.finish = '',
  });

  final String idle;
  final String run;
  final String jump;
  final String stumble;
  final String fall;
  final String recover;
  final String finish;

  String forState(RunnerState state) {
    final statePath = switch (state) {
      RunnerState.idle => idle,
      RunnerState.running => run,
      RunnerState.jumping => jump,
      RunnerState.stumbling => stumble,
      RunnerState.falling => fall,
      RunnerState.recovering => recover,
      RunnerState.finished => finish,
    };
    if (statePath.isNotEmpty) return statePath;
    if (state == RunnerState.falling ||
        state == RunnerState.recovering ||
        state == RunnerState.finished) {
      return '';
    }
    if (run.isNotEmpty) return run;
    return idle;
  }
}
