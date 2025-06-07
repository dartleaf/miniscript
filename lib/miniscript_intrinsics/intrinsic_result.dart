import 'package:miniscript/miniscript_types/value.dart';
import 'package:miniscript/miniscript_types/value_number.dart';
import 'package:miniscript/miniscript_types/value_string.dart';

/// Result represents the result of an intrinsic call.
class IntrinsicResult {
  bool done; // true if work is complete; false if we need to continue
  Value? result; // final result if done; in-progress data if not done

  /// Result constructor taking a Value, and an optional done flag.
  IntrinsicResult(this.result, {this.done = true});

  /// Result constructor for a simple numeric result.
  IntrinsicResult.fromNum(double resultNum, {this.done = true})
      : result = ValNumber(resultNum);

  /// Result constructor for a simple boolean result.
  IntrinsicResult.fromTruth(bool resultBool, {this.done = true})
      : result = ValNumber(resultBool ? 1.0 : 0.0);

  /// Result constructor for a simple string result.
  IntrinsicResult.fromString(String resultStr, {this.done = true})
      : result = resultStr.isEmpty ? ValString.empty : ValString(resultStr);

  /// Static Result representing null (no value).
  static var null_ = IntrinsicResult(null);

  /// Static Result representing "" (empty string).
  static var emptyString = IntrinsicResult(ValString.empty);

  /// Static Result representing true (1.0).
  static var true_ = IntrinsicResult(ValNumber.one);

  /// Static Result representing false (0.0).
  static var false_ = IntrinsicResult(ValNumber.zero);

  /// Static Result representing a need to wait, with no in-progress value.
  static var waiting = IntrinsicResult(null, done: false);
}
