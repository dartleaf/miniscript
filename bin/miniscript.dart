// Copyright © 2025 by the authors of the project. All rights reserved.

import 'dart:io';
import 'package:miniscript/miniscript_interpreter.dart';
import 'package:miniscript/miniscript_intrinsics/host_info.dart';
import 'package:miniscript/miniscript_unit_test.dart';

void main(List<String> args) {
  if (args.isNotEmpty) {
    if (args[0] == "--test") {
      HostInfo.name = "Test harness";

      if (args.length > 1 && args[1] == "--integration") {
        final file =
            args.length < 3 || args[2].isEmpty ? "./TestSuite.txt" : args[2];
        print("Running test suite.\n");
        runTestSuite(file);
        return;
      }

      print("Miniscript test harness.\n");
      print("Running unit tests.\n");
      UnitTest.run();

      print("\n");

      const String quickTestFilePath = "../QuickTest.ms";

      if (File(quickTestFilePath).existsSync()) {
        print("Running quick test.\n");
        final stopwatch = Stopwatch();
        stopwatch.start();
        runFile(quickTestFilePath, dumpTAC: true);
        stopwatch.stop();
        print("Run time: ${stopwatch.elapsed.inSeconds} sec");
      } else {
        print("Quick test not found, skipping...\n");
      }
      return;
    }

    if (args[0] == "--dump-tac") {
      if (args.length < 2) {
        print("Usage: miniscript --dump-tac <file>");
        return;
      }
      // Dump TAC for the specified file
      runFile(args[1], dumpTAC: true);
      return;
    }

    if (args[0] == "--help" || args[0] == "-h") {
      print("Usage: miniscript [options] [file]");
      print("Options:");
      print("  --test [--integration <file>]: Run the unit tests.");
      print("  --dump-tac <file>: Dump the TAC for the specified file.");
      print("  --help, -h: Show this help message.");
      print("  --version, -v: Show the MiniScript version.");
      print("  <file>: Run the specified MiniScript file.");
      return;
    }

    if (args[0] == "--version" || args[0] == "-v") {
      print("MiniScript Dart version ${HostInfo.version}");
      print("Build date: ${HostInfo.buildDate}");
      print("Host: ${HostInfo.name}");
      print("Info: ${HostInfo.info}");
      return;
    }

    // Run the specified file
    runFile(args[0], dumpTAC: false);
    return;
  }

  // Interactive REPL mode
  final repl = Interpreter();
  repl.implicitOutput = repl.standardOutput;

  while (true) {
    stdout.write(repl.needMoreInput() ? ">>> " : "> ");
    final input = stdin.readLineSync();
    if (input == null) break;
    repl.repl(input);
  }
}

void print(String s, {bool lineBreak = true}) {
  if (lineBreak) {
    stdout.writeln(s);
  } else {
    stdout.write(s);
  }
}

void runFile(String path, {bool dumpTAC = false}) {
  try {
    final file = File(path);
    if (!file.existsSync()) {
      print("Unable to read: $path");
      return;
    }

    final sourceLines = file.readAsStringSync();

    final miniscript = Interpreter(source: sourceLines);
    miniscript.standardOutput =
        (String s, bool eol) => print(s, lineBreak: eol);
    miniscript.implicitOutput = miniscript.standardOutput;
    miniscript.compile();

    if (dumpTAC && miniscript.vm != null) {
      miniscript.vm!.dumpTopContext();
    }

    while (!miniscript.done) {
      miniscript.runUntilDone();
    }

    if (dumpTAC && miniscript.vm != null) {
      miniscript.vm!.dumpTopContext();
    }
  } catch (e, stackTrace) {
    print("Error running file: $e");
    print(stackTrace.toString());
  }
}

class TestCounter {
  static int count = 0;
  static int success = 0;

  static void reset() {
    count = 0;
    success = 0;
  }

  static void fail() {
    count++;
  }

  static void pass() {
    count++;
    success++;
  }
}

void runTestSuite(String path) {
  TestCounter.reset();
  try {
    final file = File(path);
    if (!file.existsSync()) {
      print("Unable to read: $path");
      return;
    }

    final lines = file.readAsLinesSync();
    List<String>? sourceLines;
    List<String>? expectedOutput;
    int testLineNum = 0;
    int outputLineNum = 0;
    int lineNum = 1;

    for (final line in lines) {
      if (line.startsWith("====")) {
        if (sourceLines != null) {
          test(sourceLines, testLineNum, expectedOutput ?? [], outputLineNum);
        }
        sourceLines = null;
        expectedOutput = null;
      } else if (line.startsWith("----")) {
        expectedOutput = [];
        outputLineNum = lineNum + 1;
      } else if (expectedOutput != null) {
        expectedOutput.add(line);
      } else {
        if (sourceLines == null) {
          sourceLines = [];
          testLineNum = lineNum;
        }
        sourceLines.add(line);
      }
      lineNum++;
    }

    if (sourceLines != null) {
      test(sourceLines, testLineNum, expectedOutput ?? [], outputLineNum);
    }
    print("\nIntegration tests complete.\n");
  } catch (e, stackTrace) {
    print("Error running test suite: $e");
    print(stackTrace.toString());
  }

  print("Tests passed: ${TestCounter.success}/${TestCounter.count}");
}

void test(
  List<String> sourceLines,
  int sourceLineNum,
  List<String> expectedOutput,
  int outputLineNum,
) {
  final miniscript = Interpreter.fromLines(sourceLines: sourceLines);
  final actualOutput = <String>[];

  miniscript.standardOutput = (String s, bool eol) => actualOutput.add(s);
  miniscript.errorOutput = miniscript.standardOutput;
  miniscript.implicitOutput = miniscript.standardOutput;

  bool hasError = false;

  try {
    miniscript.runUntilDone(
      timeLimit: 30,
      returnEarly: false,
    );
    final int minLen = expectedOutput.length < actualOutput.length
        ? expectedOutput.length
        : actualOutput.length;

    // Compare actual output with expected output

    for (int i = 0; i < minLen; i++) {
      if (actualOutput[i] != expectedOutput[i]) {
        print(
          "TEST FAILED AT LINE ${outputLineNum + i + 1}\n  EXPECTED: ${expectedOutput[i]}\n    ACTUAL: ${actualOutput[i]}",
        );
        TestCounter.fail();
        hasError = true;
      }
    }

    if (expectedOutput.length > actualOutput.length) {
      print(
          "TEST FAILED: MISSING OUTPUT AT LINE ${outputLineNum + actualOutput.length}");
      for (int i = actualOutput.length; i < expectedOutput.length; i++) {
        print("  MISSING: ${expectedOutput[i]}");
      }
      TestCounter.fail();
      hasError = true;
    } else if (actualOutput.length > expectedOutput.length) {
      print(
          "TEST FAILED: EXTRA OUTPUT AT LINE ${outputLineNum + expectedOutput.length}");
      for (int i = expectedOutput.length; i < actualOutput.length; i++) {
        print("  EXTRA: ${actualOutput[i]}");
      }
      TestCounter.fail();
      hasError = true;
    }
  } catch (e, stackTrace) {
    print("TEST FAILED: EXCEPTION: $e");
    print(stackTrace.toString());
    hasError = true;

    for (int i = 0; i < expectedOutput.length - actualOutput.length; i++) {
      TestCounter.fail();
    }
  }
  if (!hasError) {
    print("TEST PASSED AT LINE $sourceLineNum");
    TestCounter.pass();
  }
}
