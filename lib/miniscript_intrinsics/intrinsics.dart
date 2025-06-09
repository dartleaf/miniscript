// Copyright © 2025 by the authors of the project. All rights reserved.

import 'dart:math' as math;
import 'package:miniscript/miniscript_errors.dart';
import 'package:miniscript/miniscript_intrinsics/host_info.dart';
import 'package:miniscript/miniscript_intrinsics/intrinsic.dart';
import 'package:miniscript/miniscript_intrinsics/intrinsic_code.dart';
import 'package:miniscript/miniscript_intrinsics/intrinsic_result.dart';
import 'package:miniscript/miniscript_tac/tac.dart' as tac;
import 'package:miniscript/miniscript_types/value.dart';
import 'package:miniscript/miniscript_types/value_list.dart';
import 'package:miniscript/miniscript_types/value_map.dart';
import 'package:miniscript/miniscript_types/value_string.dart';
import 'package:miniscript/miniscript_types/value_number.dart';
import 'package:miniscript/miniscript_types/value_null.dart';
import 'package:miniscript/miniscript_types/function.dart';

/// Helper class for sorting values with keys
class _KeyedValue {
  Value? sortKey;
  Value? value;
}

/// Intrinsics: a class containing all standard MiniScript built-in intrinsics.
class Intrinsics {
  static bool initialized = false;
  static ValMap? intrinsicsMap;
  static math.Random? random;
  static ValMap? _functionType;
  static ValMap? _listType;
  static ValMap? _mapType;
  static ValMap? _stringType;
  static ValMap? _numberType;
  static const String _stackAtBreak = "_stackAtBreak";

  /// Helper method to get a stack trace as a list of values
  static ValList stackList(tac.Machine? vm) {
    final result = ValList();
    if (vm == null) return result;
    for (final loc in vm.getStack()) {
      var s = loc!.context;
      if (s == null || s.isEmpty) s = "(current program)";
      s += " line ${loc.lineNum}";
      result.values.add(ValString(s));
    }
    return result;
  }

  /// Initialize all standard intrinsics if not already done
  static void initIfNeeded() {
    if (initialized) return;
    initialized = true;

    Intrinsic f;

    // abs
    //	Returns the absolute value of the given number.
    // x (number, default 0): number to take the absolute value of.
    // Example: abs(-42)		returns 42
    f = Intrinsic.create("abs");
    f.addParam("x", ValNumber.zero);
    f.code = (context, [partialResult]) {
      final x = context.getLocalDouble("x")!;
      return IntrinsicResult.fromNum((x.abs()));
    };

    // acos
    //	Returns the inverse cosine, that is, the angle
    //	(in radians) whose cosine is the given value.
    // x (number, default 0): cosine of the angle to find.
    // Returns: angle, in radians, whose cosine is x.
    // Example: acos(0) 		returns 1.570796
    f = Intrinsic.create("acos");
    f.addParam("x", ValNumber.zero);
    f.code = (context, [partialResult]) {
      final x = context.getLocalDouble("x")!;
      return IntrinsicResult.fromNum((math.acos(x)));
    };

    // asin
    //	Returns the inverse sine, that is, the angle
    //	(in radians) whose sine is the given value.
    // x (number, default 0): cosine of the angle to find.
    // Returns: angle, in radians, whose cosine is x.
    // Example: asin(1) return 1.570796
    f = Intrinsic.create("asin");
    f.addParam("x", ValNumber.zero);
    f.code = (context, [partialResult]) {
      final x = context.getLocalDouble("x")!;
      return IntrinsicResult.fromNum((math.asin(x)));
    };

    // atan
    //	Returns the arctangent of a value or ratio, that is, the
    //	angle (in radians) whose tangent is y/x.  This will return
    //	an angle in the correct quadrant, taking into account the
    //	sign of both arguments.  The second argument is optional,
    //	and if omitted, this function is equivalent to the traditional
    //	one-parameter atan function.  Note that the parameters are
    //	in y,x order.
    // y (number, default 0): height of the side opposite the angle
    // x (number, default 1): length of the side adjacent the angle
    // Returns: angle, in radians, whose tangent is y/x
    // Example: atan(1, -1)		returns 2.356194
    f = Intrinsic.create("atan");
    f.addParam("y", ValNumber.zero);
    f.addParam("x", ValNumber.one);
    f.code = (context, [partialResult]) {
      final y = context.getLocalDouble("y")!;
      final x = context.getLocalDouble("x")!;
      if (x == 1.0) return IntrinsicResult.fromNum((math.atan(y)));
      return IntrinsicResult.fromNum((math.atan2(y, x)));
    };

    // helper function for bit operations
    doubleToUnsignedSplit(double val) {
      final sign = val < 0;
      final unsignedVal = val.abs().toInt();
      return (sign, unsignedVal);
    }

    // bitAnd
    //	Treats its arguments as integers, and computes the bitwise
    //	`and`: each bit in the result is set only if the corresponding
    //	bit is set in both arguments.
    // i (number, default 0): first integer argument
    // j (number, default 0): second integer argument
    // Returns: bitwise `and` of i and j
    // Example: bitAnd(14, 7)		returns 6
    // See also: bitOr; bitXor
    f = Intrinsic.create("bitAnd");
    f.addParam("i", ValNumber.zero);
    f.addParam("j", ValNumber.zero);
    f.code = (context, [partialResult]) {
      final i = doubleToUnsignedSplit(context.getLocalDouble("i")!);
      final j = doubleToUnsignedSplit(context.getLocalDouble("j")!);
      final sign = i.$1 && j.$1;
      final val = i.$2 & j.$2;
      return IntrinsicResult.fromNum((sign ? -val : val).toDouble());
    };

    // bitOr
    //	Treats its arguments as integers, and computes the bitwise
    //	`or`: each bit in the result is set if the corresponding
    //	bit is set in either (or both) of the arguments.
    // i (number, default 0): first integer argument
    // j (number, default 0): second integer argument
    // Returns: bitwise `or` of i and j
    // Example: bitOr(14, 7)		returns 15
    // See also: bitAnd; bitXor
    f = Intrinsic.create("bitOr");
    f.addParam("i", ValNumber.zero);
    f.addParam("j", ValNumber.zero);
    f.code = (context, [partialResult]) {
      final i = doubleToUnsignedSplit(context.getLocalDouble("i")!);
      final j = doubleToUnsignedSplit(context.getLocalDouble("j")!);
      final sign = i.$1 || j.$1;
      final val = i.$2 | j.$2;
      return IntrinsicResult.fromNum((sign ? -val : val).toDouble());
    };

    // bitXor
    //	Treats its arguments as integers, and computes the bitwise
    //	`xor`: each bit in the result is set only if the corresponding
    //	bit is set in exactly one (not zero or both) of the arguments.
    // i (number, default 0): first integer argument
    // j (number, default 0): second integer argument
    // Returns: bitwise `xor` of i and j
    // Example: bitXor(14, 7)		returns 9
    // See also: bitAnd; bitOr
    f = Intrinsic.create("bitXor");
    f.addParam("i", ValNumber.zero);
    f.addParam("j", ValNumber.zero);
    f.code = (context, [partialResult]) {
      var i = doubleToUnsignedSplit(context.getLocalDouble("i")!);
      var j = doubleToUnsignedSplit(context.getLocalDouble("j")!);
      final sign = i.$1 != j.$1;
      final val = i.$2 ^ j.$2;
      return IntrinsicResult.fromNum(((sign ? -val : val).toDouble()));
    };

    // char
    //	Gets a character from its Unicode code point.
    // codePoint (number, default 65): Unicode code point of a character
    // Returns: string containing the specified character
    // Example: char(42)		returns "*"
    // See also: code
    f = Intrinsic.create("char");
    f.addParam("codePoint", ValNumber(65));
    f.code = (context, [partialResult]) {
      final codePoint = context.getLocalInt("codePoint")!;
      final char = String.fromCharCode(codePoint);
      return IntrinsicResult(ValString(char));
    };

    // ceil
    //	Returns the "ceiling", i.e. closest whole number
    //	greater than or equal to the given number.
    // x (number, default 0): number to get the ceiling of
    // Returns: closest whole number not less than x
    // Example: ceil(41.2)		returns 42
    // See also: floor
    f = Intrinsic.create("ceil");
    f.addParam("x", ValNumber.zero);
    f.code = (context, [partialResult]) {
      final x = context.getLocalDouble("x")!;
      return IntrinsicResult.fromNum((x.ceil().toDouble()));
    };

    // code
    //	Return the Unicode code point of the first character of
    //	the given string.  This is the inverse of `char`.
    //	May be called with function syntax or dot syntax.
    // self (string): string to get the code point of
    // Returns: Unicode code point of the first character of self
    // Example: "*".code		returns 42
    // Example: code("*")		returns 42
    f = Intrinsic.create("code");
    f.addParam("self");
    f.code = (context, [partialResult]) {
      final self = context.self!;
      final s = self.toString();
      if (s.isEmpty) return IntrinsicResult.false_;
      final runes = s.runes;
      return IntrinsicResult.fromNum((runes.first.toDouble()));
    };

    // cos
    //	Returns the cosine of the given angle (in radians).
    // radians (number): angle, in radians, to get the cosine of
    // Returns: cosine of the given angle
    // Example: cos(0)		returns 1
    f = Intrinsic.create("cos");
    f.addParam("radians", ValNumber.zero);
    f.code = (context, [partialResult]) {
      final radians = context.getLocalDouble("radians")!;
      return IntrinsicResult.fromNum((math.cos(radians)));
    };

    // floor
    //	Returns the "floor", i.e. closest whole number
    //	less than or equal to the given number.
    // x (number, default 0): number to get the floor of
    // Returns: closest whole number not more than x
    // Example: floor(42.9)		returns 42
    // See also: floor
    f = Intrinsic.create("floor");
    f.addParam("x", ValNumber.zero);
    f.code = (context, [partialResult]) {
      final x = context.getLocalDouble("x")!;
      return IntrinsicResult.fromNum((x.floor().toDouble()));
    };

    // funcRef
    //	Returns a map that represents a function reference in
    //	MiniScript's core type system.  This can be used with `isa`
    //	to check whether a variable refers to a function (but be
    //	sure to use @ to avoid invoking the function and testing
    //	the result).
    // Example: @floor isa funcRef		returns 1
    // See also: number, string, list, map
    f = Intrinsic.create("funcRef");
    f.code = (context, [partialResult]) {
      context.vm?.functionType ??=
          functionType().evalCopy(context.vm!.globalContext!);
      return IntrinsicResult(context.vm!.functionType!);
    };

    // hash
    //	Returns an integer that is "relatively unique" to the given value.
    //	In the case of strings, the hash is case-sensitive.  In the case
    //	of a list or map, the hash combines the hash values of all elements.
    //	Note that the value returned is platform-dependent, and may vary
    //	across different MiniScript implementations.
    // obj (any type): value to hash
    // Returns: integer hash of the given value
    f = Intrinsic.create("hash");
    f.addParam("obj");
    f.code = (context, [partialResult]) {
      return IntrinsicResult.fromNum(
        context.getLocal("obj")!.hash().toDouble(),
      );
    };

    // hasIndex
    //	Return whether the given index is valid for this object, that is,
    //	whether it could be used with square brackets to get some value
    //	from self.  When self is a list or string, the result is true for
    //	integers from -(length of string) to (length of string-1).  When
    //	self is a map, it is true for any key (index) in the map.  If
    //	called on a number, this method throws a runtime exception.
    // self (string, list, or map): object to check for an index on
    // index (any): value to consider as a possible index
    // Returns: 1 if self[index] would be valid; 0 otherwise
    // Example: "foo".hasIndex(2)		returns 1
    // Example: "foo".hasIndex(3)		returns 0
    // See also: indexes
    f = Intrinsic.create("hasIndex");
    f.addParam("self");
    f.addParam("index");
    f.code = (context, [partialResult]) {
      final self = context.self!;
      final index = context.getLocal("index");

      if (self is ValList) {
        if (index is ValNumber) {
          final list = (self).values;
          final i = index.intValue();
          return IntrinsicResult(
              ValNumber.truth(i >= -list.length && i < list.length));
        }
        return IntrinsicResult.false_;
      } else if (self is ValString) {
        if (index is ValNumber) {
          final str = (self).value;
          final i = index.intValue();
          return IntrinsicResult(
              ValNumber.truth(i >= -str.length && i < str.length));
        }
        return IntrinsicResult.false_;
      } else if (self is ValMap) {
        final map = self;
        return IntrinsicResult.fromTruth((map.containsKey(index)));
      }
      return IntrinsicResult.null_;
    };

    // indexes
    //	Returns the keys of a dictionary, or the non-negative indexes
    //	for a string or list.
    // self (string, list, or map): object to get the indexes of
    // Returns: a list of valid indexes for self
    // Example: "foo".indexes		returns [0, 1, 2]
    // See also: hasIndex
    f = Intrinsic.create("indexes");
    f.addParam("self");
    f.code = (context, [partialResult]) {
      final self = context.self;
      if (self is ValMap) {
        final keys = List<Value?>.from(self.map.keys);
        for (int i = 0; i < keys.length; i++) {
          if (keys[i] == null) keys[i] = null;
        }
        return IntrinsicResult(ValList(keys));
      } else if (self is ValString) {
        final str = (self).value;
        final indexes =
            List<Value>.generate(str.length, (i) => ValNumber(i.toDouble()));
        return IntrinsicResult(ValList(indexes));
      } else if (self is ValList) {
        final indexes = List<Value>.generate(
          self.values.length,
          (i) => tac.num(i.toDouble()),
        );
        return IntrinsicResult(ValList(indexes));
      }
      return IntrinsicResult.null_;
    };

    // indexOf
    //	Returns index or key of the given value, or if not found,		returns null.
    // self (string, list, or map): object to search
    // value (any): value to search for
    // after (any, optional): if given, starts the search after this index
    // Returns: first index (after `after`) such that self[index] == value, or null
    // Example: "Hello World".indexOf("o")		returns 4
    // Example: "Hello World".indexOf("o", 4)		returns 7
    // Example: "Hello World".indexOf("o", 7)		returns null
    f = Intrinsic.create("indexOf");
    f.addParam("self");
    f.addParam("value");
    f.addParam("after");
    f.code = (context, [partialResult]) {
      final self = context.self;
      final value = context.getLocal("value");
      final after = context.getLocal("after");

      if (self is ValList) {
        final list = self.values;
        int idx;

        if (after == null) {
          idx = list.indexWhere(
              (x) => x == null ? value == null : x.equality(value) == 1);
        } else {
          var afterIdx = after.intValue();
          if (afterIdx < -1) afterIdx += list.length;
          if (afterIdx < -1 || afterIdx >= list.length - 1) {
            return IntrinsicResult.null_;
          }

          idx = list.indexWhere(
              (x) => x == null ? value == null : x.equality(value) == 1,
              afterIdx + 1);
        }

        if (idx >= 0) return IntrinsicResult.fromNum(idx.toDouble());
      } else if (self is ValString) {
        final str = self.value;
        if (value == null) return IntrinsicResult.null_;

        final s = value.toString();
        int idx;

        if (after == null) {
          idx = str.indexOf(s);
        } else {
          var afterIdx = after.intValue();
          if (afterIdx < -1) afterIdx += str.length;
          if (afterIdx < -1 || afterIdx >= str.length - 1) {
            return IntrinsicResult.null_;
          }

          idx = str.indexOf(s, afterIdx + 1);
        }

        if (idx >= 0) return IntrinsicResult.fromNum(idx.toDouble());
      } else if (self is ValMap) {
        final map = self;
        var sawAfter = (after == null);

        for (final key in map.map.keys) {
          if (!sawAfter) {
            if (key?.equality(after) == 1) sawAfter = true;
          } else {
            final mapValue = map.map[key];
            if (mapValue == null
                ? value == null
                : mapValue.equality(value) == 1) {
              return IntrinsicResult(key);
            }
          }
        }
      }

      return IntrinsicResult.null_;
    };

    // insert
    //	Insert a new element into a string or list.  In the case of a list,
    //	the list is both modified in place and returned.  Strings are immutable,
    //	so in that case the original string is unchanged, but a new string is
    //	returned with the value inserted.
    // self (string or list): sequence to insert into
    // index (number): position at which to insert the new item
    // value (any): element to insert at the specified index
    // Returns: modified list, new string
    // Example: "Hello".insert(2, 42)		returns "He42llo"
    // See also: remove
    f = Intrinsic.create("insert");
    f.addParam("self");
    f.addParam("index");
    f.addParam("value");
    f.code = (context, [partialResult]) {
      final self = context.self;
      final index = context.getLocal("index");
      final value = context.getLocal("value");

      if (index == null) {
        throw RuntimeException("insert: index argument required");
      }
      if (index is! ValNumber) {
        throw RuntimeException("insert: number required for index argument");
      }

      var idx = index.intValue();

      if (self is ValList) {
        final list = (self).values;
        if (idx < 0) {
          idx += list.length +
              1; // +1 because we are inserting AND counting from the end
        }
        Check.range(idx, 0,
            list.length); // allowing all the way up to .length here, because insert
        list.insert(idx, value);
        return IntrinsicResult(self);
      } else if (self is ValString) {
        final s = (self).value;
        if (idx < 0) idx += s.length + 1;
        Check.range(idx, 0, s.length);
        final newStr =
            s.substring(0, idx) + value.toString() + s.substring(idx);
        return IntrinsicResult(ValString(newStr));
      } else {
        throw RuntimeException("insert called on invalid type");
      }
    };

    // intrinsics
    //	Returns a read-only map of all named intrinsics.
    f = Intrinsic.create("intrinsics");
    f.code = (context, [partialResult]) {
      if (intrinsicsMap != null) return IntrinsicResult(intrinsicsMap!);

      intrinsicsMap = ValMap();
      intrinsicsMap!.assignOverride = (k, v) {
        throw RuntimeException("Assignment to protected map");
      };

      for (var intrinsic in Intrinsic.all) {
        if (intrinsic == null || intrinsic.name.isEmpty) continue;
        intrinsicsMap!.map[ValString(intrinsic.name)] = intrinsic.getFunc();
      }

      return IntrinsicResult(intrinsicsMap);
    };

    // self.join
    //	Join the elements of a list together to form a string.
    // self (list): list to join
    // delimiter (string, default " "): string to insert between each pair of elements
    // Returns: string built by joining elements of self with delimiter
    // Example: [2,4,8].join("-")		returns "2-4-8"
    // See also: split
    f = Intrinsic.create("join");
    f.addParam("self");
    f.addParam("delimiter", ValString(" "));
    f.code = (context, [partialResult]) {
      final val = context.self;
      final delim = context.getLocalString("delimiter")!;

      if (val is! ValList) return IntrinsicResult(val);

      final src = val;
      final list = [];

      for (var i = 0; i < src.values.length; i++) {
        if (src.values[i] == null) {
          list.add(null);
        } else {
          list.add(src.values[i].toString());
        }
      }

      final result = list.join(delim);
      return IntrinsicResult(ValString(result));
    };

    // self.len
    //	Return the number of characters in a string, elements in
    //	a list, or key/value pairs in a map.
    //	May be called with function syntax or dot syntax.
    // self (list, string, or map): object to get the length of
    // Returns: length (number of elements) in self
    // Example: "hello".len		returns 5
    f = Intrinsic.create("len");
    f.addParam("self");
    f.code = (context, [partialResult]) {
      final val = context.self;

      if (val is ValList) {
        return IntrinsicResult.fromNum((val).values.length.toDouble());
      } else if (val is ValString) {
        return IntrinsicResult.fromNum((val).value.length.toDouble());
      } else if (val is ValMap) {
        return IntrinsicResult.fromNum((val).count.toDouble());
      }

      return IntrinsicResult.null_;
    };

    // list type
    //	Returns a map that represents the list datatype in
    //	MiniScript's core type system.  This can be used with `isa`
    //	to check whether a variable refers to a list.  You can also
    //	assign new methods here to make them available to all lists.
    // Example: [1, 2, 3] isa list		returns 1
    // See also: number, string, map, funcRef
    f = Intrinsic.create("list");
    f.code = (context, [partialResult]) {
      context.vm?.listType ??= listType().evalCopy(context.vm!.globalContext!);
      return IntrinsicResult(context.vm!.listType);
    };

    // log(x, base)
    //	Returns the logarithm (with the given) of the given number,
    //	that is, the number y such that base^y = x.
    // x (number): number to take the log of
    // base (number, default 10): logarithm base
    // Returns: a number that, when base is raised to it, produces x
    // Example: log(1000)		returns 3 (because 10^3 == 1000)
    f = Intrinsic.create("log");
    f.addParam("x", ValNumber.zero);
    f.addParam("base", ValNumber(10));
    f.code = (context, [partialResult]) {
      final x = context.getLocalDouble("x")!;
      final b = context.getLocalDouble("base")!;

      double result;
      if ((b - 2.718282).abs() < 0.000001) {
        result = math.log(x);
      } else {
        result = math.log(x) / math.log(b);
      }

      return IntrinsicResult.fromNum(result);
    };

    // lower
    //	Return a lower-case version of a string.
    //	May be called with function syntax or dot syntax.
    // self (string): string to lower-case
    // Returns: string with all capital letters converted to lowercase
    // Example: "Mo Spam".lower		returns "mo spam"
    // See also: upper
    f = Intrinsic.create("lower");
    f.addParam("self");
    f.code = (context, [partialResult]) {
      final val = context.self;

      if (val is ValString) {
        return IntrinsicResult(ValString(val.value.toLowerCase()));
      }

      return IntrinsicResult(val);
    };

    // map type
    //	Returns a map that represents the map datatype in
    //	MiniScript's core type system.  This can be used with `isa`
    //	to check whether a variable refers to a map.  You can also
    //	assign new methods here to make them available to all maps.
    // Example: {1:"one"} isa map		returns 1
    // See also: number, string, list, funcRef
    f = Intrinsic.create("map");
    f.code = (context, [partialResult]) {
      context.vm?.mapType ??= mapType().evalCopy(context.vm!.globalContext!);
      return IntrinsicResult(context.vm!.mapType);
    };

    // number type
    //	Returns a map that represents the number datatype in
    //	MiniScript's core type system.  This can be used with `isa`
    //	to check whether a variable refers to a number.  You can also
    //	assign new methods here to make them available to all maps
    //	(though because of a limitation in MiniScript's parser, such
    //	methods do not work on numeric literals).
    // Example: 42 isa number		returns 1
    // See also: string, list, map, funcRef
    f = Intrinsic.create("number");
    f.code = (context, [partialResult]) {
      context.vm?.numberType ??=
          numberType().evalCopy(context.vm!.globalContext!);
      return IntrinsicResult(context.vm!.numberType!);
    };

    // pi
    //	Returns the universal constant π, that is, the ratio of
    //	a circle's circumference to its diameter.
    // Example: pi		returns 3.141593
    f = Intrinsic.create("pi");
    f.code = (context, [partialResult]) {
      return IntrinsicResult.fromNum(math.pi);
    };

    // print
    //	Display the given value on the default output stream.  The
    //	exact effect may vary with the environment.  In most cases, the
    //	given string will be followed by the standard line delimiter
    //	(unless overridden with the second parameter).
    // s (any): value to print (converted to a string as needed)
    // delimiter (string or null): string to print after s; if null, use standard EOL
    // Returns: null
    // Example: print 6*7
    f = Intrinsic.create("print");
    f.addParam("s", ValString.empty);
    f.addParam("delimiter");
    f.code = (context, [partialResult]) {
      final sVal = context.getLocal("s");
      final s = sVal == null ? "null" : sVal.toString();
      final delimVal = context.getLocal("delimiter");

      if (delimVal == null) {
        context.vm!.standardOutput(s, true);
      } else {
        context.vm!.standardOutput(s + delimVal.toString(), false);
      }

      return IntrinsicResult.null_;
    };

    // pop
    //	Removes and	returns the last item in a list, or an arbitrary
    //	key of a map.  If the list or map is empty (or if called on
    //	any other data type), returns null.
    //	May be called with function syntax or dot syntax.
    // self (list or map): object to remove an element from the end of
    // Returns: value removed, or null
    // Example: [1, 2, 3].pop		returns (and removes) 3
    // See also: pull; push; remove
    f = Intrinsic.create("pop");
    f.addParam("self");
    f.code = (context, [partialResult]) {
      final self = context.self;

      if (self is ValList) {
        final list = self.values;
        if (list.isEmpty) return IntrinsicResult.null_;

        final result = list.last;
        list.removeLast();
        return IntrinsicResult(result);
      } else if (self is ValMap) {
        final map = self;
        if (map.map.isEmpty) return IntrinsicResult.null_;

        final key = map.map.keys.last;
        map.map.remove(key);
        return IntrinsicResult(key);
      }

      return IntrinsicResult.null_;
    };

    // pull
    //	Removes and	returns the first item in a list, or an arbitrary
    //	key of a map.  If the list or map is empty (or if called on
    //	any other data type), returns null.
    //	May be called with function syntax or dot syntax.
    // self (list or map): object to remove an element from the end of
    // Returns: value removed, or null
    // Example: [1, 2, 3].pull		returns (and removes) 1
    // See also: pop; push; remove
    f = Intrinsic.create("pull");
    f.addParam("self");
    f.code = (context, [partialResult]) {
      final self = context.self;

      if (self is ValList) {
        final list = self.values;
        if (list.isEmpty) return IntrinsicResult.null_;

        final result = list.first;
        list.removeAt(0);
        return IntrinsicResult(result);
      } else if (self is ValMap) {
        final map = self;
        if (map.map.isEmpty) return IntrinsicResult.null_;

        final key = map.map.keys.first;
        map.map.remove(key);
        return IntrinsicResult(key);
      }

      return IntrinsicResult.null_;
    };

    // push
    //	Appends an item to the end of a list, or inserts it into a map
    //	as a key with a value of 1.
    //	May be called with function syntax or dot syntax.
    // self (list or map): object to append an element to
    // Returns: self
    // See also: pop, pull, insert
    f = Intrinsic.create("push");
    f.addParam("self");
    f.addParam("value");
    f.code = (context, [partialResult]) {
      final self = context.self;
      final value = context.getLocal("value");

      if (self is ValList) {
        self.values.add(value);
        return IntrinsicResult(self);
      } else if (self is ValMap) {
        self.map[value] = ValNumber.one;
        return IntrinsicResult(self);
      }

      return IntrinsicResult(self);
    };

    // range
    //	Return a list containing a series of numbers within a range.
    // from (number, default 0): first number to include in the list
    // to (number, default 0): point at which to stop adding numbers to the list
    // step (number, optional): amount to add to the previous number on each step;
    //	defaults to 1 if to > from, or -1 if to < from
    // Example: range(50, 5, -10)		returns [50, 40, 30, 20, 10]
    f = Intrinsic.create("range");
    f.addParam("from", ValNumber.zero);
    f.addParam("to", ValNumber.zero);
    f.addParam("step");
    f.code = (context, [partialResult]) {
      final p0 = context.getLocal("from")!;
      final p1 = context.getLocal("to")!;
      final p2 = context.getLocal("step");

      final fromVal = p0.doubleValue();
      final toVal = p1.doubleValue();
      var step = (toVal >= fromVal ? 1.0 : -1);

      if (p2 is ValNumber) {
        step = p2.value;
      }

      if (step == 0) {
        throw RuntimeException("range() error (step==0)");
      }

      final values = <Value>[];
      final count = ((toVal - fromVal) / step).floor() + 1;

      if (count > ValList.maxSize) {
        throw LimitExceededException("list too large");
      }

      try {
        for (var v = fromVal;
            step > 0 ? (v <= toVal) : (v >= toVal);
            v += step) {
          values.add(tac.num(v));
        }
      } catch (e) {
        // uh-oh... probably out-of-memory exception; clean up and bail out
        values.clear();
        throw LimitExceededException("range() error", e as Exception);
      }

      return IntrinsicResult(ValList(values));
    };

    // refEquals
    //	Tests whether two values refer to the very same object (rather than
    //	merely representing the same value).  For numbers, this is the same
    //	as ==, but for strings, lists, and maps, it is reference equality.
    f = Intrinsic.create("refEquals");
    f.addParam("a");
    f.addParam("b");
    f.code = (context, [partialResult]) {
      final a = context.getLocal("a");
      final b = context.getLocal("b");
      var result = false;

      if (a == null) {
        result = (b == null);
      } else if (a is ValNumber) {
        result = (b is ValNumber && a.doubleValue() == b.doubleValue());
      } else if (a is ValString) {
        result = (b is ValString && identical(a.value, b.value));
      } else if (a is ValList) {
        result = (b is ValList && identical(a.values, b.values));
      } else if (a is ValMap) {
        result = (b is ValMap && identical(a.map, b.map));
      } else if (a is ValFunction) {
        result = (b is ValFunction && identical(a.function, b.function));
      } else {
        result = (a.equality(b) >= 1);
      }

      return IntrinsicResult.fromTruth((result));
    };

    // remove
    //	Removes part of a list, map, or string.  Exact behavior depends on
    //	the data type of self:
    // 		list: removes one element by its index; the list is mutated in place;
    //			returns null, and throws an error if the given index out of range
    //		map: removes one key/value pair by key; the map is mutated in place;
    //			returns 1 if key was found, 0 otherwise
    //		string:	returns a new string with the first occurrence of k removed
    //	May be called with function syntax or dot syntax.
    // self (list, map, or string): object to remove something from
    // k (any): index or substring to remove
    // Returns: (see above)
    // Example: a=["a","b","c"]; a.remove 1		leaves a == ["a", "c"]
    // Example: d={"ichi":"one"}; d.remove "ni"		returns 0
    // Example: "Spam".remove("S")		returns "pam"
    // See also: indexOf
    f = Intrinsic.create("remove");
    f.addParam("self");
    f.addParam("k");
    f.code = (context, [partialResult]) {
      final self = context.self;
      final k = context.getLocal("k");

      if (self is ValMap) {
        final selfMap = self;
        final key = k ?? ValNull.instance;
        if (selfMap.map.containsKey(key)) {
          selfMap.map.remove(key);
          return IntrinsicResult.true_;
        }
        return IntrinsicResult.false_;
      } else if (self is ValList) {
        if (k == null) {
          throw RuntimeException("argument to 'remove' must not be null");
        }
        final selfList = self;
        var idx = k.intValue();
        if (idx < 0) idx += selfList.values.length;
        Check.range(idx, 0, selfList.values.length - 1);
        selfList.values.removeAt(idx);
        return IntrinsicResult.null_;
      } else if (self is ValString) {
        final selfStr = self;
        if (k == null) {
          throw RuntimeException("argument to 'remove' must not be null");
        }
        final substr = k.toString();
        final foundPos = selfStr.value.indexOf(substr);
        if (foundPos < 0) return IntrinsicResult(self);
        final result = selfStr.value.substring(0, foundPos) +
            selfStr.value.substring(foundPos + substr.length);
        return IntrinsicResult(ValString(result));
      }

      throw TypeException("Type Error: 'remove' requires map, list, or string");
    };

    // replace
    //	Replace all matching elements of a list or map, or substrings of a string,
    //	with a new value.Lists and maps are mutated in place, and return themselves.
    //	Strings are immutable, so the original string is (of course) unchanged, but
    //	a new string with the replacement is returned.  Note that with maps, it is
    //	the values that are searched for and replaced, not the keys.
    // self (list, map, or string): object to replace elements of
    // oldval (any): value or substring to replace
    // newval (any): new value or substring to substitute where oldval is found
    // maxCount (number, optional): if given, replace no more than this many
    // Returns: modified list or map, or new string, with replacements done
    // Example: "Happy Pappy".replace("app", "ol")		returns "Holy Poly"
    // Example: [1,2,3,2,5].replace(2, 42)		returns (and mutates to) [1, 42, 3, 42, 5]
    // Example: d = {1: "one"}; d.replace("one", "ichi")		returns (and mutates to) {1: "ichi"}
    f = Intrinsic.create("replace");
    f.addParam("self");
    f.addParam("oldval");
    f.addParam("newval");
    f.addParam("maxCount");
    f.code = (context, [partialResult]) {
      final self = context.self;
      if (self == null) {
        throw RuntimeException("argument to 'replace' must not be null");
      }

      final oldval = context.getLocal("oldval");
      final newval = context.getLocal("newval");
      final maxCountVal = context.getLocal("maxCount");

      var maxCount = -1;
      if (maxCountVal != null) {
        maxCount = maxCountVal.intValue();
        if (maxCount < 1) return IntrinsicResult(self);
      }

      var count = 0;

      if (self is ValMap) {
        final selfMap = self;
        final keysToChange = <Value>[];

        for (var k in selfMap.map.keys) {
          if (k == null) continue;
          if (selfMap.map[k]!.equality(oldval) == 1) {
            keysToChange.add(k);
            count++;
            if (maxCount > 0 && count == maxCount) break;
          }
        }

        for (var k in keysToChange) {
          selfMap.map[k] = newval;
        }

        return IntrinsicResult(self);
      } else if (self is ValList) {
        final selfList = self;
        var idx = -1;

        while (true) {
          idx = selfList.values
              .indexWhere((x) => x!.equality(oldval) == 1, idx + 1);

          if (idx < 0) break;
          selfList.values[idx] = newval;
          count++;
          if (maxCount > 0 && count == maxCount) break;
        }

        return IntrinsicResult(self);
      } else if (self is ValString) {
        final str = self.toString();
        final oldstr = oldval == null ? "" : oldval.toString();
        if (oldstr.isEmpty) {
          throw RuntimeException("replace: oldval argument is empty");
        }

        final newstr = newval == null ? "" : newval.toString();
        var idx = 0;
        var sb = StringBuffer();

        while (true) {
          final foundIdx = str.indexOf(oldstr, idx);
          if (foundIdx < 0) break;

          sb.write(str.substring(idx, foundIdx));
          sb.write(newstr);

          count++;
          idx = foundIdx + oldstr.length;
          if (maxCount > 0 && count == maxCount) break;
        }

        if (count > 0) {
          sb.write(str.substring(idx));
          return IntrinsicResult(ValString(sb.toString()));
        }

        return IntrinsicResult(ValString.empty);
      }

      return IntrinsicResult(self);
    };

    // round
    //	Rounds a number to the specified number of decimal places.  If given
    //	a negative number for decimalPlaces, then rounds to a power of 10:
    //	-1 rounds to the nearest 10, -2 rounds to the nearest 100, etc.
    // x (number): number to round
    // decimalPlaces (number, defaults to 0): how many places past the decimal point to round to
    // Example: round(pi, 2)		returns 3.14
    // Example: round(12345, -3)		returns 12000
    f = Intrinsic.create("round");
    f.addParam("x", ValNumber.zero);
    f.addParam("decimalPlaces", ValNumber.zero);
    f.code = (context, [partialResult]) {
      var num = context.getLocalDouble("x")!;
      var decimalPlaces = context.getLocalInt("decimalPlaces")!;

      if (decimalPlaces >= 0) {
        if (decimalPlaces > 15) decimalPlaces = 15;
        num = double.parse(num.toStringAsFixed(decimalPlaces));
      } else {
        final pow10 = math.pow(10, -decimalPlaces).toDouble();
        num = (num / pow10).round() * pow10;
      }

      return IntrinsicResult.fromNum((num));
    };

    // rnd
    //	Generates a pseudorandom number between 0 and 1 (including 0 but
    //	not including 1).  If given a seed, then the generator is reset
    //	with that seed value, allowing you to create repeatable sequences
    //	of random numbers.  If you never specify a seed, then it is
    //	initialized automatically, generating a unique sequence on each run.
    // seed (number, optional): if given, reset the sequence with this value
    // Returns: pseudorandom number in the range [0,1)
    f = Intrinsic.create("rnd");
    f.addParam("seed");
    f.code = (context, [partialResult]) {
      random ??= math.Random();
      final seed = context.getLocal("seed");
      if (seed != null) {
        random = math.Random(seed.hash());
      }

      final result = random!.nextDouble();
      return IntrinsicResult.fromNum((result));
    };

    // sign
    //	Return -1 for negative numbers, 1 for positive numbers, and 0 for zero.
    // x (number): number to get the sign of
    // Returns: sign of the number
    // Example: sign(-42.6)		returns -1
    f = Intrinsic.create("sign");
    f.addParam("x", ValNumber.zero);
    f.code = (context, [partialResult]) {
      final x = context.getLocalDouble("x")!;
      if (x > 0) return IntrinsicResult.true_;
      if (x < 0) return IntrinsicResult.fromNum((-1));
      return IntrinsicResult.false_;
    };

    // sin
    //	Returns the sine of the given angle (in radians).
    // radians (number): angle, in radians, to get the sine of
    // Returns: sine of the given angle
    // Example: sin(pi/2)		returns 1
    f = Intrinsic.create("sin");
    f.addParam("radians", ValNumber.zero);
    f.code = (context, [partialResult]) {
      final radians = context.getLocalDouble("radians")!;
      return IntrinsicResult.fromNum(math.sin(radians));
    };

    // slice
    //	Return a subset of a string or list.  This is equivalent to using
    //	the square-brackets slice operator seq[from:to], but with ordinary
    //	function syntax.
    // seq (string or list): sequence to get a subsequence of
    // from (number, default 0): 0-based index to the first element to return (if negative, counts from the end)
    // to (number, optional): 0-based index of first element to *not* include in the result
    //		(if negative, count from the end; if omitted, return the rest of the sequence)
    // Returns: substring or sublist
    // Example: slice("Hello", -2)		returns "lo"
    // Example: slice(["a","b","c","d"], 1, 3)		returns ["b", "c"]
    f = Intrinsic.create("slice");
    f.addParam("seq");
    f.addParam("from", ValNumber.zero);
    f.addParam("to");
    f.code = (context, [partialResult]) {
      final seq = context.getLocal("seq");
      final fromIdx = context.getLocalInt("from")!;
      final toVal = context.getLocal("to");
      var toIdx = 0;
      if (toVal != null) toIdx = toVal.intValue();

      if (seq is ValList) {
        final list = seq.values;
        var from = fromIdx;
        if (from < 0) from += list.length;
        if (from < 0) from = 0;

        var to = toIdx;
        if (toVal == null) to = list.length;
        if (to < 0) to += list.length;
        if (to > list.length) to = list.length;

        final slice = ValList();
        if (from < list.length && to > from) {
          for (var i = from; i < to; i++) {
            slice.values.add(list[i]);
          }
        }
        return IntrinsicResult(slice);
      } else if (seq is ValString) {
        final str = seq.value;
        var from = fromIdx;
        if (from < 0) from += str.length;
        if (from < 0) from = 0;

        var to = toIdx;
        if (toVal == null) to = str.length;
        if (to < 0) to += str.length;
        if (to > str.length) to = str.length;

        if (to - from <= 0) return IntrinsicResult(ValString.empty);
        return IntrinsicResult(ValString(str.substring(from, to)));
      }

      return IntrinsicResult.null_;
    };

    // sort
    //	Sorts a list in place.  With null or no argument, this sorts the
    //	list elements by their own values.  With the byKey argument, each
    //	element is indexed by that argument, and the elements are sorted
    //	by the result.  (This only works if the list elements are maps, or
    //	they are lists and byKey is an integer index.)
    // self (list): list to sort
    // byKey (optional): if given, sort each element by indexing with this key
    // ascending (optional, default true): if false, sort in descending order
    // Returns: self (which has been sorted in place)
    // Example: a = [5,3,4,1,2]; a.sort		results in a == [1, 2, 3, 4, 5]
    // See also: shuffle
    f = Intrinsic.create("sort");
    f.addParam("self");
    f.addParam("byKey");
    f.addParam("ascending", ValNumber.one);
    f.code = (context, [partialResult]) {
      final self = context.self as ValList?;
      if (self == null || self.values.length < 2) return IntrinsicResult(self);

      final list = self.values;
      final ascending = context.getLocalBool("ascending") ?? true;
      final byKey = context.getLocal("byKey");

      if (byKey == null) {
        // Simple case: sort the values as themselves
        list.sort((a, b) {
          if ((a == null || a is ValNull) && (b == null || b is ValNull)) {
            return 0;
          }
          if ((a == null || a is ValNull)) return ascending ? 1 : -1;
          if ((b == null || b is ValNull)) return ascending ? -1 : 1;
          final comp = Value.compare(a, b);
          return ascending ? comp : -comp;
        });
      } else {
        // Harder case: sort by a key
        final count = list.length;
        final arr = List<_KeyedValue>.generate(count, (_) => _KeyedValue());

        for (var i = 0; i < count; i++) {
          arr[i].value = list[i];
        }

        // The key for each item will be the item itself, unless it is a map, in which
        // case it's the item indexed by the given key (works too for lists if our index is an integer)
        final byKeyInt = byKey.intValue();

        for (var i = 0; i < count; i++) {
          final item = list[i];
          if (item is ValMap) {
            arr[i].sortKey = item.map[byKey];
          } else if (item is ValList) {
            final itemList = item.values;
            if (byKeyInt > -itemList.length && byKeyInt < itemList.length) {
              arr[i].sortKey = itemList[byKeyInt];
            } else {
              arr[i].sortKey = null;
            }
          } else {
            arr[i].sortKey = null;
          }
        }

        // Sort our array of keyed values by key
        arr.sort((a, b) {
          if (a.sortKey == null && b.sortKey == null) return 0;
          if (a.sortKey == null) return ascending ? -1 : 1;
          if (b.sortKey == null) return ascending ? 1 : -1;
          final comp = Value.compare(a.sortKey!, b.sortKey!);
          return ascending ? comp : -comp;
        });

        // Convert back to our list
        for (var i = 0; i < count; i++) {
          list[i] = arr[i].value;
        }
      }

      return IntrinsicResult(self);
    };

    // split
    //	Split a string into a list, by some delimiter.
    //	May be called with function syntax or dot syntax.
    // self (string): string to split
    // delimiter (string, default " "): substring to split on
    // maxCount (number, default -1): if > 0, split into no more than this many strings
    // Returns: list of substrings found by splitting on delimiter
    // Example: "foo bar baz".split		returns ["foo", "bar", "baz"]
    // Example: "foo bar baz".split("a", 2)		returns ["foo b", "r baz"]
    // See also: join
    f = Intrinsic.create("split");
    f.addParam("self");
    f.addParam("delimiter", ValString(" "));
    f.addParam("maxCount", ValNumber(-1));
    f.code = (context, [partialResult]) {
      final self = context.self!.toStringWithVM(context.vm!);
      final delim = context.getLocalString("delimiter")!;
      final maxCount = context.getLocalInt("maxCount")!;

      final result = ValList();
      var pos = 0;

      while (pos < self.length) {
        int nextPos;
        if (maxCount >= 0 && result.values.length == maxCount - 1) {
          nextPos = self.length;
        } else if (delim.isEmpty) {
          nextPos = pos + 1;
        } else {
          nextPos = self.indexOf(delim, pos);
          if (nextPos < 0) nextPos = self.length;
        }

        result.values.add(ValString(self.substring(pos, nextPos)));
        pos = nextPos + delim.length;
        if (pos == self.length && delim.isNotEmpty) {
          result.values.add(ValString.empty);
        }
      }

      return IntrinsicResult(result);
    };

    // sqrt
    //	Returns the square root of a number.
    // x (number): number to get the square root of
    // Returns: square root of x
    // Example: sqrt(1764)		returns 42
    f = Intrinsic.create("sqrt");
    f.addParam("x", ValNumber.zero);
    f.code = (context, [partialResult]) {
      final x = context.getLocalDouble("x")!;
      return IntrinsicResult.fromNum(math.sqrt(x));
    };

    // stackTrace: get a list describing the call stack.
    f = Intrinsic.create("stackTrace");
    f.code = (context, [partialResult]) {
      var vm = context.vm!;
      var stackAtBreak = ValString(_stackAtBreak);

      if (vm.globalContext!.variables!
          .containsKeyWithIdentifier(_stackAtBreak)) {
        // We have a stored stack from a break or exit.
        // So, display that.  The host app should clear this when starting a 'run'
        // so it never interferes with showing a more up-to-date stack during a run.
        return IntrinsicResult(vm.globalContext!.variables!.map[stackAtBreak]!);
      }

      // Otherwise, build a stack now from the state of the VM.
      ValList result = stackList(vm);
      return IntrinsicResult(result);
    };

    //	Convert any value to a string.
    // x (any): value to convert
    // Returns: string representation of the given value
    // Example: str(42)		returns "42"
    // See also: val
    f = Intrinsic.create("str");
    f.addParam("x", ValString.empty);
    f.code = (context, [partialResult]) {
      final x = context.getLocal("x");
      if (x == null) return IntrinsicResult(ValString.empty);
      return IntrinsicResult(ValString(x.toString()));
    };

    // string type
    //	Returns a map that represents the string datatype in
    //	MiniScript's core type system.  This can be used with `isa`
    //	to check whether a variable refers to a string.  You can also
    //	assign new methods here to make them available to all strings.
    // Example: "Hello" isa string		returns 1
    // See also: number, list, map, funcRef
    f = Intrinsic.create("string");
    f.code = (context, [partialResult]) {
      context.vm?.stringType ??=
          stringType().evalCopy(context.vm!.globalContext!);
      return IntrinsicResult(context.vm!.stringType!);
    };

    // shuffle
    //	Randomize the order of elements in a list, or the mappings from
    //	keys to values in a map.  This is done in place.
    // self (list or map): object to shuffle
    // Returns: null
    f = Intrinsic.create("shuffle");
    f.addParam("self");
    f.code = (context, [partialResult]) {
      final self = context.self;

      random ??= math.Random();
      if (self is ValList) {
        final list = (self).values;
        // We'll do a Fisher-Yates shuffle, i.e., swap each element
        // with a randomly selected one.
        for (var i = list.length - 1; i >= 1; i--) {
          final j = random!.nextInt(i + 1);
          final temp = list[j];
          list[j] = list[i];
          list[i] = temp;
        }
      } else if (self is ValMap) {
        final map =
            self; // Fisher-Yates again, but this time, what we're swapping
        // is the values associated with the keys, not the keys themselves.
        final keys = map.keys.toList();
        for (var i = keys.length - 1; i >= 1; i--) {
          final j = random!.nextInt(i + 1);
          final keyi = keys[i];
          final keyj = keys[j];
          final vali = map.map[keyi]!;
          final valj = map.map[keyj]!;
          map.map[keyi] = valj;
          map.map[keyj] = vali;
        }
      }

      return IntrinsicResult(self);
    };

    // sum
    //	Returns the total of all elements in a list, or all values in a map.
    // self (list or map): object to sum
    // Returns: result of adding up all values in self
    // Example: range(3).sum		returns 6 (3 + 2 + 1 + 0)
    f = Intrinsic.create("sum");
    f.addParam("self");
    f.code = (context, [partialResult]) {
      final val = context.self;
      var sum = 0.0;

      if (val is ValList) {
        for (final v in (val).values) {
          sum += v!.doubleValue();
        }
      } else if (val is ValMap) {
        for (final v in (val).map.values) {
          sum += v!.doubleValue();
        }
      }

      return IntrinsicResult.fromNum((sum));
    };

    // tan
    //	Returns the tangent of the given angle (in radians).
    // radians (number): angle, in radians, to get the tangent of
    // Returns: tangent of the given angle
    // Example: tan(pi/4)		returns 1
    f = Intrinsic.create("tan");
    f.addParam("radians", ValNumber.zero);
    f.code = (context, [partialResult]) {
      final radians = context.getLocalDouble("radians")!;
      return IntrinsicResult.fromNum((math.tan(radians)));
    };

    // time
    //	Returns the number of seconds since the script started running.
    f = Intrinsic.create("time");
    f.code = (context, [partialResult]) {
      return IntrinsicResult.fromNum(
        context.vm!.runTime,
      );
    };

    // upper
    //	Return an upper-case (all capitals) version of a string.
    //	May be called with function syntax or dot syntax.
    // self (string): string to upper-case
    // Returns: string with all lowercase letters converted to capitals
    // Example: "Mo Spam".upper		returns "MO SPAM"
    // See also: lower
    f = Intrinsic.create("upper");
    f.addParam("self");
    f.code = (context, [partialResult]) {
      final val = context.self!;

      if (val is ValString) {
        return IntrinsicResult(ValString((val).value.toUpperCase()));
      }

      return IntrinsicResult(val);
    };

    // val
    //	Return the numeric value of a given string.  (If given a number,
    //	returns it as-is; if given a list or map, returns null.)
    //	May be called with function syntax or dot syntax.
    // self (string or number): string to get the value of
    // Returns: numeric value of the given string
    // Example: "1234.56".val		returns 1234.56
    // See also: str
    f = Intrinsic.create("val");
    f.addParam("self", ValNumber.zero);
    f.code = (context, [partialResult]) {
      final val = context.self!;

      if (val is ValNumber) return IntrinsicResult(val);
      if (val is ValString) {
        var value = 0.0;
        try {
          value = double.parse(val.value);
        } catch (_) {}
        return IntrinsicResult.fromNum((value));
      }

      return IntrinsicResult.null_;
    };

    // values
    //	Returns the values of a dictionary, or the characters of a string.
    //  (Returns any other value as-is.)
    //	May be called with function syntax or dot syntax.
    // self (any): object to get the values of.
    // Example: d={1:"one", 2:"two"}; d.values		returns ["one", "two"]
    // Example: "abc".values		returns ["a", "b", "c"]
    // See also: indexes
    f = Intrinsic.create("values");
    f.addParam("self");
    f.code = (context, [partialResult]) {
      final self = context.self;

      if (self is ValMap) {
        final values = (self).map.values.toList();
        return IntrinsicResult(ValList(values));
      } else if (self is ValString) {
        final str = (self).value;
        final values = List.generate(str.length, (i) => ValString(str[i]));
        return IntrinsicResult(ValList(values));
      }

      return IntrinsicResult(self);
    };

    // version
    //	Get a map with information about the version of MiniScript and
    //	the host environment that you're currently running.  This will
    //	include at least the following keys:
    //		miniscript: a string such as "1.5"
    //		buildDate: a date in yyyy-mm-dd format, like "2020-05-28"
    //		host: a number for the host major and minor version, like 0.9
    //		hostName: name of the host application, e.g. "Mini Micro"
    //		hostInfo: URL or other short info about the host app
    f = Intrinsic.create("version");
    f.code = (context, [partialResult]) {
      if (context.vm!.versionMap == null) {
        final d = ValMap();

        d["buildDate"] = ValString(HostInfo.buildDate);

        d["host"] = ValString(HostInfo.version);
        d["hostName"] = ValString(HostInfo.name);
        d["hostInfo"] = ValString(HostInfo.info);

        context.vm!.versionMap = d;
      }

      return IntrinsicResult(context.vm!.versionMap);
    };

    // wait
    //	Pause execution of this script for some amount of time.
    // seconds (default 1.0): how many seconds to wait
    // Example: wait 2.5		pauses the script for 2.5 seconds
    // See also: time, yield
    f = Intrinsic.create("wait");
    f.addParam("seconds", ValNumber.one);
    f.code = (context, [partialResult]) {
      final now = context.vm!.runTime;

      if (partialResult == null) {
        // Just starting our wait; calculate end time and return as partial result
        final interval = context.getLocalDouble("seconds")!;
        return IntrinsicResult.fromNum((now + interval), done: false);
      } else {
        // Continue until current time exceeds the time in the partial result
        if (now > partialResult.result!.doubleValue()) {
          return IntrinsicResult.null_;
        }
        return partialResult;
      }
    };

    // yield
    //	Pause the execution of the script until the next "tick" of
    //	the host app.  In Mini Micro, for example, this waits until
    //	the next 60Hz frame.  Exact meaning may vary, but generally
    //	if you're doing something in a tight loop, calling yield is
    //	polite to the host app or other scripts.
    f = Intrinsic.create("yield");
    f.code = (context, [partialResult]) {
      context.vm!.yielding = true;
      return IntrinsicResult.null_;
    };
  }

  // Helper method to compile a call to Slice
  static void compileSlice(
    List<tac.Line> code,
    Value? list,
    Value? fromIdx,
    Value? toIdx,
    int resultTempNum,
  ) {
    code.add(tac.Line(null, tac.LineOp.pushParam, list));
    code.add(tac.Line(null, tac.LineOp.pushParam, fromIdx ?? tac.num(0)));
    code.add(tac.Line(null, tac.LineOp.pushParam, toIdx));

    final func = Intrinsic.getByName("slice")!.getFunc();
    code.add(
      tac.Line(
        tac.lTemp(resultTempNum),
        tac.LineOp.callFunctionA,
        func,
        tac.num(3),
      ),
    );
  }

  // Type factories
  static ValMap functionType() {
    if (_functionType != null) return _functionType!;

    _functionType = ValMap();
    final map = _functionType!;

    return map;
  }

  static ValMap listType() {
    if (_listType != null) return _listType!;

    _listType = ValMap();
    final map = _listType!;

    map.map[ValString("hasIndex")] = Intrinsic.getByName("hasIndex")!.getFunc();
    map.map[ValString("indexes")] = Intrinsic.getByName("indexes")!.getFunc();
    map.map[ValString("indexOf")] = Intrinsic.getByName("indexOf")!.getFunc();
    map.map[ValString("insert")] = Intrinsic.getByName("insert")!.getFunc();
    map.map[ValString("join")] = Intrinsic.getByName("join")!.getFunc();
    map.map[ValString("len")] = Intrinsic.getByName("len")!.getFunc();
    map.map[ValString("pop")] = Intrinsic.getByName("pop")!.getFunc();
    map.map[ValString("pull")] = Intrinsic.getByName("pull")!.getFunc();
    map.map[ValString("push")] = Intrinsic.getByName("push")!.getFunc();
    map.map[ValString("shuffle")] = Intrinsic.getByName("shuffle")!.getFunc();
    map.map[ValString("sort")] = Intrinsic.getByName("sort")!.getFunc();
    map.map[ValString("sum")] = Intrinsic.getByName("sum")!.getFunc();
    map.map[ValString("remove")] = Intrinsic.getByName("remove")!.getFunc();
    map.map[ValString("replace")] = Intrinsic.getByName("replace")!.getFunc();
    map.map[ValString("values")] = Intrinsic.getByName("values")!.getFunc();

    return map;
  }

  static ValMap mapType() {
    if (_mapType != null) return _mapType!;

    _mapType = ValMap();
    final map = _mapType!;

    map.map[ValString("len")] = Intrinsic.getByName("len")!.getFunc();
    map.map[ValString("hasIndex")] = Intrinsic.getByName("hasIndex")!.getFunc();
    map.map[ValString("indexOf")] = Intrinsic.getByName("indexOf")!.getFunc();
    map.map[ValString("indexes")] = Intrinsic.getByName("indexes")!.getFunc();
    map.map[ValString("values")] = Intrinsic.getByName("values")!.getFunc();
    map.map[ValString("push")] = Intrinsic.getByName("push")!.getFunc();
    map.map[ValString("pop")] = Intrinsic.getByName("pop")!.getFunc();
    map.map[ValString("pull")] = Intrinsic.getByName("pull")!.getFunc();
    map.map[ValString("remove")] = Intrinsic.getByName("remove")!.getFunc();
    map.map[ValString("replace")] = Intrinsic.getByName("replace")!.getFunc();
    map.map[ValString("sum")] = Intrinsic.getByName("sum")!.getFunc();
    map.map[ValString("shuffle")] = Intrinsic.getByName("shuffle")!.getFunc();

    return map;
  }

  static ValMap stringType() {
    if (_stringType != null) return _stringType!;

    _stringType = ValMap();
    final map = _stringType!;

    map.map[ValString("hasIndex")] = Intrinsic.getByName("hasIndex")!.getFunc();
    map.map[ValString("indexOf")] = Intrinsic.getByName("indexOf")!.getFunc();
    map.map[ValString("indexes")] = Intrinsic.getByName("indexes")!.getFunc();
    map.map[ValString("insert")] = Intrinsic.getByName("insert")!.getFunc();
    map.map[ValString("code")] = Intrinsic.getByName("code")!.getFunc();
    map.map[ValString("len")] = Intrinsic.getByName("len")!.getFunc();
    map.map[ValString("lower")] = Intrinsic.getByName("lower")!.getFunc();
    map.map[ValString("val")] = Intrinsic.getByName("val")!.getFunc();
    map.map[ValString("remove")] = Intrinsic.getByName("remove")!.getFunc();
    map.map[ValString("replace")] = Intrinsic.getByName("replace")!.getFunc();
    map.map[ValString("split")] = Intrinsic.getByName("split")!.getFunc();
    map.map[ValString("upper")] = Intrinsic.getByName("upper")!.getFunc();
    map.map[ValString("values")] = Intrinsic.getByName("values")!.getFunc();

    return map;
  }

  static ValMap numberType() {
    if (_numberType != null) return _numberType!;

    _numberType = ValMap();
    final map = _numberType!;

    return map;
  }

  // Helper function to create intrinsic wrapper functions
  static ValFunction addIntrinsicWrapper(String name, IntrinsicCode code) {
    final f = Intrinsic.create("_$name");
    f.code = code;
    return f.getFunc();
  }
}
