import 'package:versalog_dart/versalog_dart.dart';

void main() {
  final log = VersaLog(
    enumMode: "detailed",
    showFile: true,
    showTag: true,
    tag: ["APP"],
    allSave: true,
  );

  log.info("起動しました");
  log.error("エラー発生");
}
