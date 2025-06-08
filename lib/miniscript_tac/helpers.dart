// Copyright © 2025 by the authors of the project. All rights reserved.

// Helper functions for creating tac values
import 'package:miniscript/miniscript_intrinsics/intrinsic.dart';
import 'package:miniscript/miniscript_types/value_number.dart';
import 'package:miniscript/miniscript_types/value_string.dart';
import 'package:miniscript/miniscript_types/value_temp.dart';
import 'package:miniscript/miniscript_types/value_variable.dart';

ValTemp lTemp(int tempNum) => ValTemp(tempNum);
ValVar lVar(String identifier) =>
    identifier == "self" ? ValVar.self : ValVar(identifier);
ValTemp rTemp(int tempNum) => ValTemp(tempNum);
ValNumber intrinsicByName(String name) =>
    ValNumber(Intrinsic.getByName(name)!.id.toDouble());
ValNumber num(double value) => ValNumber(value);
ValString str(String value) => ValString(value);
