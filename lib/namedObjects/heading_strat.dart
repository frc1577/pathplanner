import 'package:flutter/foundation.dart';
import 'package:pathplanner/namedObjects/named_json_data_serializer.dart';
import 'package:pathplanner/namedObjects/named_headingStrat.dart';

abstract class HeadingStrat with NamedJSONDataSerializable<HeadingStrat> {
  static HeadingStrat? fromJson(Map<String, dynamic> json) {
    final data = (json['data'] as Map<String, dynamic>?) ?? const {};
    return NamedHeadingStrat.fromDataJson(data);
  }
}