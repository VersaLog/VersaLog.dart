import 'package:versalog_dart/versalog_dart.dart';

void main() {

  // simple
  final logSimple = VersaLog(
    enumMode: "simple",
  );
  logSimple.info('Simple mode');

  // simple2
  final logSimple2 = VersaLog(
    enumMode: "simple2",
  );
  logSimple2.info('Simple2 mode');

  // detailed + tag
  final logDetailed = VersaLog(
    enumMode: "detailed",
    tag: ['APP', 'SYSTEM'],
    showTag: true,
  );
  logDetailed.info('Detailed mode');

  // file mode
  final logFile = VersaLog(
    enumMode: "file",
    showFile: true,
    allSave: true,
  );
  logFile.error('File mode error');
}
