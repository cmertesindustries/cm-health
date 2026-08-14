// Interval timer — runner. CM Health feature.
//
// Full-screen countdown for a running interval profile. The phone clock is the
// source of truth; the band buzz is a best-effort cue on every phase change
// (see interval_timer_core.dart). The screen stays awake for the whole session
// (ScreenWake — same mechanism as live workouts).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../gps/screen_wake.dart';
import '../../state/app_state.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.dart';
import '../design/design.dart';
import '../kit/kit.dart';
import 'interval_timer_core.dart';

class IntervalTimerRunScreen extends StatefulWidget {
  final IntervalProfile profile;
  const IntervalTimerRunScreen({super.key, required this.profile});

  @override
  State<IntervalTimerRunScreen> createState() => _IntervalTimerRunScreenState();
}

class _IntervalTimerRunScreenState extends State<IntervalTimerRunScreen> {
  Timer? _tick;

  // Flattened schedule: one entry per phase occurrence over all rounds.
  late final List<({IntervalPhase phase, int round})> _steps;

  int _step = -1; // index into _steps; -1 = not started yet
  int _remainingMs = 0;
  bool _running = false;
  bool _done = false;
  DateTime? _phaseEndsAt;

  IntervalProfile get p => widget.profile;

  @override
  void initState() {
    super.initState();
    _steps = [
      for (var r = 1; r <= p.rounds; r++)
        for (final ph in p.phases) (phase: ph, round: r),
    ];
    ScreenWake.enable();
  }

  @override
  void dispose() {
    _tick?.cancel();
    ScreenWake.release();
    super.dispose();
  }

  void _start() {
    setState(() => _running = true);
    _advance(); // enters step 0 and fires its cue
    _tick = Timer.periodic(const Duration(milliseconds: 100), (_) => _onTick());
  }

  void _onTick() {
    if (!_running || _done) return;
    final ends = _phaseEndsAt;
    if (ends == null) return;
    final left = ends.difference(DateTime.now()).inMilliseconds;
    if (left <= 0) {
      _advance();
    } else {
      setState(() => _remainingMs = left);
    }
  }

  void _advance() {
    final app = context.read<AppState>();
    final next = _step + 1;
    if (next >= _steps.length) {
      // Session complete.
      _tick?.cancel();
      setState(() {
        _done = true;
        _running = false;
        _remainingMs = 0;
      });
      unawaited(playBuzzCue(app, p.endCue));
      unawaited(HapticFeedback.heavyImpact());
      return;
    }
    setState(() {
      _step = next;
      _phaseEndsAt = DateTime.now()
          .add(Duration(seconds: _steps[next].phase.seconds));
      _remainingMs = _steps[next].phase.seconds * 1000;
    });
    final cue = _steps[next].phase.kind == PhaseKind.work ? p.workCue : p.restCue;
    unawaited(playBuzzCue(app, cue));
    unawaited(HapticFeedback.mediumImpact());
  }

  void _pauseResume() {
    if (_done) return;
    setState(() {
      if (_running) {
        _running = false;
        // Freeze the remaining time; recompute the end on resume.
        _phaseEndsAt = null;
      } else {
        _running = true;
        _phaseEndsAt =
            DateTime.now().add(Duration(milliseconds: _remainingMs));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final connected = context.select<AppState, bool>((a) => a.isConnected);
    final started = _step >= 0;
    final current = started && !_done ? _steps[_step] : null;
    final nextStep =
        started && _step + 1 < _steps.length ? _steps[_step + 1] : null;
    final isWork = current?.phase.kind == PhaseKind.work;

    final secondsLeft = (_remainingMs / 1000).ceil();

    return AppScaffold(
      title: p.name,
      subtitle: connected ? null : 'Band nicht verbunden — nur Anzeige',
      body: Padding(
        padding: EdgeInsets.fromLTRB(
            Sp.screen, Sp.x4, Sp.screen, dsBottomGutter(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            if (_done) ...[
              Center(
                child: Column(children: [
                  const OsAppIcon(OsIcon.check, size: 64),
                  const SizedBox(height: Sp.x4),
                  Text('Geschafft!', style: AppText.display),
                  const SizedBox(height: Sp.x2),
                  Text(
                    '${p.rounds == 1 ? '1 Runde' : '${p.rounds} Runden'} · '
                    '${fmtClock(p.totalSeconds)}',
                    style: AppText.bodySoft,
                  ),
                ]),
              ),
            ] else if (!started) ...[
              Center(
                child: Column(children: [
                  Text(p.name, style: AppText.h1),
                  const SizedBox(height: Sp.x2),
                  Text(profileSummary(p), style: AppText.bodySoft),
                  const SizedBox(height: Sp.x2),
                  Text('Gesamt: ${fmtClock(p.totalSeconds)}',
                      style: AppText.captionMuted),
                ]),
              ),
            ] else ...[
              Center(
                child: Column(children: [
                  StatusChip(
                    'Runde ${current!.round} / ${p.rounds}',
                    tone: ChipTone.neutral,
                  ),
                  const SizedBox(height: Sp.x3),
                  Text(
                    current.phase.name.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: AppText.h1.copyWith(
                      color: isWork ? AppColors.accent : AppColors.onSurfaceMuted,
                    ),
                  ),
                  const SizedBox(height: Sp.x2),
                  Text(
                    fmtClock(secondsLeft),
                    style: AppText.hero.copyWith(
                      fontSize: 96,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: Sp.x3),
                  Text(
                    nextStep == null
                        ? 'Letzte Phase'
                        : 'Danach: ${nextStep.phase.name} '
                            '(${fmtClock(nextStep.phase.seconds)})',
                    style: AppText.captionMuted,
                  ),
                ]),
              ),
            ],
            const Spacer(),
            if (_done)
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Fertig'),
              )
            else if (!started)
              FilledButton(
                onPressed: _start,
                child: const Text('Start'),
              )
            else ...[
              FilledButton(
                onPressed: _pauseResume,
                child: Text(_running ? 'Pause' : 'Weiter'),
              ),
              const SizedBox(height: Sp.x2),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Abbrechen'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
