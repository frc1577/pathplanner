import 'dart:collection';
import 'dart:math';

import 'package:pathplanner/util/wpimath/geometry.dart';

class Waypoint {
  static const num headingHandleLength = 0.5;
  static HashMap<String, Pose2d> linked = HashMap();

  Translation2d anchor;
  Rotation2d holonomicAngle;
  num kp;
  num ki;
  num kd;
  num tolerance;
  num toleranceDeg;
  bool isLocked;
  String? linkedName;
  String? controllerSettingId; // Reference to a controller setting

  bool _isAnchorDragging = false;
  bool _isHeadingDragging = false;

  Waypoint({
    required this.anchor,
    Rotation2d? holonomicAngle,
    this.kp = 0.0,
    this.ki = 0.0,
    this.kd = 0.0,
    this.tolerance = 0.1,
    this.toleranceDeg = 360,
    this.isLocked = false,
    this.linkedName,
    this.controllerSettingId,
  }) : holonomicAngle = holonomicAngle ?? const Rotation2d();

  bool get isAnchorDragging => _isAnchorDragging;

  bool get isHeadingDragging => _isHeadingDragging;

  Waypoint.fromJson(Map<String, dynamic> json)
      : this(
          anchor: Translation2d.fromJson(json['anchor']),
          holonomicAngle: _holonomicAngleFromJson(json),
          kp: json['kp'] ?? 0.0,
          ki: json['ki'] ?? 0.0,
          kd: json['kd'] ?? 0.0,
          tolerance: json['tolerance'] ?? 0.1,
          toleranceDeg: json['toleranceDeg'] ?? 360,
          isLocked: json['isLocked'] ?? false,
          linkedName: json['linkedName'],
          controllerSettingId: json['controllerSettingId'],
        );

  static Rotation2d _holonomicAngleFromJson(Map<String, dynamic> json) {
    if (json['holonomicAngle'] != null) {
      return Rotation2d.fromDegrees(json['holonomicAngle'].toDouble());
    }

    if (json['nextControl'] != null) {
      final anchor = Translation2d.fromJson(json['anchor']);
      final nextControl = Translation2d.fromJson(json['nextControl']);
      return (nextControl - anchor).angle;
    }

    if (json['prevControl'] != null) {
      final anchor = Translation2d.fromJson(json['anchor']);
      final prevControl = Translation2d.fromJson(json['prevControl']);
      return (anchor - prevControl).angle;
    }

    return const Rotation2d();
  }

  Map<String, dynamic> toJson() {
    return {
      'anchor': anchor.toJson(),
      'holonomicAngle': holonomicAngle.degrees,
      'kp': kp,
      'ki': ki,
      'kd': kd,
      'tolerance': tolerance,
      'toleranceDeg': toleranceDeg,
      'isLocked': isLocked,
      'linkedName': linkedName,
      'controllerSettingId': controllerSettingId,
    };
  }

  Rotation2d get heading => holonomicAngle;

  void move(num x, num y) {
    anchor = Translation2d(x, y);

    if (linkedName != null) {
      linked[linkedName!] = Pose2d(anchor, holonomicAngle);
    }
  }

  Waypoint clone() {
    return Waypoint(
      anchor: anchor,
      holonomicAngle: holonomicAngle,
      kp: kp,
      ki: ki,
      kd: kd,
      tolerance: tolerance,
      toleranceDeg: toleranceDeg,
      isLocked: isLocked,
      linkedName: linkedName,
      controllerSettingId: controllerSettingId,
    );
  }

  void setHeading(Rotation2d heading) {
    holonomicAngle = heading;
  }

  Translation2d headingHandlePosition() {
    return anchor + Translation2d.fromAngle(headingHandleLength, holonomicAngle);
  }

  bool isPointInAnchor(num xPos, num yPos, num radius) {
    return pow(xPos - anchor.x, 2) + pow(yPos - anchor.y, 2) < pow(radius, 2);
  }

  bool isPointInHeadingHandle(num xPos, num yPos, num radius) {
    Translation2d handle = headingHandlePosition();
    return pow(xPos - handle.x, 2) + pow(yPos - handle.y, 2) < pow(radius, 2);
  }

  bool startDragging(num xPos, num yPos, num anchorRadius, num headingRadius) {
    if (isPointInAnchor(xPos, yPos, anchorRadius)) {
      return _isAnchorDragging = true;
    } else if (isPointInHeadingHandle(xPos, yPos, headingRadius)) {
      return _isHeadingDragging = true;
    }
    return false;
  }

  void dragUpdate(num x, num y) {
    if (_isAnchorDragging && !isLocked) {
      move(x, y);
    } else if (_isHeadingDragging) {
      Rotation2d newHeading = Rotation2d.fromComponents(x - anchor.x, y - anchor.y);
      if (newHeading.radians.isFinite) {
        holonomicAngle = newHeading;
      }
    }
  }

  void stopDragging() {
    _isHeadingDragging = false;
    _isAnchorDragging = false;
  }

  @override
  bool operator ==(Object other) =>
      other is Waypoint &&
      other.runtimeType == runtimeType &&
      other.anchor == anchor &&
      other.holonomicAngle == holonomicAngle &&
      other.kp == kp &&
      other.ki == ki &&
      other.kd == kd &&
  other.tolerance == tolerance &&
  other.toleranceDeg == toleranceDeg &&
      other.linkedName == linkedName &&
      other.controllerSettingId == controllerSettingId;

  @override
  int get hashCode => Object.hash(
    anchor, holonomicAngle, kp, ki, kd, tolerance, toleranceDeg, linkedName, controllerSettingId);
}
