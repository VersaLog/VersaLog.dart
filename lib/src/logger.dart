import 'dart:async';
import 'dart:io';

enum LogMode { simple, simple2, detailed, file }
enum LogLevel { info, error, warning, debug, critical }

class _LogItem {
  final String text;
  final LogLevel level;
  _LogItem(this.text, this.level);
}

class VersaLog {
  static const Map<LogLevel, String> colors = {
    LogLevel.info: '\x1B[32m',
    LogLevel.error: '\x1B[31m',
    LogLevel.warning: '\x1B[33m',
    LogLevel.debug: '\x1B[36m',
    LogLevel.critical: '\x1B[35m',
  };

  static const Map<LogLevel, String> symbols = {
    LogLevel.info: '[+]',
    LogLevel.error: '[-]',
    LogLevel.warning: '[!]',
    LogLevel.debug: '[D]',
    LogLevel.critical: '[C]',
  };

  static const String reset = '\x1B[0m';

  LogMode mode;
  bool showFile;
  bool showTag;
  bool notice;
  bool allSave;
  bool silent;
  bool catchExceptions;
  List<String>? tag;
  List<LogLevel> saveLevels;

  final StreamController<_LogItem> _queue =
      StreamController<_LogItem>.broadcast();

  DateTime? _lastCleanupDate;

  VersaLog({
    String enumMode = "simple",
    this.tag,
    this.showFile = false,
    this.showTag = false,
    bool enableAll = false,
    this.notice = false,
    this.allSave = false,
    List<String>? saveLevels,
    this.silent = false,
    this.catchExceptions = false,
  })  : mode = _parseMode(enumMode),
        saveLevels = _parseLevels(saveLevels) {
    if (enableAll) {
      showFile = true;
      showTag = true;
      notice = true;
      allSave = true;
    }

    _queue.stream.listen(_worker);

    if (catchExceptions) {
      runZonedGuarded(() {}, (e, st) {
        critical("Unhandled exception:\n$st");
      });
    }
  }

  static LogMode _parseMode(String m) {
    switch (m.toLowerCase()) {
      case "simple":
        return LogMode.simple;
      case "simple2":
        return LogMode.simple2;
      case "file":
        return LogMode.file;
      case "detailed":
        return LogMode.detailed;
      default:
        throw ArgumentError("Invalid enum '$m'");
    }
  }

  static List<LogLevel> _parseLevels(List<String>? levels) {
    if (levels == null) return LogLevel.values;

    return levels.map((e) {
      return LogLevel.values.firstWhere(
        (l) => l.name == e.toLowerCase(),
        orElse: () => throw ArgumentError("Invalid save level $e"),
      );
    }).toList();
  }

  String _getTime() =>
      DateTime.now().toString().substring(0, 19);

  String _getCaller() {
    final stack = StackTrace.current.toString().split("\n");
    if (stack.length < 4) return "";
    return stack[3].trim();
  }


  void _cleanupOldLogs({int days = 7}) {
    final dir = Directory('log');
    if (!dir.existsSync()) return;

    final now = DateTime.now();

    for (final entity in dir.listSync()) {
      if (entity is! File) continue;

      final diff = now.difference(entity.statSync().modified);

      if (diff.inDays >= days) {
        entity.deleteSync();
        if (!silent) {
          info("[LOG CLEANUP] removed: ${entity.path}");
        }
      }
    }
  }

  void _worker(_LogItem item) {
    if (!allSave) return;
    if (!saveLevels.contains(item.level)) return;

    final dir = Directory('log');
    if (!dir.existsSync()) dir.createSync();

    final file =
        File('log/${DateTime.now().toString().substring(0, 10)}.log');

    file.writeAsStringSync("${item.text}\n",
        mode: FileMode.append);

    final today = DateTime.now();

    if (_lastCleanupDate == null ||
        today.day != _lastCleanupDate!.day) {
      _cleanupOldLogs();
      _lastCleanupDate = today;
    }
  }

  void _log(String msg, LogLevel level, [Object? customTag]) {
    final color = colors[level] ?? "";
    final symbol = symbols[level] ?? "[?]";
    final typeStr = level.name.toUpperCase();

    List<String> tags = [];

    if (customTag != null) {
      if (customTag is List) {
        tags = customTag.map((e) => e.toString()).toList();
      } else {
        tags = [customTag.toString()];
      }
    } else if (showTag && tag != null) {
      tags = tag!;
    }

    final tagStr =
        tags.isNotEmpty ? tags.map((e) => "[$e]").join() : "";

    final caller =
        (showFile || mode == LogMode.file) ? _getCaller() : "";

    String formatted = "";
    String plain = "";

    switch (mode) {
      case LogMode.simple:
        formatted =
            "${caller.isNotEmpty ? "[$caller]" : ""}$tagStr$color$symbol$reset $msg";
        plain =
            "${caller.isNotEmpty ? "[$caller]" : ""}$tagStr$symbol $msg";
        break;

      case LogMode.simple2:
        final t = _getTime();
        formatted =
            "[$t] ${caller.isNotEmpty ? "[$caller]" : ""}$tagStr$color$symbol$reset $msg";
        plain =
            "[$t] ${caller.isNotEmpty ? "[$caller]" : ""}$tagStr$symbol $msg";
        break;

      case LogMode.file:
        formatted =
            "[${caller}]$tagStr$color[$typeStr]$reset $msg";
        plain =
            "[${caller}]$tagStr[$typeStr] $msg";
        break;

      case LogMode.detailed:
        final t = _getTime();
        formatted =
            "[$t]$color[$typeStr]$reset$tagStr${showFile ? "[$caller]" : ""} : $msg";
        plain =
            "[$t][$typeStr]$tagStr${showFile ? "[$caller]" : ""} : $msg";
        break;
    }

    if (!silent) print(formatted);

    _queue.add(_LogItem(plain, level));
  }

  void info(String m, [Object? t]) => _log(m, LogLevel.info, t);
  void error(String m, [Object? t]) => _log(m, LogLevel.error, t);
  void warning(String m, [Object? t]) => _log(m, LogLevel.warning, t);
  void debug(String m, [Object? t]) => _log(m, LogLevel.debug, t);
  void critical(String m, [Object? t]) =>
      _log(m, LogLevel.critical, t);

  void progress(String title, int current, int total,
      [Object? t]) {
    final percent =
        total > 0 ? ((current / total) * 100).floor() : 0;
    final msg = "$title : $percent% ($current/$total)";
    _log(msg, LogLevel.info, t);
  }

  void step(String title, int step, int total,
      [Object? t]) {
    final msg = "[STEP $step/$total] $title";
    _log(msg, LogLevel.info, t);
  }

  Future<T> timer<T>(
      String title, Future<T> Function() task,
      [Object? t]) async {
    final sw = Stopwatch()..start();

    _log("$title : start", LogLevel.info, t);

    try {
      return await task();
    } finally {
      sw.stop();
      final sec = (sw.elapsedMilliseconds / 1000)
          .toStringAsFixed(2);
      _log("$title : done (${sec}s)", LogLevel.info, t);
    }
  }

  void board() {
    if (!silent) {
      print(List.filled(45, "=").join());
    }
  }
}
