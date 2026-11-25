import 'package:flutter/foundation.dart';
import 'package:pathplanner/namedObjects/named_json_data_serializer.dart';
import 'package:pathplanner/namedObjects/named_command.dart';

abstract class Command with NamedJSONDataSerializable<Command> {
  static Command? fromJson(Map<String, dynamic> json) {
    final data = (json['data'] as Map<String, dynamic>?) ?? const {};
    return NamedCommand.fromDataJson(data);
  }
}