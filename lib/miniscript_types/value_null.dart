// Copyright © 2025 by the authors of the project. All rights reserved.

import 'package:miniscript/miniscript_types/value.dart';

import '../miniscript_tac/tac.dart' as tac;
import './value_map.dart' show ValMap;
import '../value_pointer.dart' show ValuePointer;

/// ValNull is an object to represent null in places where we can't use
/// an actual null (such as a dictionary key or value).
class ValNull extends Value {
  ValNull._(); // Private constructor

  @override
  String toStringWithVM([tac.Machine? vm]) {
    return "null";
  }

  @override
  bool isA(Value? type, tac.Machine vm) {
    return type == null;
  }

  @override
  int hash() {
    return -1;
  }

  @override
  Value? val(tac.Context context) {
    return null;
  }

  @override
  Value? valWithMap(tac.Context context, ValuePointer<ValMap> valueFoundIn) {
    valueFoundIn.value = null;
    return null;
  }

  @override
  Value? fullEval(tac.Context context) {
    return null;
  }

  @override
  int intValue() {
    return 0;
  }

  @override
  double doubleValue() {
    return 0.0;
  }

  @override
  bool boolValue() {
    return false;
  }

  @override
  double equality(Value? rhs) {
    return (rhs == null || rhs is ValNull ? 1 : 0);
  }

  static final ValNull _inst = ValNull._();

  /// Handy accessor to a shared "instance".
  static ValNull get instance => _inst;
}
