import 'package:flutter/foundation.dart';
import 'package:pathplanner/namedObjects/named_json_data_serializer.dart';
import 'package:pathplanner/namedObjects/named_controllersettings.dart';

abstract class ControllerSettings with NamedJSONDataSerializable<ControllerSettings> {
  static ControllerSettings? fromJson(Map<String, dynamic> json) {
    final data = (json['data'] as Map<String, dynamic>?) ?? const {};
    return NamedControllerSettings.fromDataJson(data);
  }
}