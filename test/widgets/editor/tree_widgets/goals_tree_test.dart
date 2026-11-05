import 'package:file/memory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/path/goal.dart';
import 'package:pathplanner/path/goal_picker.dart';
import 'package:pathplanner/path/waypoint.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/goals_tree.dart';
import 'package:undo/undo.dart';

void main() {
  testWidgets('shows goals and adds a waypoint to a goal', (tester) async {
    final picker = GoalPicker(
      name: 'test',
      pathDir: '/paths',
      fs: MemoryFileSystem(),
      startPose: const Pose2d(Translation2d(0, 0), Rotation2d()),
      goals: [
        Goal(waypoints: [Waypoint(anchor: const Translation2d(1, 1))]),
      ],
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GoalsTree(path: picker, undoStack: ChangeStack()),
      ),
    ));

    expect(find.text('Goal 1'), findsOneWidget);
    expect(find.text('Waypoint 1'), findsOneWidget);

    await tester.tap(find.byTooltip('Add Waypoint'));
    await tester.pump();

    expect(picker.goals.single.waypoints.length, 2);
    expect(find.text('Waypoint 2'), findsOneWidget);
    expect(find.text('Heading Strat'), findsOneWidget);
    expect(find.text('Controller Setting'), findsOneWidget);
    expect(find.text('Arrival Tolerance (M)'), findsOneWidget);
    expect(find.text('Rotation Tolerance (Deg)'), findsOneWidget);
  });

  testWidgets('adds, reorders, deletes, and undoes goals', (tester) async {
    final picker = GoalPicker(
      name: 'test',
      pathDir: '/paths',
      fs: MemoryFileSystem(),
      startPose: const Pose2d(Translation2d(0, 0), Rotation2d()),
      goals: [
        Goal(waypoints: [Waypoint(anchor: const Translation2d(1, 1))]),
      ],
    );
    final undoStack = ChangeStack();

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: GoalsTree(path: picker, undoStack: undoStack)),
    ));

    await tester.tap(find.byTooltip('Add Goal'));
    await tester.pump();
    expect(picker.goals.length, 2);

    await tester.tap(find.byTooltip('Move Goal Up').last);
    await tester.pump();
    expect(picker.goals.length, 2);

    await tester.tap(find.byTooltip('Delete Goal').first);
    await tester.pump();
    expect(picker.goals.length, 1);

    undoStack.undo();
    await tester.pump();
    expect(picker.goals.length, 2);
  });
}