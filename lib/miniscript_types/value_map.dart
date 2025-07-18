// Copyright © 2025 by the authors of the project. All rights reserved.

import 'package:miniscript/miniscript_errors.dart';
import 'package:miniscript/miniscript_types/helpers.dart';
import 'package:miniscript/miniscript_types/value.dart';
import 'package:miniscript/miniscript_types/value_null.dart';
import 'package:miniscript/miniscript_types/value_seq_elem.dart';
import 'package:miniscript/miniscript_types/value_temp.dart';
import 'package:miniscript/miniscript_types/value_variable.dart';

import '../miniscript_tac/tac.dart' as tac;
import './value_string.dart' show ValString, TempValString;
import '../value_pointer.dart' show ValuePointer;

/// ValMap represents a MiniScript map, which under the hood is just a Dictionary
/// of Value, Value pairs.
class ValMap<T> extends Value {
  /// Define a maximum depth we will allow an inheritance ("__isa") chain to be.
  /// This is used to avoid locking up the app if some bozo creates a loop in
  /// the __isa chain, but it also means we can't allow actual inheritance trees
  /// to be longer than this.  So, use a reasonably generous value.
  static const int maxIsaDepth = 256;

  late final Dictionary map;

  /// Assignment override function: return true to cancel (override)
  /// the assignment, or false to allow it to happen as normal.
  bool Function(Value? key, Value? value)? assignOverride;

  // Can store arbitrary data. Useful for retaining a C# object
  // passed into scripting.
  T? userData;

  // Evaluation override function: Allows map to be fully backed
  // by a C# object (or otherwise intercept map indexing).
  // Return true to return the out value to the caller, or false
  // to proceed with normal map look-up.
  bool Function(Value? key, ValuePointer<Value> valuePointer)? evalOverride;

  ValMap([Dictionary? map]) {
    this.map = map ?? Dictionary();
  }

  /// A map is considered true if it is nonempty.
  @override
  bool boolValue() => map.isNotEmpty;

  /// Convenience method to check whether the map contains a given string key.
  bool containsKeyWithIdentifier(String identifier) {
    var idVal = TempValString.get(identifier);
    bool result = map.containsKey(idVal);
    TempValString.release(idVal);
    return result;
  }

  /// Convenience method to check whether this map contains a given key
  /// (of arbitrary type).
  bool containsKey(Value? key) {
    key ??= ValNull.instance;
    return map.containsKey(key);
  }

  /// Get the number of entries in this map.
  int get count => map.length;

  /// Return the keys list for this map.
  List<Value?> get keys => map.keys.toList();

  /// Accessor to get/set on element of this map by a string key, walking
  /// the __isa chain as needed.  (Note that if you want to avoid that, then
  /// simply look up your value in .map directly.)
  Value? operator [](String identifier) {
    var idVal = TempValString.get(identifier);
    Value? result = lookup(idVal, ValuePointer<Value>());
    TempValString.release(idVal);
    return result;
  }

  void operator []=(String identifier, Value? value) {
    map[TempValString.get(identifier)] = value;
  }

  /// Look up the given identifier in the backing map (unless overridden
  /// by the evalOverride function).
  bool tryGetValueWithIdentifier(String identifier, ValuePointer<Value> value) {
    // old method, and still better on big maps: use dictionary look-up.
    var idVal = TempValString.get(identifier);
    bool result = tryGetValue(idVal, value);
    TempValString.release(idVal);
    return result;
  }

  /// Look up the given identifier as quickly as possible, without
  /// walking the __isa chain or doing anything fancy.  (This is used
  /// when looking up local variables.)
  bool tryGetValue(Value key, ValuePointer<Value> valuePointer) {
    if (evalOverride != null && evalOverride!(key, valuePointer)) return true;

    if (map.containsKey(key)) {
      valuePointer.value = map[key];
      return true;
    }

    return false;
  }

  /// Look up a value in this dictionary, walking the __isa chain to find
  /// it in a parent object if necessary.
  Value? lookup(Value? key, ValuePointer<Value> valueFoundIn) {
    key ??= ValNull.instance;
    ValMap? obj = this;
    int chainDepth = 0;

    while (obj != null) {
      final resultPointer = ValuePointer<Value>();
      if (obj.tryGetValue(key, resultPointer)) {
        valueFoundIn.value = obj;
        return resultPointer.value;
      }
      final parentPointer = ValuePointer<Value>();
      if (!obj.tryGetValue(ValString.magicIsA, parentPointer)) break;
      if (chainDepth++ > maxIsaDepth) {
        throw RuntimeException(
          '__isa depth exceeded (perhaps a reference loop?)',
        );
      }
      obj = parentPointer.value as ValMap?;
    }

    return null;
  }

  /// Look up a value in this dictionary, walking the __isa chain to find
  /// it in a parent object if necessary; return both the value found and
  /// (via the output parameter) the map it was found in.
  Value? lookupWithMap(Value? key, ValuePointer<ValMap> valueFoundIn) {
    key ??= ValNull.instance;
    ValuePointer<Value> result = ValuePointer();
    ValMap? obj = this;
    int chainDepth = 0;

    while (obj != null) {
      if (obj.tryGetValue(key, result)) {
        valueFoundIn.value = obj;
        return result.value;
      }
      // Create a ValuePointer for parent and pass it to tryGetValue
      ValuePointer<Value> parentPointer = ValuePointer<Value>();
      if (!obj.tryGetValue(ValString.magicIsA, parentPointer)) break;
      // Now extract the value from the pointer
      Value? parent = parentPointer.value;
      if (chainDepth++ > maxIsaDepth) {
        throw RuntimeException(
          '__isa depth exceeded (perhaps a reference loop?)',
        );
      }
      obj = parent as ValMap?;
    }

    valueFoundIn.value = null;
    return null;
  }

  @override
  Value fullEval(tac.Context context) {
    // Evaluate each of our elements, and if any of those is
    // a variable or temp, then resolve those now.

    for (var key in map.keys.toList()) {
      final value = map[key];
      if (key is ValTemp || key is ValVar) {
        map.remove(key);
        var newKey = key?.val(context);
        map[newKey] = value;
      }
      if (value is ValTemp || value is ValVar) {
        map[key] = value?.val(context);
      }
    }
    return this;
  }

  ValMap evalCopy(tac.Context context) {
    // Create a copy of this map, evaluating its members as we go.
    // This is used when a map literal appears in the source, to
    // ensure that each time that code executes, we get a new, distinct
    // mutable object, rather than the same object multiple times.
    ValMap result = ValMap();
    for (Value? key in map.keys) {
      Value? value = map[key];
      if (key is ValTemp || key is ValVar || key is ValSeqElem) {
        key = key?.val(context);
      }
      if (value is ValTemp || value is ValVar || value is ValSeqElem) {
        value = value?.val(context);
      }
      result.map[key] = value;
    }
    return result;
  }

  @override
  String codeForm(tac.Machine? vm, {int recursionLimit = -1}) {
    if (recursionLimit == 0) return '{...}';
    if (recursionLimit > 0 && recursionLimit < 3) {
      String? shortName = vm?.findShortName(this);
      if (shortName != null) return shortName;
    }

    var strs = <String>[];
    for (var kv in map.entries) {
      var nextRecurLimit = recursionLimit - 1;
      if (kv.key == ValString.magicIsA) nextRecurLimit = 1;
      strs.add(
        '${kv.key?.codeForm(vm, recursionLimit: nextRecurLimit)}: '
        '${kv.value?.codeForm(vm, recursionLimit: nextRecurLimit)}',
      );
    }
    return '{${strs.join(", ")}}';
  }

  @override
  String toStringWithVM([tac.Machine? vm]) {
    return codeForm(vm, recursionLimit: 3);
  }

  @override
  bool isA(Value? type, tac.Machine vm) {
    if (type == null) return false;
    // If the given type is the magic 'map' type, then we're definitely
    // one of those.  Otherwise, we have to walk the __isa chain.
    if (type == vm.mapType) return true;

    var pointer = ValuePointer<ValMap>();
    tryGetValueWithIdentifier(ValString.magicIsA.value, pointer);
    int chainDepth = 0;

    while (pointer.value != null) {
      if (pointer.value == type) return true;
      if (pointer.value is! ValMap) return false;
      if (chainDepth++ > maxIsaDepth) {
        throw RuntimeException(
          '__isa depth exceeded (perhaps a reference loop?)',
        );
      }
      pointer.value!.tryGetValue(ValString.magicIsA, pointer);
    }

    return false;
  }

  @override
  int hash() => recursiveHash();

  @override
  double equality(Value? rhs) {
    // Quick bail-out cases:
    if (rhs is! ValMap) return 0;
    final rhm = rhs.map;
    if (identical(rhm, map)) return 1; // (same map)
    if (map.length != rhm.length) return 0;
    // Otherwise:
    return recursiveEqual(rhs) ? 1 : 0;
  }

  @override
  bool canSetElem() => true;

  /// Set the value associated with the given key (index).  This is where
  /// we take the opportunity to look for an assignment override function,
  /// and if found, give that a chance to handle it instead.
  @override
  void setElem(Value? index, Value? value) {
    index ??= ValNull.instance;
    if (assignOverride == null || !assignOverride!(index, value)) {
      for (final kv in map.entries) {
        if (isIdentical(kv.key, index)) {
          map[kv.key] = value;
          return; // (we found it, so just update the value)
        }
      }

      map[index] = value; // (not found, so add a new entry)
    }
  }

  /// Get the indicated key/value pair as another map containing "key" and "value".
  /// (This is used when iterating over a map with "for".)
  ValMap getKeyValuePair(int index) {
    if (index < 0 || index >= map.length) {
      throw MiniscriptException('index $index out of range for map');
    }

    final key = map.keys
        .elementAtOrNull(index); // (TODO: consider more efficient methods here)
    var result = ValMap();
    result.map[keyStr] = key;
    result.map[valStr] = map[key];
    return result;
  }

  static final keyStr = ValString('key');
  static final valStr = ValString('value');
}
