import 'package:miniscript/miniscript_errors.dart';
import 'package:miniscript/miniscript_interpreter.dart';
import 'package:miniscript/miniscript_intrinsics/intrinsic.dart';
import 'package:miniscript/miniscript_tac/context.dart';
import 'package:miniscript/miniscript_tac/line.dart';
import 'package:miniscript/miniscript_types/function.dart';
import 'package:miniscript/miniscript_types/value.dart';
import 'package:miniscript/miniscript_types/value_map.dart';
import 'package:miniscript/miniscript_types/value_seq_elem.dart';
import 'package:miniscript/miniscript_types/value_string.dart';
import 'package:miniscript/miniscript_types/value_variable.dart';
import 'package:miniscript/value_pointer.dart';

/// TAC.Machine implements a complete MiniScript virtual machine.  It
/// keeps the context stack, keeps track of run time, and provides
/// methods to step, stop, or reset the program.
class Machine {
  /// interpreter hosting this machine
  WeakReference<Interpreter>? interpreter;

  /// where print() results should go
  TextOutputMethod standardOutput;

  /// whether to store implicit values (e.g. for REPL)
  bool storeImplicit = false;

  /// set to true by yield intrinsic
  bool yielding = false;

  ValMap? functionType;
  ValMap? listType;
  ValMap? mapType;
  ValMap? stringType;
  ValMap? numberType;
  ValMap? versionMap;

  late final Context? _globalContext;

  /// contains global variables
  Context? get globalContext => _globalContext;

  List<Context> stack = [];
  Stopwatch? stopwatch;

  double get runTime {
    return stopwatch == null ? 0 : stopwatch!.elapsed.inSeconds.toDouble();
  }

  bool get done => stack.length <= 1 && stack.last.done;

  Machine(Context globalContext, TextOutputMethod? standardOutput)
      : _globalContext = globalContext,
        standardOutput = standardOutput ?? ((s, eol) => print(s)) {
    globalContext.vm = this;
    stack = List<Context>.from([globalContext]);
  }

  void stop() {
    while (stack.length > 1) {
      stack.removeLast();
    }
    stack.last.jumpToEnd();
  }

  void reset() {
    while (stack.length > 1) {
      stack.removeLast();
    }
    stack.last.reset(false);
  }

  void step() {
    if (stack.isEmpty) return; // not even a global context
    stopwatch ??= Stopwatch()..start();
    var context = stack.last;
    while (context.done) {
      if (stack.length == 1) return; // all done (can't pop the global context)
      popContext();
      context = stack.last;
    }

    final line = context.code[context.lineNum++];

    try {
      doOneLine(line, context);
    } on MiniscriptException catch (e) {
      e.location ??= line.location;

      if (e.location == null) {
        for (final ctx in [...stack, context]) {
          if (ctx.lineNum >= ctx.code.length) continue;
          e.location = ctx.code[ctx.lineNum].location;
          if (e.location != null) break;
        }
      }

      rethrow;
    }
  }

  /// Directly invoke a ValFunction by manually pushing it onto the call stack.
  /// This might be useful, for example, in invoking handlers that have somehow
  /// been registered with the host app via intrinsics.
  void manuallyPushCall(ValFunction func, Value resultStorage,
      [List<Value>? arguments]) {
    var context = stack.last;
    int argCount = func.function.parameters.length;
    for (var i = 0; i < argCount; i++) {
      if (arguments != null && i < arguments.length) {
        final val = context.valueInContext(arguments[i]);
        context.pushParamArgument(val);
      } else {
        context.pushParamArgument(null);
      }
    }

    Context nextContext =
        context.nextCallContext(func.function, argCount, false, null);
    nextContext.resultStorage = resultStorage;
    stack.add(nextContext);
  }

  void doOneLine(Line line, Context context) {
    if (line.op == LineOp.pushParam) {
      final val = context.valueInContext(line.rhsA);
      context.pushParamArgument(val);
    } else if (line.op == LineOp.callFunctionA) {
      // Resolve rhsA. If it's a function, invoke it; otherwise,
      // just store it directly (but pop the call context).
      var valueFoundInPointer = ValuePointer<ValMap>();
      final funcVal = line.rhsA!.valWithMap(context, valueFoundInPointer);

      if (funcVal is ValFunction) {
        Value? self;
        // Bind "super" to the parent of the map the function was found in
        final superVal = valueFoundInPointer.value
            ?.lookup(ValString.magicIsA, ValuePointer());

        if (line.rhsA is ValSeqElem) {
          // Bind "self" to the object used to invoke the call,
          // except when invoking via "super"
          final seq = (line.rhsA as ValSeqElem).sequence;
          if (seq is ValVar && (seq).identifier == "super") {
            self = context.self;
          } else {
            self = context.valueInContext(seq);
          }
        }

        final argCount = line.rhsB!.intValue();
        final nextContext = context.nextCallContext(
          funcVal.function,
          argCount,
          self != null,
          line.lhs,
        );

        nextContext.outerVars = funcVal.outerVars;
        if (valueFoundInPointer.value != null) {
          nextContext.setVar("super", superVal);
        }
        if (self != null) nextContext.self = self;
        stack.add(nextContext);
      } else {
        // The user is attempting to call something that's not a function.
        // We'll allow that, but any number of parameters is too many.  [#35]
        // (No need to pop them, as the exception will pop the whole call stack anyway.)
        int argCount = line.rhsB!.intValue();
        if (argCount > 0) throw TooManyArgumentsException();
        context.storeValue(line.lhs, funcVal);
      }
    } else if (line.op == LineOp.returnA) {
      final val = line.evaluate(context);
      context.storeValue(line.lhs, val);
      popContext();
    } else if (line.op == LineOp.assignImplicit) {
      final val = line.evaluate(context);
      if (storeImplicit) {
        context.storeValue(ValVar.implicitResult, val);
        context.implicitResultCounter++;
      }
    } else {
      final val = line.evaluate(context);
      context.storeValue(line.lhs, val);
    }
  }

  void popContext() {
    // Our top context is done; pop it off, and copy the return value in temp 0.
    if (stack.length == 1) {
      return; // down to just the global stack (which we keep)
    }
    var context = stack.removeLast();
    final result = context.getTemp(0, null);
    final storage = context.resultStorage;
    context = stack.last;
    context.storeValue(storage, result);
  }

  Context getTopContext() {
    return stack.last;
  }

  void dumpTopContext() {
    stack.last.dump();
  }

  String? findShortName(Value value) {
    if (globalContext == null || globalContext!.variables == null) return null;
    for (final entry in globalContext!.variables!.map.entries) {
      if (entry.value == value && entry.key != value) {
        return entry.value!.toStringWithVM(this);
      }
    }
    return Intrinsic.shortNames[value] ?? "null";
  }

  List<SourceLoc?> getStack() {
    final result = <SourceLoc?>[];

    // Return the newest call context first, and the oldest (global) context last
    // by iterating through the stack in reverse
    for (var i = stack.length - 1; i >= 0; i--) {
      final ctx = stack[i];
      result.add(ctx.getSourceLoc());
    }

    return result;
  }

  void pushContext(Context context) {
    stack.add(context);
    context = context;
  }
}
