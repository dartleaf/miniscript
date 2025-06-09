# MiniScript Dart
An exact port of the MiniScript C# interpreter for Dart.

# Installation
## CLI Installation
Run on your terminal.
```sh
dart pub global activate miniscript
``` 

## Library Installation
Run this on your workspace terminal
```sh
dart pub add miniscript
``` 

# How to Use
## CLI
Just run this on your terminal.
```
miniscript --help
```

## Library
Please check the example folder.

# Limitations
Due to how Dart's typings work, we are unable to make a `floatValue` function thus we have to enforce the use of single floating point type.