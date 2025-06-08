// Copyright © 2025 by the authors of the project. All rights reserved.

import 'package:miniscript/miniscript_errors.dart';
import 'package:miniscript/miniscript_types/value.dart';
import 'package:miniscript/miniscript_types/value_temp.dart';
import 'package:miniscript/miniscript_types/value_variable.dart';

import '../miniscript_tac/tac.dart' as tac;
import './value_number.dart' show ValNumber;

/// ValList represents a MiniScript list (which, under the hood, is
/// just a wrapper for a List of Values).
class ValList extends Value {
  /// about 16 MB
  static const int maxSize = 0xFFFFFF;

  late List<Value?> values;

  ValList([List<Value?>? values]) {
    this.values = values ?? [];
  }

  @override
  Value? fullEval(tac.Context context) {
    // Evaluate each of our list elements, and if any of those is
    // a variable or temp, then resolve those now.
    // CAUTION: do not mutate our original list!  We may need
    // it in its original form on future iterations.
    ValList? result;
    for (var i = 0; i < values.length; i++) {
      var copied = false;
      if (values[i] is ValTemp || values[i] is ValVar) {
        Value? newVal = values[i]!.val(context);
        // OK, something changed, so we're going to need a new copy of the list.
        if (newVal != values[i]) {
          result ??= ValList();
          for (var j = 0; j < i; j++) {
            result.values.add(values[j]);
          }
          result.values.add(newVal);
          copied = true;
        }
      }
      if (!copied && result != null) {
        // No change; but we have new results to return, so copy it as-is
        result.values.add(values[i]);
      }
    }
    return result ?? this;
  }

  ValList evalCopy(tac.Context context) {
    // Create a copy of this list, evaluating its members as we go.
    // This is used when a list literal appears in the source, to
    // ensure that each time that code executes, we get a new, distinct
    // mutable object, rather than the same object multiple times.
    var result = ValList();
    for (var i = 0; i < values.length; i++) {
      result.values.add(values[i]?.val(context));
    }
    return result;
  }

  @override
  String codeForm(tac.Machine? vm, {int recursionLimit = -1}) {
    if (recursionLimit == 0) return "[...]";
    if (recursionLimit > 0 && recursionLimit < 3) {
      String? shortName = vm?.findShortName(this);
      if (shortName != null) return shortName;
    }

    var strs = List<String>.generate(values.length, (i) {
      return values[i]?.codeForm(vm, recursionLimit: recursionLimit - 1) ??
          "null";
    });
    return "[${strs.join(", ")}]";
  }

  @override
  String toStringWithVM([tac.Machine? vm]) {
    return codeForm(vm, recursionLimit: 3);
  }

  @override
  bool boolValue() {
    // A list is considered true if it is nonempty.
    return values.isNotEmpty;
  }

  @override
  bool isA(Value? type, tac.Machine vm) {
    if (type == null) return false;
    return type == vm.listType;
  }

  @override
  int hash() {
    return recursiveHash();
  }

  @override
  double equality(Value? rhs) {
    // Quick bail-out cases:
    if (rhs is! ValList) return 0;
    List<Value?> rhl = rhs.values;
    if (identical(rhl, values)) return 1; // (same list)
    int count = values.length;
    if (count != rhl.length) return 0;

    // Otherwise, we have to do:
    return recursiveEqual(rhs) ? 1 : 0;
  }

  @override
  bool canSetElem() => true;

  @override
  void setElem(Value? index, Value? value) {
    var i = index!.intValue();
    if (i < 0) i += values.length;
    if (i < 0 || i >= values.length) {
      throw RuntimeException("Index Error (list index $index out of range)");
    }
    values[i] = value;
  }

  Value getElem(Value index) {
    if (index is! ValNumber) {
      throw RuntimeException("List index must be numeric");
    }
    var i = index.intValue();
    if (i < 0) i += values.length;
    if (i < 0 || i >= values.length) {
      throw RuntimeException("Index Error (list index $index out of range)");
    }
    return values[i]!;
  }
}
