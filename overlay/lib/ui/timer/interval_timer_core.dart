// Interval timer — CM Health feature. Data model, persistence and the band
// vibration cues.
//
// A profile is a named sequence of phases (work/rest, each with its own
// length) repeated for a number of rounds. On every phase transition the band
// buzzes — WHICH pattern is configurable per profile and per transition kind
// (work start / rest start / session end), e.g. "one long buzz" for GO and
// "three short buzzes" for REST.
//
// Buzz mechanics (see app_state.dart buzzSessionComplete for the background):
// rapid back-to-back runHapticsPattern frames re-trigger the band's haptic
// engine while it is still playing and merge into ONE longer sensation. We use
// that deliberately for the "long" cue; distinct short pulses need real gaps
// (>= ~350 ms) so they are felt as separate.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../state/app_state.dart';

// ── buzz cues ────────────────────────────────────────────────────────────────

enum BuzzCue { none, short1, short2, short3, long }

String buzzCueLabel(BuzzCue c) => switch (c) {
      BuzzCue.none => 'Keine Vibration',
      BuzzCue.short1 => '1× kurz',
      BuzzCue.short2 => '2× kurz',
      BuzzCue.short3 => '3× kurz',
      BuzzCue.long => 'Lang (ca. 2 s)',
    };

/// Fire a cue on the band. Best-effort: a disconnected band never breaks a
/// running timer — the on-screen countdown is the source of truth.
Future<void> playBuzzCue(AppState app, BuzzCue cue) async {
  if (cue == BuzzCue.none) return;
  Future<void> pulse() async {
    try {
      await app.testBuzzPattern(1);
    } catch (_) {/* not connected — screen still shows the change */}
  }

  switch (cue) {
    case BuzzCue.none:
      break;
    case BuzzCue.short1:
      await pulse();
    case BuzzCue.short2:
      await pulse();
      await Future<void>.delayed(const Duration(milliseconds: 900));
      await pulse();
    case BuzzCue.short3:
      for (var i = 0; i < 3; i++) {
        if (i > 0) await Future<void>.delayed(const Duration(milliseconds: 900));
        await pulse();
      }
    case BuzzCue.long:
      // Rapid frames merge into one continuous ~2 s sensation (see header).
      for (var i = 0; i < 5; i++) {
        await pulse();
        await Future<void>.delayed(const Duration(milliseconds: 120));
      }
  }
}

// ── model ────────────────────────────────────────────────────────────────────

enum PhaseKind { work, rest }

class IntervalPhase {
  String name;
  int seconds;
  PhaseKind kind;

  IntervalPhase({required this.name, required this.seconds, required this.kind});

  Map<String, dynamic> toJson() =>
      {'name': name, 'seconds': seconds, 'kind': kind.name};

  factory IntervalPhase.fromJson(Map<String, dynamic> j) => IntervalPhase(
        name: (j['name'] as String?) ?? '',
        seconds: (j['seconds'] as num?)?.toInt() ?? 30,
        kind: (j['kind'] == 'rest') ? PhaseKind.rest : PhaseKind.work,
      );
}

class IntervalProfile {
  String id;
  String name;
  List<IntervalPhase> phases;
  int rounds;
  BuzzCue workCue; // fired when a WORK phase starts
  BuzzCue restCue; // fired when a REST/pause phase starts
  BuzzCue endCue; // fired once when the whole session completes

  IntervalProfile({
    required this.id,
    required this.name,
    required this.phases,
    this.rounds = 1,
    this.workCue = BuzzCue.long,
    this.restCue = BuzzCue.short3,
    this.endCue = BuzzCue.short2,
  });

  int get totalSeconds =>
      rounds * phases.fold<int>(0, (a, p) => a + p.seconds);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phases': [for (final p in phases) p.toJson()],
        'rounds': rounds,
        'workCue': workCue.name,
        'restCue': restCue.name,
        'endCue': endCue.name,
      };

  factory IntervalProfile.fromJson(Map<String, dynamic> j) => IntervalProfile(
        id: (j['id'] as String?) ?? DateTime.now().microsecondsSinceEpoch.toString(),
        name: (j['name'] as String?) ?? 'Profil',
        phases: [
          for (final p in (j['phases'] as List? ?? const []))
            IntervalPhase.fromJson(Map<String, dynamic>.from(p as Map)),
        ],
        rounds: (j['rounds'] as num?)?.toInt() ?? 1,
        workCue: _cue(j['workCue'], BuzzCue.long),
        restCue: _cue(j['restCue'], BuzzCue.short3),
        endCue: _cue(j['endCue'], BuzzCue.short2),
      );

  static BuzzCue _cue(Object? name, BuzzCue fallback) =>
      BuzzCue.values.where((c) => c.name == name).firstOrNull ?? fallback;
}

// ── persistence ──────────────────────────────────────────────────────────────

class IntervalProfileStore {
  static const _key = 'cm_interval_profiles_v1';

  static Future<List<IntervalProfile>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return _seed();
    try {
      final list = jsonDecode(raw) as List;
      return [
        for (final e in list)
          IntervalProfile.fromJson(Map<String, dynamic>.from(e as Map)),
      ];
    } catch (_) {
      return _seed();
    }
  }

  static Future<void> save(List<IntervalProfile> profiles) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode([for (final p in profiles) p.toJson()]));
  }

  /// First-run example the user can edit or delete — shows the shape of a
  /// profile without forcing an empty state.
  static List<IntervalProfile> _seed() => [
        IntervalProfile(
          id: 'seed-hiit',
          name: 'HIIT 30/90',
          phases: [
            IntervalPhase(name: 'Sprint', seconds: 30, kind: PhaseKind.work),
            IntervalPhase(name: 'Pause', seconds: 90, kind: PhaseKind.rest),
          ],
          rounds: 8,
        ),
      ];
}

/// Compact one-line summary: "8 Runden · Sprint 30 s / Pause 90 s".
String profileSummary(IntervalProfile p) {
  final phases = p.phases
      .map((ph) => '${ph.name} ${_fmtSec(ph.seconds)}')
      .join(' / ');
  final r = p.rounds == 1 ? '1 Runde' : '${p.rounds} Runden';
  return '$r · $phases';
}

String _fmtSec(int s) {
  if (s % 60 == 0 && s >= 60) return '${s ~/ 60} min';
  return '$s s';
}

/// mm:ss for the runner.
String fmtClock(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}
