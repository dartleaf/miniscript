// Copyright © 2025 by the authors of the project. All rights reserved.

/*	
  miniscript_interpreter.dart

  The only class in this file is Interpreter, which is your main interface 
  to the MiniScript system. You give Interpreter some MiniScript source 
  code, and tell it where to send its output (via function typedefs called
  TextOutputMethod). Then you typically call runUntilDone, which returns 
  when either the script has stopped or the given timeout has passed.  

  For details, see Chapters 1-3 of the MiniScript Integration Guide.
*/

import 'package:miniscript/miniscript_tac/tac.dart' as tac;

import 'miniscript_parser/parser.dart';
import 'miniscript_types/value_variable.dart';
import 'miniscript_types/value.dart';
import 'miniscript_errors.dart';

/// TextOutputMethod: a function typedef used to return text from the script
/// (e.g. normal output, errors, etc.) to your Dart code.
typedef TextOutputMethod = void Function(String output, bool addLineBreak);

/// Interpreter: an object that contains and runs one MiniScript script.
class Interpreter {
  /// standardOutput: receives the output of the "print" intrinsic.
  TextOutputMethod get standardOutput => _standardOutput;
  set standardOutput(TextOutputMethod value) {
    _standardOutput = value;
    if (vm != null) vm!.standardOutput = value;
  }

  /// implicitOutput: receives the value of expressions entered when
  /// in REPL mode. If you're not using the REPL() method, you can
  /// safely ignore this.
  TextOutputMethod? implicitOutput;

  /// errorOutput: receives error messages from the runtime. (This happens
  /// via the reportError method, which is virtual; so if you want to catch
  /// the actual exceptions rather than get the error messages as strings,
  /// you can extend Interpreter and override that method.)
  TextOutputMethod? errorOutput;

  /// hostData is just a convenient place for you to attach some arbitrary
  /// data to the interpreter. It gets passed through to the context object,
  /// so you can access it inside your custom intrinsic functions. Use it
  /// for whatever you like (or don't, if you don't feel the need).
  Object? hostData;

  /// done: returns true when we don't have a virtual machine, or we do have
  /// one and it is done (has reached the end of its code).
  bool get done {
    return vm == null || vm!.done;
  }

  /// vm: the virtual machine this interpreter is running. Most applications will
  /// not need to use this, but it's provided for advanced users.
  tac.Machine? vm;

  late TextOutputMethod _standardOutput;
  String? source;
  Parser? parser;

  /// Constructor taking some MiniScript source code, and the output delegates.
  Interpreter({
    this.source,
    TextOutputMethod? standardOutput,
    TextOutputMethod? errorOutput,
  }) {
    _standardOutput = standardOutput ?? ((s, eol) => print(s));
    this.errorOutput = errorOutput ?? ((s, eol) => print(s));
  }

  /// Constructor taking source code in the form of a list of strings.
  Interpreter.fromLines({
    required List<String> sourceLines,
    TextOutputMethod? standardOutput,
    TextOutputMethod? errorOutput,
  }) : this(
            source: sourceLines.join("\n"),
            standardOutput: standardOutput,
            errorOutput: errorOutput);

  /// Stop the virtual machine, and jump to the end of the program code.
  /// Also reset the parser, in case it's stuck waiting for a block ender.
  void stop() {
    if (vm != null) vm!.stop();
    if (parser != null) parser!.partialReset();
  }

  /// Reset the interpreter with the given source code.
  void reset({String source = ""}) {
    this.source = source;
    parser = null;
    vm = null;
  }

  /// Compile our source code, if we haven't already done so, so that we are
  /// either ready to run, or generate compiler errors (reported via errorOutput).
  void compile() {
    if (vm != null) return; // already compiled

    parser ??= Parser();
    try {
      parser!.parse(source ?? "");
      vm = parser!.createVM(standardOutput);
      vm!.interpreter = WeakReference(this);
    } on MiniscriptException catch (e) {
      reportError(e);
      if (vm == null) parser = null;
    }
  }

  /// Reset the virtual machine to the beginning of the code. Note that this
  /// does *not* reset global variables; it simply clears the stack and jumps
  /// to the beginning. Useful in cases where you have a short script you
  /// want to run over and over, without recompiling every time.
  void restart() {
    if (vm != null) vm!.reset();
  }

  /// Run the compiled code until we either reach the end, or we reach the
  /// specified time limit. In the latter case, you can then call runUntilDone
  /// again to continue execution right from where it left off.
  ///
  /// Or, if returnEarly is true, we will also return if we reach an intrinsic
  /// method that returns a partial result, indicating that it needs to wait
  /// for something. Again, call runUntilDone again later to continue.
  ///
  /// Note that this method first compiles the source code if it wasn't compiled
  /// already, and in that case, may generate compiler errors. And of course
  /// it may generate runtime errors while running. In either case, these are
  /// reported via errorOutput.
  void runUntilDone({
    double timeLimit = 60,
    bool returnEarly = true,
  }) {
    int startImpResultCount = 0;
    try {
      if (vm == null) {
        compile();
        if (vm == null) return; // (must have been some error)
      }
      startImpResultCount = vm!.globalContext!.implicitResultCounter;
      double startTime = DateTime.now().second.toDouble();
      vm!.yielding = false;
      while (!vm!.done && !vm!.yielding) {
        // ToDo: find a substitute for vm.runTime, or make it go faster
        if (DateTime.now().second.toDouble() - startTime > timeLimit) {
          return; // time's up for now!
        }
        vm!.step(); // update the machine
        if (returnEarly && vm!.getTopContext().partialResult != null) {
          return; // waiting for something
        }
      }
    } on MiniscriptException catch (e) {
      reportError(e);
      stop();
    }
    checkImplicitResult(startImpResultCount);
  }

  /// Run one step of the virtual machine. This method is not very useful
  /// except in special cases; usually you will use runUntilDone (above) instead.
  void step() {
    try {
      compile();
      vm!.step();
    } on MiniscriptException catch (e) {
      reportError(e);
      stop();
    }
  }

  /// Read Eval Print Loop. Run the given source until it either terminates,
  /// or hits the given time limit. When it terminates, if we have new
  /// implicit output, print that to the implicitOutput stream.
  void repl(String? sourceLine, {double timeLimit = 60}) {
    parser ??= Parser();
    if (vm == null) {
      vm = parser!.createVM(standardOutput);
      vm!.interpreter = WeakReference(this);
    } else if (vm!.done && !parser!.needMoreInput()) {
      // Since the machine and parser are both done, we don't really need the
      // previously-compiled code. So let's clear it out, as a memory optimization.
      vm!.getTopContext().clearCodeAndTemps();
      parser!.partialReset();
    }
    if (sourceLine == "#DUMP") {
      vm!.dumpTopContext();
      return;
    }

    double startTime = vm!.stopwatch!.elapsed.inSeconds.toDouble();
    int startImpResultCount = vm!.globalContext!.implicitResultCounter;
    vm!.storeImplicit = (implicitOutput != null);
    vm!.yielding = false;

    try {
      if (sourceLine != null) parser!.parse(sourceLine, replMode: true);
      if (!parser!.needMoreInput()) {
        while (!vm!.done && !vm!.yielding) {
          if (vm!.stopwatch!.elapsed.inSeconds - startTime > timeLimit) {
            return; // time's up for now!
          }
          vm!.step();
        }
        checkImplicitResult(startImpResultCount);
      }
    } on MiniscriptException catch (e) {
      reportError(e);
      // Attempt to recover from an error by jumping to the end of the code.
      stop();
    }
  }

  /// Report whether the virtual machine is still running, that is,
  /// whether it has not yet reached the end of the program code.
  bool running() {
    return vm != null && !vm!.done;
  }

  /// Return whether the parser needs more input, for example because we have
  /// run out of source code in the middle of an "if" block. This is typically
  /// used with REPL for making an interactive console, so you can change the
  /// prompt when more input is expected.
  bool needMoreInput() {
    return parser != null && parser!.needMoreInput();
  }

  /// Get a value from the global namespace of this interpreter.
  Value? getGlobalValue(String varName) {
    if (vm == null) return null;
    tac.Context c = vm!.globalContext!;
    try {
      return c.getVar(varName);
    } on UndefinedIdentifierException {
      return null;
    }
  }

  /// Set a value in the global namespace of this interpreter.
  void setGlobalValue(String varName, Value value) {
    vm?.globalContext!.setVar(varName, value);
  }

  /// Helper method that checks whether we have a new implicit result, and if
  /// so, invokes the implicitOutput callback (if any). This is how you can
  /// see the result of an expression in a Read-Eval-Print Loop (REPL).
  void checkImplicitResult(int previousImpResultCount) {
    if (implicitOutput != null &&
        vm!.globalContext!.implicitResultCounter > previousImpResultCount) {
      Value? result =
          vm!.globalContext!.getVar(ValVar.implicitResult.identifier);
      implicitOutput!(result!.toStringWithVM(vm!), true);
    }
  }

  /// Report a MiniScript error to the user. The default implementation
  /// simply invokes errorOutput with the error description. If you want
  /// to do something different, then make an Interpreter subclass, and
  /// override this method.
  void reportError(MiniscriptException mse) {
    errorOutput!(mse.description(), true);
  }
}
