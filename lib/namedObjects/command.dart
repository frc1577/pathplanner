import 'package:flutter/foundation.dart';
import 'package:pathplanner/namedObjects/named_command.dart';

abstract class Command {
  Map<String, dynamic> dataToJson();

  Command clone();

  @nonVirtual
  Map<String, dynamic> toJson() {
    return {
      'data': dataToJson(),
    };
  }

  static Command? fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> data = json['data'] ?? {};
    return NamedCommand.fromDataJson(data);
  }
}