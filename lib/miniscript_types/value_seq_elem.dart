import 'package:miniscript/miniscript_types/value.dart';

import '../miniscript_tac/tac.dart' as tac;
import './value_map.dart' show ValMap;
import './value_list.dart' show ValList;
import './value_string.dart' show TempValString, ValString;
import './value_number.dart' show ValNumber;
import './value_variable.dart' show ValVar;
import './value_temp.dart' show ValTemp;
import '../value_pointer.dart' show ValuePointer;
import '../miniscript_intrinsics/intrinsics.dart' show Intrinsics;
import '../miniscript_errors.dart'
    show
        LimitExceededException,
        KeyException,
        TypeException,
        UndefinedIdentifierException;

class ValSeqElem extends Value {
  final Value? sequence;
  final Value? index;

  /// reflects use of "@" (address-of) operator
  bool noInvoke = false;

  ValSeqElem(this.sequence, this.index);

  /// Look up the given identifier in the given sequence, walking the type chain
  /// until we either find it, or fail.
  static Value? resolve(
    Value? sequence,
    String identifier,
    tac.Context context,
    ValuePointer<ValMap> valueFoundIn,
  ) {
    var includeMapType = true;
    valueFoundIn.value = null;
    int loopsLeft = ValMap.maxIsaDepth;

    while (sequence != null) {
      if (sequence is ValTemp || sequence is ValVar) {
        sequence = sequence.val(context);
      }

      if (sequence is ValMap) {
        // If the map contains this identifier, return its value.

        final resultPointer = ValuePointer<Value>();
        var idVal = TempValString.get(identifier);
        bool found = sequence.tryGetValue(idVal, resultPointer);
        TempValString.release(idVal);

        if (found) {
          valueFoundIn.value = sequence;
          return resultPointer.value;
        }

        // Otherwise, if we have an __isa, try that next.
        if (loopsLeft < 0) {
          throw LimitExceededException(
            "__isa depth exceeded (perhaps a reference loop?)",
          );
        }
        ValuePointer<Value> isaPointer = ValuePointer(null);
        if (!(sequence).tryGetValue(
          ValString.magicIsA,
          isaPointer,
        )) {
          // ...and if we don't have an __isa, try the generic map type if allowed
          if (!includeMapType) throw KeyException(identifier);
          sequence = context.vm?.mapType ?? Intrinsics.mapType();
          includeMapType = false;
        } else {
          sequence = isaPointer.value;
        }
      } else if (sequence is ValList) {
        sequence = context.vm?.listType ?? Intrinsics.listType();
        includeMapType = false;
      } else if (sequence is ValString) {
        sequence = context.vm?.stringType ?? Intrinsics.stringType();
        includeMapType = false;
      } else if (sequence is ValNumber) {
        sequence = context.vm?.numberType ?? Intrinsics.numberType();
        includeMapType = false;
      } else {
        throw TypeException(
          "Type Error (while attempting to look up $identifier)",
        );
      }

      loopsLeft--;
    }

    return null;
  }

  @override
  Value? val(tac.Context context) {
    return valWithMap(context, ValuePointer<ValMap>(null));
  }

  @override
  Value? valWithMap(tac.Context context, ValuePointer<ValMap> valueFoundIn) {
    var baseSeq = sequence;
    if (sequence == ValVar.self) {
      baseSeq = context.self;
      if (baseSeq == null) throw UndefinedIdentifierException("self");
    }

    valueFoundIn.value = null;
    final idxVal = index?.val(context);

    if (idxVal is ValString) {
      return resolve(baseSeq, (idxVal).value, context, valueFoundIn);
    }

    final baseVal = baseSeq!.val(context);
    if (baseVal is ValMap) {
      final result = baseVal.lookup(idxVal, valueFoundIn);
      if (valueFoundIn.value == null) {
        throw KeyException(
          idxVal == null
              ? "null"
              : idxVal.codeForm(context.vm!, recursionLimit: 1),
        );
      }
      return result;
    } else if (baseVal is ValList) {
      return (baseVal).getElem(idxVal!);
    } else if (baseVal is ValString) {
      return (baseVal).getElem(idxVal!);
    } else if (baseVal == null) {
      throw TypeException("Null Reference Exception: can't index into null");
    }

    throw TypeException("Type Exception: can't index into this type");
  }

  @override
  String toStringWithVM([tac.Machine? vm]) {
    return "${noInvoke ? '@' : ''}$sequence[$index]";
  }

  @override
  int hash() {
    return sequence!.hash() ^ index!.hash();
  }

  @override
  double equality(Value? rhs) {
    return rhs is ValSeqElem &&
            (rhs).sequence == sequence &&
            (rhs).index == index
        ? 1
        : 0;
  }
}
