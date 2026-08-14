// BandStatusCard — CM Health addition. A compact, always-visible status strip
// at the top of the Today dashboard showing the two "right now" facts about
// the band on the wrist: current heart rate (live BLE stream) and band
// battery. Complements — not replaces — the ambient LIVE HEART RATE tile on
// the Heart screen.
//
// Follows the project's honesty gates (see live_hr_tile.dart): never fabricate
// a number. "—" whenever the value is absent, stale, off-wrist or the band is
// disconnected. A 1 s ticker re-evaluates freshness so a frozen live value
// decays to "—" even when no new BLE frame arrives.

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
    // Freshness ticker: the staleness gate below depends on wall-clock time,
    // not only on incoming state — re-check once a second.
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
    // Rebuild only when the fields this card reads actually change.
    final snap =
        context.select<AppState, (int?, int?, double?, bool?, String)>((s) {
      final d = s.device;
      return (d.liveHr, d.liveHrAt, d.batteryPct, d.charging, d.connection);
    });
    final (hr, at, battery, charging, conn) = snap;

    final connected = conn == 'connected';
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final fresh = at != null && (nowMs - at) < _staleMs;
    final liveHr = connected && fresh && hr != null && hr > 0 ? hr : null;
    final batt = connected && battery != null ? battery.round() : null;

    final battLow = batt != null && batt <= 15 && charging != true;

    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: Sp.x4, vertical: Sp.x3),
      child: Row(
        children: [
          // ── live heart rate ──
          AppIcon(
            OsIcon.heartRate,
            size: 20,
            color: liveHr != null ? AppColors.accent : AppColors.onSurfaceFaint,
          ),
          const SizedBox(width: Sp.x2),
          Text(
            liveHr != null ? '$liveHr' : '—',
            style: AppText.h2.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: Sp.x1),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('bpm', style: AppText.captionMuted),
          ),
          const Spacer(),
          // ── band battery ──
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
            batt != null ? '$batt %${charging == true ? ' ⚡' : ''}' : '—',
            style: AppText.title.copyWith(
              color: battLow ? AppColors.bad : null,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (!connected) ...[
            const SizedBox(width: Sp.x3),
            StatusChip('nicht verbunden', tone: ChipTone.neutral),
          ],
        ],
      ),
    );
  }
}
