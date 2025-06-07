import 'package:miniscript/miniscript_intrinsics/intrinsic_result.dart';
import 'package:miniscript/miniscript_tac/context.dart' as tac;

/// IntrinsicCode is a function type for the actual Dart code invoked by an intrinsic method.
typedef IntrinsicCode = IntrinsicResult Function(
  tac.Context context, [
  IntrinsicResult? partialResult,
]);
