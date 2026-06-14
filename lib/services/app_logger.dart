import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Writes Flutter-side logs and uncaught errors to a file, so issues can be
/// inspected without a console attached.
///
/// Windows: %LOCALAPPDATA%\cramp4\flutter.log
/// Linux:   ~/.local/share/cramp4/flutter.log
class AppLogger {
  static IOSink? _sink;

  static String get _logDir {
    final sep = Platform.pathSeparator;
    if (Platform.isWindows) {
      final base = Platform.environment['LOCALAPPDATA'] ??
          '${Platform.environment['USERPROFILE'] ?? ''}${sep}AppData${sep}Local';
      return '$base${sep}cramp4';
    }
    final home = Platform.environment['HOME'] ?? '';
    return '$home$sep.local${sep}share${sep}cramp4';
  }

  static void init() {
    try {
      final dir = Directory(_logDir);
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final file = File('$_logDir${Platform.pathSeparator}flutter.log');
      _sink = file.openWrite(mode: FileMode.write);
      write('INFO', 'AppLogger', 'Log started at ${DateTime.now()}');
    } catch (_) {
      // Logging must never crash the app.
    }
  }

  static void write(String severity, String source, String message) {
    final ts = DateTime.now().toIso8601String().substring(11, 23);
    final line = '[$ts] [${severity.padRight(7)}] [$source] $message';
    _sink?.writeln(line);
    if (kDebugMode) debugPrint(line);
  }

  static void info(String source, String message) =>
      write('INFO', source, message);

  static void warn(String source, String message) =>
      write('WARN', source, message);

  static void error(String source, String message) =>
      write('ERROR', source, message);

  /// Installs global handlers so every uncaught Flutter/Dart error is logged.
  /// Pass the app entrypoint as [body]; it runs inside a guarded zone.
  static void runGuarded(void Function() body) {
    FlutterError.onError = (details) {
      write('ERROR', 'FlutterError',
          '${details.exceptionAsString()}\n${details.stack}');
      FlutterError.presentError(details);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      write('ERROR', 'PlatformDispatcher', '$error\n$stack');
      return true;
    };

    runZonedGuarded(body, (error, stack) {
      write('ERROR', 'Zone', '$error\n$stack');
    });
  }

  static Future<void> close() async {
    await _sink?.flush();
    await _sink?.close();
    _sink = null;
  }
}
