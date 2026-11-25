import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:pathplanner/path/goal.dart';
import 'package:pathplanner/path/goal_picker.dart';
import 'package:pathplanner/path/waypoint.dart';
import 'package:pathplanner/robot_features/feature.dart';
import 'package:pathplanner/trajectory/config.dart';
import 'package:pathplanner/util/path_painter_util.dart';
import 'package:pathplanner/util/prefs.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undo/undo.dart';

class SplitGoalPickerEditor extends StatefulWidget {
  final SharedPreferences prefs;
  final GoalPicker goalPicker;
  final List<Goal> allGoals;
  final VoidCallback? onGoalPickerChanged;
  final FieldImage fieldImage;
  final ChangeStack undoStack;
  final ValueChanged<Goal>? onEditGoalPressed;
  final ValueChanged<Goal>? onPromoteGoalToProject;

  const SplitGoalPickerEditor({
    required this.prefs,
    required this.goalPicker,
    required this.allGoals,
    required this.fieldImage,
    required this.undoStack,
    this.onGoalPickerChanged,
    this.onEditGoalPressed,
    this.onPromoteGoalToProject,
    super.key,
  });

  @override
  State<SplitGoalPickerEditor> createState() => _SplitGoalPickerEditorState();
}

class _SplitGoalPickerEditorState extends State<SplitGoalPickerEditor> {
  final MultiSplitViewController _controller = MultiSplitViewController();
  int? _hoveredGoalIndex;
  late bool _treeOnRight;

  bool _hoveringStartPose = false;
  bool _hoveringStartHeading = false;
  bool _draggingStartPose = false;
  bool _draggingStartHeading = false;
  Pose2d? _startPoseDragSnapshot;

  late TextEditingController _startXController;
  late TextEditingController _startYController;
  late TextEditingController _startRotController;

  @override
  void initState() {
    super.initState();

    _treeOnRight =
        widget.prefs.getBool(PrefsKeys.treeOnRight) ?? Defaults.treeOnRight;

    double treeWeight = widget.prefs.getDouble(PrefsKeys.editorTreeWeight) ??
        Defaults.editorTreeWeight;
    _controller.areas = [
      Area(
        weight: _treeOnRight ? (1.0 - treeWeight) : treeWeight,
        minimalWeight: 0.4,
      ),
      Area(
        weight: _treeOnRight ? treeWeight : (1.0 - treeWeight),
        minimalWeight: 0.4,
      ),
    ];

    _startXController = TextEditingController(
      text: widget.goalPicker.startPose.x.toStringAsFixed(2),
    );
    _startYController = TextEditingController(
      text: widget.goalPicker.startPose.y.toStringAsFixed(2),
    );
    _startRotController = TextEditingController(
      text: widget.goalPicker.startPose.rotation.degrees.toStringAsFixed(1),
    );
  }

  @override
  void dispose() {
    _startXController.dispose();
    _startYController.dispose();
    _startRotController.dispose();
    super.dispose();
  }

  void _syncStartPoseControllers() {
    _startXController.text = widget.goalPicker.startPose.x.toStringAsFixed(2);
    _startYController.text = widget.goalPicker.startPose.y.toStringAsFixed(2);
    _startRotController.text =
        widget.goalPicker.startPose.rotation.degrees.toStringAsFixed(1);
  }

  List<Goal> _cloneGoals() =>
      [for (final g in widget.goalPicker.goals) g.clone()];

  void _recordGoalsChange(List<Goal> before, List<Goal> after) {
    widget.undoStack.add(
      Change<List<Goal>>(
        before,
        () {
          widget.goalPicker.goals = [for (final g in after) g.clone()];
          widget.onGoalPickerChanged?.call();
          setState(() {});
        },
        (oldValue) {
          widget.goalPicker.goals = [for (final g in oldValue) g.clone()];
          widget.onGoalPickerChanged?.call();
          setState(() {});
        },
      ),
    );
  }

  void _recordStartPoseChange(Pose2d before, Pose2d after) {
    widget.undoStack.add(
      Change<Pose2d>(
        before,
        () {
          widget.goalPicker.startPose = after;
          _syncStartPoseControllers();
          widget.onGoalPickerChanged?.call();
          setState(() {});
        },
        (oldValue) {
          widget.goalPicker.startPose = oldValue;
          _syncStartPoseControllers();
          widget.onGoalPickerChanged?.call();
          setState(() {});
        },
      ),
    );
  }

  Translation2d _startHeadingHandlePosition([double handleDistance = 0.75]) {
    final start = widget.goalPicker.startPose;
    return start.translation +
        Translation2d(
          handleDistance * cos(start.rotation.radians),
          handleDistance * sin(start.rotation.radians),
        );
  }

  bool _isNearStartPose(Translation2d pos, double radius) {
    return (widget.goalPicker.startPose.translation - pos).norm <= radius;
  }

  bool _isNearStartHeading(Translation2d pos, double radius) {
    return (_startHeadingHandlePosition() - pos).norm <= radius;
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    final fieldViewer = Center(
      child: InteractiveViewer(
        maxScale: 10.0,
        panEnabled: !(_draggingStartPose || _draggingStartHeading),
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: AspectRatio(
            aspectRatio: widget.fieldImage.defaultSize.width /
                widget.fieldImage.defaultSize.height,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final scale =
                    constraints.maxWidth / widget.fieldImage.defaultSize.width;
                final anchorPx = PathPainterUtil.uiPointSizeToPixels(
                    32, scale, widget.fieldImage);
                final anchorR = PathPainterUtil.pixelsToMeters(
                    anchorPx, scale, widget.fieldImage);
                final headingPx = PathPainterUtil.uiPointSizeToPixels(
                    32, scale, widget.fieldImage);
                final headingR = PathPainterUtil.pixelsToMeters(
                    headingPx, scale, widget.fieldImage);

                return MouseRegion(
                  cursor: (_draggingStartPose || _draggingStartHeading)
                      ? SystemMouseCursors.grabbing
                      : ((_hoveringStartPose || _hoveringStartHeading)
                          ? SystemMouseCursors.grab
                          : SystemMouseCursors.basic),
                  onHover: (event) {
                    final pos = PathPainterUtil.pixelOffsetToPoint(
                      event.localPosition,
                      scale,
                      widget.fieldImage,
                    );
                    final nearHeading = _isNearStartHeading(pos, headingR);
                    final nearPose =
                        !nearHeading && _isNearStartPose(pos, anchorR);
                    if (nearHeading != _hoveringStartHeading ||
                        nearPose != _hoveringStartPose) {
                      setState(() {
                        _hoveringStartHeading = nearHeading;
                        _hoveringStartPose = nearPose;
                      });
                    }
                  },
                  onExit: (_) {
                    if (_hoveringStartPose || _hoveringStartHeading) {
                      setState(() {
                        _hoveringStartPose = false;
                        _hoveringStartHeading = false;
                      });
                    }
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (details) {
                      final pos = PathPainterUtil.pixelOffsetToPoint(
                        details.localPosition,
                        scale,
                        widget.fieldImage,
                      );
                      if (_isNearStartHeading(pos, headingR)) {
                        _startPoseDragSnapshot = widget.goalPicker.startPose;
                        setState(() => _draggingStartHeading = true);
                      } else if (_isNearStartPose(pos, anchorR)) {
                        _startPoseDragSnapshot = widget.goalPicker.startPose;
                        setState(() => _draggingStartPose = true);
                      }
                    },
                    onPanUpdate: (details) {
                      if (!_draggingStartPose && !_draggingStartHeading) {
                        return;
                      }
                      final pos = PathPainterUtil.pixelOffsetToPoint(
                        details.localPosition,
                        scale,
                        widget.fieldImage,
                      );
                      if (_draggingStartHeading) {
                        final start = widget.goalPicker.startPose.translation;
                        final angle = atan2(pos.y - start.y, pos.x - start.x);
                        setState(() {
                          widget.goalPicker.startPose =
                              Pose2d(start, Rotation2d(angle));
                          _syncStartPoseControllers();
                        });
                        widget.onGoalPickerChanged?.call();
                      } else if (_draggingStartPose) {
                        setState(() {
                          widget.goalPicker.startPose = Pose2d(
                            pos,
                            widget.goalPicker.startPose.rotation,
                          );
                          _syncStartPoseControllers();
                        });
                        widget.onGoalPickerChanged?.call();
                      }
                    },
                    onPanEnd: (_) {
                      if (_draggingStartPose || _draggingStartHeading) {
                        final before = _startPoseDragSnapshot;
                        final after = widget.goalPicker.startPose;
                        if (before != null && before != after) {
                          _recordStartPoseChange(before, after);
                        }
                        setState(() {
                          _draggingStartPose = false;
                          _draggingStartHeading = false;
                          _startPoseDragSnapshot = null;
                        });
                        widget.onGoalPickerChanged?.call();
                      }
                    },
                    child: Stack(
                      children: [
                        Positioned.fill(child: widget.fieldImage.getWidget()),
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _GoalPickerPainter(
                              colorScheme: colorScheme,
                              goalPicker: widget.goalPicker,
                              fieldImage: widget.fieldImage,
                              hideOtherGoalsOnHover: widget.prefs
                                      .getBool(PrefsKeys.hidePathsOnHover) ??
                                  Defaults.hidePathsOnHover,
                              hoveredGoalIndex: _hoveredGoalIndex,
                              highlightStartPose:
                                  _hoveringStartPose || _draggingStartPose,
                              highlightStartHeading: _hoveringStartHeading ||
                                  _draggingStartHeading,
                              prefs: widget.prefs,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

    final treePanel = Card(
      margin: const EdgeInsets.all(0),
      elevation: 4.0,
      color: colorScheme.surface,
      surfaceTintColor: colorScheme.surfaceTint,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: _treeOnRight ? const Radius.circular(12) : Radius.zero,
          topRight: _treeOnRight ? Radius.zero : const Radius.circular(12),
          bottomLeft: _treeOnRight ? const Radius.circular(12) : Radius.zero,
          bottomRight: _treeOnRight ? Radius.zero : const Radius.circular(12),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: _buildGoalPickerTree(context, colorScheme),
      ),
    );

    return Stack(
      children: [
        fieldViewer,
        MultiSplitViewTheme(
          data: MultiSplitViewThemeData(
            dividerPainter: DividerPainters.grooved1(
              color: colorScheme.surfaceContainerHighest,
              highlightedColor: colorScheme.primary,
            ),
          ),
          child: MultiSplitView(
            axis: Axis.horizontal,
            controller: _controller,
            onWeightChange: () {
              double? newWeight = _treeOnRight
                  ? _controller.areas[1].weight
                  : _controller.areas[0].weight;
              widget.prefs
                  .setDouble(PrefsKeys.editorTreeWeight, newWeight ?? 0.5);
            },
            children: [
              if (_treeOnRight) const IgnorePointer(child: SizedBox.expand()),
              treePanel,
              if (!_treeOnRight) const IgnorePointer(child: SizedBox.expand()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGoalPickerTree(BuildContext context, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header with side-swap button
        Row(
          children: [
            Icon(Icons.flag_rounded, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'GoalPicker Configuration',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Move panel to other side',
              icon: Icon(
                _treeOnRight
                    ? Icons.align_horizontal_left_rounded
                    : Icons.align_horizontal_right_rounded,
              ),
              onPressed: () => setState(() {
                _treeOnRight = !_treeOnRight;
                widget.prefs.setBool(PrefsKeys.treeOnRight, _treeOnRight);
                _controller.areas = _controller.areas.reversed.toList();
              }),
            ),
          ],
        ),
        const Divider(),
        // Start Pose Card
        Card(
          elevation: 0,
          color: colorScheme.surfaceContainerHighest.withAlpha(80),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Start Pose (or drag on field)',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _startXController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true, signed: true),
                        decoration: const InputDecoration(
                          labelText: 'X (m)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onSubmitted: (val) {
                          final x = double.tryParse(val);
                          if (x != null) {
                            final before = widget.goalPicker.startPose;
                            final after = Pose2d(
                              Translation2d(x, before.y),
                              before.rotation,
                            );
                            widget.goalPicker.startPose = after;
                            _recordStartPoseChange(before, after);
                            widget.onGoalPickerChanged?.call();
                            setState(() {});
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _startYController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true, signed: true),
                        decoration: const InputDecoration(
                          labelText: 'Y (m)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onSubmitted: (val) {
                          final y = double.tryParse(val);
                          if (y != null) {
                            final before = widget.goalPicker.startPose;
                            final after = Pose2d(
                              Translation2d(before.x, y),
                              before.rotation,
                            );
                            widget.goalPicker.startPose = after;
                            _recordStartPoseChange(before, after);
                            widget.onGoalPickerChanged?.call();
                            setState(() {});
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _startRotController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true, signed: true),
                        decoration: const InputDecoration(
                          labelText: 'Heading (°)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onSubmitted: (val) {
                          final deg = double.tryParse(val);
                          if (deg != null) {
                            final before = widget.goalPicker.startPose;
                            final after = Pose2d(
                              before.translation,
                              Rotation2d.fromDegrees(deg),
                            );
                            widget.goalPicker.startPose = after;
                            _recordStartPoseChange(before, after);
                            widget.onGoalPickerChanged?.call();
                            setState(() {});
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Goals List Header + Add Buttons
        Row(
          children: [
            Text(
              'Goals (${widget.goalPicker.goals.length})',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const Spacer(),
            if (widget.allGoals.isNotEmpty)
              PopupMenuButton<Goal>(
                tooltip: 'Add existing goal',
                icon: const Icon(Icons.playlist_add_rounded),
                itemBuilder: (context) => [
                  for (final g in widget.allGoals)
                    PopupMenuItem<Goal>(
                      value: g,
                      child: Text(g.name.isEmpty ? 'Unnamed Goal' : g.name),
                    ),
                ],
                onSelected: (selectedGoal) {
                  final before = _cloneGoals();
                  widget.goalPicker.goals.add(selectedGoal.clone());
                  _recordGoalsChange(before, _cloneGoals());
                  widget.onGoalPickerChanged?.call();
                  setState(() {});
                },
              ),
            IconButton(
              tooltip: 'Add new goal',
              icon: const Icon(Icons.add_rounded),
              onPressed: () {
                final before = _cloneGoals();
                final newGoal = Goal(
                  name: 'Goal ${widget.goalPicker.goals.length + 1}',
                  waypoints: [
                    Waypoint(anchor: const Translation2d(4.0, 6.0)),
                  ],
                );
                widget.onPromoteGoalToProject?.call(newGoal);
                widget.goalPicker.goals.add(newGoal);
                if (!widget.allGoals.any((g) => g.name == newGoal.name)) {
                  widget.allGoals.add(newGoal.clone());
                }
                _recordGoalsChange(before, _cloneGoals());
                widget.onGoalPickerChanged?.call();
                setState(() {});
              },
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Reorderable list of Goals inside this GoalPicker
        Expanded(
          child: widget.goalPicker.goals.isEmpty
              ? Center(
                  child: Text(
                    'No goals added yet.\nClick + to add a goal to this picker.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                )
              : ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  itemCount: widget.goalPicker.goals.length,
                  onReorder: (oldIndex, newIndex) {
                    final before = _cloneGoals();
                    if (newIndex > oldIndex) newIndex -= 1;
                    final moved = widget.goalPicker.goals.removeAt(oldIndex);
                    widget.goalPicker.goals.insert(newIndex, moved);
                    _recordGoalsChange(before, _cloneGoals());
                    widget.onGoalPickerChanged?.call();
                    setState(() {});
                  },
                  itemBuilder: (context, index) {
                    final goal = widget.goalPicker.goals[index];
                    final displayName = goal.name.isNotEmpty
                        ? goal.name
                        : 'Goal ${index + 1}';

                    return MouseRegion(
                      key: ValueKey('goal_item_$index'),
                      onEnter: (_) => setState(() => _hoveredGoalIndex = index),
                      onExit: (_) {
                        if (_hoveredGoalIndex == index) {
                          setState(() => _hoveredGoalIndex = null);
                        }
                      },
                      child: Card(
                        elevation: 1,
                        margin: const EdgeInsets.only(bottom: 8),
                        color: _hoveredGoalIndex == index
                            ? colorScheme.primaryContainer.withAlpha(110)
                            : colorScheme.surfaceContainerHighest.withAlpha(70),
                        child: ListTile(
                          leading: ReorderableDragStartListener(
                            index: index,
                            child: const Icon(Icons.drag_handle_rounded),
                          ),
                          title: Text(displayName),
                          subtitle: Text(
                            '${goal.waypoints.length} waypoint${goal.waypoints.length == 1 ? '' : 's'}'
                            '${goal.command.isNotEmpty ? ' • Cmd: ${goal.command}' : ''}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.onEditGoalPressed != null)
                                IconButton(
                                  tooltip: 'Edit Goal Waypoints',
                                  icon: const Icon(Icons.edit_rounded, size: 18),
                                  onPressed: () =>
                                      widget.onEditGoalPressed!(goal),
                                ),
                              IconButton(
                                tooltip: 'Duplicate Goal',
                                icon: const Icon(Icons.copy_rounded, size: 18),
                                onPressed: () {
                                  final before = _cloneGoals();
                                  final copy = goal.clone();
                                  if (copy.name.isNotEmpty) {
                                    copy.name = 'Copy of ${copy.name}';
                                  }
                                  widget.onPromoteGoalToProject?.call(copy);
                                  widget.goalPicker.goals
                                      .insert(index + 1, copy);
                                  if (!widget.allGoals
                                      .any((g) => g.name == copy.name)) {
                                    widget.allGoals.add(copy.clone());
                                  }
                                  _recordGoalsChange(before, _cloneGoals());
                                  widget.onGoalPickerChanged?.call();
                                  setState(() {});
                                },
                              ),
                              IconButton(
                                tooltip: 'Remove Goal',
                                icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    size: 18),
                                onPressed: () {
                                  final before = _cloneGoals();
                                  widget.goalPicker.goals.removeAt(index);
                                  if (_hoveredGoalIndex == index) {
                                    _hoveredGoalIndex = null;
                                  }
                                  _recordGoalsChange(before, _cloneGoals());
                                  widget.onGoalPickerChanged?.call();
                                  setState(() {});
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _GoalPickerPainter extends CustomPainter {
  final ColorScheme colorScheme;
  final GoalPicker goalPicker;
  final FieldImage fieldImage;
  final bool hideOtherGoalsOnHover;
  final int? hoveredGoalIndex;
  final bool highlightStartPose;
  final bool highlightStartHeading;
  final SharedPreferences prefs;

  late final RobotConfig robotConfig;
  final List<Feature> robotFeatures = [];

  _GoalPickerPainter({
    required this.colorScheme,
    required this.goalPicker,
    required this.fieldImage,
    required this.hideOtherGoalsOnHover,
    required this.hoveredGoalIndex,
    required this.highlightStartPose,
    required this.highlightStartHeading,
    required this.prefs,
  }) {
    robotConfig = RobotConfig.fromPrefs(prefs);
    for (String featureJson in prefs.getStringList(PrefsKeys.robotFeatures) ??
        Defaults.robotFeatures) {
      try {
        robotFeatures.add(Feature.fromJson(jsonDecode(featureJson))!);
      } catch (_) {}
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / fieldImage.defaultSize.width;

    // 1. Optional grid
    if (prefs.getBool(PrefsKeys.showGrid) ?? Defaults.showGrid) {
      final gridPaint = Paint()
        ..color = colorScheme.secondary.withAlpha(50)
        ..strokeWidth = 1;
      final gridSpacing =
          PathPainterUtil.metersToPixels(0.5, scale, fieldImage);

      for (double x = 0; x <= size.width; x += gridSpacing) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      }
      for (double y = 0; y <= size.height; y += gridSpacing) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      }
    }

    // 2. Paint Start Pose robot outline + draggable handles
    PathPainterUtil.paintRobotOutline(
      goalPicker.startPose,
      fieldImage,
      robotConfig.bumperSize,
      robotConfig.bumperOffset,
      scale,
      canvas,
      (highlightStartPose || highlightStartHeading)
          ? Colors.lightGreenAccent
          : Colors.green.withAlpha(180),
      colorScheme.surfaceContainer,
      robotFeatures,
    );

    final startOffset = PathPainterUtil.pointToPixelOffset(
      goalPicker.startPose.translation,
      scale,
      fieldImage,
    );

    final headingHandleWorld = goalPicker.startPose.translation +
        Translation2d(
          0.75 * cos(goalPicker.startPose.rotation.radians),
          0.75 * sin(goalPicker.startPose.rotation.radians),
        );
    final headingOffset = PathPainterUtil.pointToPixelOffset(
      headingHandleWorld,
      scale,
      fieldImage,
    );

    final handleLinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = Colors.green;
    canvas.drawLine(startOffset, headingOffset, handleLinePaint);

    final anchorRadius =
        PathPainterUtil.uiPointSizeToPixels(24, scale, fieldImage);
    final headingRadius =
        PathPainterUtil.uiPointSizeToPixels(18, scale, fieldImage);

    // Center drag dot
    canvas.drawCircle(
      startOffset,
      anchorRadius,
      Paint()
        ..style = PaintingStyle.fill
        ..color = highlightStartPose ? Colors.lightGreenAccent : Colors.green,
    );
    canvas.drawCircle(
      startOffset,
      anchorRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = colorScheme.surfaceContainer,
    );

    // Heading rotation drag handle
    canvas.drawCircle(
      headingOffset,
      headingRadius,
      Paint()
        ..style = PaintingStyle.fill
        ..color =
            highlightStartHeading ? Colors.lightGreenAccent : Colors.green,
    );
    canvas.drawCircle(
      headingOffset,
      headingRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = colorScheme.surfaceContainer,
    );

    final bool hidePoints =
        prefs.getBool(PrefsKeys.hidePointsAndTolerances) ??
            Defaults.hidePointsAndTolerances;

    // 3. Paint each Goal's path & waypoints branching from startPose
    for (int i = 0; i < goalPicker.goals.length; i++) {
      if (hideOtherGoalsOnHover &&
          hoveredGoalIndex != null &&
          hoveredGoalIndex != i) {
        continue;
      }

      final goal = goalPicker.goals[i];
      if (goal.waypoints.isEmpty) continue;

      final isHovered = hoveredGoalIndex == i;
      final color = isHovered ? Colors.orange : colorScheme.secondary;

      final linePaint = Paint()
        ..style = PaintingStyle.stroke
        ..color = color
        ..strokeWidth = isHovered ? 3.5 : 2.0;

      final path = Path()..moveTo(startOffset.dx, startOffset.dy);
      for (final w in goal.waypoints) {
        final pt =
            PathPainterUtil.pointToPixelOffset(w.anchor, scale, fieldImage);
        path.lineTo(pt.dx, pt.dy);
      }
      canvas.drawPath(path, linePaint);

      // End robot outline for the goal's final waypoint
      final lastWp = goal.waypoints.last;
      PathPainterUtil.paintRobotOutline(
        Pose2d(lastWp.anchor, new Rotation2d()),
        fieldImage,
        robotConfig.bumperSize,
        robotConfig.bumperOffset,
        scale,
        canvas,
        (isHovered ? Colors.orange : Colors.red).withAlpha(125),
        colorScheme.surfaceContainer,
        robotFeatures,
      );

      if (!hidePoints) {
        for (int wIdx = 0; wIdx < goal.waypoints.length; wIdx++) {
          final w = goal.waypoints[wIdx];
          final wpOffset =
              PathPainterUtil.pointToPixelOffset(w.anchor, scale, fieldImage);
          final radius =
              PathPainterUtil.uiPointSizeToPixels(22, scale, fieldImage);

          final fillPaint = Paint()
            ..style = PaintingStyle.fill
            ..color = isHovered
                ? Colors.orange
                : (wIdx == goal.waypoints.length - 1
                    ? Colors.red
                    : colorScheme.secondary);
          canvas.drawCircle(wpOffset, radius, fillPaint);

          final strokePaint = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = colorScheme.surfaceContainer;
          canvas.drawCircle(wpOffset, radius, strokePaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GoalPickerPainter oldDelegate) => true;
}