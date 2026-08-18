// CM Health Wecker (v2.1.0) — Wecker-Kachel auf "Heute".
//
// Zeigt den nächsten anstehenden Wecker ("Morgen 06:00 · Frühschicht");
// läuft gerade ein Wecker, wird die Kachel zur Stopp-Karte. Tippen öffnet
// die Weckerliste. Kein Wecker aktiv → Kachel bleibt komplett unsichtbar,
// damit "Heute" aufgeräumt bleibt.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.dart';
import '../../models/cm_alarm.dart';
import '../alarm/alarm_screen.dart';
import '../design/design.dart';
import '../kit/kit.dart';

class AlarmCard extends StatelessWidget {
  const AlarmCard({super.key});

  @override
  Widget build(BuildContext context) {
    try {
      final app = context.watch<AppState>();
      final engine = app.wakeEngine;
      final ringing = engine.ringing;

      if (ringing != null) {
        return SurfaceCard(
          padding: const EdgeInsets.all(Sp.x4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Wecker läuft: ${ringing.name}',
                  style: AppText.h2, textAlign: TextAlign.center),
              const SizedBox(height: Sp.x2),
              Text('Doppeltippe aufs Band oder drücke Stopp.',
                  style: AppText.captionMuted, textAlign: TextAlign.center),
              const SizedBox(height: Sp.x3),
              FilledButton(
                onPressed: () => engine.dismiss('Stopp-Knopf (Heute)'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.critical,
                  padding: const EdgeInsets.symmetric(vertical: Sp.x3),
                ),
                child: const Text('STOPP'),
              ),
            ],
          ),
        );
      }

      final next = engine.nextPlanned();
      if (next == null) return const SizedBox.shrink();
      final (alarm, at) = next;
      return SurfaceCard(
        padding:
            const EdgeInsets.symmetric(horizontal: Sp.x4, vertical: Sp.x2),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const AlarmScreen()),
        ),
        child: ListRow(
          icon: OsIcon.alarm,
          iconColor: AppColors.accent,
          title: 'Wecker · ${fmtNextOccurrence(at, DateTime.now())}',
          subtitle: alarm.name,
          trailing: StatusChip(
            weekdaysSummary(alarm.weekdays),
            tone: ChipTone.neutral,
          ),
        ),
      );
    } catch (e) {
      // Defensiv wie die BandStatusCard: ein Fehler wird sichtbar gemacht,
      // nie eine unsichtbare Lücke (Lehre aus v2.0.0).
      return Padding(
        padding: const EdgeInsets.all(Sp.x2),
        child: Text('Wecker-Kachel-Fehler: $e', style: AppText.captionMuted),
      );
    }
  }
}
