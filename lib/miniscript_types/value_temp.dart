import '../miniscript_tac/tac.dart' as tac;
import '../value_pointer.dart' show ValuePointer;
import './value_map.dart' show ValMap;
import 'value.dart';

class ValTemp extends Value {
  final int tempNum;

  ValTemp(this.tempNum);

  @override
  Value? val(tac.Context context) {
    return context.getTemp(tempNum);
  }

  @override
  Value? valWithMap(tac.Context context, ValuePointer<ValMap> valueFoundIn) {
    valueFoundIn.value = null;
    return context.getTemp(tempNum);
  }

  @override
  String toStringWithVM([tac.Machine? vm]) {
    return "_$tempNum";
  }

  @override
  int hash() {
    return tempNum.hashCode;
  }

  @override
  double equality(Value? rhs) {
    return rhs is ValTemp && rhs.tempNum == tempNum ? 1 : 0;
  }
}
