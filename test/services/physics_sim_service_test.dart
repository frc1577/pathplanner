import 'package:flutter_test/flutter_test.dart';
import 'package:file/memory.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/path/path_constraints.dart';
import 'package:pathplanner/path/waypoint.dart';
import 'package:pathplanner/path/goal_end_state.dart';
import 'package:pathplanner/path/ideal_starting_state.dart';
import 'package:pathplanner/services/physics_sim_service.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';

void main() {
  test('physics simulation produces samples', () {
    final path = PathPlannerPath(
      name: 'test',
      pathDir: '/paths',
      fs: MemoryFileSystem(),
      waypoints: [
        Waypoint(
          anchor: const Translation2d(0.0, 0.0),
          cruiseVelocity: 2.0,
          maxAcceleration: 1.0,
          targetEndVelocity: 0.5,
          tolerance: 0.05,
        ),
        Waypoint(
          anchor: const Translation2d(2.0, 0.0),
          cruiseVelocity: 2.0,
          maxAcceleration: 1.0,
          targetEndVelocity: 0.0,
          tolerance: 0.05,
        ),
      ],
      globalConstraints: PathConstraints(),
      goalEndState: GoalEndState(0.0, const Rotation2d()),
      constraintZones: const [],
      pointTowardsZones: const [],
      rotationTargets: const [],
      eventMarkers: const [],
      reversed: false,
      folder: null,
      idealStartingState: IdealStartingState(0.0, const Rotation2d()),
      useDefaultConstraints: false,
    );

    final result = PhysicsSimService.simulatePath(path);

    expect(result.states.isNotEmpty, true);
    expect(result.totalTimeSeconds, greaterThan(0.0));

    final endPose = result.states.last.pose.translation;
    expect(endPose.getDistance(path.waypoints.last.anchor),
        lessThanOrEqualTo(path.waypoints.last.tolerance));
  });
}
