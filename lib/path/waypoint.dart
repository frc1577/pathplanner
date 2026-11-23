import 'dart:math';

import 'package:pathplanner/util/wpimath/geometry.dart';

class Waypoint {
  Translation2d anchor;
  num tolerance;
  num toleranceDeg;
  String? headingStratName;
  String? controllerSettingName;
  bool isLocked;
  String? linkedName;

  static Map<String, Pose2d> linked = {};

  Waypoint({
    required this.anchor,
    this.tolerance = 0.25,
    this.toleranceDeg = 5.0,
    this.headingStratName,
    this.controllerSettingName,
    this.isLocked = false,
    this.linkedName,
  });

  factory Waypoint.fromJson(Map<String, dynamic> json) {
    return Waypoint(
      anchor: Translation2d.fromJson(json['anchor'] as Map<String, dynamic>),
      tolerance: (json['tolerance'] as num?) ?? 0.25,
      toleranceDeg: (json['toleranceDeg'] as num?) ?? 5.0,
      headingStratName: json['headingStratName'] as String?,
      controllerSettingName: json['controllerSettingName'] as String?,
      isLocked: (json['isLocked'] as bool?) ?? false,
      linkedName: json['linkedName'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'anchor': anchor.toJson(),
      'tolerance': tolerance,
      'toleranceDeg': toleranceDeg,
      'headingStratName': headingStratName,
      'controllerSettingName': controllerSettingName,
      'isLocked': isLocked,
      'linkedName': linkedName,
    };
  }

  Waypoint clone() {
    return Waypoint(
      anchor: anchor,
      tolerance: tolerance,
      toleranceDeg: toleranceDeg,
      headingStratName: headingStratName,
      controllerSettingName: controllerSettingName,
      isLocked: isLocked,
      linkedName: linkedName,
    );
  }

  void move(num x, num y) {
    anchor = Translation2d(x, y);
  }


  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Waypoint &&
          runtimeType == other.runtimeType &&
          anchor == other.anchor &&
          tolerance == other.tolerance &&
          toleranceDeg == other.toleranceDeg &&
          headingStratName == other.headingStratName &&
          controllerSettingName == other.controllerSettingName &&
          isLocked == other.isLocked &&
          linkedName == other.linkedName;

  @override
  int get hashCode => Object.hash(
        anchor,
        tolerance,
        toleranceDeg,
        headingStratName,
        controllerSettingName,
        isLocked,
        linkedName,
      );
}