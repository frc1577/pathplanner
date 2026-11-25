import 'package:flutter/foundation.dart';
import 'package:pathplanner/namedObjects/named_json_data_serializer.dart';
import 'package:pathplanner/namedObjects/named_trigger.dart';

abstract class Trigger with NamedJSONDataSerializable<Trigger> {
  static Trigger? fromJson(Map<String, dynamic> json) {
    final data = (json['data'] as Map<String, dynamic>?) ?? const {};
    return NamedTrigger.fromDataJson(data);
  }
}