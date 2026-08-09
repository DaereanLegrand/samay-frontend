import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

enum LogLevel {
  debug(0, 'DEBUG'),
  info(1, 'INFO'),
  warn(2, 'WARN'),
  error(3, 'ERROR'),
  emergency(4, 'EMERGENCY');

  const LogLevel(this.severity, this.label);

  final int severity;
  final String label;
}

/// Samay's logging/observability layer.
///
/// Singleton with 5 levels (debug/info/warn/error/emergency). `debug` and
/// `info` are compiled out in release mode. Entries are written synchronously
/// to `samay.log` in the app documents directory; `debugPrint` is kept only
/// as a fallback sink when file I/O is unavailable.
///
/// Crash markers (LOG-03): [markCrash] writes `.samay_crash_marker`;
/// [recoverCrashMarker] appends it to `samay_crash.log` and clears it on the
/// next launch. I-70 will wrap a Sentry SDK around this API.
class AppLogger {
  AppLogger({Directory? storageDir}) : _storageDir = storageDir;

  static AppLogger instance = AppLogger();

  static const logFileName = 'samay.log';
  static const markerFileName = '.samay_crash_marker';
  static const crashLogFileName = 'samay_crash.log';

  final Directory? _storageDir;
  Directory? _dir;

  /// Resolves the storage directory once. Tests inject [storageDir] via the
  /// constructor and never touch path_provider.
  Future<void> init({Directory? storageDir}) async {
    if (storageDir != null) {
      _dir = storageDir;
      return;
    }
    try {
      _dir = await getApplicationDocumentsDirectory();
    } catch (_) {
      _dir = null;
    }
  }

  static final _benignRules = <({LogLevel level, RegExp pattern})>[
    (level: LogLevel.info, pattern: RegExp(r'Cancelled')),
    (level: LogLevel.info, pattern: RegExp(r'Bad state: Future already completed')),
    (level: LogLevel.warn, pattern: RegExp(r'MissingPluginException')),
  ];

  /// Classifies known-benign errors (LOG-04). Returns the level the error
  /// should be logged at, or null when the error is genuinely reportable.
  LogLevel? knownBenignError(Object error) {
    final message = error.toString();
    for (final rule in _benignRules) {
      if (rule.pattern.hasMatch(message)) return rule.level;
    }
    return null;
  }

  void debug(String message, [String stack = '']) =>
      log(LogLevel.debug, message, stack);

  void info(String message, [String stack = '']) =>
      log(LogLevel.info, message, stack);

  void warn(String message, [String stack = '']) =>
      log(LogLevel.warn, message, stack);

  void error(String message, [String stack = '']) =>
      log(LogLevel.error, message, stack);

  void emergency(String message, [String stack = '']) =>
      log(LogLevel.emergency, message, stack);

  void log(LogLevel level, String message, [String stack = '']) {
    if (kReleaseMode && (level == LogLevel.debug || level == LogLevel.info)) {
      return;
    }
    final line =
        '[Samay][${level.label}] ${DateTime.now().toUtc().toIso8601String()} '
        '$message${stack.isNotEmpty ? '\n$stack' : ''}';
    final dir = _dir ?? _storageDir;
    if (dir == null) {
      debugPrint(line);
      return;
    }
    try {
      final file = File('${dir.path}/$logFileName');
      final raf = file.openSync(mode: FileMode.append);
      try {
        raf.writeStringSync('$line\n');
      } finally {
        raf.closeSync();
      }
    } catch (_) {
      debugPrint(line);
    }
  }

  /// Writes a crash marker file for detection on the next launch (LOG-03).
  Future<void> markCrash(String message, [String stack = '']) async {
    final dir = await _resolveDir();
    if (dir == null) return;
    final content =
        '[Samay][EMERGENCY] ${DateTime.now().toUtc().toIso8601String()} '
        '$message${stack.isNotEmpty ? '\n$stack' : ''}';
    try {
      await File('${dir.path}/$markerFileName').writeAsString(content,
          flush: true);
    } catch (_) {
      debugPrint('[Samay] markCrash failed to write marker: $message');
    }
  }

  Future<String?> readCrashMarker() async {
    final dir = await _resolveDir();
    if (dir == null) return null;
    try {
      final marker = File('${dir.path}/$markerFileName');
      if (!await marker.exists()) return null;
      return await marker.readAsString();
    } catch (_) {
      return null;
    }
  }

  Future<void> clearCrashMarker() async {
    final dir = await _resolveDir();
    if (dir == null) return;
    try {
      await File('${dir.path}/$markerFileName').delete();
    } catch (_) {
      // Marker already gone — nothing to clear.
    }
  }

  /// Startup recovery: appends the pending crash marker to `samay_crash.log`
  /// and clears it. Returns the recovered content, or null if no marker
  /// existed. Recovery UI (banner/dialog) is future work (LOG-03).
  Future<String?> recoverCrashMarker() async {
    final content = await readCrashMarker();
    if (content == null) return null;
    final dir = await _resolveDir();
    if (dir != null) {
      try {
        final file = File('${dir.path}/$crashLogFileName');
        final raf = await file.open(mode: FileMode.append);
        try {
          await raf.writeString('${content.trimRight()}\n');
        } finally {
          await raf.close();
        }
      } catch (_) {
        debugPrint('[Samay] recoverCrashMarker failed to append crash log: '
            '$content');
      }
    }
    await clearCrashMarker();
    return content;
  }

  Future<Directory?> _resolveDir() async {
    final dir = _dir ?? _storageDir;
    if (dir != null) return dir;
    await init();
    return _dir;
  }
}
