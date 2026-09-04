// Diagnose-Export — CM Health addition (v2.0.1).
//
// One tap collects the app's internal state (connection, alarm confirmation
// machine, phone-step pipeline, db counts) plus the recent in-memory log and
// the persistent sync log file, writes a readable report, and hands both to
// the system share sheet — so a bug report is one screenshotless tap away.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../notify/notification_service.dart';
import '../../state/app_state.dart';
import '../../sync/file_log.dart';

Future<void> shareDiagnoseReport(
  BuildContext context,
  AppState app, {
  Rect? sharePositionOrigin,
}) async {
  final buf = StringBuffer();
  final now = DateTime.now();

  buf.writeln('CM Health — Diagnosebericht');
  buf.writeln('Erstellt: ${now.toIso8601String()}');
  try {
    final pkg = await PackageInfo.fromPlatform();
    buf.writeln('App: ${pkg.version}+${pkg.buildNumber} (${pkg.packageName})');
  } catch (_) {
    buf.writeln('App: Version unbekannt');
  }
  buf.writeln('Plattform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
  buf.writeln('');

  // ── Band / Verbindung ──
  final d = app.device;
  buf.writeln('── Band ──');
  buf.writeln('Verbindung: ${d.connection}');
  buf.writeln('Seriennummer: ${d.serial ?? '-'}');
  buf.writeln('Akku: ${d.batteryPct?.round() ?? '-'} %  (lädt: ${d.charging ?? '-'})');
  buf.writeln('Am Handgelenk: ${d.wristOn ?? '-'}');
  buf.writeln('Live-HF: ${d.liveHr ?? '-'} (Zeitstempel: ${d.liveHrAt ?? '-'})');
  buf.writeln('Standard-HR-Fallback: ${d.standardHrFallback}');
  buf.writeln('Auto-Reconnect pausiert: ${d.autoReconnectPaused}');
  buf.writeln('Uhr-Sync verloren: ${d.syncClockLost}');
  buf.writeln('Datenfenster Band: ${d.dataRangeOldest ?? '-'} .. ${d.dataRangeNewest ?? '-'}');
  buf.writeln('');

  // ── Wecker ──
  buf.writeln('── Wecker ──');
  final alarm = app.alarmEpoch;
  buf.writeln('Gestellt (Unix): ${alarm ?? '-'}'
      '${alarm != null ? ' = ${DateTime.fromMillisecondsSinceEpoch(alarm * 1000)}' : ''}');
  buf.writeln('Bestätigt: ${app.alarmConfirmed}');
  buf.writeln('Wartet auf Bestätigung: ${app.alarmPending}');
  buf.writeln('Unbestätigt (Warnzustand): ${app.alarmUnconfirmed}');
  buf.writeln('Letztes Alarm-Event: ${app.alarmLastEventId ?? '-'}');
  buf.writeln('Zuletzt ausgelöst: ${app.alarmFiredAt ?? '-'}');
  buf.writeln('');

  // ── Handy-Wecker (v2.1.2) ──
  buf.writeln('── Handy-Wecker ──');
  try {
    final we = app.wakeEngine;
    buf.writeln('Gespeicherte Wecker: ${we.alarms.length} '
        '(aktiv: ${we.alarms.where((a) => a.enabled).length})');
    final next = we.nextPlanned();
    buf.writeln('Nächste Auslösung: '
        '${next == null ? '-' : '${next.$2} (${next.$1.name})'}');
    buf.writeln('Läuft gerade: ${we.ringing?.name ?? '-'}');
  } catch (e) {
    buf.writeln('Wecker-Status-Fehler: $e');
  }
  try {
    buf.write(await NotificationService.instance.wakeDiagnostics());
  } catch (e) {
    buf.writeln('Notification-Diagnose-Fehler: $e');
  }
  buf.writeln('');

  // ── Schritte (Telefon-Pipeline) ──
  buf.writeln('── Schritte ──');
  buf.writeln('Telefon-Schritte aktiviert: ${app.phoneStepsEnabled}');
  buf.writeln('Letzter Sync: ${app.phoneStepsLastSyncedDays} Tag(e), '
      '${app.phoneStepsLastTotal} Schritte gelesen');
  buf.writeln('Heute (Telefon, gebankt): ${app.phoneStepsToday}');
  buf.writeln('Telefon besitzt den Tag: ${app.todayStepsFromPhone}');
  buf.writeln('Live-Schritte (Band): ${app.liveSteps}');
  buf.writeln('');

  // ── CM Health v2.3.0: Sync-Takt / HF-Modus / Log-Deckel ──
  buf.writeln('── Sync (v2.3.0) ──');
  try {
    buf.writeln('Abruftakt: ${app.syncIntervalMin} min');
    final cap = app.pipelineStatus['capture'] as Map<String, dynamic>?;
    if (cap != null) {
      for (final k in [
        'active', 'high_freq_requested', 'high_freq_reason',
        'history_requests', 'history_completions', 'records_seen',
        'gate_dropped_total', 'counter_regressions_total',
        'corrupt_data_ranges_total', 'strap_history_newest_ts',
      ]) {
        if (cap.containsKey(k)) buf.writeln('$k: ${cap[k]}');
      }
    }
    final der = app.pipelineStatus['derive'] as Map<String, dynamic>?;
    if (der != null) {
      buf.writeln('derive: running=${der['running']} '
          'offload_active=${der['offload_active']} '
          'pending_light=${der['pending_light']} '
          'pending_heavy=${der['pending_heavy']}');
    }
    buf.writeln('Letzter Datensatz (Band-Zeit): ${app.lastRecordAt ?? '-'}');
    buf.writeln('Ausführliches Protokoll: ${app.verboseLog}');
    buf.writeln('Logdatei: ${(await FileLog.sizeBytes()) ~/ 1024} KB, '
        'gedrosselte Zeilen seit Start: ${FileLog.droppedLines}');
  } catch (e) {
    buf.writeln('Sync-Status-Fehler: $e');
  }
  buf.writeln('');

  // ── Sync / Datenbank ──
  buf.writeln('── Daten ──');
  buf.writeln('Health-Connect-Sync aktiv: ${app.healthSyncEnabled}');
  buf.writeln('Synct gerade: ${app.syncingNow}');
  buf.writeln('Reanalyse läuft: ${app.reanalyzing} (${app.reanalyzeProgress})');
  app.dbCounts.forEach((k, v) => buf.writeln('db.$k: $v'));
  buf.writeln('');

  // ── Letzte App-Logzeilen (neueste zuerst) ──
  buf.writeln('── Log (letzte ${app.logLines.length} Zeilen, neueste zuerst) ──');
  for (final line in app.logLines) {
    buf.writeln(line);
  }

  final dir = await getTemporaryDirectory();
  final report = File(
      '${dir.path}/cm-health-diagnose-${now.millisecondsSinceEpoch}.txt');
  await report.writeAsString(buf.toString());

  final files = <XFile>[XFile(report.path)];
  // The persistent sync log survives app restarts — attach it when present.
  try {
    final syncLogPath = await FileLog.path();
    if (syncLogPath != null && await File(syncLogPath).exists()) {
      files.add(XFile(syncLogPath));
    }
  } catch (_) {}

  await Share.shareXFiles(
    files,
    text: 'CM Health Diagnosebericht',
    sharePositionOrigin: sharePositionOrigin,
  );
}
