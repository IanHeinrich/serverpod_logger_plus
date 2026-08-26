import 'package:serverpod/serverpod.dart';

/// Orders a [LogLevel] from least to most severe, so severities can be
/// compared without depending on the declaration order of Serverpod's enum.
///
/// If you add a case here, add the matching case to every severity mapping in
/// `lib/src/writers/`.
int logSeverityRank(LogLevel level) => switch (level) {
      LogLevel.debug => 0,
      LogLevel.info => 1,
      LogLevel.warning => 2,
      LogLevel.error => 3,
      LogLevel.fatal => 4,
    };
