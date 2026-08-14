// Interval timer — profile list. CM Health feature.
//
// Entry point (Today app bar). Shows the saved interval profiles; tap to
// start, pencil to edit, plus to create a new one.

import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import '../../theme/tokens.dart';
import '../design/design.dart';
import '../kit/kit.dart';
import 'interval_timer_core.dart';
import 'interval_timer_edit_screen.dart';
import 'interval_timer_run_screen.dart';

class IntervalTimerScreen extends StatefulWidget {
  const IntervalTimerScreen({super.key});

  @override
  State<IntervalTimerScreen> createState() => _IntervalTimerScreenState();
}

class _IntervalTimerScreenState extends State<IntervalTimerScreen> {
  List<IntervalProfile>? _profiles;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await IntervalProfileStore.load();
    if (mounted) setState(() => _profiles = p);
  }

  Future<void> _persist() async {
    final p = _profiles;
    if (p != null) await IntervalProfileStore.save(p);
  }

  Future<void> _edit(IntervalProfile? profile) async {
    final list = _profiles ?? [];
    final result = await Navigator.of(context).push<EditResult>(
      MaterialPageRoute(
        builder: (_) => IntervalTimerEditScreen(profile: profile),
      ),
    );
    if (result == null) return;
    setState(() {
      if (result.deleted) {
        list.removeWhere((p) => p.id == result.profile.id);
      } else {
        final i = list.indexWhere((p) => p.id == result.profile.id);
        if (i >= 0) {
          list[i] = result.profile;
        } else {
          list.add(result.profile);
        }
      }
    });
    await _persist();
  }

  @override
  Widget build(BuildContext context) {
    final profiles = _profiles;
    return AppScaffold(
      title: 'Intervall-Timer',
      actions: [
        RoundIconButton(
          OsIcon.plus,
          onTap: () => _edit(null),
        ),
      ],
      body: profiles == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.fromLTRB(
                  Sp.screen, Sp.x2, Sp.screen, dsBottomGutter(context)),
              children: [
                if (profiles.isEmpty)
                  StateCard(
                    icon: OsIcon.hiit,
                    title: 'Noch keine Profile',
                    message:
                        'Lege mit + ein Intervall-Profil an — z. B. 8 Runden '
                        'à 30 s Sprint / 90 s Pause. Das Band vibriert bei '
                        'jedem Wechsel.',
                    actionLabel: 'Profil anlegen',
                    onAction: () => _edit(null),
                  )
                else
                  for (final p in profiles) ...[
                    SurfaceCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: Sp.x4, vertical: Sp.x2),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => IntervalTimerRunScreen(profile: p),
                        ),
                      ),
                      child: ListRow(
                        icon: OsIcon.hiit,
                        iconColor: AppColors.accent,
                        title: p.name,
                        subtitle: profileSummary(p),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            StatusChip(
                              fmtClock(p.totalSeconds),
                              tone: ChipTone.neutral,
                            ),
                            const SizedBox(width: Sp.x2),
                            RoundIconButton(
                              OsIcon.edit,
                              onTap: () => _edit(p),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: Sp.x2),
                  ],
                const SizedBox(height: Sp.x2),
                Text(
                  'Tippe auf ein Profil, um den Timer zu starten. Das Band '
                  'vibriert bei Intervallstart, Pause und am Ende — die '
                  'Vibrationsart stellst du im Profil ein.',
                  style: AppText.captionMuted,
                ),
              ],
            ),
    );
  }
}
