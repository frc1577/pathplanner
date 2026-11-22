import 'package:flutter/foundation.dart';
import 'package:pathplanner/commands/named_trigger.dart';

abstract class Trigger {
  Map<String, dynamic> dataToJson();

  Trigger clone();

  @nonVirtual
  Map<String, dynamic> toJson() {
    return {
      'data': dataToJson(),
    };
  }

  static Trigger? fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> data = json['data'] ?? {};
    return NamedTrigger.fromDataJson(data);
  }
}