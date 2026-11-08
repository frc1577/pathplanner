import 'package:file/file.dart';
import 'package:pathplanner/path/goal.dart';
import 'package:pathplanner/path/goal_end_state.dart';
import 'package:pathplanner/path/ideal_starting_state.dart';
import 'package:pathplanner/path/path_constraints.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/path/waypoint.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';

export 'package:pathplanner/path/goal.dart';

class GoalPicker extends PathPlannerPath {
  Pose2d startPose;
  List<Goal> goals;

  GoalPicker({
    required super.name,
    required this.startPose,
    required this.goals,
    required super.pathDir,
    required super.fs,
    PathConstraints? constraints,
    super.folder,
  }) : super(
          waypoints: _flattenWaypoints(startPose, goals),
          globalConstraints: constraints ?? PathConstraints(),
          goalEndState: GoalEndState(
            0,
            _endRotation(startPose, goals),
          ),
          constraintZones: [],
          pointTowardsZones: [],
          rotationTargets: [],
          eventMarkers: [],
          reversed: false,
          idealStartingState: IdealStartingState(0, startPose.rotation),
          useDefaultConstraints: constraints == null,
          controllerSettings: [],
        );

  GoalPicker.fromJson(
      Map<String, dynamic> json, String name, String pathDir, FileSystem fs)
      : startPose = _startPoseFromJson(json['startPose']),
        goals = [
          for (final goalJson in json['goals'] ?? []) Goal.fromJson(goalJson),
        ],
        super(
          name: name,
          pathDir: pathDir,
          fs: fs,
          waypoints: _flattenWaypoints(
            _startPoseFromJson(json['startPose']),
            [
              for (final goalJson in json['goals'] ?? [])
                Goal.fromJson(goalJson),
            ],
          ),
          globalConstraints:
              PathConstraints.fromJson(json['globalConstraints'] ?? {}),
          goalEndState: GoalEndState.fromJson(json['goalEndState'] ?? {}),
          constraintZones: [],
          pointTowardsZones: [],
          rotationTargets: [],
          eventMarkers: [],
          reversed: json['reversed'] ?? false,
          folder: json['folder'],
          idealStartingState: IdealStartingState.fromJson(
              json['idealStartingState'] ?? {}),
          useDefaultConstraints: json['useDefaultConstraints'] ?? true,
          controllerSettings: [],
        );

  static List<Waypoint> _flattenWaypoints(
      Pose2d startPose, List<Goal> goals) {
    return [
      Waypoint(anchor: startPose.translation, holonomicAngle: startPose.rotation),
      for (final goal in goals) ...goal.waypoints,
    ];
  }

  static Rotation2d _endRotation(Pose2d startPose, List<Goal> goals) {
    for (final goal in goals.reversed) {
      if (goal.waypoints.isNotEmpty) {
        return goal.waypoints.last.holonomicAngle;
      }
    }
    return startPose.rotation;
  }

  static Pose2d _startPoseFromJson(Map<String, dynamic>? json) {
    final value = json ?? {};
    return Pose2d(
      Translation2d(value['x'] ?? 0, value['y'] ?? 0),
      Rotation2d.fromDegrees(value['degrees'] ?? 0),
    );
  }

  void rebuildPath() {
    waypoints
      ..clear()
      ..addAll(_flattenWaypoints(startPose, goals));
    goalEndState = GoalEndState(0, _endRotation(startPose, goals));
    idealStartingState = IdealStartingState(0, startPose.rotation);
    generatePathPoints();
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'startPose': {
        'x': startPose.x,
        'y': startPose.y,
        'degrees': startPose.rotation.degrees,
      },
      'goals': [
        for (final goal in goals) goal.toJson(),
      ],
    };
  }
}