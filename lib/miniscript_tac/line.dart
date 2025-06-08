// Copyright © 2025 by the authors of the project. All rights reserved.

import 'dart:math';

import 'package:miniscript/miniscript_errors.dart';
import 'package:miniscript/miniscript_intrinsics/intrinsic.dart';
import 'package:miniscript/miniscript_tac/context.dart';
import 'package:miniscript/miniscript_tac/machine.dart';
import 'package:miniscript/miniscript_types/function.dart';
import 'package:miniscript/miniscript_types/value.dart';
import 'package:miniscript/miniscript_types/value_list.dart';
import 'package:miniscript/miniscript_types/value_map.dart';
import 'package:miniscript/miniscript_types/value_number.dart';
import 'package:miniscript/miniscript_types/value_seq_elem.dart';
import 'package:miniscript/miniscript_types/value_string.dart';
import 'package:miniscript/value_pointer.dart';

enum LineOp {
  noop,
  assignA,
  assignImplicit,
  aPlusB,
  aMinusB,
  aTimesB,
  aDividedByB,
  aModB,
  aPowB,
  aEqualB,
  aNotEqualB,
  aGreaterThanB,
  aGreatOrEqualB,
  aLessThanB,
  aLessOrEqualB,
  aIsaB,
  aAndB,
  aOrB,
  bindAssignA,
  copyA,
  newA,
  notA,
  gotoA,
  gotoAifB,
  gotoAifTrulyB,
  gotoAifNotB,
  pushParam,
  callFunctionA,
  callIntrinsicA,
  returnA,
  elemBofA,
  elemBofIterA,
  lengthOfA
}

class Line {
  Value? lhs;
  LineOp op;
  Value? rhsA;
  Value? rhsB;
  SourceLoc? location;
  String? comment;

  Line(this.lhs, this.op, [this.rhsA, this.rhsB]);

  @override
  String toString() => toStringWithVM(null);

  String toStringWithVM([Machine? vm]) {
    String text;
    switch (op) {
      case LineOp.assignA:
        text = "${lhs?.toStringWithVM(vm)} := ${rhsA?.toStringWithVM(vm)}";
        break;
      case LineOp.assignImplicit:
        text = "_ := ${rhsA?.toStringWithVM(vm)}";
        break;
      case LineOp.aPlusB:
        text =
            "${lhs?.toStringWithVM(vm)} := ${rhsA?.toStringWithVM(vm)} + ${rhsB?.toStringWithVM(vm)}";
        break;
      case LineOp.aMinusB:
        text =
            "${lhs?.toStringWithVM(vm)} := ${rhsA?.toStringWithVM(vm)} - ${rhsB?.toStringWithVM(vm)}";
        break;
      case LineOp.aTimesB:
        text =
            "${lhs?.toStringWithVM(vm)} := ${rhsA?.toStringWithVM(vm)} * ${rhsB?.toStringWithVM(vm)}";
        break;
      case LineOp.aDividedByB:
        text =
            "${lhs?.toStringWithVM(vm)} := ${rhsA?.toStringWithVM(vm)} / ${rhsB?.toStringWithVM(vm)}";
        break;
      case LineOp.aModB:
        text =
            "${lhs?.toStringWithVM(vm)} := ${rhsA?.toStringWithVM(vm)} % ${rhsB?.toStringWithVM(vm)}";
        break;
      case LineOp.aPowB:
        text =
            "${lhs?.toStringWithVM(vm)} := ${rhsA?.toStringWithVM(vm)} ^ ${rhsB?.toStringWithVM(vm)}";
        break;
      case LineOp.aEqualB:
        text =
            "${lhs?.toStringWithVM(vm)} := ${rhsA?.toStringWithVM(vm)} == ${rhsB?.toStringWithVM(vm)}";
        break;
      case LineOp.aNotEqualB:
        text =
            "${lhs?.toStringWithVM(vm)} := ${rhsA?.toStringWithVM(vm)} != ${rhsB?.toStringWithVM(vm)}";
        break;
      case LineOp.aGreaterThanB:
        text =
            "${lhs?.toStringWithVM(vm)} := ${rhsA?.toStringWithVM(vm)} > ${rhsB?.toStringWithVM(vm)}";
        break;
      case LineOp.aGreatOrEqualB:
        text =
            "${lhs?.toStringWithVM(vm)} := ${rhsA?.toStringWithVM(vm)} >= ${rhsB?.toStringWithVM(vm)}";
        break;
      case LineOp.aLessThanB:
        text =
            "${lhs?.toStringWithVM(vm)} := ${rhsA?.toStringWithVM(vm)} < ${rhsB?.toStringWithVM(vm)}";
        break;
      case LineOp.aLessOrEqualB:
        text =
            "${lhs?.toStringWithVM(vm)} := ${rhsA?.toStringWithVM(vm)} <= ${rhsB?.toStringWithVM(vm)}";
        break;
      case LineOp.aAndB:
        text =
            "${lhs?.toStringWithVM(vm)} := ${rhsA?.toStringWithVM(vm)} and ${rhsB?.toStringWithVM(vm)}";
        break;
      case LineOp.aOrB:
        text =
            "${lhs?.toStringWithVM(vm)} := ${rhsA?.toStringWithVM(vm)} or ${rhsB?.toStringWithVM(vm)}";
        break;
      case LineOp.aIsaB:
        text =
            "${lhs?.toStringWithVM(vm)} := ${rhsA?.toStringWithVM(vm)} isa ${rhsB?.toStringWithVM(vm)}";
        break;
      case LineOp.bindAssignA:
        text =
            "${rhsA?.toStringWithVM(vm)} := ${rhsB?.toStringWithVM(vm)}; ${rhsA?.toStringWithVM(vm)}.outerVars=";
        break;
      case LineOp.copyA:
        text =
            "${lhs?.toStringWithVM(vm)} := copy of ${rhsA?.toStringWithVM(vm)}";
        break;
      case LineOp.newA:
        text = "${lhs?.toStringWithVM(vm)} := new ${rhsA?.toStringWithVM(vm)}";
        break;
      case LineOp.notA:
        text = "${lhs?.toStringWithVM(vm)} := not ${rhsA?.toStringWithVM(vm)}";
        break;
      case LineOp.gotoA:
        text = "goto ${rhsA?.toStringWithVM(vm)}";
        break;
      case LineOp.gotoAifB:
        text =
            "goto ${rhsA?.toStringWithVM(vm)} if ${rhsB?.toStringWithVM(vm)}";
        break;
      case LineOp.gotoAifTrulyB:
        text =
            "goto ${rhsA?.toStringWithVM(vm)} if truly ${rhsB?.toStringWithVM(vm)}";
        break;
      case LineOp.gotoAifNotB:
        text =
            "goto ${rhsA?.toStringWithVM(vm)} if not ${rhsB?.toStringWithVM(vm)}";
        break;
      case LineOp.pushParam:
        text = "push param ${rhsA?.toStringWithVM(vm)}";
        break;
      case LineOp.callFunctionA:
        text =
            "${lhs?.toStringWithVM(vm)} := call ${rhsA?.toStringWithVM(vm)} with ${rhsB?.toStringWithVM(vm)} args";
        break;
      case LineOp.callIntrinsicA:
        text = "intrinsic ${Intrinsic.getByID(rhsA!.intValue())}";
        break;
      case LineOp.returnA:
        text =
            "${lhs?.toStringWithVM(vm)} := ${rhsA?.toStringWithVM(vm)}; return";
        break;
      case LineOp.elemBofA:
        text =
            "${lhs?.toStringWithVM(vm)} = ${rhsA?.toStringWithVM(vm)}[${rhsB?.toStringWithVM(vm)}]";
        break;
      case LineOp.elemBofIterA:
        text =
            "${lhs?.toStringWithVM(vm)} = ${rhsA?.toStringWithVM(vm)} iter ${rhsB?.toStringWithVM(vm)}";
        break;
      case LineOp.lengthOfA:
        text = "${lhs?.toStringWithVM(vm)} = len(${rhsA?.toStringWithVM(vm)})";
        break;
      default:
        text = "unknown opcode: $op";
    }

    if (location != null) text = "$text\t// $location";
    return text;
  }

  /// Evaluate this line and return the value that would be stored
  /// into the lhs.
  Value? evaluate(Context context) {
    if (op == LineOp.assignA ||
        op == LineOp.returnA ||
        op == LineOp.assignImplicit) {
      // Assignment is a bit of a special case.  It's EXTREMELY common
      // in TAC, so needs to be efficient, but we have to watch out for
      // the case of a RHS that is a list or map.  This means it was a
      // literal in the source, and may contain references that need to
      // be evaluated now.
      if (rhsA is ValList || rhsA is ValMap) {
        return rhsA!.fullEval(context);
      } else if (rhsA == null) {
        return null;
      } else {
        return rhsA!.val(context);
      }
    }

    if (op == LineOp.copyA) {
      // This opcode is used for assigning a literal.  We actually have
      // to copy the literal, in the case of a mutable object like a
      // list or map, to ensure that if the same code executes again,
      // we get a new, unique object.
      if (rhsA is ValList) {
        return (rhsA as ValList).evalCopy(context);
      } else if (rhsA is ValMap) {
        return (rhsA as ValMap).evalCopy(context);
      } else if (rhsA == null) {
        return null;
      } else {
        return rhsA!.val(context);
      }
    }

    final opA = rhsA?.val(context);
    final opB = rhsB?.val(context);

    if (op == LineOp.aIsaB) {
      if (opA == null) return ValNumber.truth(opB == null);
      return ValNumber.truth(opA.isA(opB, context.vm!));
    }

    if (op == LineOp.newA) {
      // Create a new map, and set __isa on it to operand A (after
      // verifying that this is a valid map to subclass).
      if (opA is! ValMap) {
        throw RuntimeException("argument to 'new' must be a map");
      } else if (opA == context.vm!.stringType) {
        throw RuntimeException(
            "invalid use of 'new'; to create a string, use quotes, e.g. \"foo\"");
      } else if (opA == context.vm!.listType) {
        throw RuntimeException(
            "invalid use of 'new'; to create a list, use square brackets, e.g. [1,2]");
      } else if (opA == context.vm!.numberType) {
        throw RuntimeException(
            "invalid use of 'new'; to create a number, use a numeric literal, e.g. 42");
      } else if (opA == context.vm!.functionType) {
        throw RuntimeException(
            "invalid use of 'new'; to create a function, use the 'function' keyword");
      }

      final ValMap newMap = ValMap();
      newMap.setElem(ValString.magicIsA, opA);
      return newMap;
    }

    if (op == LineOp.elemBofA && opB is ValString) {
      // You can now look for a string in almost anything...
      // and we have a convenient (and relatively fast) method for it:
      return ValSeqElem.resolve(opA!, (opB).value, context, ValuePointer());
    }

    // check for special cases of comparison to null (works with any type)
    if (op == LineOp.aEqualB && (opA == null || opB == null)) {
      return ValNumber.truth(opA == opB);
    }
    if (op == LineOp.aNotEqualB && (opA == null || opB == null)) {
      return ValNumber.truth(opA != opB);
    }

    // check for implicit coersion of other types to string; this happens
    // when either side is a string and the operator is addition.
    if ((opA is ValString || opB is ValString) && op == LineOp.aPlusB) {
      if (opA == null) return opB;
      if (opB == null) return opA;
      final String sA = opA.toStringWithVM(context.vm!);
      final String sB = opB.toStringWithVM(context.vm!);
      if (sA.length + sB.length > ValString.maxSize) {
        throw LimitExceededException("string too large");
      }
      return ValString(sA + sB);
    }

    if (opA is ValNumber) {
      final double fA = (opA).value;
      switch (op) {
        case LineOp.gotoA:
          context.lineNum = fA.toInt();
          return null;

        case LineOp.gotoAifB:
          if (opB != null && opB.boolValue()) context.lineNum = fA.toInt();
          return null;

        case LineOp.gotoAifTrulyB:
          // Unlike GotoAifB, which branches if B has any nonzero
          // value (including 0.5 or 0.001), this branches only if
          // B is TRULY true, i.e., its integer value is nonzero.
          // (Used for short-circuit evaluation of "or".)
          int i = 0;
          if (opB != null) i = opB.intValue();
          if (i != 0) context.lineNum = fA.toInt();
          return null;

        case LineOp.gotoAifNotB:
          if (opB == null || !opB.boolValue()) context.lineNum = fA.toInt();
          return null;

        case LineOp.callIntrinsicA:
          // NOTE: intrinsics do not go through NextFunctionContext.  Instead
          // they execute directly in the current context.  (But usually, the
          // current context is a wrapper function that was invoked via
          // Op.CallFunction, so it got a parameter context at that time.)
          final result =
              Intrinsic.execute(fA.toInt(), context, context.partialResult);
          if (result.done) {
            context.partialResult = null;
            return result.result;
          }
          // OK, this intrinsic function is not yet done with its work.
          // We need to stay on this same line and call it again with
          // the partial result, until it reports that its job is complete.
          context.partialResult = result;
          context.lineNum--;
          return null;

        case LineOp.notA:
          return ValNumber(1.0 - _absClamp01(fA));

        default:
          if (opB is ValNumber || opB == null) {
            final double fB = opB != null ? (opB as ValNumber).value : 0;
            switch (op) {
              case LineOp.aPlusB:
                return ValNumber(fA + fB);
              case LineOp.aMinusB:
                return ValNumber(fA - fB);
              case LineOp.aTimesB:
                return ValNumber(fA * fB);
              case LineOp.aDividedByB:
                return ValNumber(fA / fB);
              case LineOp.aModB:
                return ValNumber(fA % fB);
              case LineOp.aPowB:
                return ValNumber(pow(fA, fB).toDouble());
              case LineOp.aEqualB:
                return ValNumber.truth(fA == fB);
              case LineOp.aNotEqualB:
                return ValNumber.truth(fA != fB);
              case LineOp.aGreaterThanB:
                return ValNumber.truth(fA > fB);
              case LineOp.aGreatOrEqualB:
                return ValNumber.truth(fA >= fB);
              case LineOp.aLessThanB:
                return ValNumber.truth(fA < fB);
              case LineOp.aLessOrEqualB:
                return ValNumber.truth(fA <= fB);
              case LineOp.aAndB:
                final double effectiveFB;
                if (opB is! ValNumber) {
                  effectiveFB = opB != null && opB.boolValue() ? 1 : 0;
                } else {
                  effectiveFB = fB;
                }
                return ValNumber(_absClamp01(fA * effectiveFB));
              case LineOp.aOrB:
                final double effectiveFB;
                if (opB is! ValNumber) {
                  effectiveFB = opB != null && opB.boolValue() ? 1 : 0;
                } else {
                  effectiveFB = fB;
                }
                return ValNumber(
                    _absClamp01(fA + effectiveFB - fA * effectiveFB));
              default:
                break;
            }
          }

          // Handle equality testing between a number (opA) and a non-number (opB).
          // These are always considered unequal.
          if (op == LineOp.aEqualB) return ValNumber.zero;
          if (op == LineOp.aNotEqualB) return ValNumber.one;
      }
    } else if (opA is ValString) {
      final sA = opA.value;

      if (op == LineOp.aTimesB || op == LineOp.aDividedByB) {
        var factor = 0.0;
        if (op == LineOp.aTimesB) {
          Check.type<ValNumber>(opB, "string replication");
          factor = (opB as ValNumber).value;
        } else {
          Check.type<ValNumber>(opB, "string division");
          factor = 1.0 / (opB as ValNumber).value;
        }
        if (factor.isNaN || factor.isInfinite) return null;
        if (factor <= 0) return ValString.empty;

        final repeats = factor.toInt();
        if (repeats * sA.length > ValString.maxSize) {
          throw LimitExceededException("string too large");
        }

        final result = StringBuffer();
        for (var i = 0; i < repeats; i++) {
          result.write(sA);
        }

        final extraChars = (sA.length * (factor - repeats)).toInt();
        if (extraChars > 0) result.write(sA.substring(0, extraChars));

        return ValString(result.toString());
      }

      if (op == LineOp.elemBofA || op == LineOp.elemBofIterA) {
        return (opA).getElem(opB!);
      }

      if (opB == null || opB is ValString) {
        final sB = opB == null ? null : (opB as ValString).value;
        switch (op) {
          case LineOp.aMinusB:
            if (opB == null) return opA;
            if (sA.endsWith(sB!)) {
              return ValString(sA.substring(0, sA.length - sB.length));
            }
            return opA;
          case LineOp.notA:
            return ValNumber.truth(sA.isEmpty);
          case LineOp.aEqualB:
            return ValNumber.truth(sA == sB);
          case LineOp.aNotEqualB:
            return ValNumber.truth(sA != sB);
          case LineOp.aGreaterThanB:
            return ValNumber.truth(sA.compareTo(sB!) > 0);
          case LineOp.aGreatOrEqualB:
            return ValNumber.truth(sA.compareTo(sB!) >= 0);
          case LineOp.aLessThanB:
            return ValNumber.truth(sA.compareTo(sB!) < 0);
          case LineOp.aLessOrEqualB:
            return ValNumber.truth(sA.compareTo(sB!) <= 0);
          case LineOp.lengthOfA:
            return ValNumber(sA.length.toDouble());
          default:
            break;
        }
      } else {
        // RHS is neither null nor a string.
        // We no longer automatically coerce in all these cases; about
        // all we can do is equal or unequal testing.
        // (Note that addition was handled way above here.)
        if (op == LineOp.aEqualB) return ValNumber.zero;
        if (op == LineOp.aNotEqualB) return ValNumber.one;
      }
    } else if (opA is ValList) {
      final list = opA.values;

      if (op == LineOp.elemBofA || op == LineOp.elemBofIterA) {
        // list indexing
        return opA.getElem(opB!);
      } else if (op == LineOp.lengthOfA) {
        return ValNumber(list.length.toDouble());
      } else if (op == LineOp.aEqualB) {
        return ValNumber(opA.equality(opB!));
      } else if (op == LineOp.aNotEqualB) {
        return ValNumber(1.0 - opA.equality(opB!));
      } else if (op == LineOp.aPlusB) {
        // List concatenation
        Check.type<ValList>(opB, "list concatenation");
        final list2 = (opB as ValList).values;

        if (list.length + list2.length > ValList.maxSize) {
          throw LimitExceededException("list too large");
        }

        final result = <Value?>[];
        for (final v in list) {
          result.add(context.valueInContext(v));
        }
        for (final v in list2) {
          result.add(context.valueInContext(v));
        }

        return ValList(result);
      } else if (op == LineOp.aTimesB || op == LineOp.aDividedByB) {
        // list replication (or division)
        var factor = 0.0;
        if (op == LineOp.aTimesB) {
          Check.type<ValNumber>(opB, "list replication");
          factor = (opB as ValNumber).value;
        } else {
          Check.type<ValNumber>(opB, "list division");
          factor = 1.0 / (opB as ValNumber).value;
        }

        if (factor.isNaN || factor.isInfinite) return null;
        if (factor <= 0) return ValList();

        final finalCount = (list.length * factor).toInt();
        if (finalCount > ValList.maxSize) {
          throw LimitExceededException("list too large");
        }

        final result = <Value?>[];
        for (var i = 0; i < finalCount; i++) {
          result.add(context.valueInContext(list[i % list.length]));
        }

        return ValList(result);
      } else if (op == LineOp.notA) {
        return ValNumber.truth(!opA.boolValue());
      }
    } else if (opA is ValMap) {
      if (op == LineOp.elemBofA) {
        // map lookup
        // (note, cases where opB is a string are handled above, along with
        // all the other types; so we'll only get here for non-string cases)
        final ValSeqElem se = ValSeqElem(opA, opB);
        return se.val(context);
        // (This ensures we walk the "__isa" chain in the standard way.)
      } else if (op == LineOp.elemBofIterA) {
        // With a map, ElemBofIterA is different from ElemBofA.  This one
        // returns a mini-map containing a key/value pair.
        return (opA).getKeyValuePair(opB!.intValue());
      } else if (op == LineOp.lengthOfA) {
        return ValNumber((opA).count.toDouble());
      } else if (op == LineOp.aEqualB) {
        return ValNumber((opA).equality(opB!));
      } else if (op == LineOp.aNotEqualB) {
        return ValNumber(1.0 - (opA).equality(opB!));
      } else if (op == LineOp.aPlusB) {
        // map combination
        final map = opA.map;
        Check.type<ValMap>(opB, "map combination");
        final map2 = (opB as ValMap).map;

        final ValMap result = ValMap();
        for (final kv in map.entries) {
          result.map[kv.key] = context.valueInContext(kv.value);
        }
        for (final kv in map2.entries) {
          result.map[kv.key] = context.valueInContext(kv.value);
        }

        return result;
      } else if (op == LineOp.notA) {
        return ValNumber.truth(!opA.boolValue());
      }
    } else if (opA is ValFunction && opB is ValFunction) {
      final fA = (opA).function;
      final fB = (opB).function;

      switch (op) {
        case LineOp.aEqualB:
          return ValNumber.truth(identical(fA, fB));
        case LineOp.aNotEqualB:
          return ValNumber.truth(!identical(fA, fB));
        default:
          break;
      }
    } else {
      // opA is something else... perhaps null
      switch (op) {
        case LineOp.bindAssignA:
          context.variables ??= ValMap();
          final ValFunction valFunc = opA as ValFunction;
          return valFunc.bindAndCopy(context.variables!);

        case LineOp.notA:
          return opA != null && opA.boolValue()
              ? ValNumber.zero
              : ValNumber.one;

        case LineOp.elemBofA:
          if (opA == null) {
            throw TypeException(
                "Null Reference Exception: can't index into null");
          } else {
            throw TypeException("Type Exception: can't index into this type");
          }
        default:
          break;
      }
    }

    if (op == LineOp.aAndB || op == LineOp.aOrB) {
      // We already handled the case where opA was a number above;
      // this code handles the case where opA is something else.
      final double fA = opA != null && opA.boolValue() ? 1 : 0;
      double fB;
      if (opB is ValNumber) {
        fB = (opB).value;
      } else {
        fB = opB != null && opB.boolValue() ? 1 : 0;
      }
      double result;
      if (op == LineOp.aAndB) {
        result = _absClamp01(fA * fB);
      } else {
        result = _absClamp01(fA + fB - fA * fB);
      }

      return ValNumber(result);
    }

    return null;
  }

  /// Helper method to clamp values between 0 and 1 and ensure positive
  double _absClamp01(double d) {
    if (d < 0) d = -d;
    if (d > 1) d = 1;
    return d;
  }
}
