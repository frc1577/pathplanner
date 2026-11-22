import 'package:flutter/foundation.dart';
import 'package:pathplanner/namedObjects/named_controllersettings.dart';
abstract class ControllerSettings {
  Map<String, dynamic> dataToJson();

  ControllerSettings clone();

  @nonVirtual
  Map<String, dynamic> toJson() {
    return {
      'data': dataToJson(),
    };
  }

  static ControllerSettings? fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> data = json['data'] ?? {};
    return NamedControllerSettings.fromDataJson(data);
  }
}