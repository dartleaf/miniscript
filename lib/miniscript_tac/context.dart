// Copyright © 2025 by the authors of the project. All rights reserved.

import 'package:miniscript/miniscript_errors.dart';
import 'package:miniscript/miniscript_interpreter.dart';
import 'package:miniscript/miniscript_intrinsics/intrinsic.dart';
import 'package:miniscript/miniscript_intrinsics/intrinsic_result.dart';
import 'package:miniscript/miniscript_tac/dump.dart' as tac;
import 'package:miniscript/miniscript_tac/line.dart';
import 'package:miniscript/miniscript_tac/machine.dart';
import 'package:miniscript/miniscript_types/function.dart';
import 'package:miniscript/miniscript_types/value.dart';
import 'package:miniscript/miniscript_types/value_map.dart';
import 'package:miniscript/miniscript_types/value_seq_elem.dart';
import 'package:miniscript/miniscript_types/value_string.dart';
import 'package:miniscript/miniscript_types/value_temp.dart';
import 'package:miniscript/miniscript_types/value_variable.dart';
import 'package:miniscript/value_pointer.dart';

/// TAC.Context keeps track of the runtime environment, including local
/// variables.  Context objects form a linked list via a "parent" reference,
/// with a new context formed on each function call (this is known as the
/// call stack).
class Context {
  /// TAC lines we're executing
  List<Line> code;

  /// next line to be executed
  int lineNum = 0;

  /// local variables for this call frame
  ValMap? variables;

  /// variables of the context where this function was defined
  ValMap? outerVars;

  /// value of self in this context
  Value? self;

  /// pushed arguments for upcoming calls
  List<Value?>? args;

  /// parent (calling) context
  Context? parent;

  /// where to store the return value (in the calling context)
  Value? resultStorage;

  /// virtual machine
  Machine? vm;

  /// work-in-progress of our current intrinsic
  IntrinsicResult? partialResult;

  /// how many times we have stored an implicit result
  int implicitResultCounter = 0;

  /// values of temporaries; temps[0] is always return value
  List<Value?>? temps;

  bool get done => lineNum >= code.length;

  Context get root {
    var c = this;
    while (c.parent != null) {
      c = c.parent!;
    }
    return c;
  }

  Interpreter? get interpreter {
    if (vm == null || vm!.interpreter == null) return null;
    return vm!.interpreter!.target;
  }

  Context(this.code);

  void clearCodeAndTemps() {
    code.clear();
    lineNum = 0;
    temps?.clear();
  }

  /// Reset this context to the first line of code, clearing out any
  /// temporary variables, and optionally clearing out all variables.
  void reset([bool clearVariables = true]) {
    lineNum = 0;
    temps = null;
    if (clearVariables) variables = ValMap();
  }

  void jumpToEnd() {
    lineNum = code.length;
  }

  void setTemp(int tempNum, Value? value) {
    // OFI: let each context record how many temps it will need, so we
    // can pre-allocate this list with that many and avoid having to
    // grow it later.  Also OFI: do lifetime analysis on these temps
    // and reuse ones we don't need anymore.
    temps ??= [];
    while (temps!.length <= tempNum) {
      temps!.add(null);
    }
    temps![tempNum] = value;
  }

  Value? getTemp(int tempNum, [Value? defaultValue]) {
    if (defaultValue == null) {
      return temps == null ? null : temps?[tempNum];
    }
    if (temps != null && tempNum < temps!.length) {
      return temps![tempNum];
    }
    return defaultValue;
  }

  void setVar(String identifier, Value? value) {
    if (identifier == "globals" || identifier == "locals") {
      throw RuntimeException("can't assign to $identifier");
    }

    if (identifier == "self") {
      self = value;
      return;
    }

    variables ??= ValMap();
    if (variables!.assignOverride == null ||
        !variables!.assignOverride!(ValString(identifier), value)) {
      variables![identifier] = value;
    }
  }

  /// Get the value of a local variable ONLY -- does not check any other
  /// scopes, nor check for special built-in identifiers like "globals".
  /// Used mainly by host apps to easily look up an argument to an
  /// intrinsic function call by the parameter name.
  Value? getLocal(String identifier, [Value? defaultValue]) {
    var result = ValuePointer<Value>();
    if (variables != null &&
        variables!.tryGetValueWithIdentifier(identifier, result)) {
      return result.value;
    }
    return defaultValue;
  }

  int? getLocalInt(String identifier, [int defaultValue = 0]) {
    var result = ValuePointer<Value>();
    if (variables != null &&
        variables!.tryGetValueWithIdentifier(identifier, result)) {
      if (result.value == null) {
        return 0; // variable found, but its value was null!
      }
      return result.value?.intValue();
    }
    return defaultValue;
  }

  bool? getLocalBool(String identifier, [bool defaultValue = false]) {
    var result = ValuePointer<Value>();
    if (variables != null &&
        variables!.tryGetValueWithIdentifier(identifier, result)) {
      if (result.value == null) {
        return false; // variable found, but its value was null!
      }
      return result.value?.boolValue();
    }
    return defaultValue;
  }

  double? getLocalDouble(String identifier, [double defaultValue = 0]) {
    var result = ValuePointer<Value>();
    if (variables != null &&
        variables!.tryGetValueWithIdentifier(identifier, result)) {
      if (result.value == null) {
        return 0; // variable found, but its value was null!
      }
      return result.value?.doubleValue();
    }
    return defaultValue;
  }

  String? getLocalString(String identifier, [String? defaultValue]) {
    var result = ValuePointer<Value>();
    if (variables != null &&
        variables!.tryGetValueWithIdentifier(identifier, result)) {
      return result.value?.toString();
    }
    return defaultValue;
  }

  SourceLoc? getSourceLoc() {
    if (lineNum < 0 || lineNum >= code.length) return null;
    return code[lineNum].location;
  }

  /// Get the value of a variable available in this context (including
  /// locals, globals, and intrinsics).  Raise an exception if no such
  /// identifier can be found.
  Value? getVar(
    String identifier, {
    LocalOnlyMode localOnly = LocalOnlyMode.off,
  }) {
    // check for special built-in identifiers 'locals', 'globals', etc.
    switch (identifier.length) {
      case 4:
        if (identifier == "self") return self;
        break;
      case 5:
        if (identifier == "outer") {
          // return module variables, if we have them; else globals
          if (outerVars != null) return outerVars;
          root.variables ??= ValMap();
          return root.variables;
        }
        break;
      case 6:
        if (identifier == "locals") {
          variables ??= ValMap();
          return variables!;
        }
        break;
      case 7:
        if (identifier == "globals") {
          root.variables ??= ValMap();
          return root.variables;
        }
        break;
    }

    // check for a local variable
    ValuePointer<Value> resultPointer = ValuePointer();
    if (variables != null &&
        variables!.tryGetValueWithIdentifier(
          identifier,
          resultPointer,
        )) {
      return resultPointer.value;
    }

    if (localOnly != LocalOnlyMode.off) {
      if (localOnly == LocalOnlyMode.strict) {
        throw UndefinedLocalException(identifier);
      } else {
        vm?.standardOutput(
          "Warning: assignment of unqualified local '$identifier' based on nonlocal is deprecated ${code[lineNum].location}",
          true,
        );
      }
    }

    // check for a module variable
    if (outerVars != null &&
        outerVars!.tryGetValueWithIdentifier(identifier, resultPointer)) {
      return resultPointer.value;
    }

    // OK, we don't have a local or module variable with that name.
    // Check the global scope (if that's not us already).
    if (parent != null) {
      Context globals = root;
      if (globals.variables != null &&
          globals.variables!.tryGetValueWithIdentifier(
            identifier,
            resultPointer,
          )) {
        return resultPointer.value;
      }
    }

    // Finally, check intrinsics.
    final intrinsic = Intrinsic.getByName(identifier);
    if (intrinsic != null) return intrinsic.getFunc();

    // No luck there either?  Undefined identifier.
    throw UndefinedIdentifierException(identifier);
  }

  void storeValue(Value? lhs, Value? value) {
    if (lhs is ValTemp) {
      setTemp(lhs.tempNum, value);
    } else if (lhs is ValVar) {
      setVar(lhs.identifier, value);
    } else if (lhs is ValSeqElem) {
      final seq = lhs.sequence!.val(this);
      if (seq == null) {
        throw RuntimeException("can't set indexed element of null");
      }
      if (!seq.canSetElem()) {
        throw RuntimeException("can't set indexed element in this type");
      }
      var index = lhs.index;
      if (index is ValVar || index is ValSeqElem || index is ValTemp) {
        index = index!.val(this);
      }
      seq.setElem(index, value);
    } else if (lhs != null) {
      throw RuntimeException("not an lvalue");
    }
  }

  Value? valueInContext(Value? value) {
    return value?.val(this);
  }

  /// Store a parameter argument in preparation for an upcoming call
  /// (which should be executed in the context returned by NextCallContext).
  void pushParamArgument(Value? arg) {
    args ??= [];
    if (args!.length > 255) {
      throw RuntimeException("Argument limit exceeded");
    }
    args!.add(arg);
  }

  /// Get a context for the next call, which includes any parameter arguments
  /// that have been set.
  Context nextCallContext(
    VFunction func,
    int argCount,
    bool gotSelf,
    Value? resultStorage,
  ) {
    final result = Context(func.code!);

    result.resultStorage = resultStorage;
    result.parent = this;
    result.vm = vm;

    /// Stuff arguments, stored in our 'args' stack,
    /// into local variables corrersponding to parameter names.
    /// As a special case, skip over the first parameter if it is named 'self'
    /// and we were invoked with dot syntax.
    final selfParam = (gotSelf &&
            func.parameters.isNotEmpty &&
            func.parameters[0].name == "self")
        ? 1
        : 0;

    for (int i = 0; i < argCount; i++) {
      // Careful -- when we pop them off, they're in reverse order.
      final argument = args!.removeLast();
      final paramNum = argCount - 1 - i + selfParam;

      if (paramNum >= func.parameters.length) {
        throw TooManyArgumentsException();
      }

      final param = func.parameters[paramNum].name;
      if (param == "self") {
        result.self = argument;
      } else {
        result.setVar(param, argument);
      }
    }

    // And fill in the rest with default values
    for (var paramNum = argCount + selfParam;
        paramNum < func.parameters.length;
        paramNum++) {
      result.setVar(
        func.parameters[paramNum].name,
        func.parameters[paramNum].defaultValue,
      );
    }

    return result;
  }

  /// This function prints the three-address code to the console, for debugging purposes.
  void dump() {
    print("CODE:");
    tac.dump(code, lineNum);

    print("\nVARS:");
    if (variables == null) {
      print(" NONE");
    } else {
      for (var entry in variables!.map.entries) {
        final id = entry.key?.toStringWithVM(vm!);
        final value = entry.value;
        print("$id: ${value?.toStringWithVM(vm!)}");
      }
    }

    print("\nTEMPS:");
    if (temps == null) {
      print(" NONE");
    } else {
      for (int i = 0; i < temps!.length; i++) {
        print("_$i: ${temps![i]?.toStringWithVM(vm!)}");
      }
    }
  }

  @override
  String toString() => "Context[$lineNum/${code.length}]";
}
