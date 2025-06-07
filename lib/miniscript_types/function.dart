import '../miniscript_tac/tac.dart' as tac;
import './value_map.dart' show ValMap;
import './value.dart' show Value;

/// Param: helper class representing a function parameter.
class FunctionParam {
  final String name;
  final Value? defaultValue;

  FunctionParam(this.name, [this.defaultValue]);
}

/// Function: our internal representation of a MiniScript function.  This includes
/// its parameters and its code.  (It does not include a name -- functions don't
/// actually HAVE names; instead there are named variables whose value may happen
/// to be a function.)
class VFunction {
  /// Function parameters
  final List<FunctionParam> parameters;

  /// Function code (compiled down to TAC form)
  List<tac.Line>? code;

  VFunction([this.code]) : parameters = [];

  String toStringWithVM([tac.Machine? vm]) {
    final buffer = StringBuffer();
    buffer.write("FUNCTION(");

    for (var i = 0; i < parameters.length; i++) {
      if (i > 0) buffer.write(", ");
      buffer.write(parameters[i].name);
      if (parameters[i].defaultValue != null) {
        buffer.write("=${parameters[i].defaultValue!.codeForm(vm)}");
      }
    }

    buffer.write(")");
    return buffer.toString();
  }
}

/// ValFunction: a Value that is, in fact, a Function.
class ValFunction extends Value {
  final VFunction function;

  /// local variables where the function was defined (usually, the module)
  final ValMap? outerVars;

  ValFunction(this.function) : outerVars = null;

  ValFunction.withOuterVars(this.function, this.outerVars);

  @override
  String toStringWithVM([tac.Machine? vm]) {
    return function.toStringWithVM(vm);
  }

  @override
  bool boolValue() {
    // A function value is ALWAYS considered true.
    return true;
  }

  @override
  bool isA(Value? type, tac.Machine vm) {
    if (type == null) return false;
    return identical(type, vm.functionType);
  }

  @override
  int hash() {
    return function.hashCode;
  }

  @override
  double equality(Value? rhs) {
    if (rhs is! ValFunction) return 0;
    return identical(this, rhs) || identical(function, rhs.function) ? 1 : 0;
  }

  ValFunction bindAndCopy(ValMap contextVariables) {
    return ValFunction.withOuterVars(function, contextVariables);
  }
}
