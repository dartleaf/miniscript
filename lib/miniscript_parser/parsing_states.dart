// Copyright © 2025 by the authors of the project. All rights reserved.

import '../miniscript_tac/tac.dart' as tac;
import '../miniscript_types/value_number.dart';
import '../miniscript_errors.dart';

/// BackPatch: represents a place where we need to patch the code to fill
/// in a jump destination (once we figure out where that destination is).
class BackPatch {
  int lineNum;
  String waitingFor;

  BackPatch({
    required this.lineNum,
    required this.waitingFor,
  });
}

/// JumpPoint: represents a place in the code we will need to jump to later
/// (typically, the top of a loop of some sort).
class JumpPoint {
  int lineNum;
  String keyword;

  JumpPoint({
    required this.lineNum,
    required this.keyword,
  });
}

class ParseState {
  List<tac.Line> code = [];
  List<BackPatch> backpatches = [];
  List<JumpPoint> jumpPoints = [];
  int nextTempNum = 0;
  String?
      localOnlyIdentifier; // identifier to be looked up in local scope *only*
  bool localOnlyStrict =
      false; // whether localOnlyIdentifier applies strictly, or merely warns

  void add(tac.Line line) {
    code.add(line);
  }

  /// Add the last code line as a backpatch point, to be patched
  /// (in rhsA) when we encounter a line with the given waitFor.
  void addBackpatch(String waitFor) {
    backpatches.add(BackPatch(lineNum: code.length - 1, waitingFor: waitFor));
  }

  void addJumpPoint(String jumpKeyword) {
    jumpPoints.add(JumpPoint(lineNum: code.length, keyword: jumpKeyword));
  }

  JumpPoint closeJumpPoint(String keyword) {
    int idx = jumpPoints.length - 1;
    if (idx < 0 || jumpPoints[idx].keyword != keyword) {
      throw CompilerException("'end $keyword' without matching '$keyword'");
    }
    JumpPoint result = jumpPoints[idx];
    jumpPoints.removeAt(idx);
    return result;
  }

  /// Return whether the given line is a jump target.
  bool isJumpTarget(int lineNum) {
    for (int i = 0; i < code.length; i++) {
      var op = code[i].op;
      if ((op == tac.LineOp.gotoA ||
              op == tac.LineOp.gotoAifB ||
              op == tac.LineOp.gotoAifNotB ||
              op == tac.LineOp.gotoAifTrulyB) &&
          code[i].rhsA is ValNumber &&
          (code[i].rhsA as ValNumber).intValue() == lineNum) {
        return true;
      }
    }
    for (int i = 0; i < jumpPoints.length; i++) {
      if (jumpPoints[i].lineNum == lineNum) return true;
    }
    return false;
  }

  /// Call this method when we've found an 'end' keyword, and want
  /// to patch up any jumps that were waiting for that.  Patch the
  /// matching backpatch (and any after it) to the current code end.
  void patch(
    String keywordFound, {
    bool alsoBreak = false,
    int reservingLines = 0,
  }) {
    final target = ValNumber((code.length + reservingLines).toDouble());
    bool done = false;

    for (int idx = backpatches.length - 1; idx >= 0 && !done; idx--) {
      final bp = backpatches[idx];
      bool patchIt = false;

      if (bp.waitingFor == keywordFound) {
        patchIt = true;
        done = true;
      } else if (bp.waitingFor == "break") {
        // Not the expected keyword, but "break"; this is always OK,
        // but we may or may not patch it depending on the call.
        patchIt = alsoBreak;
      } else {
        // Not the expected patch, and not "break"; we have a mismatched block start/end.
        throw CompilerException(
            "'$keywordFound' skips expected '${bp.waitingFor}'");
      }

      if (patchIt) {
        code[bp.lineNum].rhsA = target;
        backpatches.removeAt(idx);
      }
    }

    // Make sure we found one...
    if (!done) {
      throw CompilerException("'$keywordFound' without matching block starter");
    }
  }

  /// Patches up all the branches for a single open if block.  That includes
  /// the last "else" block, as well as one or more "end if" jumps.
  void patchIfBlock(bool singleLineIf) {
    ValNumber target = ValNumber(code.length.toDouble());

    int idx = backpatches.length - 1;
    while (idx >= 0) {
      BackPatch bp = backpatches[idx];
      if (bp.waitingFor == "if:MARK") {
        // There's the special marker that indicates the true start of this if block.
        backpatches.removeAt(idx);
        return;
      } else if (bp.waitingFor == "end if" || bp.waitingFor == "else") {
        code[bp.lineNum].rhsA = target;
        backpatches.removeAt(idx);
      } else if (backpatches[idx].waitingFor == "break") {
        // Not the expected keyword, but "break"; this is always OK.
      } else {
        // Not the expected patch, and not "break"; we have a mismatched block start/end.
        String msg;
        if (singleLineIf) {
          if (bp.waitingFor == "end for" || bp.waitingFor == "end while") {
            msg = "loop is invalid within single-line 'if'";
          } else {
            msg = "invalid control structure within single-line 'if'";
          }
        } else {
          msg = "'end if' without matching 'if'";
        }
        throw CompilerException(msg);
      }
      idx--;
    }
    // If we get here, we never found the expected if:MARK.  That's an error.
    throw CompilerException("'end if' without matching 'if'");
  }
}
