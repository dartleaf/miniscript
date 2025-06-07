/*
  miniscript_keywords.dart

  This file defines a Keywords class, which contains all the 
  MiniScript reserved words (break, for, etc.). It might be useful 
  if you are doing something like syntax coloring, or want to make 
  sure some user-entered identifier isn't going to conflict with a 
  reserved word.
*/

/// Static class containing MiniScript reserved keywords
class Keywords {
  /// List of all MiniScript keywords
  static final List<String> all = [
    "break",
    "continue",
    "else",
    "end",
    "for",
    "function",
    "if",
    "in",
    "isa",
    "new",
    "null",
    "then",
    "repeat",
    "return",
    "while",
    "and",
    "or",
    "not",
    "true",
    "false",
  ];

  /// Checks if the given text is a MiniScript keyword
  static bool isKeyword(String text) {
    return all.contains(text);
  }
}
