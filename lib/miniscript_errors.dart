/*  miniscript_errors.dart

This file defines the exception hierarchy used by Miniscript.
The core of the tree is this:

  MiniscriptException
    LexerException -- any error while finding tokens from raw source
    CompilerException -- any error while compiling tokens into bytecode
    RuntimeException -- any error while actually executing code.

We have a number of fine-grained exception types within these,
but they will always derive from one of those three (and ultimately
from MiniscriptException).
*/

import 'dart:core';
import 'miniscript_types/value.dart';

class SourceLoc {
  /// file name, etc. (optional)
  String? context;
  int lineNum;

  SourceLoc(this.context, this.lineNum);

  @override
  String toString() {
    return "[${context?.isEmpty ?? true ? '' : '$context '}line $lineNum]";
  }
}

class MiniscriptException implements Exception {
  String message;
  SourceLoc? location;
  Exception? inner;

  MiniscriptException([this.message = "Error", this.inner]);

  MiniscriptException.withLocation(
    String context,
    int lineNum,
    this.message, [
    this.inner,
  ]) {
    location = SourceLoc(context, lineNum);
  }

  /// Get a standard description of this error, including type and location.
  String description() {
    String desc = "Error: ";
    if (this is LexerException) {
      desc = "Lexer Error: ";
    } else if (this is CompilerException) {
      desc = "Compiler Error: ";
    } else if (this is RuntimeException) {
      desc = "Runtime Error: ";
    }
    desc += message;
    if (location != null) desc += " $location";
    return desc;
  }

  @override
  String toString() {
    return description();
  }
}

class LexerException extends MiniscriptException {
  LexerException([super.message = "Lexer Error", super.inner]);
}

class CompilerException extends MiniscriptException {
  CompilerException([super.message = "Syntax Error", super.inner]);

  CompilerException.withLocation(super.context, super.lineNum, super.message,
      [super.inner])
      : super.withLocation();
}

class RuntimeException extends MiniscriptException {
  RuntimeException([super.message = "Runtime Error", super.inner]);
}

class IndexException extends RuntimeException {
  IndexException(
      [super.message = "Index Error (index out of range)", super.inner]);
}

class KeyException extends RuntimeException {
  KeyException([String? key, Exception? inner])
      : super(
            key != null
                ? "Key Not Found: '$key' not found in map"
                : "Key Not Found",
            inner);
}

class TypeException extends RuntimeException {
  TypeException(
      [super.message = "Type Error (wrong type for whatever you're doing)",
      super.inner]);
}

class TooManyArgumentsException extends RuntimeException {
  TooManyArgumentsException(
      [super.message = "Too Many Arguments", super.inner]);
}

class LimitExceededException extends RuntimeException {
  LimitExceededException(
      [super.message = "Runtime Limit Exceeded", super.inner]);
}

class UndefinedIdentifierException extends RuntimeException {
  UndefinedIdentifierException([String? ident, Exception? inner])
      : super(
            ident != null
                ? "Undefined Identifier: '$ident' is unknown in this context"
                : "Undefined Identifier",
            inner);
}

class UndefinedLocalException extends RuntimeException {
  UndefinedLocalException([String? ident, Exception? inner])
      : super(
            ident != null
                ? "Undefined Local Identifier: '$ident' is unknown in this context"
                : "Undefined Local Identifier",
            inner);
}

class Check {
  static void range(int i, int min, int max, [String desc = "index"]) {
    if (i < min || i > max) {
      throw IndexException(
        "Index Error: $desc ($i) out of range ($min to $max)",
      );
    }
  }

  static void type<T>(Value? val, [String? desc]) {
    if (val is! T) {
      String typeStr = val == null ? "null" : "a ${val.runtimeType}";
      throw TypeException(
        "got $typeStr where a ${T.toString()} was required${desc == null ? '' : ' ($desc)'}",
      );
    }
  }
}
