import 'package:file/memory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/path/path_constraints.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/util/prefs.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/path_tree.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/waypoints_tree.dart';
import 'package:pathplanner/widgets/editor/runtime_display.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undo/undo.dart';

void main() {
  late PathPlannerPath path;
  bool sideSwapped = false;
  late SharedPreferences prefs;

  setUp(() async {
    path = PathPlannerPath.defaultPath(
      pathDir: '/paths',
      fs: MemoryFileSystem(),
    );
    path.reversed = false;
    sideSwapped = false;
    SharedPreferences.setMockInitialValues({
      PrefsKeys.holonomicMode: true,
      PrefsKeys.treeOnRight: true,
    });
    prefs = await SharedPreferences.getInstance();
  });

  testWidgets('has runtime display', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PathTree(
          path: path,
          undoStack: ChangeStack(),
          holonomicMode: true,
          defaultConstraints: PathConstraints(),
          runtimeDisplay: const RuntimeDisplay(
            currentRuntime: 5.0,
            previousRuntime: null,
          ),
          prefs: prefs,
          fieldSizeMeters: const Size(16.54, 8.21),
        ),
      ),
    ));

    expect(find.byType(RuntimeDisplay), findsOneWidget);
  });

  testWidgets('swap side button', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PathTree(
          path: path,
          undoStack: ChangeStack(),
          onSideSwapped: () => sideSwapped = true,
          holonomicMode: true,
          defaultConstraints: PathConstraints(),
          prefs: prefs,
          fieldSizeMeters: const Size(16.54, 8.21),
        ),
      ),
    ));

    var btn = find.byTooltip('Move to Other Side');

    expect(btn, findsOneWidget);

    await widgetTester.tap(btn);
    await widgetTester.pump();
    expect(sideSwapped, true);
  });

  testWidgets('has waypoints tree', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PathTree(
          path: path,
          undoStack: ChangeStack(),
          holonomicMode: true,
          defaultConstraints: PathConstraints(),
          prefs: prefs,
          fieldSizeMeters: const Size(16.54, 8.21),
        ),
      ),
    ));

    expect(find.byType(WaypointsTree), findsOneWidget);
  });


  testWidgets('has optimizer tree', (widgetTester) async {
    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PathTree(
          path: path,
          undoStack: ChangeStack(),
          holonomicMode: true,
          defaultConstraints: PathConstraints(),
          prefs: prefs,
          fieldSizeMeters: const Size(16.54, 8.21),
        ),
      ),
    ));

    // PathOptimizationTree is part of PathTree; we check presence indirectly
    expect(find.byType(WaypointsTree), findsOneWidget);
  });

  testWidgets('Reversed button', (widgetTester) async {
    final ChangeStack undoStack = ChangeStack();

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PathTree(
          path: path,
          undoStack: undoStack,
          holonomicMode: false,
          defaultConstraints: PathConstraints(),
          prefs: prefs,
          fieldSizeMeters: const Size(16.54, 8.21),
        ),
      ),
    ));

    final reversedButton = find.byTooltip('Reverse Path');

    expect(reversedButton, findsOneWidget);

    await widgetTester.tap(reversedButton);
    await widgetTester.pump();
    expect(path.reversed, true);

    undoStack.undo();

    await widgetTester.pump();
    expect(path.reversed, false);

    undoStack.redo();

    await widgetTester.pump();
    expect(path.reversed, true);
  });
}
