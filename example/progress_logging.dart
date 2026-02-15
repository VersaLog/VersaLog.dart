import 'dart:async';
import 'dart:math';
import 'package:versalog_dart/versalog_dart.dart';

final log = VersaLog(
  enumMode: "detailed",
  showTag: true,
  tag: ["BATCH"],
);

Future<void> processLine(int lineNumber) async {
  await Future.delayed(Duration(milliseconds: 100));

  if (Random().nextDouble() < 0.05) {
    log.warning("Line $lineNumber took longer than expected");
  }
}

Future<void> processFile(int fileIndex, int totalFiles) async {
  log.step("Processing file_$fileIndex.txt", fileIndex, totalFiles);

  await log.timer("file_$fileIndex.txt", () async {
    const totalLines = 20;

    for (int i = 1; i <= totalLines; i++) {
      await processLine(i);

      log.progress(
        "file_$fileIndex.txt",
        i,
        totalLines,
      );
    }
  });
}

Future<void> main() async {
  const totalFiles = 5;

  log.info("Batch Start");

  await log.timer("Total Batch", () async {
    for (int i = 1; i <= totalFiles; i++) {
      await processFile(i, totalFiles);

      log.progress(
        "Overall Progress",
        i,
        totalFiles,
      );
    }
  });

  log.info("Batch Finished");
}
