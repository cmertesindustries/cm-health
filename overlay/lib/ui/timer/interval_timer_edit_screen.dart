// Interval timer — profile editor. CM Health feature.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.dart';
import '../design/design.dart';
import '../kit/kit.dart';
import 'interval_timer_core.dart';

class EditResult {
  final IntervalProfile profile;
  final bool deleted;
  EditResult(this.profile, {this.deleted = false});
}

class IntervalTimerEditScreen extends StatefulWidget {
  final IntervalProfile? profile; // null → create new
  const IntervalTimerEditScreen({super.key, this.profile});

  @override
  State<IntervalTimerEditScreen> createState() =>
      _IntervalTimerEditScreenState();
}

class _IntervalTimerEditScreenState extends State<IntervalTimerEditScreen> {
  late final TextEditingController _name;
  late List<IntervalPhase> _phases;
  late int _rounds;
  late BuzzCue _workCue;
  late BuzzCue _restCue;
  late BuzzCue _endCue;
  late final bool _isNew;
  late final String _id;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _isNew = p == null;
    _id = p?.id ?? DateTime.now().microsecondsSinceEpoch.toString();
    _name = TextEditingController(text: p?.name ?? '');
    _phases = [
      for (final ph in p?.phases ??
          [
            IntervalPhase(name: 'Intervall', seconds: 30, kind: PhaseKind.work),
            IntervalPhase(name: 'Pause', seconds: 60, kind: PhaseKind.rest),
          ])
        IntervalPhase(name: ph.name, seconds: ph.seconds, kind: ph.kind),
    ];
    _rounds = p?.rounds ?? 4;
    _workCue = p?.workCue ?? BuzzCue.long;
    _restCue = p?.restCue ?? BuzzCue.short3;
    _endCue = p?.endCue ?? BuzzCue.short2;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty || _phases.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Bitte Namen eingeben und mindestens eine Phase anlegen.')));
      return;
    }
    Navigator.of(context).pop(EditResult(IntervalProfile(
      id: _id,
      name: name,
      phases: _phases,
      rounds: _rounds,
      workCue: _workCue,
      restCue: _restCue,
      endCue: _endCue,
    )));
  }

  Future<void> _editPhase(int index) async {
    final ph = _phases[index];
    final nameCtrl = TextEditingController(text: ph.name);
    final minCtrl =
        TextEditingController(text: (ph.seconds ~/ 60).toString());
    final secCtrl =
        TextEditingController(text: (ph.seconds % 60).toString());
    var kind = ph.kind;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(R.card)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(Sp.x6, Sp.x4, Sp.x6,
              Sp.x6 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Phase bearbeiten', style: AppText.h2),
              const SizedBox(height: Sp.x4),
              TextField(
                controller: nameCtrl,
                maxLength: 24,
                autofocus: ph.name.isEmpty,
                decoration:
                    const InputDecoration(labelText: 'Name (z. B. Sprint)'),
              ),
              const SizedBox(height: Sp.x3),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: minCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Minuten'),
                    ),
                  ),
                  const SizedBox(width: Sp.x3),
                  Expanded(
                    child: TextField(
                      controller: secCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Sekunden'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Sp.x4),
              SegmentedControl(
                options: const ['Belastung', 'Pause'],
                index: kind == PhaseKind.work ? 0 : 1,
                expanded: true,
                onChanged: (i) => setSheet(
                    () => kind = i == 0 ? PhaseKind.work : PhaseKind.rest),
              ),
              const SizedBox(height: Sp.x4),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Übernehmen'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;
    final mins = int.tryParse(minCtrl.text.trim()) ?? 0;
    final secs = int.tryParse(secCtrl.text.trim()) ?? 0;
    final total = (mins * 60 + secs).clamp(1, 24 * 3600);
    setState(() {
      ph.name = nameCtrl.text.trim().isEmpty ? 'Phase' : nameCtrl.text.trim();
      ph.seconds = total;
      ph.kind = kind;
    });
  }

  Widget _cueRow(String title, String hint, BuzzCue value,
      ValueChanged<BuzzCue> onChanged) {
    final app = context.read<AppState>();
    return ListRow(
      icon: OsIcon.notifications,
      title: title,
      subtitle: hint,
      divider: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButton<BuzzCue>(
            value: value,
            underline: const SizedBox.shrink(),
            items: [
              for (final c in BuzzCue.values)
                DropdownMenuItem(value: c, child: Text(buzzCueLabel(c))),
            ],
            onChanged: (c) {
              if (c != null) onChanged(c);
            },
          ),
          const SizedBox(width: Sp.x1),
          // Feel it on the wrist before trusting it mid-workout.
          RoundIconButton(
            OsIcon.arrowRight,
            onTap: () => playBuzzCue(app, value),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _isNew ? 'Neues Profil' : 'Profil bearbeiten',
      children: [
        TextField(
          controller: _name,
          maxLength: 30,
          decoration: const InputDecoration(
            labelText: 'Profilname',
            hintText: 'z. B. HIIT 30/90',
          ),
        ),
        const SizedBox(height: Sp.x4),
        SectionHeader('Phasen'),
        const SizedBox(height: Sp.x2),
        SurfaceCard(
          padding: const EdgeInsets.symmetric(vertical: Sp.x1),
          child: Column(
            children: [
              for (var i = 0; i < _phases.length; i++)
                ListRow(
                  icon: _phases[i].kind == PhaseKind.work
                      ? OsIcon.intensity
                      : OsIcon.calm,
                  title: _phases[i].name,
                  subtitle: _phases[i].kind == PhaseKind.work
                      ? 'Belastung'
                      : 'Pause',
                  value: fmtClock(_phases[i].seconds),
                  divider: i < _phases.length - 1,
                  onTap: () => _editPhase(i),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (i > 0)
                        RoundIconButton(
                          OsIcon.up,
                          onTap: () => setState(() {
                            final p = _phases.removeAt(i);
                            _phases.insert(i - 1, p);
                          }),
                        ),
                      const SizedBox(width: Sp.x1),
                      RoundIconButton(
                        OsIcon.trash,
                        onTap: () => setState(() => _phases.removeAt(i)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: Sp.x2),
        OutlinedButton.icon(
          onPressed: () async {
            setState(() => _phases.add(IntervalPhase(
                name: '', seconds: 30, kind: PhaseKind.work)));
            await _editPhase(_phases.length - 1);
          },
          icon: const AppIcon(OsIcon.plus, size: 18),
          label: const Text('Phase hinzufügen'),
        ),
        const SizedBox(height: Sp.x4),
        SectionHeader('Runden'),
        const SizedBox(height: Sp.x2),
        SurfaceCard(
          padding:
              const EdgeInsets.symmetric(horizontal: Sp.x4, vertical: Sp.x2),
          child: Row(
            children: [
              Text('Wiederholungen', style: AppText.body),
              const Spacer(),
              RoundIconButton(
                OsIcon.down,
                onTap: () =>
                    setState(() => _rounds = (_rounds - 1).clamp(1, 99)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Sp.x3),
                child: Text('$_rounds', style: AppText.h2),
              ),
              RoundIconButton(
                OsIcon.up,
                onTap: () =>
                    setState(() => _rounds = (_rounds + 1).clamp(1, 99)),
              ),
            ],
          ),
        ),
        const SizedBox(height: Sp.x4),
        SectionHeader('Vibration am Band'),
        const SizedBox(height: Sp.x2),
        SurfaceCard(
          padding: const EdgeInsets.symmetric(vertical: Sp.x1),
          child: Column(
            children: [
              _cueRow('Intervallstart', 'Wenn eine Belastungsphase beginnt',
                  _workCue, (c) => setState(() => _workCue = c)),
              _cueRow('Pause', 'Wenn eine Pausenphase beginnt', _restCue,
                  (c) => setState(() => _restCue = c)),
              _cueRow('Ende', 'Wenn die letzte Runde vorbei ist', _endCue,
                  (c) => setState(() => _endCue = c)),
            ],
          ),
        ),
        const SizedBox(height: Sp.x2),
        Text(
          'Mit dem Pfeil-Knopf kannst du jede Vibrationsart sofort am Band '
          'testen (Band muss verbunden sein).',
          style: AppText.captionMuted,
        ),
        const SizedBox(height: Sp.x6),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _save,
            child: const Text('Speichern'),
          ),
        ),
        if (!_isNew) ...[
          const SizedBox(height: Sp.x2),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(EditResult(
                  IntervalProfile(id: _id, name: '', phases: []),
                  deleted: true)),
              child: const Text('Profil löschen'),
            ),
          ),
        ],
      ],
    );
  }
}
