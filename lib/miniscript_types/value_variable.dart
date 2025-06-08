// Copyright © 2025 by the authors of the project. All rights reserved.

import '../miniscript_tac/tac.dart' as tac;
import './value_map.dart' show ValMap;
import '../value_pointer.dart' show ValuePointer;
import 'value.dart';

enum LocalOnlyMode { off, warn, strict }

class ValVar extends Value {
  final String identifier;

  /// reflects use of "@" (address-of) operator
  bool noInvoke = false;

  /// whether to look this up in the local scope only
  LocalOnlyMode localOnly = LocalOnlyMode.off;

  ValVar(this.identifier);

  @override
  Value? val(tac.Context context) {
    if (this == self) return context.self;
    return context.getVar(identifier);
  }

  @override
  Value? valWithMap(tac.Context context, ValuePointer<ValMap> valueFoundIn) {
    valueFoundIn.value = null;
    if (this == self) return context.self;
    return context.getVar(identifier, localOnly: localOnly);
  }

  @override
  String toStringWithVM([tac.Machine? vm]) {
    if (noInvoke) return '@$identifier';
    return identifier;
  }

  @override
  int hash() {
    return identifier.hashCode;
  }

  @override
  double equality(Value? rhs) {
    return rhs is ValVar && rhs.identifier == identifier ? 1 : 0;
  }

  /// Special name for the implicit result variable we assign to on expression statements:
  static final ValVar implicitResult = ValVar('_');

  /// Special var for 'self'
  static final ValVar self = ValVar('self');
}
