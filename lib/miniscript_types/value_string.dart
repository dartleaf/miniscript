// Copyright © 2025 by the authors of the project. All rights reserved.

import 'package:miniscript/miniscript_errors.dart';

import '../miniscript_tac/tac.dart' as tac;
import './value_number.dart' show ValNumber;

import 'value.dart';

/// ValString represents a string (text) value.
class ValString extends Value {
  /// about 16M elements
  static const int maxSize = 0xFFFFFF;

  String value;

  ValString([this.value = '']);

  @override
  String toStringWithVM([tac.Machine? vm]) {
    return value;
  }

  @override
  String codeForm(tac.Machine? vm, {int recursionLimit = -1}) {
    return '"${value.replaceAll('"', '""')}"';
  }

  @override
  bool boolValue() {
    // Any nonempty string is considered true.
    return value.isNotEmpty;
  }

  @override
  bool isA(Value? type, tac.Machine vm) {
    if (type == null) return false;
    return type == vm.stringType;
  }

  @override
  int hash() {
    return value.hashCode;
  }

  @override
  double equality(Value? rhs) {
    // String equality is treated the same as in C#.
    return rhs is ValString && rhs.value == value ? 1 : 0;
  }

  Value getElem(Value index) {
    if (index is! ValNumber) {
      throw MiniscriptException('String index must be numeric');
    }
    int i = index.intValue();
    if (i < 0) i += value.length;
    if (i < 0 || i >= value.length) {
      throw MiniscriptException(
          'Index Error (string index $index out of range)');
    }
    return ValString(value.substring(i, i + 1));
  }

  // Magic identifier for the is-a entry in the class system:
  static final ValString magicIsA = ValString('__isa');
  static final ValString _empty = ValString('');

  /// Handy accessor for an empty ValString.
  /// IMPORTANT: do not alter the value of the object returned!
  static ValString get empty => _empty;
}

// We frequently need to generate a ValString out of a string for fleeting purposes,
// like looking up an identifier in a map (which we do ALL THE TIME).  So, here's
// a little recycling pool of reusable ValStrings, for this purpose only.
class TempValString extends ValString {
  TempValString? next;

  TempValString._(super.s);

  static TempValString? _tempPoolHead;

  static TempValString get(String s) {
    if (_tempPoolHead == null) {
      return TempValString._(s);
    } else {
      final result = _tempPoolHead!;
      _tempPoolHead = _tempPoolHead!.next;
      result.value = s;
      return result;
    }
  }

  static void release(TempValString temp) {
    temp.next = _tempPoolHead;
    _tempPoolHead = temp;
  }
}
