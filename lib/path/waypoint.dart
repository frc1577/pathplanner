import 'dart:math';

import 'package:pathplanner/util/wpimath/geometry.dart';

class Waypoint {
  Translation2d anchor;
  Rotation2d holonomicAngle;
  num toleranceM;
  num toleranceDeg;
  String? headingStratName;
  String? controllerSettingName;
  bool isLocked;
  String? linkedName;

  static Map<String, Pose2d> linked = {};

  Waypoint({
    required this.anchor,
    this.holonomicAngle = const Rotation2d(),
    this.toleranceM = 0.25,
    this.toleranceDeg = 5.0,
    this.headingStratName,
    this.controllerSettingName,
    this.isLocked = false,
    this.linkedName,
  });

  factory Waypoint.fromJson(Map<String, dynamic> json) {
    final rawHeading = (json['headingStratName'] as String?)?.trim();
    final rawController = (json['controllerSettingName'] as String?)?.trim();

    return Waypoint(
      anchor: Translation2d.fromJson(json['anchor'] as Map<String, dynamic>),
      holonomicAngle: json['holonomicAngle'] != null
          ? Rotation2d.fromDegrees((json['holonomicAngle'] as num))
          : const Rotation2d(),
      toleranceM: (json['toleranceM'] as num?) ?? 0.25,
      toleranceDeg: (json['toleranceDeg'] as num?) ?? 5.0,
      headingStratName:
          (rawHeading == null || rawHeading.isEmpty) ? null : rawHeading,
      controllerSettingName: (rawController == null || rawController.isEmpty)
          ? null
          : rawController,
      isLocked: (json['isLocked'] as bool?) ?? false,
      linkedName: json['linkedName'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'anchor': anchor.toJson(),
      'holonomicAngle': holonomicAngle.degrees,
      'toleranceM': toleranceM,
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
      holonomicAngle: holonomicAngle,
      toleranceM: toleranceM,
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

  Translation2d headingHandlePosition([num handleDistance = 0.7]) {
    return anchor +
        Translation2d(
          handleDistance * cos(holonomicAngle.radians),
          handleDistance * sin(holonomicAngle.radians),
        );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Waypoint &&
          runtimeType == other.runtimeType &&
          anchor == other.anchor &&
          holonomicAngle == other.holonomicAngle &&
          toleranceM == other.toleranceM &&
          toleranceDeg == other.toleranceDeg &&
          headingStratName == other.headingStratName &&
          controllerSettingName == other.controllerSettingName &&
          isLocked == other.isLocked &&
          linkedName == other.linkedName;

  @override
  int get hashCode => Object.hash(
        anchor,
        holonomicAngle,
        toleranceM,
        toleranceDeg,
        headingStratName,
        controllerSettingName,
        isLocked,
        linkedName,
      );
}