import 'package:pathplanner/path/goal.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';

export 'package:pathplanner/path/goal.dart';

class GoalPicker {
  Pose2d startPose;
  List<Goal> goals;

  GoalPicker({
    required this.startPose,
    required this.goals,
  });

  factory GoalPicker.fromJson(Map<String, dynamic> json) {
    final poseJson = json['startPose'] as Map<String, dynamic>? ?? {};
    return GoalPicker(
      startPose: Pose2d(
        Translation2d(poseJson['x'] ?? 0, poseJson['y'] ?? 0),
        Rotation2d.fromDegrees(poseJson['degrees'] ?? 0),
      ),
      goals: [
        for (final goalJson in json['goals'] ?? []) Goal.fromJson(goalJson),
      ],
    );
  }

  Map<String, dynamic> toJson() => {
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