// BandStatusCard — CM Health addition. A compact, always-visible status strip
// at the top of the Today dashboard: current heart rate (live BLE stream) and
// band battery. Complements the ambient LIVE HEART RATE tile on the Heart
// screen.
//
// Honesty gates (see live_hr_tile.dart): never fabricate a number — "—"
// whenever the value is absent, stale, off-wrist or the band is disconnected.
// A 1 s ticker re-evaluates freshness so a frozen live value decays to "—".
//
// v2.0.1: deliberately DEFENSIVE. The v2.0.0 build of this card never showed
// up on device (invisible box where the card should be — an exception
// swallowed by the release-mode ErrorWidget is the prime suspect). This
// version (a) avoids the fancier constructs (record-select, Spacer,
// FontFeature), and (b) wraps its build in a catch that renders the error
// TEXT into the card, so a failure can never be invisible again.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.dart';
import '../design/design.dart';
import '../kit/kit.dart';

const _staleMs = 10000; // matches the Heart screen's live tile

class BandStatusCard extends StatefulWidget {
  const BandStatusCard({super.key});

  @override
  State<BandStatusCard> createState() => _BandStatusCardState();
}

class _BandStatusCardState extends State<BandStatusCard> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Freshness ticker: the staleness gate depends on wall-clock time, not
    // only on incoming state — re-check once a second.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    try {
      return _card(context);
    } catch (e) {
      // Self-diagnosing fallback: a build failure renders as readable text
      // instead of an invisible box (the v2.0.0 symptom).
      return SurfaceCard(
        padding: const EdgeInsets.symmetric(horizontal: Sp.x4, vertical: Sp.x3),
        child: Text(
          'Statuskachel-Fehler: $e',
          style: AppText.captionMuted,
        ),
      );
    }
  }

  Widget _card(BuildContext context) {
    // Plain watch — the Today screen around us already scopes its own
    // rebuilds; this card is cheap to rebuild.
    final app = context.watch<AppState>();
    final d = app.device;

    final connected = d.connection == 'connected';
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final at = d.liveHrAt;
    final fresh = at != null && (nowMs - at) < _staleMs;
    final hr = d.liveHr;
    final liveHr = connected && fresh && hr != null && hr > 0 ? hr : null;
    final battPct = d.batteryPct;
    final batt = connected && battPct != null ? battPct.round() : null;
    final charging = d.charging == true;
    final battLow = batt != null && batt <= 15 && !charging;

    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: Sp.x4, vertical: Sp.x3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ── live heart rate ──
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AppIcon(
                OsIcon.heartRate,
                size: 20,
                color: liveHr != null
                    ? AppColors.accent
                    : AppColors.onSurfaceFaint,
              ),
              const SizedBox(width: Sp.x2),
              Text(liveHr != null ? '$liveHr' : '—', style: AppText.h2),
              const SizedBox(width: Sp.x1),
              Text('bpm', style: AppText.captionMuted),
            ],
          ),
          // ── band battery / connection ──
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (!connected) ...[
                StatusChip('Band getrennt', tone: ChipTone.neutral),
                const SizedBox(width: Sp.x3),
              ] else if (battLow) ...[
                StatusChip('Band laden!', tone: ChipTone.critical),
                const SizedBox(width: Sp.x3),
              ],
              AppIcon(
                OsIcon.battery,
                size: 20,
                color: battLow
                    ? AppColors.bad
                    : (batt != null
                        ? AppColors.onSurfaceMuted
                        : AppColors.onSurfaceFaint),
              ),
              const SizedBox(width: Sp.x2),
              Text(
                batt != null ? '$batt %${charging ? ' ⚡' : ''}' : '—',
                style: AppText.title.copyWith(
                  color: battLow ? AppColors.bad : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
