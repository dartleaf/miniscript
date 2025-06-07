import 'package:miniscript/miniscript_intrinsics/intrinsic_code.dart';
import 'package:miniscript/miniscript_intrinsics/intrinsic_result.dart';
import 'package:miniscript/miniscript_intrinsics/intrinsics.dart';
import 'package:miniscript/miniscript_tac/tac.dart' as tac;
import 'package:miniscript/miniscript_types/function.dart';
import 'package:miniscript/miniscript_types/value.dart';
import 'package:miniscript/miniscript_types/value_number.dart';
import 'package:miniscript/miniscript_types/value_string.dart';

/// Intrinsic: represents an intrinsic function available to MiniScript code.
class Intrinsic {
  /// Name of this intrinsic (should be a valid MiniScript identifier)
  String name = '';

  /// Actual Dart code invoked by the intrinsic
  IntrinsicCode? code;

  /// A numeric ID (used internally)
  int get id => numericID;

  late VFunction function;
  late ValFunction valFunction;
  int numericID = 0;

  static final all = <Intrinsic?>[null];
  static final Map<String, Intrinsic> nameMap = {};

  static final null_ = IntrinsicResult(null, done: true);
  static final emptyString = IntrinsicResult(ValString.empty);
  static final true_ = IntrinsicResult(ValNumber.one, done: true);
  static final false_ = IntrinsicResult(ValNumber.zero, done: true);

  // static map from Values to short names, used when displaying lists/maps;
  // feel free to add to this any values (especially lists/maps) provided
  // by your own intrinsics.
  static final shortNames = <Value, String>{};

  @override
  String toString() {
    return "Intrinsic: $name (ID: $numericID)";
  }

  /// Factory method to create a new Intrinsic
  static Intrinsic create(String name) {
    final result = Intrinsic();
    result.name = name;
    result.numericID = all.length;
    result.function = VFunction(null);
    result.valFunction = ValFunction(result.function);
    all.add(result);
    nameMap[name] = result;
    return result;
  }

  /// Look up an Intrinsic by its internal numeric ID.
  static Intrinsic getByID(int id) {
    return all[id]!;
  }

  /// Look up an Intrinsic by its name.
  static Intrinsic? getByName(String name) {
    Intrinsics.initIfNeeded();
    return nameMap[name];
  }

  /// Add a parameter to this Intrinsic, optionally with a default value.
  void addParam(String name, [Value? defaultValue]) {
    function.parameters.add(FunctionParam(name, defaultValue));
  }

  /// Add a parameter with a numeric default value.
  void addParamNum(String name, double defaultValue) {
    Value defVal = switch (defaultValue) {
      0 => ValNumber.zero,
      1 => ValNumber.one,
      _ => ValNumber(defaultValue),
    };
    function.parameters.add(FunctionParam(name, defVal));
  }

  /// Add a parameter with a string default value.
  void addParamStr(String name, String? defaultValue) {
    Value defVal = switch (defaultValue) {
      "" => ValString.empty,
      null => ValString.empty,
      "__isa" => ValString.magicIsA,
      "self" => ValString("self"),
      _ => ValString(defaultValue),
    };
    function.parameters.add(FunctionParam(name, defVal));
  }

  /// GetFunc is used by the compiler to get the MiniScript function for an intrinsic call.

  ValFunction getFunc() {
    function.code ??= [
      tac.Line(
        tac.lTemp(0),
        tac.LineOp.callIntrinsicA,
        tac.num(numericID.toDouble()),
      )
    ];
    return valFunction;
  }

  /// Execute an intrinsic by ID given a context and partial result.
  static IntrinsicResult execute(
    int id,
    tac.Context context,
    IntrinsicResult? partialResult,
  ) {
    final item = getByID(id);
    return item.code!.call(context, partialResult);
  }
}
