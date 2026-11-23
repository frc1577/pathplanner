import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:pathplanner/path/waypoint.dart';
import 'package:pathplanner/robot_features/feature.dart';
import 'package:pathplanner/trajectory/config.dart';
import 'package:pathplanner/util/path_painter_util.dart';
import 'package:pathplanner/util/prefs.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PathPainter extends CustomPainter {
  final ColorScheme colorScheme;
  final List<Waypoint> waypoints;
  final FieldImage fieldImage;
  final bool simple;
  final int? hoveredWaypoint;
  final int? selectedWaypoint;
  final SharedPreferences prefs;

  late final RobotConfig robotConfig;
  late final num robotRadius;
  final List<Feature> robotFeatures = [];

  static double scale = 1;

  PathPainter({
    required this.colorScheme,
    required this.waypoints,
    required this.fieldImage,
    this.simple = false,
    this.hoveredWaypoint,
    this.selectedWaypoint,
    required this.prefs,
  }) {
    robotConfig = RobotConfig.fromPrefs(prefs);
    robotRadius = sqrt((robotConfig.bumperSize.width *
                robotConfig.bumperSize.width) +
            (robotConfig.bumperSize.height * robotConfig.bumperSize.height)) /
        2.0;

    for (String featureJson in prefs.getStringList(PrefsKeys.robotFeatures) ??
        Defaults.robotFeatures) {
      try {
        robotFeatures.add(Feature.fromJson(jsonDecode(featureJson))!);
      } catch (_) {
        // Ignore and skip loading this feature
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    scale = size.width / fieldImage.defaultSize.width;

    _paintGrid(
      canvas,
      size,
      prefs.getBool(PrefsKeys.showGrid) ?? Defaults.showGrid,
    );

    if (waypoints.isEmpty) return;

    if (!simple) {
      _paintRadius(canvas, scale);
    }

    // Paint straight connecting lines between waypoints
    if (waypoints.length > 1) {
      final linePaint = Paint()
        ..style = PaintingStyle.stroke
        ..color = colorScheme.secondary
        ..strokeWidth = 2.0;

      final path = Path();
      final start = PathPainterUtil.pointToPixelOffset(
          waypoints.first.anchor, scale, fieldImage);
      path.moveTo(start.dx, start.dy);

      for (int i = 1; i < waypoints.length; i++) {
        final pos = PathPainterUtil.pointToPixelOffset(
            waypoints[i].anchor, scale, fieldImage);
        path.lineTo(pos.dx, pos.dy);
      }

      canvas.drawPath(path, linePaint);
    }

    // Paint start and end robot outlines
    PathPainterUtil.paintRobotOutline(
      Pose2d(waypoints.first.anchor, waypoints.first.holonomicAngle),
      fieldImage,
      robotConfig.bumperSize,
      robotConfig.bumperOffset,
      scale,
      canvas,
      Colors.green.withAlpha(125),
      colorScheme.surfaceContainer,
      robotFeatures,
    );

    if (waypoints.length > 1) {
      PathPainterUtil.paintRobotOutline(
        Pose2d(waypoints.last.anchor, waypoints.last.holonomicAngle),
        fieldImage,
        robotConfig.bumperSize,
        robotConfig.bumperOffset,
        scale,
        canvas,
        Colors.red.withAlpha(125),
        colorScheme.surfaceContainer,
        robotFeatures,
      );
    }

    // Paint robot outline for selected intermediate waypoint
    if (!simple &&
        selectedWaypoint != null &&
        selectedWaypoint! > 0 &&
        selectedWaypoint! < waypoints.length - 1) {
      final sel = waypoints[selectedWaypoint!];
      PathPainterUtil.paintRobotOutline(
        Pose2d(sel.anchor, sel.holonomicAngle),
        fieldImage,
        robotConfig.bumperSize,
        robotConfig.bumperOffset,
        scale,
        canvas,
        Colors.orange.withAlpha(125),
        colorScheme.surfaceContainer,
        robotFeatures,
      );
    }

    bool hidePoints = prefs.getBool(PrefsKeys.hidePointsAndTolerances) ??
        Defaults.hidePointsAndTolerances;

    if (!hidePoints) {
      for (int w = 0; w < waypoints.length; w++) {
        _paintWaypoint(canvas, scale, w);
      }
    }
  }

  @override
  bool shouldRepaint(PathPainter oldDelegate) => true;

  void _paintRadius(Canvas canvas, double scale) {
    if (selectedWaypoint != null &&
        selectedWaypoint! >= 0 &&
        selectedWaypoint! < waypoints.length) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..color = colorScheme.surfaceContainerHighest
        ..strokeWidth = 2;

      canvas.drawCircle(
        PathPainterUtil.pointToPixelOffset(
            waypoints[selectedWaypoint!].anchor, scale, fieldImage),
        PathPainterUtil.metersToPixels(
            robotRadius.toDouble(), scale, fieldImage),
        paint,
      );
    }
  }

  void _paintWaypoint(Canvas canvas, double scale, int waypointIdx) {
    final waypoint = waypoints[waypointIdx];

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    if (waypointIdx == selectedWaypoint) {
      paint.color = Colors.orange;
    } else if (waypointIdx == hoveredWaypoint) {
      paint.color = Colors.deepPurpleAccent;
    } else {
      paint.color = Colors.grey[700]!;
    }

    if (!simple) {
      if (waypoint.tolerance > 0) {
        final tolerancePaint = Paint()
          ..style = PaintingStyle.stroke
          ..color = colorScheme.secondary.withAlpha(80)
          ..strokeWidth = 2;
        canvas.drawCircle(
          PathPainterUtil.pointToPixelOffset(
              waypoint.anchor, scale, fieldImage),
          PathPainterUtil.metersToPixels(
              waypoint.tolerance.toDouble(), scale, fieldImage),
          tolerancePaint,
        );
      }

      // Draw heading handle line
      canvas.drawLine(
        PathPainterUtil.pointToPixelOffset(waypoint.anchor, scale, fieldImage),
        PathPainterUtil.pointToPixelOffset(
            waypoint.headingHandlePosition(), scale, fieldImage),
        paint,
      );
    }

    if (waypointIdx == 0) {
      paint.color = Colors.green;
    } else if (waypointIdx == waypoints.length - 1) {
      paint.color = Colors.red;
    } else {
      paint.color = colorScheme.secondary;
    }

    if (waypointIdx == selectedWaypoint) {
      paint.color = Colors.orange;
    } else if (waypointIdx == hoveredWaypoint) {
      paint.color = Colors.deepPurpleAccent;
    }

    // Draw anchor point
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(
      PathPainterUtil.pointToPixelOffset(waypoint.anchor, scale, fieldImage),
      PathPainterUtil.uiPointSizeToPixels(25, scale, fieldImage),
      paint,
    );
    paint.style = PaintingStyle.stroke;
    paint.color = colorScheme.surfaceContainer;
    canvas.drawCircle(
      PathPainterUtil.pointToPixelOffset(waypoint.anchor, scale, fieldImage),
      PathPainterUtil.uiPointSizeToPixels(25, scale, fieldImage),
      paint,
    );

    // Draw heading handle knob
    if (!simple) {
      paint.style = PaintingStyle.fill;
      if (waypointIdx == selectedWaypoint) {
        paint.color = Colors.orange;
      } else if (waypointIdx == hoveredWaypoint) {
        paint.color = Colors.deepPurpleAccent;
      } else {
        paint.color = colorScheme.secondary;
      }

      canvas.drawCircle(
        PathPainterUtil.pointToPixelOffset(
            waypoint.headingHandlePosition(), scale, fieldImage),
        PathPainterUtil.uiPointSizeToPixels(20, scale, fieldImage),
        paint,
      );
      paint.style = PaintingStyle.stroke;
      paint.color = colorScheme.surfaceContainer;
      canvas.drawCircle(
        PathPainterUtil.pointToPixelOffset(
            waypoint.headingHandlePosition(), scale, fieldImage),
        PathPainterUtil.uiPointSizeToPixels(20, scale, fieldImage),
        paint,
      );
    }
  }

  void _paintGrid(Canvas canvas, Size size, bool showGrid) {
    if (!showGrid) return;

    final paint = Paint()
      ..color = colorScheme.secondary.withAlpha(50)
      ..strokeWidth = 1;

    double gridSpacing = PathPainterUtil.metersToPixels(0.5, scale, fieldImage);

    for (double x = 0; x <= size.width; x += gridSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = 0; y <= size.height; y += gridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }
}