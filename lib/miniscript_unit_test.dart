// Copyright © 2025 by the authors of the project. All rights reserved.

/*
  miniscript_unit_test.dart

  This file contains a number of unit tests for various parts of the MiniScript
  architecture. It's used by the MiniScript developers to ensure we don't
  break something when we make changes.

  You can safely ignore this, but if you really want to run the tests yourself,
  just call MiniscriptUnitTest.run().
*/

import "miniscript_parser/parser.dart";
import "miniscript_lexer.dart";

class UnitTest {
  static void reportError(String err) {
    print(err);
  }

  static void errorIf(bool condition, String err, [int? count, int? length]) {
    if (condition) {
      reportError(err);
    }
  }

  static void errorIfNull(Object? obj) {
    if (obj == null) {
      reportError("Unexpected null");
    }
  }

  static void errorIfNotNull(Object? obj) {
    if (obj != null) {
      reportError("Expected null, but got non-null");
    }
  }

  static void errorIfNotEqual(
    String actual,
    String expected, [
    String desc = "Expected {1}, got {0}",
  ]) {
    if (actual != expected) {
      reportError(desc.replaceAll('{0}', actual).replaceAll('{1}', expected));
    }
  }

  static void run() {
    Lexer.runUnitTests();
    Parser.runUnitTests();
  }
}
