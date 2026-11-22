import 'dart:convert';

import 'package:file/memory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/path/goal.dart';
import 'package:pathplanner/path/goal_picker.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';
import 'package:pathplanner/path/waypoint.dart';

void main() {
  test('flattens the start pose and goals in execution order', () {
    final picker = GoalPicker(
      name: 'test',
      pathDir: '/paths',
      fs: MemoryFileSystem(),
      startPose: Pose2d(Translation2d(0, 0), Rotation2d.fromDegrees(15)),
      goals: [
        Goal(
          waypoints: [
            Waypoint(anchor: const Translation2d(1, 1)),
            Waypoint(anchor: const Translation2d(2, 1)),
          ],
        ),
        Goal(
          waypoints: [
            Waypoint(anchor: const Translation2d(3, 2)),
            Waypoint(anchor: const Translation2d(4, 2)),
          ],
        ),
      ],
    );

    expect(
      picker.waypoints.map((waypoint) => waypoint.anchor).toList(),
      [
        const Translation2d(0, 0),
        const Translation2d(1, 1),
        const Translation2d(2, 1),
        const Translation2d(3, 2),
        const Translation2d(4, 2),
      ],
    );
    expect(picker.pathPoints.isNotEmpty, true);
  });

  test('round trips the start pose and goals', () {
    final picker = GoalPicker(
      name: 'test',
      pathDir: '/paths',
      fs: MemoryFileSystem(),
      startPose: Pose2d(Translation2d(1, 2), Rotation2d.fromDegrees(30)),
      goals: [
        Goal(waypoints: [Waypoint(anchor: const Translation2d(3, 4))]),
      ],
    );

    final restored = GoalPicker.fromJson(
      picker.toJson(),
      picker.name,
      picker.pathDir,
      picker.fs,
    );

    expect(restored.startPose.x, picker.startPose.x);
    expect(restored.startPose.y, picker.startPose.y);
    expect(restored.startPose.rotation.degrees,
      picker.startPose.rotation.degrees);
    expect(restored.goals.length, 1);
    expect(restored.goals.single.waypoints.single.anchor,
        const Translation2d(3, 4));
    expect(restored.waypoints.map((waypoint) => waypoint.anchor),
        picker.waypoints.map((waypoint) => waypoint.anchor));
  });

  test('reloads grouped paths as GoalPickers', () async {
    final fs = MemoryFileSystem();
    fs.directory('/paths').createSync();
    final picker = GoalPicker(
      name: 'test',
      pathDir: '/paths',
      fs: fs,
      startPose: const Pose2d(Translation2d(1, 2), Rotation2d()),
      goals: [
        Goal(waypoints: [Waypoint(anchor: const Translation2d(3, 4))]),
      ],
    );

    fs.file('/paths/test.path').writeAsStringSync(jsonEncode(picker));
    final loaded = await PathPlannerPath.loadAllPathsInDir('/paths', fs);

    expect(loaded.single, isA<GoalPicker>());
    expect((loaded.single as GoalPicker).goals.single.waypoints.length, 1);
  });
}