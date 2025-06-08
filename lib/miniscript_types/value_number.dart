// Copyright © 2025 by the authors of the project. All rights reserved.

import 'package:miniscript/miniscript_types/value.dart';

import '../miniscript_tac/tac.dart' as tac;

/// ValNumber represents a numeric (double-precision floating point) value in MiniScript.
/// Since we also use numbers to represent boolean values, ValNumber does that job too.
class ValNumber extends Value {
  final double value;

  ValNumber(this.value);

  @override
  String toStringWithVM([tac.Machine? vm]) {
    return formatValue().replaceAll('e-', 'E-0');
  }

  String formatValue() {
    // Convert to a string in the standard MiniScript way.
    if (value % 1.0 == 0.0) {
      // integer values as integers
      String result = value.toStringAsFixed(0);
      if (result == "-0") result = "0";
      return result;
    } else if (value > 1E10 ||
        value < -1E10 ||
        (value < 1E-6 && value > -1E-6)) {
      // very large/small numbers in exponential form
      String s = value.toStringAsExponential(6);
      return s;
    } else {
      // all others in decimal form, with 1-6 digits past the decimal point;
      // and take care not to display "-0" for "negative" 0.0
      String result = _formatDecimal(value);
      if (result == "-0") result = "0";
      return result;
    }
  }

  String _formatDecimal(double num) {
    // Helper function to format decimal numbers with up to 6 decimal places
    String str = num.toString();
    if (str.contains('.')) {
      List<String> parts = str.split('.');
      String decimalPart = parts[1];
      if (decimalPart.length > 6) {
        decimalPart = decimalPart.substring(0, 6);
        // Remove trailing zeros
        decimalPart = decimalPart.replaceAll(RegExp(r'0+$'), '');
        if (decimalPart.isEmpty) {
          return parts[0];
        }
        return '${parts[0]}.$decimalPart';
      }
    }
    return str;
  }

  @override
  int intValue() {
    return value.toInt();
  }

  @override
  double doubleValue() {
    return value;
  }

  @override
  bool boolValue() {
    // Any nonzero value is considered true, when treated as a bool.
    return value != 0;
  }

  @override
  bool isA(Value? type, tac.Machine vm) {
    if (type == null) return false;
    return type == vm.numberType;
  }

  @override
  int hash() {
    return value.hashCode;
  }

  @override
  double equality(Value? rhs) {
    return rhs is ValNumber && rhs.value == value ? 1 : 0;
  }

  static final ValNumber _zero = ValNumber(0);
  static final ValNumber _one = ValNumber(1);

  /// Handy accessor to a shared "zero" (0) value.
  /// IMPORTANT: do not alter the value of the object returned!
  static ValNumber get zero => _zero;

  /// Handy accessor to a shared "one" (1) value.
  /// IMPORTANT: do not alter the value of the object returned!
  static ValNumber get one => _one;

  /// Convenience method to get a reference to zero or one, according
  /// to the given boolean.  (Note that this only covers Boolean
  /// truth values; MiniScript also allows fuzzy truth values, like
  /// 0.483, but obviously this method won't help with that.)
  /// IMPORTANT: do not alter the value of the object returned!
  static ValNumber truth(bool truthValue) {
    return truthValue ? one : zero;
  }

  /// Basically this just makes a ValNumber out of a double,
  /// BUT it is optimized for the case where the given value
  ///	is either 0 or 1 (as is usually the case with truth tests).
  static ValNumber truthFromDouble(double truthValue) {
    if (truthValue == 0.0) return zero;
    if (truthValue == 1.0) return one;
    return ValNumber(truthValue);
  }
}
