/*  miniscript_lexer.dart

This file is used internally during parsing of the code, breaking source
code text into a series of tokens.

Unless you're writing a fancy MiniScript code editor, you probably don't 
need to worry about this stuff. 

*/

import 'dart:collection';
import 'miniscript_errors.dart';
import 'miniscript_keywords.dart';
import 'miniscript_unit_test.dart';

/// Token type enum
enum TokenType {
  unknown,
  keyword,
  number,
  string,
  identifier,
  opAssign,
  opPlus,
  opMinus,
  opTimes,
  opDivide,
  opMod,
  opPower,
  opEqual,
  opNotEqual,
  opGreater,
  opGreatEqual,
  opLesser,
  opLessEqual,
  opAssignPlus,
  opAssignMinus,
  opAssignTimes,
  opAssignDivide,
  opAssignMod,
  opAssignPower,
  lParen,
  rParen,
  lSquare,
  rSquare,
  lCurly,
  rCurly,
  addressOf,
  comma,
  dot,
  colon,
  comment,
  eol,
}

class Token {
  TokenType type;

  /// may be null for things like operators, whose text is fixed
  String? text;
  bool afterSpace = false;

  Token({this.type = TokenType.unknown, this.text});

  @override
  String toString() {
    if (text == null) return type.toString();
    return "$type($text)";
  }

  static final Token eol = Token(type: TokenType.eol);
}

class Lexer {
  /// start at 1, so we report 1-based line numbers
  int lineNum = 1;
  late int position;

  late String input;
  late int inputLength;

  late Queue<Token> pending;

  bool get atEnd {
    return position >= inputLength && pending.isEmpty;
  }

  Lexer(this.input) {
    inputLength = input.length;
    position = 0;
    pending = Queue<Token>();
  }

  Token peek() {
    if (pending.isEmpty) {
      if (atEnd) return Token.eol;
      pending.add(dequeue());
    }
    return pending.first;
  }

  Token dequeue() {
    if (pending.isNotEmpty) return pending.removeFirst();

    int oldPos = position;
    skipWhitespaceAndComment();

    if (atEnd) return Token.eol;

    Token result = Token();
    result.afterSpace = (position > oldPos);
    int startPos = position;
    String c = input[position++];

    // Handle two-character operators first.
    if (!atEnd) {
      String c2 = input[position];
      if (c2 == '=') {
        if (c == '=') {
          result.type = TokenType.opEqual;
        } else if (c == '+') {
          result.type = TokenType.opAssignPlus;
        } else if (c == '-') {
          result.type = TokenType.opAssignMinus;
        } else if (c == '*') {
          result.type = TokenType.opAssignTimes;
        } else if (c == '/') {
          result.type = TokenType.opAssignDivide;
        } else if (c == '%') {
          result.type = TokenType.opAssignMod;
        } else if (c == '^') {
          result.type = TokenType.opAssignPower;
        }
      }
      if (c == '!' && c2 == '=') result.type = TokenType.opNotEqual;
      if (c == '>' && c2 == '=') result.type = TokenType.opGreatEqual;
      if (c == '<' && c2 == '=') result.type = TokenType.opLessEqual;

      if (result.type != TokenType.unknown) {
        position++;
        return result;
      }
    }

    // Handle one-char operators next.
    if (c == '+') {
      result.type = TokenType.opPlus;
    } else if (c == '-') {
      result.type = TokenType.opMinus;
    } else if (c == '*') {
      result.type = TokenType.opTimes;
    } else if (c == '/') {
      result.type = TokenType.opDivide;
    } else if (c == '%') {
      result.type = TokenType.opMod;
    } else if (c == '^') {
      result.type = TokenType.opPower;
    } else if (c == '(') {
      result.type = TokenType.lParen;
    } else if (c == ')') {
      result.type = TokenType.rParen;
    } else if (c == '[') {
      result.type = TokenType.lSquare;
    } else if (c == ']') {
      result.type = TokenType.rSquare;
    } else if (c == '{') {
      result.type = TokenType.lCurly;
    } else if (c == '}') {
      result.type = TokenType.rCurly;
    } else if (c == ',') {
      result.type = TokenType.comma;
    } else if (c == ':') {
      result.type = TokenType.colon;
    } else if (c == '=') {
      result.type = TokenType.opAssign;
    } else if (c == '<') {
      result.type = TokenType.opLesser;
    } else if (c == '>') {
      result.type = TokenType.opGreater;
    } else if (c == '@') {
      result.type = TokenType.addressOf;
    } else if (c == ';' || c == '\n') {
      result.type = TokenType.eol;
      result.text = c == ';' ? ";" : "\n";
      if (c != ';') lineNum++;
    }
    if (c == '\r') {
      // Careful; DOS may use \r\n, so we need to check for that too.
      result.type = TokenType.eol;
      if (position < inputLength && input[position] == '\n') {
        position++;
        result.text = "\r\n";
      } else {
        result.text = "\r";
      }
      lineNum++;
    }
    if (result.type != TokenType.unknown) return result;

    // Then, handle more extended tokens.

    if (c == '.') {
      // A token that starts with a dot is just Type.Dot, UNLESS
      // it is followed by a number, in which case it's a decimal number.
      if (position >= inputLength || !isNumeric(input[position])) {
        result.type = TokenType.dot;
        return result;
      }
    }

    if (c == '.' || isNumeric(c)) {
      result.type = TokenType.number;
      while (position < inputLength) {
        String lastc = c;
        c = input[position];
        if (isNumeric(c) ||
            c == '.' ||
            c == 'E' ||
            c == 'e' ||
            ((c == '-' || c == '+') && (lastc == 'E' || lastc == 'e'))) {
          position++;
        } else {
          break;
        }
      }
    } else if (isIdentifier(c)) {
      while (position < inputLength) {
        if (isIdentifier(input[position])) {
          position++;
        } else {
          break;
        }
      }
      result.text = input.substring(startPos, position);
      result.type = (Keywords.isKeyword(result.text!)
          ? TokenType.keyword
          : TokenType.identifier);
      if (result.text == "end") {
        // As a special case: when we see "end", grab the next keyword (after whitespace)
        // too, and conjoin it, so our token is "end if", "end function", etc.
        Token nextWord = dequeue();
        if (nextWord.type == TokenType.keyword) {
          result.text = "${result.text!} ${nextWord.text ?? ""}";
        } else {
          // Oops, didn't find another keyword.  User error.
          throw LexerException(
            "'end' without following keyword ('if', 'function', etc.)",
          );
        }
      } else if (result.text == "else") {
        // And similarly, conjoin an "if" after "else" (to make "else if").
        // (Note we can't use Peek or Dequeue/Enqueue for these, because we are probably
        // inside a Peek call already, and that would end up swapping the order of these tokens.)
        var p = position;
        while (p < inputLength && (input[p] == ' ' || input[p] == '\t')) {
          p++;
        }
        if (p + 1 < inputLength &&
            input.substring(p, p + 2) == "if" &&
            (p + 2 >= inputLength || !isIdentifier(input[p + 2]))) {
          result.text = "else if";
          position = p + 2;
        }
      }
      return result;
    } else if (c == '"') {
      // Lex a string... to the closing ", but skipping (and singling) a doubled double quote ("")
      result.type = TokenType.string;
      bool haveDoubledQuotes = false;
      startPos = position;
      bool gotEndQuote = false;
      while (position < inputLength) {
        c = input[position++];
        if (c == '"') {
          if (position < inputLength && input[position] == '"') {
            // This is just a doubled quote.
            haveDoubledQuotes = true;
            position++;
          } else {
            // This is the closing quote, marking the end of the string.
            gotEndQuote = true;
            break;
          }
        } else if (c == '\n' || c == '\r') {
          // Break at end of line (string literals should not contain a line break).
          break;
        }
      }
      if (!gotEndQuote) throw LexerException("missing closing quote (\")");
      result.text = input.substring(startPos, position - 1);
      if (haveDoubledQuotes) {
        result.text = result.text!.replaceAll("\"\"", "\"");
      }
      return result;
    } else {
      result.type = TokenType.unknown;
    }

    result.text = input.substring(startPos, position);
    return result;
  }

  void skipWhitespaceAndComment() {
    while (!atEnd && isWhitespace(input[position])) {
      position++;
    }

    if (position < input.length - 1 &&
        input[position] == '/' &&
        input[position + 1] == '/') {
      // Comment.  Skip to end of line.
      position += 2;
      while (!atEnd && input[position] != '\n') {
        position++;
      }
    }
  }

  static bool isNumeric(String c) {
    return c.codeUnitAt(0) >= '0'.codeUnitAt(0) &&
        c.codeUnitAt(0) <= '9'.codeUnitAt(0);
  }

  static bool isIdentifier(String c) {
    int code = c.codeUnitAt(0);
    return c == '_' ||
        (code >= 'a'.codeUnitAt(0) && code <= 'z'.codeUnitAt(0)) ||
        (code >= 'A'.codeUnitAt(0) && code <= 'Z'.codeUnitAt(0)) ||
        (code >= '0'.codeUnitAt(0) && code <= '9'.codeUnitAt(0)) ||
        code > 0x009F;
  }

  static bool isWhitespace(String c) {
    return c == ' ' || c == '\t';
  }

  bool isAtWhitespace() {
    // Caution: ignores queue, and uses only current position
    return atEnd || isWhitespace(input[position]);
  }

  static bool isInStringLiteral(
    int charPos,
    String source, [
    int startPos = 0,
  ]) {
    bool inString = false;
    for (int i = startPos; i < charPos; i++) {
      if (source[i] == '"') inString = !inString;
    }
    return inString;
  }

  static int commentStartPos(String source, int startPos) {
    // Find the first occurrence of "//" in this line that
    // is not within a string literal.
    int commentStart = startPos - 2;
    while (true) {
      commentStart = source.indexOf("//", commentStart + 2);
      if (commentStart < 0) break; // no comment found
      if (!isInStringLiteral(commentStart, source, startPos)) {
        break; // valid comment
      }
    }
    return commentStart;
  }

  static String trimComment(String source) {
    int startPos = source.lastIndexOf('\n') + 1;
    int commentStart = commentStartPos(source, startPos);
    if (commentStart >= 0) return source.substring(startPos, commentStart);
    return source;
  }

  // Find the last token in the given source, ignoring any whitespace
  // or comment at the end of that line.
  static Token lastToken(String source) {
    // Start by finding the start and logical end of the last line.
    int startPos = source.lastIndexOf('\n') + 1;
    int commentStart = commentStartPos(source, startPos);

    // Walk back from end of string or start of comment, skipping whitespace.
    int endPos = (commentStart >= 0 ? commentStart - 1 : source.length - 1);
    while (endPos >= 0 && isWhitespace(source[endPos])) {
      endPos--;
    }
    if (endPos < 0) return Token.eol;

    // Find the start of that last token.
    // There are several cases to consider here.
    int tokStart = endPos;
    String c = source[endPos];

    if (isIdentifier(c)) {
      while (tokStart > startPos && isIdentifier(source[tokStart - 1])) {
        tokStart--;
      }
    } else if (c == '"') {
      bool inQuote = true;
      while (tokStart > startPos) {
        tokStart--;
        if (source[tokStart] == '"') {
          inQuote = !inQuote;
          if (!inQuote && tokStart > startPos && source[tokStart - 1] != '"') {
            break;
          }
        }
      }
    } else if (c == '=' && tokStart > startPos) {
      String c2 = source[tokStart - 1];
      if (c2 == '>' || c2 == '<' || c2 == '=' || c2 == '!') {
        tokStart--;
      }
    }
    // Now use the standard lexer to grab just that bit.
    Lexer lex = Lexer(source);
    lex.position = tokStart;
    return lex.dequeue();
  }

  static void check(
    Token? tok,
    TokenType type, [
    String? text,
    int lineNum = 0,
  ]) {
    UnitTest.errorIfNull(tok);
    if (tok == null) return;
    UnitTest.errorIf(
      tok.type != type,
      "Token type: expected $type, but got ${tok.type}",
    );

    UnitTest.errorIf(
      text != null && tok.text != text,
      "Token text: expected $text, but got ${tok.text}",
    );
  }

  static void checkLineNum(int actual, int expected) {
    UnitTest.errorIf(
      actual != expected,
      "Lexer line number: expected $expected, but got $actual",
    );
  }

  static void runUnitTests() {
    Lexer lex = Lexer("42  * 3.14158");
    check(lex.dequeue(), TokenType.number, "42");
    checkLineNum(lex.lineNum, 1);
    check(lex.dequeue(), TokenType.opTimes);
    check(lex.dequeue(), TokenType.number, "3.14158");
    UnitTest.errorIf(!lex.atEnd, "AtEnd not set when it should be", 1);
    checkLineNum(lex.lineNum, 1);

    lex = Lexer("6*(.1-foo) end if // and a comment!");
    check(lex.dequeue(), TokenType.number, "6");
    checkLineNum(lex.lineNum, 1);
    check(lex.dequeue(), TokenType.opTimes);
    check(lex.dequeue(), TokenType.lParen);
    check(lex.dequeue(), TokenType.number, ".1");
    check(lex.dequeue(), TokenType.opMinus);
    check(lex.peek(), TokenType.identifier, "foo");
    check(lex.peek(), TokenType.identifier, "foo");
    check(lex.dequeue(), TokenType.identifier, "foo");
    check(lex.dequeue(), TokenType.rParen);
    check(lex.dequeue(), TokenType.keyword, "end if");
    check(lex.dequeue(), TokenType.eol);
    UnitTest.errorIf(!lex.atEnd, "AtEnd not set when it should be", 2);
    checkLineNum(lex.lineNum, 1);

    lex = Lexer("\"foo\" \"isn't \"\"real\"\"\" \"now \"\"\"\" double!\"");
    check(lex.dequeue(), TokenType.string, "foo");
    check(lex.dequeue(), TokenType.string, "isn't \"real\"");
    check(lex.dequeue(), TokenType.string, "now \"\" double!");
    UnitTest.errorIf(!lex.atEnd, "AtEnd not set when it should be", 3);

    lex = Lexer("foo\nbar\rbaz\r\nbamf");
    check(lex.dequeue(), TokenType.identifier, "foo");
    checkLineNum(lex.lineNum, 1);
    check(lex.dequeue(), TokenType.eol);
    check(lex.dequeue(), TokenType.identifier, "bar");
    checkLineNum(lex.lineNum, 2);
    check(lex.dequeue(), TokenType.eol);
    check(lex.dequeue(), TokenType.identifier, "baz");
    checkLineNum(lex.lineNum, 3);
    check(lex.dequeue(), TokenType.eol);
    check(lex.dequeue(), TokenType.identifier, "bamf");
    checkLineNum(lex.lineNum, 4);
    check(lex.dequeue(), TokenType.eol);
    UnitTest.errorIf(!lex.atEnd, "AtEnd not set when it should be", 4);

    lex = Lexer("x += 42");
    check(lex.dequeue(), TokenType.identifier, "x");
    checkLineNum(lex.lineNum, 1);
    check(lex.dequeue(), TokenType.opAssignPlus);
    check(lex.dequeue(), TokenType.number, "42");
    UnitTest.errorIf(!lex.atEnd, "AtEnd not set when it should be", 5);

    check(lastToken("x=42 // foo"), TokenType.number, "42");
    check(lastToken("x = [1, 2, // foo"), TokenType.comma);
    check(lastToken("x = [1, 2 // foo"), TokenType.number, "2");
    check(
      lastToken("x = [1, 2 // foo // and \"more\" foo"),
      TokenType.number,
      "2",
    );
    check(lastToken("x = [\"foo\", \"//bar\"]"), TokenType.rSquare);
    check(lastToken("print 1 // line 1\nprint 2"), TokenType.number, "2");
    check(
      lastToken("print \"Hi\"\"Quote\" // foo bar"),
      TokenType.string,
      "Hi\"Quote",
    );
  }
}
