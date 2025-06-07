import 'package:miniscript/miniscript_tac/line.dart';
import 'package:miniscript/miniscript_types/function.dart';

void dump(List<Line> lines, int lineNumToHighlight, [int indent = 0]) {
  int lineNum = 0;
  for (Line line in lines) {
    String s = "${lineNum == lineNumToHighlight ? "> " : "  "}${lineNum++}. ";

    print("$s$line");
    if (line.op == LineOp.bindAssignA) {
      ValFunction func = line.rhsA as ValFunction;
      dump(func.function.code!, -1, indent + 1);
    }
  }
}
