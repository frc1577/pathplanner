import 'package:flutter/foundation.dart';
import 'package:pathplanner/namedObjects/named_headingStrat.dart';

abstract class HeadingStrat {
  Map<String, dynamic> dataToJson();

  HeadingStrat clone();

  @nonVirtual
  Map<String, dynamic> toJson() {
    return {
      'data': dataToJson(),
    };
  }

  static HeadingStrat? fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> data = json['data'] ?? {};
    return NamedHeadingStrat.fromDataJson(data);
  }
}