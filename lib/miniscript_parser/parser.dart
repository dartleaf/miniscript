import 'package:miniscript/miniscript_interpreter.dart';
import 'package:miniscript/miniscript_types/function.dart';
import 'package:miniscript/miniscript_types/value_null.dart';
import 'package:miniscript/miniscript_types/value_seq_elem.dart';

import '../miniscript_tac/tac.dart' as tac;
import '../miniscript_types/value_map.dart';
import '../miniscript_types/value_list.dart';
import '../miniscript_types/value_string.dart';
import '../miniscript_types/value_number.dart';
import '../miniscript_types/value_variable.dart';
import '../miniscript_types/value_temp.dart';
import '../miniscript_types/value.dart';
import '../miniscript_intrinsics/intrinsics.dart';
import '../miniscript_errors.dart';
import '../miniscript_lexer.dart';
import './parsing_states.dart';

class Parser {
  /// name of file, etc., used for error reporting
  String errorContext = '';

  /// Partial input, in the case where line continuation has been used.
  String? partialInput;

  /// List of open code blocks we're working on (while compiling a function,
  /// we push a new one onto this stack, compile to that, and then pop it
  /// off when we reach the end of the function).
  List<ParseState?>? outputStack;

  /// Handy reference to the top of outputStack.
  ParseState? output;

  /// A new parse state that needs to be pushed onto the stack, as soon as we
  /// finish with the current line we're working on:
  ParseState? pendingState;

  Parser() {
    reset();
  }

  /// Completely clear out and reset our parse state, throwing out
  /// any code and intermediate results.
  void reset() {
    output = ParseState();
    if (outputStack == null) {
      outputStack = [];
    } else {
      outputStack!.clear();
    }
    outputStack!.add(output);
  }

  /// Partially reset, abandoning backpatches, but keeping already-
  /// compiled code.  This would be used in a REPL, when the user
  /// may want to reset and continue after a botched loop or function.
  void partialReset() {
    outputStack ??= [];
    while (outputStack!.length > 1) {
      outputStack!.removeLast();
    }
    output = outputStack!.last;
    output?.backpatches.clear();
    output?.jumpPoints.clear();
    output?.nextTempNum = 0;
    partialInput = null;
    pendingState = null;
  }

  bool needMoreInput() {
    if (partialInput != null && partialInput!.isNotEmpty) return true;
    if (outputStack!.length > 1) return true;
    if (output!.backpatches.isNotEmpty) return true;
    return false;
  }

  /// Return whether the given source code ends in a token that signifies that
  /// the statement continues on the next line.  That includes binary operators,
  /// open brackets or parentheses, etc.
  static bool endsWithLineContinuation(String sourceCode) {
    try {
      final lastTok = Lexer.lastToken(sourceCode);
      // Almost any token at the end will signify line continuation, except:
      switch (lastTok.type) {
        case TokenType.eol:
        case TokenType.identifier:
        case TokenType.number:
        case TokenType.rCurly:
        case TokenType.rParen:
        case TokenType.rSquare:
        case TokenType.string:
        case TokenType.unknown:
          return false;
        case TokenType.keyword:
          // of keywords, only these can cause line continuation:
          return lastTok.text == 'and' ||
              lastTok.text == 'or' ||
              lastTok.text == 'isa' ||
              lastTok.text == 'not' ||
              lastTok.text == 'new';
        default:
          return true;
      }
    } on LexerException {
      return false;
    }
  }

  void _checkForOpenBackpatches(int sourceLineNum) {
    if (output!.backpatches.isEmpty) return;
    final bp = output!.backpatches.last;
    String msg;
    switch (bp.waitingFor) {
      case 'end for':
        msg = "'for' without matching 'end for'";
        break;
      case 'end if':
      case 'else':
        msg = "'if' without matching 'end if'";
        break;
      case 'end while':
        msg = "'while' without matching 'end while'";
        break;
      default:
        msg = "unmatched block opener";
        break;
    }
    throw CompilerException.withLocation(errorContext, sourceLineNum, msg);
  }

  void parse(String sourceCode, {bool replMode = false}) {
    if (replMode) {
      // Check for an incomplete final line by finding the last (non-comment) token.
      final bool isPartial = endsWithLineContinuation(sourceCode);
      if (isPartial) {
        partialInput = '${partialInput ?? ""}${Lexer.trimComment(sourceCode)} ';
        return;
      }
    }
    final Lexer tokens = Lexer('${partialInput ?? ''}$sourceCode');
    partialInput = null;
    _parseMultipleLines(tokens);

    if (!replMode && needMoreInput()) {
      // Whoops, we need more input but we don't have any.  This is an error.
      tokens
          .lineNum++; // (so we report PAST the last line, making it clear this is an EOF problem)
      if (outputStack!.length > 1) {
        throw CompilerException.withLocation(
          errorContext,
          tokens.lineNum,
          "'function' without matching 'end function'",
        );
      }
      _checkForOpenBackpatches(tokens.lineNum);
    }
  }

  /// Create a virtual machine loaded with the code we have parsed.
  tac.Machine createVM([TextOutputMethod? standardOutput]) {
    final tac.Context root = tac.Context(output!.code);
    return tac.Machine(root, standardOutput);
  }

  /// Create a Function with the code we have parsed, for use as
  /// an import.  That means, it runs all that code, then at the
  /// end it returns `locals` so that the caller can get its symbols.
  VFunction createImport() {
    // Add one additional line to return `locals` as the function return value.
    final locals = ValVar('locals');
    output!.add(tac.Line(tac.lTemp(0), tac.LineOp.returnA, locals));
    // Then wrap the whole thing in a Function.
    return VFunction(output!.code);
  }

  void repl(String line) {
    parse(line);
    final tac.Machine vm = createVM(null);
    while (!vm.done) {
      vm.step();
    }
  }

  void _allowLineBreak(Lexer tokens) {
    while (tokens.peek().type == TokenType.eol && !tokens.atEnd) {
      tokens.dequeue();
    }
  }

  /// Parse multiple statements until we run out of tokens, or reach 'end function'.
  void _parseMultipleLines(Lexer tokens) {
    while (!tokens.atEnd) {
      // Skip any blank lines
      if (tokens.peek().type == TokenType.eol) {
        tokens.dequeue();
        continue;
      }

      // Prepare a source code location for error reporting
      final SourceLoc location = SourceLoc(errorContext, tokens.lineNum);

      // Pop our context if we reach 'end function'.
      if (tokens.peek().type == TokenType.keyword &&
          tokens.peek().text == 'end function') {
        tokens.dequeue();
        if (outputStack!.length > 1) {
          _checkForOpenBackpatches(tokens.lineNum);
          outputStack!.removeLast();
          output = outputStack!.last;
        } else {
          throw CompilerException.withLocation(
            "'end function' without matching block starter",
            tokens.lineNum,
            errorContext,
          );
        }
        continue;
      }

      // Parse one line (statement).
      final outputStart = output!.code.length;
      try {
        _parseStatement(tokens);
      } on MiniscriptException catch (mse) {
        mse.location ??= location;
        rethrow;
      }
      // Fill in the location info for all the TAC lines we just generated.
      for (int i = outputStart; i < output!.code.length; i++) {
        output!.code[i].location = location;
      }
    }
  }

  void _parseStatement(Lexer tokens, {bool allowExtra = false}) {
    if (tokens.peek().type == TokenType.keyword &&
        tokens.peek().text != 'not' &&
        tokens.peek().text != 'true' &&
        tokens.peek().text != 'false') {
      // Handle statements that begin with a keyword.
      final keyword = tokens.dequeue().text!;
      switch (keyword) {
        case 'return':
          Value? returnValue;
          if (tokens.peek().type != TokenType.eol &&
              tokens.peek().text != 'else' &&
              tokens.peek().text != 'else if') {
            returnValue = _parseExpr(tokens);
          }
          output!.add(tac.Line(tac.lTemp(0), tac.LineOp.returnA, returnValue));
          break;
        case 'if':
          final condition = _parseExpr(tokens);
          _requireToken(tokens, TokenType.keyword, 'then');
          // OK, now we need to emit a conditional branch, but keep track of this
          // on a stack so that when we get the corresponding "else" or  "end if",
          // we can come back and patch that jump to the right place.
          output!.add(tac.Line(null, tac.LineOp.gotoAifNotB, null, condition));

          // ...but if blocks also need a special marker in the backpack stack
          // so we know where to stop when patching up (possibly multiple) 'end if' jumps.
          // We'll push a special dummy backpatch here that we look for in PatchIfBlock.
          output!.addBackpatch('if:MARK');
          output!.addBackpatch('else');

          // Allow for the special one-statement if: if the next token after "then"
          // is not EOL, then parse a statement, and do the same for any else or
          // else-if blocks, until we get to EOL (and then implicitly do "end if").
          if (tokens.peek().type != TokenType.eol) {
            _parseStatement(tokens,
                allowExtra:
                    true); // parses a single statement for the "then" body
            if (tokens.peek().type == TokenType.keyword &&
                tokens.peek().text == 'else') {
              tokens.dequeue(); // skip "else"
              _startElseClause();
              _parseStatement(
                tokens,
                allowExtra: true,
              ); // parse a single statement for the "else" body
            } else if (tokens.peek().type == TokenType.keyword &&
                tokens.peek().text == 'else if') {
              tokens.peek().text =
                  'if'; // the trick: convert the "else if" token to a regular "if"...
              _startElseClause(); // but start an else clause...
              _parseStatement(
                tokens,
                allowExtra: true,
              ); // then parse a single statement starting with "if"
            } else {
              _requireEitherToken(
                tokens,
                TokenType.keyword,
                'else',
                TokenType.eol,
              ); // terminate the single-line if
            }
            output!.patchIfBlock(true);
          } else {
            tokens.dequeue(); // skip EOL
          }
          return;
        case 'else':
          _startElseClause();
          break;
        case 'else if':
          _startElseClause();
          final condition = _parseExpr(tokens);
          _requireToken(tokens, TokenType.keyword, 'then');
          output!.add(tac.Line(null, tac.LineOp.gotoAifNotB, null, condition));
          output!.addBackpatch('else');
          break;
        case 'end if':
          // OK, this is tricky.  We might have an open "else" block or we might not.
          // And, we might have multiple open "end if" jumps (one for the if part,
          // and another for each else-if part).  Patch all that as a special case.
          output!.patchIfBlock(false);
          break;
        case 'while':
          // We need to note the current line, so we can jump back up to it at the end.
          output!.addJumpPoint(keyword);
          // Then parse the condition.
          final condition = _parseExpr(tokens);

          // OK, now we need to emit a conditional branch, but keep track of this
          // on a stack so that when we get the corresponding "end while",
          // we can come back and patch that jump to the right place.
          output!.add(tac.Line(null, tac.LineOp.gotoAifNotB, null, condition));
          output!.addBackpatch('end while');
          break;
        case 'end while':
          // Unconditional jump back to the top of the while loop.
          final JumpPoint jump = output!.closeJumpPoint('while');
          output!.add(tac.Line(
            null,
            tac.LineOp.gotoA,
            tac.num(jump.lineNum.toDouble()),
          ));
          // Then, backpatch the open "while" branch to here, right after the loop.
          // And also patch any "break" branches emitted after that point.
          output!.patch(keyword, alsoBreak: true);
          break;
        case 'for':
          // Get the loop variable, "in" keyword, and expression to loop over.
          // (Note that the expression is only evaluated once, before the loop.)
          final loopVarTok = _requireToken(tokens, TokenType.identifier);
          final loopVar = ValVar(loopVarTok.text!);
          _requireToken(tokens, TokenType.keyword, 'in');
          final stuff = _parseExpr(tokens);
          if (stuff == null) {
            throw CompilerException.withLocation(
              errorContext,
              tokens.lineNum,
              "sequence expression expected for 'for' loop",
            );
          }
          // Create an index variable to iterate over the sequence, initialized to -1.
          final idxVar = ValVar('__${loopVarTok.text}_idx');
          output!.add(tac.Line(idxVar, tac.LineOp.assignA, tac.num(-1)));

          // Now increment the index variable, and branch to the end if it's too big.
          // (We'll have to backpatch this branch later.)
          output!.addJumpPoint(keyword);
          output!.add(tac.Line(idxVar, tac.LineOp.aPlusB, idxVar, tac.num(1)));
          final ValTemp sizeOfSeq = ValTemp(output!.nextTempNum++);
          output!.add(tac.Line(sizeOfSeq, tac.LineOp.lengthOfA, stuff));
          final ValTemp isTooBig = ValTemp(output!.nextTempNum++);
          output!.add(
              tac.Line(isTooBig, tac.LineOp.aGreatOrEqualB, idxVar, sizeOfSeq));
          output!.add(tac.Line(null, tac.LineOp.gotoAifB, null, isTooBig));
          output!.addBackpatch('end for');
          // Otherwise, get the sequence value into our loop variable.
          output!
              .add(tac.Line(loopVar, tac.LineOp.elemBofIterA, stuff, idxVar));
          break;
        case 'end for':
          // Unconditional jump back to the top of the for loop.
          final JumpPoint jump = output!.closeJumpPoint('for');

          output!.add(
            tac.Line(
              null,
              tac.LineOp.gotoA,
              tac.num(jump.lineNum.toDouble()),
            ),
          ); // Then, backpatch the open "for" branch to here, right after the loop.
          // And also patch any "break" branches emitted after that point.
          output!.patch(keyword, alsoBreak: true);
          break;
        case 'break':
          // Emit a jump to the end, to get patched up later.
          if (output!.jumpPoints.isEmpty) {
            throw CompilerException.withLocation(
              errorContext,
              tokens.lineNum,
              "'break' without open loop block",
            );
          }
          output!.add(tac.Line(null, tac.LineOp.gotoA));
          output!.addBackpatch('break');
          break;
        case 'continue':

          // Jump unconditionally back to the current open jump point.
          if (output!.jumpPoints.isEmpty) {
            throw CompilerException.withLocation(
              errorContext,
              tokens.lineNum,
              "'continue' without open loop block",
            );
          }
          final JumpPoint jump = output!.jumpPoints.last;
          output!.add(
            tac.Line(null, tac.LineOp.gotoA, tac.num(jump.lineNum.toDouble())),
          );
          break;
        default:
          throw CompilerException.withLocation(
            errorContext,
            tokens.lineNum,
            "unexpected keyword '$keyword' at start of line",
          );
      }
    } else {
      _parseAssignment(tokens, allowExtra: allowExtra);
    }

    // A statement should consume everything to the end of the line.
    if (!allowExtra) _requireToken(tokens, TokenType.eol);

    // Finally, if we have a pending state, because we encountered a function(),
    // then push it onto our stack now that we're done with that statement.
    if (pendingState != null) {
      output = pendingState!;
      outputStack!.add(output);
      pendingState = null;
    }
  }

  void _startElseClause() {
    // Back-patch the open if block, but leaving room for the jump:
    // Emit the jump from the current location, which is the end of an if-block,
    // to the end of the else block (which we'll have to back-patch later).
    output!.add(tac.Line(null, tac.LineOp.gotoA));
    // Back-patch the previously open if-block to jump here (right past the goto).
    output!.patch('else');
    // And open a new back-patch for this goto (which will jump all the way to the end if).
    output!.addBackpatch('end if');
  }

  void _parseAssignment(Lexer tokens, {bool allowExtra = false}) {
    final expr = _parseExpr(tokens, asLval: true, statementStart: true);
    Value? lhs, rhs;
    final peek = tokens.peek();
    if (peek.type == TokenType.eol ||
        (peek.type == TokenType.keyword &&
            (peek.text == 'else' || peek.text == 'else if'))) {
      // No explicit assignment; store an implicit result
      rhs = _fullyEvaluate(expr);
      output!.add(tac.Line(null, tac.LineOp.assignImplicit, rhs));
      return;
    }
    if (peek.type == TokenType.opAssign) {
      tokens.dequeue(); // skip '='
      lhs = expr;
      output!.localOnlyIdentifier = null;
      output!.localOnlyStrict =
          false; // ToDo: make this always strict, and change "localOnly" to a simple bool
      if (lhs is ValVar) {
        output!.localOnlyIdentifier = lhs.identifier;
      }
      rhs = _parseExpr(tokens);
      output!.localOnlyIdentifier = null;
    } else if (peek.type == TokenType.opAssignPlus ||
        peek.type == TokenType.opAssignMinus ||
        peek.type == TokenType.opAssignTimes ||
        peek.type == TokenType.opAssignDivide ||
        peek.type == TokenType.opAssignMod ||
        peek.type == TokenType.opAssignPower) {
      var op = tac.LineOp.aPlusB;
      switch (tokens.dequeue().type) {
        case TokenType.opAssignMinus:
          op = tac.LineOp.aMinusB;
          break;
        case TokenType.opAssignTimes:
          op = tac.LineOp.aTimesB;
          break;
        case TokenType.opAssignDivide:
          op = tac.LineOp.aDividedByB;
          break;
        case TokenType.opAssignMod:
          op = tac.LineOp.aModB;
          break;
        case TokenType.opAssignPower:
          op = tac.LineOp.aPowB;
          break;
        default:
          break;
      }

      lhs = expr;
      output!.localOnlyIdentifier = null;
      output!.localOnlyStrict = true;
      if (lhs is ValVar) {
        output!.localOnlyIdentifier = lhs.identifier;
      }
      rhs = _parseExpr(tokens);

      final opA = _fullyEvaluate(lhs, localOnlyMode: LocalOnlyMode.strict);
      final opB = _fullyEvaluate(rhs);
      final tempNum = output!.nextTempNum++;
      output!.add(tac.Line(tac.lTemp(tempNum), op, opA, opB));
      rhs = tac.rTemp(tempNum);
      output!.localOnlyIdentifier = null;
    } else {
      // This looks like a command statement.  Parse the rest
      // of the line as arguments to a function call.
      final funcRef = expr;
      int argCount = 0;
      while (true) {
        final arg = _parseExpr(tokens);
        output!.add(tac.Line(null, tac.LineOp.pushParam, arg));
        argCount++;
        if (tokens.peek().type == TokenType.eol) break;
        if (tokens.peek().type == TokenType.keyword &&
            (tokens.peek().text == 'else' || tokens.peek().text == 'else if')) {
          break;
        }
        if (tokens.peek().type == TokenType.comma) {
          tokens.dequeue();
          _allowLineBreak(tokens);
          continue;
        }
        if (_requireEitherToken(tokens, TokenType.comma, null, TokenType.eol)
                .type ==
            TokenType.eol) {
          break;
        }
      }
      final ValTemp result = ValTemp(output!.nextTempNum++);
      output!.add(
        tac.Line(
          result,
          tac.LineOp.callFunctionA,
          funcRef,
          tac.num(argCount.toDouble()),
        ),
      );
      output!.add(tac.Line(null, tac.LineOp.assignImplicit, result));
      return;
    }

    // Now we need to assign the value in rhs to the lvalue in lhs.
    // First, check for the case where lhs is a temp; that indicates it is not an lvalue
    // (for example, it might be a list slice).
    if (lhs is ValTemp) {
      throw CompilerException.withLocation(
        errorContext,
        tokens.lineNum,
        "invalid assignment (not an lvalue)",
      );
    }

    // OK, now, in many cases our last TAC line at this point is an assignment to our RHS temp.
    // In that case, as a simple (but very useful) optimization, we can simply patch that to
    // assign to our lhs instead.  BUT, we must not do this if there are any jumps to the next
    // line, as may happen due to short-cut evaluation (issue #6).
    if (rhs is ValTemp &&
        output!.code.isNotEmpty &&
        !output!.isJumpTarget(output!.code.length)) {
      final tac.Line line = output!.code.last;
      if (line.lhs == rhs) {
        // Yep, that's the case.  Patch it up.
        line.lhs = lhs;
        return;
      }
    }

    // If the last line was us creating and assigning a function, then we don't add a second assign
    // op, we instead just update that line with the proper LHS
    if (rhs is ValFunction && output!.code.isNotEmpty) {
      final tac.Line line = output!.code.last;
      if (line.op == tac.LineOp.bindAssignA) {
        line.lhs = lhs;
        return;
      }
    }

    // In any other case, do an assignment statement to our lhs.
    output!.add(tac.Line(lhs, tac.LineOp.assignA, rhs));
  }

  Value? _parseExpr(
    Lexer tokens, {
    bool asLval = false,
    bool statementStart = false,
  }) {
    return _parseFunction(
      tokens,
      asLval: asLval,
      statementStart: statementStart,
    );
  }

  Value? _parseFunction(
    Lexer tokens, {
    bool asLval = false,
    bool statementStart = false,
  }) {
    var tok = tokens.peek();
    if (tok.type != TokenType.keyword || tok.text != 'function') {
      return _parseOr(
        tokens,
        asLval: asLval,
        statementStart: statementStart,
      );
    }
    tokens.dequeue();

    final VFunction func = VFunction();
    tok = tokens.peek();
    if (tok.type != TokenType.eol) {
      _requireToken(tokens, TokenType.lParen);
      while (tokens.peek().type != TokenType.rParen) {
        // parse a parameter: a comma-separated list of
        //			identifier
        //	or...	identifier = constant
        final id = tokens.dequeue();
        if (id.type != TokenType.identifier) {
          throw CompilerException.withLocation(errorContext, tokens.lineNum,
              "got $id where an identifier is required");
        }
        Value? defaultValue;
        if (tokens.peek().type == TokenType.opAssign) {
          tokens.dequeue(); // skip '='
          defaultValue = _parseExpr(tokens);
          // Ensure the default value is a constant, not an expression.
          if (defaultValue is ValTemp) {
            throw CompilerException.withLocation(
              errorContext,
              tokens.lineNum,
              "parameter default value must be a literal value",
            );
          }
        }
        func.parameters.add(FunctionParam(id.text!, defaultValue));
        if (tokens.peek().type == TokenType.rParen) break;
        _requireToken(tokens, TokenType.comma);
      }
      _requireToken(tokens, TokenType.rParen);
    }

    // Now, we need to parse the function body into its own parsing context.
    // But don't push it yet -- we're in the middle of parsing some expression
    // or statement in the current context, and need to finish that.
    if (pendingState != null) {
      throw CompilerException.withLocation(
        errorContext,
        tokens.lineNum,
        "can't start two functions in one statement",
      );
    }
    pendingState = ParseState();
    pendingState!.nextTempNum = 1; // (since 0 is used to hold return value)

    // Create a function object attached to the new parse state code.
    func.code = pendingState!.code;
    final valFunc = ValFunction(func);
    output!.add(tac.Line(null, tac.LineOp.bindAssignA, valFunc));
    return valFunc;
  }

  Value? _parseOr(
    Lexer tokens, {
    bool asLval = false,
    bool statementStart = false,
  }) {
    var val = _parseAnd(tokens, asLval: asLval, statementStart: statementStart);
    List<tac.Line>? jumpLines;
    var tok = tokens.peek();
    while (tok.type == TokenType.keyword && tok.text == 'or') {
      tokens.dequeue(); // discard "or"
      val = _fullyEvaluate(val);

      _allowLineBreak(tokens); // allow a line break after a binary operator

      // Set up a short-circuit jump based on the current value;
      // we'll fill in the jump destination later.  Note that the
      // usual GotoAifB opcode won't work here, without breaking
      // our calculation of intermediate truth.  We need to jump
      // only if our truth value is >= 1 (i.e. absolutely true).
      final jump = tac.Line(null, tac.LineOp.gotoAifTrulyB, null, val);
      output!.add(jump);
      jumpLines ??= [];
      jumpLines.add(jump);

      final opB = _parseAnd(tokens);
      final tempNum = output!.nextTempNum++;
      output!.add(tac.Line(tac.lTemp(tempNum), tac.LineOp.aOrB, val, opB));
      val = tac.rTemp(tempNum);

      tok = tokens.peek();
    }

    // Now, if we have any short-circuit jumps, those are going to need
    // to copy the short-circuit result (always 1) to our output temp.
    // And anything else needs to skip over that.  So:
    if (jumpLines != null) {
      output!.add(
        tac.Line(null, tac.LineOp.gotoA, tac.num(output!.code.length + 2)),
      ); // skip over this line:
      output!.add(
        tac.Line(val, tac.LineOp.assignA, ValNumber.one),
      ); // result = 1
      for (final jump in jumpLines) {
        jump.rhsA = tac.num(
          output!.code.length - 1,
        ); // short-circuit to the above result=1 line
      }
    }

    return val;
  }

  Value? _parseAnd(
    Lexer tokens, {
    bool asLval = false,
    bool statementStart = false,
  }) {
    var val = _parseNot(tokens, asLval: asLval, statementStart: statementStart);
    List<tac.Line>? jumpLines;
    var tok = tokens.peek();
    while (tok.type == TokenType.keyword && tok.text == 'and') {
      tokens.dequeue(); // discard "and"
      val = _fullyEvaluate(val);

      _allowLineBreak(tokens); // allow a line break after a binary operator

      // Set up a short-circuit jump based on the current value;
      // we'll fill in the jump destination later.
      final jump = tac.Line(null, tac.LineOp.gotoAifNotB, null, val);
      output!.add(jump);
      jumpLines ??= [];
      jumpLines.add(jump);

      final opB = _parseNot(tokens);
      final tempNum = output!.nextTempNum++;
      output!.add(tac.Line(tac.lTemp(tempNum), tac.LineOp.aAndB, val, opB));
      val = tac.rTemp(tempNum);
      tok = tokens.peek();
    }

    // Now, if we have any short-circuit jumps, those are going to need
    // to copy the short-circuit result (always 0) to our output temp.
    // And anything else needs to skip over that.  So:
    if (jumpLines != null) {
      output!.add(
        tac.Line(null, tac.LineOp.gotoA, tac.num(output!.code.length + 2)),
      ); // skip over this line:
      output!.add(
        tac.Line(val, tac.LineOp.assignA, ValNumber.zero),
      ); // result = 0
      for (final jump in jumpLines) {
        jump.rhsA = tac.num(
          output!.code.length - 1,
        ); // short-circuit to the above result=0 line
      }
    }

    return val;
  }

  Value? _parseNot(
    Lexer tokens, {
    bool asLval = false,
    bool statementStart = false,
  }) {
    final tok = tokens.peek();
    if (tok.type == TokenType.keyword && tok.text == 'not') {
      tokens.dequeue(); // discard "not"

      _allowLineBreak(tokens); // allow a line break after a unary operator

      final val = _parseIsA(tokens);
      final tempNum = output!.nextTempNum++;
      output!.add(tac.Line(tac.lTemp(tempNum), tac.LineOp.notA, val));
      return tac.rTemp(tempNum);
    } else {
      return _parseIsA(tokens, asLval: asLval, statementStart: statementStart);
    }
  }

  Value? _parseIsA(
    Lexer tokens, {
    bool asLval = false,
    bool statementStart = false,
  }) {
    var val = _parseComparisons(
      tokens,
      asLval: asLval,
      statementStart: statementStart,
    );
    if (tokens.peek().type == TokenType.keyword &&
        tokens.peek().text == 'isa') {
      tokens.dequeue(); // discard the isa operator
      _allowLineBreak(tokens); // allow a line break after a binary operator
      val = _fullyEvaluate(val);
      final opB = _parseComparisons(tokens);
      final tempNum = output!.nextTempNum++;
      output!.add(tac.Line(tac.lTemp(tempNum), tac.LineOp.aIsaB, val, opB));
      return tac.rTemp(tempNum);
    }
    return val;
  }

  Value? _parseComparisons(
    Lexer tokens, {
    bool asLval = false,
    bool statementStart = false,
  }) {
    var val = _parseAddSub(
      tokens,
      asLval: asLval,
      statementStart: statementStart,
    );
    var opA = val;
    tac.LineOp opcode = _comparisonOp(tokens.peek().type);
    // Parse a string of comparisons, all multiplied together
    // (so every comparison must be true for the whole expression to be true).
    bool firstComparison = true;
    while (opcode != tac.LineOp.noop) {
      tokens.dequeue(); // discard the operator (we have the opcode)
      opA = _fullyEvaluate(opA);

      _allowLineBreak(tokens); // allow a line break after a binary operator

      final opB = _parseAddSub(tokens);
      int tempNum = output!.nextTempNum++;
      output!.add(tac.Line(tac.lTemp(tempNum), opcode, opA, opB));
      if (firstComparison) {
        firstComparison = false;
      } else {
        tempNum = output!.nextTempNum++;
        output!.add(
          tac.Line(tac.lTemp(tempNum), tac.LineOp.aTimesB, val,
              tac.rTemp(tempNum - 1)),
        );
      }
      val = tac.rTemp(tempNum);
      opA = opB;
      opcode = _comparisonOp(tokens.peek().type);
    }
    return val;
  }

  // Find the TAC operator that corresponds to the given token type,
  // for comparisons.  If it's not a comparison operator, return TAC.Line.Op.Noop.
  static tac.LineOp _comparisonOp(TokenType tokenType) {
    switch (tokenType) {
      case TokenType.opEqual:
        return tac.LineOp.aEqualB;
      case TokenType.opNotEqual:
        return tac.LineOp.aNotEqualB;
      case TokenType.opGreater:
        return tac.LineOp.aGreaterThanB;
      case TokenType.opGreatEqual:
        return tac.LineOp.aGreatOrEqualB;
      case TokenType.opLesser:
        return tac.LineOp.aLessThanB;
      case TokenType.opLessEqual:
        return tac.LineOp.aLessOrEqualB;
      default:
        return tac.LineOp.noop;
    }
  }

  Value? _parseAddSub(
    Lexer tokens, {
    bool asLval = false,
    bool statementStart = false,
  }) {
    var val = _parseMultDiv(
      tokens,
      asLval: asLval,
      statementStart: statementStart,
    );
    var tok = tokens.peek();
    while (tok.type == TokenType.opPlus ||
        (tok.type == TokenType.opMinus &&
            (!statementStart || !tok.afterSpace || tokens.isAtWhitespace()))) {
      tokens.dequeue();

      _allowLineBreak(tokens); // allow a line break after a binary operator

      val = _fullyEvaluate(val);
      final opB = _parseMultDiv(tokens);
      final tempNum = output!.nextTempNum++;
      output!.add(tac.Line(
        tac.lTemp(tempNum),
        tok.type == TokenType.opPlus ? tac.LineOp.aPlusB : tac.LineOp.aMinusB,
        val,
        opB,
      ));
      val = tac.rTemp(tempNum);
      tok = tokens.peek();
    }
    return val;
  }

  Value? _parseMultDiv(
    Lexer tokens, {
    bool asLval = false,
    bool statementStart = false,
  }) {
    var val = _parseUnaryMinus(
      tokens,
      asLval: asLval,
      statementStart: statementStart,
    );
    var tok = tokens.peek();
    while (tok.type == TokenType.opTimes ||
        tok.type == TokenType.opDivide ||
        tok.type == TokenType.opMod) {
      tokens.dequeue();
      _allowLineBreak(tokens); // allow a line break after a binary operator

      val = _fullyEvaluate(val);
      final opB = _parseUnaryMinus(tokens);
      final tempNum = output!.nextTempNum++;
      switch (tok.type) {
        case TokenType.opTimes:
          output!.add(tac.Line(
            tac.lTemp(tempNum),
            tac.LineOp.aTimesB,
            val,
            opB,
          ));
          break;
        case TokenType.opDivide:
          output!.add(tac.Line(
            tac.lTemp(tempNum),
            tac.LineOp.aDividedByB,
            val,
            opB,
          ));
          break;
        case TokenType.opMod:
          output!.add(tac.Line(
            tac.lTemp(tempNum),
            tac.LineOp.aModB,
            val,
            opB,
          ));
          break;
        default:
          break;
      }
      val = tac.rTemp(tempNum);
      tok = tokens.peek();
    }
    return val;
  }

  Value? _parseUnaryMinus(
    Lexer tokens, {
    bool asLval = false,
    bool statementStart = false,
  }) {
    if (tokens.peek().type != TokenType.opMinus) {
      return _parseNew(tokens, asLval: asLval, statementStart: statementStart);
    }
    tokens.dequeue(); // skip '-'
    _allowLineBreak(tokens); // allow a line break after a unary operator

    var val = _parseNew(tokens);
    if (val is ValNumber) {
      // If what follows is a numeric literal, just invert it and be done!
      val = ValNumber(-val.value);
      return val;
    }
    // Otherwise, subtract it from 0 and return a new temporary.
    final tempNum = output!.nextTempNum++;
    output!.add(
      tac.Line(tac.lTemp(tempNum), tac.LineOp.aMinusB, tac.num(0), val),
    );
    return tac.rTemp(tempNum);
  }

  Value? _parseNew(
    Lexer tokens, {
    bool asLval = false,
    bool statementStart = false,
  }) {
    if (tokens.peek().type != TokenType.keyword ||
        tokens.peek().text != 'new') {
      return _parsePower(
        tokens,
        asLval: asLval,
        statementStart: statementStart,
      );
    }
    tokens.dequeue(); // skip 'new'
    _allowLineBreak(tokens); // allow a line break after a unary operator
    final isa = _parsePower(tokens);
    final ValTemp result = ValTemp(output!.nextTempNum++);
    output!.add(tac.Line(result, tac.LineOp.newA, isa));
    return result;
  }

  Value? _parsePower(
    Lexer tokens, {
    bool asLval = false,
    bool statementStart = false,
  }) {
    var val = _parseAddressOf(
      tokens,
      asLval: asLval,
      statementStart: statementStart,
    );
    var tok = tokens.peek();
    while (tok.type == TokenType.opPower) {
      tokens.dequeue();
      _allowLineBreak(tokens); // allow a line break after a binary operator

      val = _fullyEvaluate(val);
      final opB = _parseAddressOf(tokens);
      final tempNum = output!.nextTempNum++;
      output!.add(tac.Line(tac.lTemp(tempNum), tac.LineOp.aPowB, val, opB));
      val = tac.rTemp(tempNum);
      tok = tokens.peek();
    }
    return val;
  }

  Value? _parseAddressOf(
    Lexer tokens, {
    bool asLval = false,
    bool statementStart = false,
  }) {
    if (tokens.peek().type != TokenType.addressOf) {
      return _parseCallExpr(
        tokens,
        asLval: asLval,
        statementStart: statementStart,
      );
    }
    tokens.dequeue();
    _allowLineBreak(tokens); // allow a line break after a unary operator
    final val = _parseCallExpr(
      tokens,
      asLval: true,
      statementStart: statementStart,
    );
    if (val is ValVar) {
      val.noInvoke = true;
    } else if (val is ValSeqElem) {
      val.noInvoke = true;
    }
    return val;
  }

  Value? _fullyEvaluate(
    Value? val, {
    LocalOnlyMode localOnlyMode = LocalOnlyMode.off,
  }) {
    if (val is ValVar) {
      if (val.noInvoke) return val;
      // If var was protected with @, then return it as-is; don't attempt to call it.
      if (val.identifier == output!.localOnlyIdentifier) {
        val.localOnly = localOnlyMode;
      }
      // Don't invoke super; leave as-is so we can do special handling
      // of it at runtime.  Also, as an optimization, same for "self".
      if (val.identifier == 'super' || val.identifier == 'self') return val;
      // Evaluate a variable (which might be a function we need to call).
      final ValTemp temp = ValTemp(output!.nextTempNum++);
      output!.add(
        tac.Line(temp, tac.LineOp.callFunctionA, val, ValNumber.zero),
      );
      return temp;
    } else if (val is ValSeqElem) {
      // If sequence element was protected with @, then return it as-is; don't attempt to call it.
      if (val.noInvoke) return val;
      // Evaluate a sequence lookup (which might be a function we need to call).
      final ValTemp temp = ValTemp(output!.nextTempNum++);
      output!.add(
        tac.Line(temp, tac.LineOp.callFunctionA, val, ValNumber.zero),
      );
      return temp;
    }
    return val;
  }

  Value? _parseCallExpr(
    Lexer tokens, {
    bool asLval = false,
    bool statementStart = false,
  }) {
    var val = _parseMap(tokens, asLval: asLval, statementStart: statementStart);
    while (true) {
      if (tokens.peek().type == TokenType.dot) {
        tokens.dequeue(); // discard '.'
        _allowLineBreak(tokens); // allow a line break after a binary operator
        final nextIdent = _requireToken(tokens, TokenType.identifier);
        // We're chaining sequences here; look up (by invoking)
        // the previous part of the sequence, so we can build on it.
        val = _fullyEvaluate(val);
        // Now build the lookup.
        val = ValSeqElem(val, ValString(nextIdent.text!));
        if (tokens.peek().type == TokenType.lParen &&
            !tokens.peek().afterSpace) {
          // If this new element is followed by parens, we need to
          // parse it as a call right away.
          val = _parseCallArgs(val, tokens);
        }
      } else if (tokens.peek().type == TokenType.lSquare &&
          !tokens.peek().afterSpace) {
        tokens.dequeue(); // discard '['
        _allowLineBreak(tokens); // allow a line break after open bracket
        val = _fullyEvaluate(val);

        if (tokens.peek().type == TokenType.colon) {
          // e.g., foo[:4]
          tokens.dequeue(); // discard ':'
          _allowLineBreak(tokens); // allow a line break after colon
          Value? index2;
          if (tokens.peek().type != TokenType.rSquare) {
            index2 = _parseExpr(tokens);
          }
          final temp = ValTemp(output!.nextTempNum++);
          Intrinsics.compileSlice(
            output!.code,
            val,
            null,
            index2,
            temp.tempNum,
          );
          val = temp;
        } else {
          final index = _parseExpr(tokens);
          if (tokens.peek().type == TokenType.colon) {
            tokens.dequeue(); // discard ':'
            _allowLineBreak(tokens); // allow a line break after colon
            Value? index2;
            if (tokens.peek().type != TokenType.rSquare) {
              index2 = _parseExpr(tokens);
            }
            final ValTemp temp = ValTemp(output!.nextTempNum++);
            Intrinsics.compileSlice(
                output!.code, val, index, index2, temp.tempNum);
            val = temp;
          } else {
            if (asLval && statementStart) {
              // At the start of a statement, we don't want to compile the
              // last sequence lookup, because we might have to convert it into
              // an assignment. But we want to compile any previous one.
              if (val is ValSeqElem) {
                ValTemp temp = ValTemp(output!.nextTempNum++);
                output!.add(
                  tac.Line(temp, tac.LineOp.elemBofA, val.sequence, val.index),
                );
                val = temp;
              }
              val = ValSeqElem(val, index);
            } else {
              // Anywhere else in an expression, we can compile the lookup right away.
              ValTemp temp = ValTemp(output!.nextTempNum++);
              output!.add(tac.Line(temp, tac.LineOp.elemBofA, val, index));
              val = temp;
            }
          }
        }
        _requireToken(tokens, TokenType.rSquare);
      } else if ((val is ValVar && !val.noInvoke) ||
          (val is ValSeqElem && !val.noInvoke)) {
        // Got a variable... it might refer to a function!
        if (!asLval ||
            (tokens.peek().type == TokenType.lParen &&
                !tokens.peek().afterSpace)) {
          // If followed by parens, definitely a function call, possibly with arguments!
          // If not, well, let's call it anyway unless we need an lvalue.
          val = _parseCallArgs(val, tokens);
        } else {
          break;
        }
      } else {
        break;
      }
    }
    return val;
  }

  Value? _parseMap(
    Lexer tokens, {
    bool asLval = false,
    bool statementStart = false,
  }) {
    if (tokens.peek().type != TokenType.lCurly) {
      return _parseList(tokens, asLval: asLval, statementStart: statementStart);
    }
    // NOTE: we must be sure this map gets created at runtime, not here at parse time.
    // Since it is a mutable object, we need to return a different one each time
    // this code executes (in a loop, function, etc.).  So, we use Op.CopyA below!
    tokens.dequeue();
    final ValMap map = ValMap();
    if (tokens.peek().type == TokenType.rCurly) {
      tokens.dequeue();
    } else {
      while (true) {
        _allowLineBreak(
          tokens,
        ); // allow a line break after a comma or open brace

        // Allow the map to close with a } on its own line.
        if (tokens.peek().type == TokenType.rCurly) {
          tokens.dequeue();
          break;
        }
        final key = _parseExpr(tokens);
        _requireToken(tokens, TokenType.colon);
        _allowLineBreak(tokens); // allow a line break after a colon
        final value = _parseExpr(tokens);
        map.map[key ?? ValNull.instance] = value;
        if (_requireEitherToken(tokens, TokenType.comma, null, TokenType.rCurly)
                .type ==
            TokenType.rCurly) {
          break;
        }
      }
    }
    final result = ValTemp(output!.nextTempNum++);
    output!.add(tac.Line(result, tac.LineOp.copyA, map));
    return result;
  }

  //		list	:= '[' expr [, expr, ...] ']'
  //				 | quantity
  Value? _parseList(
    Lexer tokens, {
    bool asLval = false,
    bool statementStart = false,
  }) {
    if (tokens.peek().type != TokenType.lSquare) {
      return _parseQuantity(
        tokens,
        asLval: asLval,
        statementStart: statementStart,
      );
    }
    tokens.dequeue();
    // NOTE: we must be sure this list gets created at runtime, not here at parse time.
    // Since it is a mutable object, we need to return a different one each time
    // this code executes (in a loop, function, etc.).  So, we use Op.CopyA below!
    final ValList list = ValList();
    if (tokens.peek().type == TokenType.rSquare) {
      tokens.dequeue();
    } else {
      while (true) {
        _allowLineBreak(
          tokens,
        ); // allow a line break after a comma or open bracket

        // Allow the list to close with a ] on its own line.
        if (tokens.peek().type == TokenType.rSquare) {
          tokens.dequeue();
          break;
        }
        final elem = _parseExpr(tokens);
        list.values.add(elem);
        if (_requireEitherToken(
              tokens,
              TokenType.comma,
              null,
              TokenType.rSquare,
            ).type ==
            TokenType.rSquare) {
          break;
        }
      }
    }
    final ValTemp result = ValTemp(output!.nextTempNum++);
    output!.add(tac.Line(
      result,
      tac.LineOp.copyA,
      list,
    )); // use COPY on this mutable list!
    return result;
  }

  //		quantity := '(' expr ')'
  //				  | call
  Value? _parseQuantity(
    Lexer tokens, {
    bool asLval = false,
    bool statementStart = false,
  }) {
    if (tokens.peek().type != TokenType.lParen) {
      return _parseAtom(tokens, asLval: asLval, statementStart: statementStart);
    }
    tokens.dequeue();
    _allowLineBreak(tokens); // allow a line break after an open paren
    final val = _parseExpr(tokens);
    _requireToken(tokens, TokenType.rParen);
    return val;
  }

  /// Helper method that gathers arguments, emitting SetParamAasB for each one,
  /// and then emits the actual call to the given function.  It works both for
  /// a parenthesized set of arguments, and for no parens (i.e. no arguments).
  Value? _parseCallArgs(Value? funcRef, Lexer tokens) {
    int argCount = 0;
    if (tokens.peek().type == TokenType.lParen) {
      tokens.dequeue(); // remove '('
      if (tokens.peek().type != TokenType.rParen) {
        while (true) {
          // allow a line break after a comma or open paren
          _allowLineBreak(tokens);
          final arg = _parseExpr(tokens);
          output!.add(tac.Line(null, tac.LineOp.pushParam, arg));
          argCount++;
          if (_requireEitherToken(
                tokens,
                TokenType.comma,
                null,
                TokenType.rParen,
              ).type ==
              TokenType.rParen) {
            break;
          }
        }
      } else {
        tokens.dequeue();
      }
    }
    final ValTemp result = ValTemp(output!.nextTempNum++);
    output!.add(
      tac.Line(result, tac.LineOp.callFunctionA, funcRef,
          tac.num(argCount.toDouble())),
    );
    return result;
  }

  Value? _parseAtom(
    Lexer tokens, {
    bool asLval = false,
    bool statementStart = false,
  }) {
    Token tok = !tokens.atEnd ? tokens.dequeue() : Token.eol;
    if (tok.type == TokenType.number) {
      double d;
      try {
        d = double.parse(tok.text!);
        return ValNumber(d);
      } catch (e) {
        throw CompilerException.withLocation(
          errorContext,
          tokens.lineNum,
          "invalid numeric literal: ${tok.text}",
        );
      }
    } else if (tok.type == TokenType.string) {
      return ValString(tok.text!);
    } else if (tok.type == TokenType.identifier) {
      if (tok.text == "self") return ValVar.self;
      ValVar result = ValVar(tok.text!);
      if (result.identifier == output!.localOnlyIdentifier) {
        result.localOnly =
            output!.localOnlyStrict ? LocalOnlyMode.strict : LocalOnlyMode.warn;
      }
      return result;
    } else if (tok.type == TokenType.keyword) {
      switch (tok.text) {
        case "null":
          return null;
        case "true":
          return ValNumber.one;
        case "false":
          return ValNumber.zero;
      }
    }
    throw CompilerException.withLocation(
      errorContext,
      tokens.lineNum,
      "got $tok where number, string, or identifier is required",
    );
  }

  /// The given token type and text is required. So, consume the next token,
  /// and if it doesn't match, throw an error.
  Token _requireToken(Lexer tokens, TokenType type, [String? text]) {
    final got = tokens.atEnd ? Token.eol : tokens.dequeue();
    if (got.type != type || (text != null && got.text != text)) {
      // provide a special error for the common mistake of using `=` instead of `==`
      // in an `if` condition; this will be found here:
      if (got.type == TokenType.opAssign && text == 'then') {
        throw CompilerException.withLocation(
          errorContext,
          tokens.lineNum,
          "found = instead of == in if condition",
        );
      }
      final expected = Token(type: type, text: text);
      throw CompilerException('got $got where $expected is required');
    }
    return got;
  }

  Token _requireEitherToken(
    Lexer tokens,
    TokenType type1,
    String? text1,
    TokenType type2, [
    String? text2,
  ]) {
    final got = tokens.atEnd ? Token.eol : tokens.dequeue();
    if ((got.type != type1 && got.type != type2) ||
        ((text1 != null && got.text != text1) &&
            (text2 != null && got.text != text2))) {
      final expected1 = Token(type: type1, text: text1);
      final expected2 = Token(type: type2, text: text2);
      throw CompilerException(
        'got $got where $expected1 or $expected2 is required',
      );
    }
    return got;
  }

  static void testValidParse(String src, {bool dumpTac = false}) {
    final parser = Parser();
    try {
      parser.parse(src);
    } catch (e, stackTrace) {
      print('$e while parsing:\n$src');
      print(stackTrace);
    }
    if (dumpTac && parser.output != null) {
      tac.dump(parser.output!.code, -1);
    }
  }

  static void runUnitTests() {
    testValidParse('pi < 4');
    testValidParse('(pi < 4)');
    testValidParse('if true then 20 else 30');
    testValidParse('f = function(x)\nreturn x*3\nend function\nf(14)');
    testValidParse('foo="bar"\nindexes(foo*2)\nfoo.indexes');
    testValidParse('x=[]\nx.push(42)');
    testValidParse('list1=[10, 20, 30, 40, 50]; range(0, list1.len)');
    testValidParse(
        'f = function(x); print("foo"); end function; print(false and f)');
    testValidParse('print 42');
    testValidParse('print true');
    testValidParse('f = function(x)\nprint x\nend function\nf 42');
    testValidParse('myList = [1, null, 3]');
    testValidParse(
        'while true; if true then; break; else; print 1; end if; end while');
    testValidParse('x = 0 or\n1');
    testValidParse('x = [1, 2, \n 3]');
    testValidParse('range 1,\n10, 2');
  }
}
