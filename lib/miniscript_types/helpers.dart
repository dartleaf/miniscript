// Copyright © 2025 by the authors of the project. All rights reserved.

import 'package:miniscript/miniscript_types/value.dart';
import 'package:miniscript/miniscript_types/value_list.dart';
import 'package:miniscript/miniscript_types/value_number.dart';
import 'package:miniscript/miniscript_types/value_string.dart';

class Dictionary implements Map<Value?, Value?> {
  late final Map<Value?, Value?> realMap;

  Dictionary([Map<Value?, Value?> initialMap = const {}]) {
    realMap = initialMap;
  }

  Value? getExistingKey(Value? key) {
    for (var entry in realMap.entries) {
      if (isIdentical(entry.key, key)) {
        return entry.key;
      }
    }
    return key;
  }

  @override
  Value? operator [](Object? key) {
    if (key is! Value) {
      throw ArgumentError('Key must be of type Value');
    }

    return realMap[getExistingKey(key)];
  }

  @override
  void operator []=(Value? key, Value? value) {
    realMap[getExistingKey(key)] = value;
  }

  @override
  void addAll(Map<Value?, Value?> other) {
    for (var entry in other.entries) {
      final key = getExistingKey(entry.key);

      realMap[key] = entry.value;
    }
  }

  @override
  void addEntries(Iterable<MapEntry<Value?, Value?>> newEntries) {
    for (var entry in newEntries) {
      final key = getExistingKey(entry.key);

      realMap[key] = entry.value;
    }
  }

  @override
  Map<RK, RV> cast<RK, RV>() {
    throw UnimplementedError('cast<RK, RV>() is not implemented in Dictionary');
  }

  @override
  void clear() {
    realMap.clear();
  }

  @override
  bool containsKey(Object? key) {
    if (key is! Value?) {
      throw ArgumentError('Key must be of type Value');
    }

    return realMap.containsKey(getExistingKey(key));
  }

  @override
  bool containsValue(Object? value) {
    if (value is! Value?) {
      throw ArgumentError('Value must be of type Value');
    }

    for (var entry in realMap.entries) {
      if (isIdentical(entry.value, value)) {
        return true;
      }
    }

    return false;
  }

  @override
  Iterable<MapEntry<Value?, Value?>> get entries => realMap.entries;

  @override
  void forEach(void Function(Value? key, Value? value) action) {
    for (var entry in realMap.entries) {
      action(entry.key, entry.value);
    }
  }

  @override
  bool get isEmpty => realMap.isEmpty;

  @override
  bool get isNotEmpty => realMap.isNotEmpty;

  @override
  Iterable<Value?> get keys => realMap.keys;

  @override
  int get length => realMap.length;

  @override
  Map<K2, V2> map<K2, V2>(
    MapEntry<K2, V2> Function(Value? key, Value? value) convert,
  ) {
    throw UnimplementedError(
      'map<K2, V2>(convert) is not implemented in Dictionary',
    );
  }

  @override
  Value? putIfAbsent(Value? key, Value? Function() ifAbsent) {
    final existingKey = getExistingKey(key);
    if (realMap.containsKey(existingKey)) {
      return realMap[existingKey];
    } else {
      final newValue = ifAbsent();
      realMap[key] = newValue;
      return newValue;
    }
  }

  @override
  Value? remove(Object? key) {
    if (key is! Value?) {
      throw ArgumentError('Key must be of type Value');
    }

    final existingKey = getExistingKey(key);
    if (realMap.containsKey(existingKey)) {
      return realMap.remove(existingKey);
    }
    return null;
  }

  @override
  void removeWhere(bool Function(Value? key, Value? value) test) {
    realMap.removeWhere((key, value) => test(key, value));
  }

  @override
  Value? update(
    Value? key,
    Value? Function(Value? value) update, {
    Value? Function()? ifAbsent,
  }) {
    final existingKey = getExistingKey(key);
    if (realMap.containsKey(existingKey)) {
      final currentValue = realMap[existingKey];
      final newValue = update(currentValue);
      realMap[existingKey] = newValue;
      return newValue;
    }
    if (ifAbsent != null) {
      final newValue = ifAbsent();
      realMap[key] = newValue;
      return newValue;
    }
    throw ArgumentError('Key not found and no ifAbsent provided');
  }

  @override
  void updateAll(Value? Function(Value? key, Value? value) update) {
    realMap.updateAll((key, value) => update(key, value));
  }

  @override
  Iterable<Value?> get values => realMap.values;
}

/// ValuePair: used internally when working out whether two maps
/// or lists are equal.
class ValuePair {
  Value? a;
  Value? b;

  ValuePair(this.a, this.b);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ValuePair && identical(a, other.a) && identical(b, other.b);
  }

  @override
  int get hashCode {
    return a.hashCode ^ b.hashCode;
  }
}

class ValueSorter {
  static final ValueSorter instance = ValueSorter();

  int compare(Value x, Value y) {
    return Value.compare(x, y);
  }
}

class ValueReverseSorter {
  static final ValueReverseSorter instance = ValueReverseSorter();

  int compare(Value x, Value y) {
    return Value.compare(y, x);
  }
}

class RValueEqualityComparer {
  bool equals(Value val1, Value val2) {
    return val1.equality(val2) > 0;
  }

  int getHashCode(Value val) {
    return val.hash();
  }

  static RValueEqualityComparer? _instance;

  static RValueEqualityComparer get instance {
    _instance ??= RValueEqualityComparer();
    return _instance!;
  }
}

bool isIdentical(Value? a, Value? b) {
  if (a is ValString && b is ValString) {
    return a.value == b.value;
  }
  if (a is ValNumber && b is ValNumber) {
    return a.value == b.value;
  }
  if (a == null && b == null) return true;
  if (a is ValList && b is ValList) {
    if (a.values.length != b.values.length) return false;
    for (int i = 0; i < a.values.length; i++) {
      if (!isIdentical(a.values[i], b.values[i])) return false;
    }
    return true;
  }

  return identical(a, b);
}
