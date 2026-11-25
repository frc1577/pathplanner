import 'package:flutter/foundation.dart';

mixin NamedJSONDataSerializable<T> {
  Map<String, dynamic> dataToJson();

  T clone();

  @nonVirtual
  Map<String, dynamic> toJson() {
    return {
      'data': dataToJson(),
    };
  }
}