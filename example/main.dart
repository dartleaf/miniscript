import 'dart:io';

import 'package:miniscript/miniscript_interpreter.dart';

void main() {
  final miniscript = Interpreter(source: 'print "Hello, Miniscript!"');

  miniscript.standardOutput = (String s, bool eol) => print(s, lineBreak: eol);
  miniscript.implicitOutput = miniscript.standardOutput;
  miniscript.compile();
}

void print(String s, {bool lineBreak = true}) {
  if (lineBreak) {
    stdout.writeln(s);
  } else {
    stdout.write(s);
  }
}
