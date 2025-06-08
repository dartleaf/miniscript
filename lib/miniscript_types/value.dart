// Copyright © 2025 by the authors of the project. All rights reserved.

import 'package:miniscript/miniscript_types/helpers.dart';

import '../miniscript_tac/tac.dart' as tac;
import './value_map.dart' show ValMap;
import './value_list.dart' show ValList;
import '../value_pointer.dart' show ValuePointer;
import 'value_number.dart';
import 'value_string.dart';

/// Value: abstract base class for the MiniScript type hierarchy.
/// Defines a number of handy methods that you can call on ANY
/// value (though some of these do nothing for some types).
abstract class Value {
  /// Get the current value of this Value in the given context.  Basic types
  /// evaluate to themselves, but some types (e.g. variable references) may
  /// evaluate to something else.
  Value? val(tac.Context context) {
    return this; // most types evaluate to themselves
  }

  String toStringWithVM([tac.Machine? vm]);

  @override
  String toString() {
    return toStringWithVM();
  }

  /// This version of Val is like the one above, but also returns
  /// (via the output parameter) the ValMap the value was found in,
  /// which could be several steps up the __isa chain.
  Value? valWithMap(tac.Context context, ValuePointer<ValMap> valueFoundIn) {
    valueFoundIn.value = null;
    return this;
  }

  /// Similar to Val, but recurses into the sub-values contained by this
  /// value (if it happens to be a container, such as a list or map).
  Value? fullEval(tac.Context context) {
    return this;
  }

  /// Get the numeric value of this Value as an integer.
  int intValue() {
    return doubleValue().toInt();
  }

  /// Get the numeric value of this Value as an unsigned integer.
  int uintValue() {
    return doubleValue().toInt().toUnsigned(32);
  }

  /// Get the numeric value of this Value as a single-precision float.
  double floatValue() {
    return doubleValue().toDouble();
  }

  /// Get the numeric value of this Value as a double-precision floating-point number.
  double doubleValue() {
    return 0; // most types don't have a numeric value
  }

  /// Get the boolean (truth) value of this Value.  By default, we consider
  /// any numeric value other than zero to be true.  (But subclasses override
  /// this with different criteria for strings, lists, and maps.)
  bool boolValue() {
    return intValue() != 0;
  }

  /// Get this value in the form of a MiniScript literal.
  String codeForm(tac.Machine? vm, {int recursionLimit = -1}) {
    return toStringWithVM(vm);
  }

  /// Get a hash value for this Value.  Two values that are considered
  /// equal will return the same hash value.
  int hash();

  /// Check whether this Value is equal to another Value.
  double equality(Value? rhs);

  /// Can we set elements within this value?  (I.e., is it a list or map?)
  bool canSetElem() => false;

  /// Set an element associated with the given index within this Value.
  void setElem(Value? index, Value? value) {}

  /// Return whether this value is the given type (or some subclass thereof)
  /// in the context of the given virtual machine.
  bool isA(Value? type, tac.Machine vm) {
    return false;
  }

  /// Compare two Values for sorting purposes.
  static int compare(Value? x, Value? y) {
    // Always sort null to the end of the list.
    if (x == null) {
      if (y == null) return 0;
      return 1;
    }
    if (y == null) return -1;

    // If either argument is a string, do a string comparison
    if (x is ValString || y is ValString) {
      var sx = x.toString();
      var sy = y.toString();
      return sx.compareTo(sy);
    }

    // If both arguments are numbers, compare numerically
    if (x is ValNumber && y is ValNumber) {
      double fx = (x).value;
      double fy = (y).value;
      if (fx < fy) return -1;
      if (fx > fy) return 1;
      return 0;
    }

    // Otherwise, consider all values equal, for sorting purposes.
    return 0;
  }

  static int intBitsSize = 64;

  int _rotateBits(int n) {
    return (n >> 1) | (n << intBitsSize - 1); // Rotating for 32-bit integers
  }

  /// Compare lhs and rhs for equality, in a way that traverses down
  /// the tree when it finds a list or map.  For any other type, this
  /// just calls through to the regular Equality method.
  ///
  /// Note that this works correctly for loops (maintaining a visited
  /// list to avoid recursing indefinitely).
  bool recursiveEqual(Value rhs) {
    var toDo = <ValuePair>[];
    var visited = <ValuePair>{};
    toDo.add(ValuePair(this, rhs));

    while (toDo.isNotEmpty) {
      var pair = toDo.removeLast();
      visited.add(pair);

      if (pair.a is ValList?) {
        var listA = pair.a as ValList?;
        var listB = pair.b as ValList?;
        if (listB == null) return false;
        if (identical(listA, listB)) continue;
        int aCount = listA!.values.length;
        if (aCount != listB.values.length) return false;
        for (int i = 0; i < aCount; i++) {
          var newPair = ValuePair(listA.values[i], listB.values[i]);
          if (!visited.contains(newPair)) toDo.add(newPair);
        }
      } else if (pair.a is ValMap?) {
        var mapA = pair.a as ValMap?;
        var mapB = pair.b as ValMap?;
        if (mapB == null) return false;
        if (identical(mapA, mapB)) continue;
        if (mapA!.map.length != mapB.map.length) return false;
        for (var kv in mapA.map.entries) {
          var valFromB = mapB.map[kv.key];
          if (valFromB == null && !mapB.map.containsKey(kv.key)) {
            return false;
          }
          var newPair = ValuePair(kv.value, valFromB);
          if (!visited.contains(newPair)) toDo.add(newPair);
        }
      } else if (pair.a == null || pair.b == null) {
        if (pair.a == null || pair.b == null) return false;
      } else {
        // No other types can recurse, so we can safely do:
        if (pair.a!.equality(pair.b) == 0) return false;
      }
    }

    // If we clear out our toDo list without finding anything unequal,
    // then the values as a whole must be equal.
    return true;
  }

  /// Hash function that works correctly with nested lists and maps.
  int recursiveHash() {
    int result = 0;
    var toDo = <Value?>[];
    var visited = <Value?>{};
    toDo.add(this);

    while (toDo.isNotEmpty) {
      final item = toDo.removeLast();
      visited.add(item);

      if (item is ValList) {
        result = _rotateBits(result) ^ item.values.length.hashCode;
        for (int i = item.values.length - 1; i >= 0; i--) {
          final child = item.values[i]!;
          if (!(child is ValList || child is ValMap) ||
              !visited.contains(child)) {
            toDo.add(child);
          }
        }
      } else if (item is ValMap) {
        result = _rotateBits(result) ^ item.map.length.hashCode;
        for (var kv in item.map.entries) {
          if (!(kv.key is ValList || kv.key is ValMap) ||
              !visited.contains(kv.key)) {
            toDo.add(kv.key);
          }
          if (!(kv.value is ValList || kv.value is ValMap) ||
              !visited.contains(kv.value)) {
            toDo.add(kv.value);
          }
        }
      } else {
        // Anything else, we can safely use the standard hash method
        result = _rotateBits(result) ^ (item == null ? 0 : item.hash());
      }
    }

    return result;
  }
}
