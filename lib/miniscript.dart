enum ErrorType { syntax }

class Error {
  int lineNum;
  ErrorType type;
  late String description;

  Error(this.lineNum, this.type, [String? description]) {
    if (description == null) {
      this.description = type.toString().split('.').last;
    } else {
      this.description = description;
    }
  }

  static void assertBool(bool condition) {
    if (!condition) {
      print("Internal assertion failed.");
    }
  }
}

class Script {
  List<Error> errors = [];

  void compile(String source) {
    // Implementation to be added
  }
}
