import 'package:flutter/material.dart';
import 'package:pathplanner/path/goal.dart';
import 'package:pathplanner/path/waypoint.dart';
import 'package:pathplanner/services/stores_Service.dart';
import 'package:pathplanner/util/path_painter_util.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';
import 'package:pathplanner/widgets/conditional_widget.dart';
import 'package:pathplanner/widgets/custom_appbar.dart';
import 'package:pathplanner/widgets/editor/path_painter.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/widgets/keyboard_shortcuts.dart';
import 'package:pathplanner/widgets/renamable_title.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undo/undo.dart';

class GoalEditorPage extends StatefulWidget {
  final SharedPreferences prefs;
  final Goal goal;
  final FieldImage fieldImage;
  final ValueChanged<String> onRenamed;
  final ChangeStack undoStack;
  final bool shortcuts;
  final VoidCallback? onGoalChanged;

  const GoalEditorPage({
    super.key,
    required this.prefs,
    required this.goal,
    required this.fieldImage,
    required this.onRenamed,
    required this.undoStack,
    this.shortcuts = true,
    this.onGoalChanged,
  });

  @override
  State<GoalEditorPage> createState() => _GoalEditorPageState();
}

class _GoalEditorPageState extends State<GoalEditorPage> {
  int? _selectedWaypoint;
  int? _hoveredWaypoint;
  int? _draggingWaypoint;
  List<Waypoint>? _dragStartSnapshot;

  late TextEditingController _commandController;
  late TextEditingController _successCondController;
  late TextEditingController _failureCondController;
  late TextEditingController _backupGoalController;

  @override
  void initState() {
    super.initState();
    _commandController = TextEditingController(text: widget.goal.command);
    _successCondController =
        TextEditingController(text: widget.goal.successCondition);
    _failureCondController =
        TextEditingController(text: widget.goal.failiureCondition);
    _backupGoalController = TextEditingController(text: widget.goal.backUpGoal);
  }

  @override
  void dispose() {
    _commandController.dispose();
    _successCondController.dispose();
    _failureCondController.dispose();
    _backupGoalController.dispose();
    super.dispose();
  }

  void _notifyChanged() {
    widget.onGoalChanged?.call();
    setState(() {});
  }

  List<Waypoint> _cloneWaypoints() =>
      [for (final w in widget.goal.waypoints) w.clone()];

  void _recordUndo(List<Waypoint> before, List<Waypoint> after) {
    widget.undoStack.add(
      Change<List<Waypoint>>(
        before,
        () {
          widget.goal.waypoints = [for (final w in after) w.clone()];
          _clampSelection();
          _notifyChanged();
        },
        (oldValue) {
          widget.goal.waypoints = [for (final w in oldValue) w.clone()];
          _clampSelection();
          _notifyChanged();
        },
      ),
    );
  }

  void _clampSelection() {
    if (_selectedWaypoint != null &&
        _selectedWaypoint! >= widget.goal.waypoints.length) {
      _selectedWaypoint = widget.goal.waypoints.isEmpty
          ? null
          : widget.goal.waypoints.length - 1;
    }
  }

  Translation2d _offsetToField(Offset localPos, double scale) {
    return PathPainterUtil.pixelOffsetToPoint(
        localPos, scale, widget.fieldImage);
  }

  double _anchorRadiusMeters(double scale) {
    final px = PathPainterUtil.uiPointSizeToPixels(25, scale, widget.fieldImage);
    return PathPainterUtil.pixelsToMeters(px, scale, widget.fieldImage);
  }

  double _headingRadiusMeters(double scale) {
    final px = PathPainterUtil.uiPointSizeToPixels(20, scale, widget.fieldImage);
    return PathPainterUtil.pixelsToMeters(px, scale, widget.fieldImage);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final editorBody = Row(
      children: [
        // Field canvas
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.touch_app_rounded,
                        size: 18, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Click empty field to place waypoint • Drag anchor or heading handle • Right-click waypoint to delete',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const Spacer(),
                    if (widget.goal.waypoints.isNotEmpty)
                      TextButton.icon(
                        onPressed: () {
                          final before = _cloneWaypoints();
                          widget.goal.waypoints.clear();
                          _selectedWaypoint = null;
                          _recordUndo(before, _cloneWaypoints());
                          _notifyChanged();
                        },
                        icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                        label: const Text('Clear Waypoints'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: widget.fieldImage.defaultSize.width /
                          widget.fieldImage.defaultSize.height,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final scale = constraints.maxWidth /
                              widget.fieldImage.defaultSize.width;
                          final anchorR = _anchorRadiusMeters(scale);
                          final headingR = _headingRadiusMeters(scale);

                          return MouseRegion(
                            onHover: (event) {
                              final pos =
                                  _offsetToField(event.localPosition, scale);
                              int? found;
                              for (int i = widget.goal.waypoints.length - 1;
                                  i >= 0;
                                  i--) {
                                final w = widget.goal.waypoints[i];
                                if (w.isPointInAnchor(pos.x, pos.y, anchorR) ||
                                    w.isPointInHeadingHandle(
                                        pos.x, pos.y, headingR)) {
                                  found = i;
                                  break;
                                }
                              }
                              if (found != _hoveredWaypoint) {
                                setState(() => _hoveredWaypoint = found);
                              }
                            },
                            onExit: (_) {
                              if (_hoveredWaypoint != null) {
                                setState(() => _hoveredWaypoint = null);
                              }
                            },
                            child: GestureDetector(
                              onTapUp: (details) {
                                final pos = _offsetToField(
                                    details.localPosition, scale);

                                // Check if tapping an existing waypoint first
                                for (int i = widget.goal.waypoints.length - 1;
                                    i >= 0;
                                    i--) {
                                  final w = widget.goal.waypoints[i];
                                  if (w.isPointInAnchor(
                                          pos.x, pos.y, anchorR) ||
                                      w.isPointInHeadingHandle(
                                          pos.x, pos.y, headingR)) {
                                    setState(() => _selectedWaypoint = i);
                                    return;
                                  }
                                }

                                // Otherwise place a new waypoint
                                final before = _cloneWaypoints();
                                widget.goal.waypoints
                                    .add(Waypoint(anchor: pos));
                                _selectedWaypoint =
                                    widget.goal.waypoints.length - 1;
                                _recordUndo(before, _cloneWaypoints());
                                _notifyChanged();
                              },
                              onSecondaryTapUp: (details) {
                                final pos = _offsetToField(
                                    details.localPosition, scale);
                                for (int i = widget.goal.waypoints.length - 1;
                                    i >= 0;
                                    i--) {
                                  if (widget.goal.waypoints[i]
                                      .isPointInAnchor(pos.x, pos.y, anchorR)) {
                                    final before = _cloneWaypoints();
                                    widget.goal.waypoints.removeAt(i);
                                    if (_selectedWaypoint == i) {
                                      _selectedWaypoint = null;
                                    } else if (_selectedWaypoint != null &&
                                        _selectedWaypoint! > i) {
                                      _selectedWaypoint =
                                          _selectedWaypoint! - 1;
                                    }
                                    _recordUndo(before, _cloneWaypoints());
                                    _notifyChanged();
                                    return;
                                  }
                                }
                              },
                              onPanStart: (details) {
                                final pos = _offsetToField(
                                    details.localPosition, scale);
                                for (int i = widget.goal.waypoints.length - 1;
                                    i >= 0;
                                    i--) {
                                  if (widget.goal.waypoints[i].startDragging(
                                      pos.x, pos.y, anchorR, headingR)) {
                                    _dragStartSnapshot = _cloneWaypoints();
                                    _draggingWaypoint = i;
                                    setState(() => _selectedWaypoint = i);
                                    return;
                                  }
                                }
                              },
                              onPanUpdate: (details) {
                                if (_draggingWaypoint == null) return;
                                final pos = _offsetToField(
                                    details.localPosition, scale);
                                widget.goal.waypoints[_draggingWaypoint!]
                                    .dragUpdate(pos.x, pos.y);
                                _notifyChanged();
                              },
                              onPanEnd: (_) {
                                if (_draggingWaypoint != null) {
                                  widget.goal.waypoints[_draggingWaypoint!]
                                      .stopDragging();
                                  if (_dragStartSnapshot != null) {
                                    _recordUndo(
                                        _dragStartSnapshot!, _cloneWaypoints());
                                  }
                                  _draggingWaypoint = null;
                                  _dragStartSnapshot = null;
                                  _notifyChanged();
                                }
                              },
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: widget.fieldImage.getWidget(),
                                    ),
                                  ),
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: PathPainter(
                                        colorScheme: colorScheme,
                                        waypoints: widget.goal.waypoints,
                                        fieldImage: widget.fieldImage,
                                        hoveredWaypoint: _hoveredWaypoint,
                                        selectedWaypoint: _selectedWaypoint,
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
              ],
            ),
          ),
        ),
        // Right sidebar: Selected waypoint inspector + Goal settings
        SizedBox(
          width: 340,
          child: Card(
            margin: const EdgeInsets.fromLTRB(0, 12, 12, 12),
            elevation: 1,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_selectedWaypoint != null &&
                    _selectedWaypoint! < widget.goal.waypoints.length) ...[
                  _buildSelectedWaypointCard(
                    widget.goal.waypoints[_selectedWaypoint!],
                    _selectedWaypoint!,
                    colorScheme,
                  ),
                  const Divider(height: 24),
                ],
                Text(
                  'Goal Settings',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _commandController,
                  decoration: const InputDecoration(
                    labelText: 'Command',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (val) {
                    widget.goal.command = val;
                    _notifyChanged();
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Command-Based Goal'),
                  value: widget.goal.commandBasedGoal,
                  onChanged: (val) {
                    widget.goal.commandBasedGoal = val;
                    _notifyChanged();
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Finish When Drive Finishes'),
                  value: widget.goal.finishWhenDriveFinishes,
                  onChanged: (val) {
                    widget.goal.finishWhenDriveFinishes = val;
                    _notifyChanged();
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('With Success Condition'),
                  value: widget.goal.withSuccessCondition,
                  onChanged: (val) {
                    widget.goal.withSuccessCondition = val;
                    _notifyChanged();
                  },
                ),
                if (widget.goal.withSuccessCondition) ...[
                  TextField(
                    controller: _successCondController,
                    decoration: const InputDecoration(
                      labelText: 'Success Condition',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (val) {
                      widget.goal.successCondition = val;
                      _notifyChanged();
                    },
                  ),
                  const SizedBox(height: 8),
                ],
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('With Failure Condition'),
                  value: widget.goal.withFailiureCondition,
                  onChanged: (val) {
                    widget.goal.withFailiureCondition = val;
                    _notifyChanged();
                  },
                ),
                if (widget.goal.withFailiureCondition) ...[
                  TextField(
                    controller: _failureCondController,
                    decoration: const InputDecoration(
                      labelText: 'Failure Condition',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (val) {
                      widget.goal.failiureCondition = val;
                      _notifyChanged();
                    },
                  ),
                  const SizedBox(height: 8),
                ],
                TextField(
                  controller: _backupGoalController,
                  decoration: const InputDecoration(
                    labelText: 'Backup Goal',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (val) {
                    widget.goal.backUpGoal = val;
                    _notifyChanged();
                  },
                ),
                const Divider(height: 24),
                Text(
                  'Waypoints (${widget.goal.waypoints.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                for (int i = 0; i < widget.goal.waypoints.length; i++)
                  _buildWaypointListTile(i, colorScheme),
              ],
            ),
          ),
        ),
      ],
    );

    return Scaffold(
      appBar: CustomAppBar(
        titleWidget: RenamableTitle(
          title: widget.goal.name,
          textStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurface,
          ),
          onRename: (value) {
            widget.onRenamed.call(value);
            setState(() {});
          },
        ),
        leading: BackButton(
          onPressed: () {
            widget.undoStack.clearHistory();
            Navigator.of(context).pop();
          },
        ),
      ),
      body: ConditionalWidget(
        condition: widget.shortcuts,
        trueChild: KeyBoardShortcuts(
          keysToPress: shortCut(BasicShortCuts.undo),
          onKeysPressed: widget.undoStack.undo,
          child: KeyBoardShortcuts(
            keysToPress: shortCut(BasicShortCuts.redo),
            onKeysPressed: widget.undoStack.redo,
            child: editorBody,
          ),
        ),
        falseChild: editorBody,
      ),
    );
  }

  Widget _buildSelectedWaypointCard(
    Waypoint w,
    int index,
    ColorScheme colorScheme,
  ) {
    final controllers = ControllerSettingsStore.settings.map((e) => e.name).toList();
    final headingStrats = HeadingStratsStore.headingStrats.map((e) => e.name).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Waypoint ${index + 1}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            IconButton(
              tooltip: w.isLocked ? 'Unlock Waypoint' : 'Lock Waypoint',
              icon: Icon(w.isLocked ? Icons.lock_rounded : Icons.lock_open_rounded),
              onPressed: () {
                w.isLocked = !w.isLocked;
                _notifyChanged();
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String?>(
          value: controllers.contains(w.controllerSettingName)
              ? w.controllerSettingName
              : null,
          decoration: const InputDecoration(
            labelText: 'Controller Settings',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('None')),
            for (final name in controllers)
              DropdownMenuItem<String?>(value: name, child: Text(name)),
          ],
          onChanged: (val) {
            w.controllerSettingName = val;
            _notifyChanged();
          },
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String?>(
          value: headingStrats.contains(w.headingStratName)
              ? w.headingStratName
              : null,
          decoration: const InputDecoration(
            labelText: 'Heading Strategy',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('None')),
            for (final name in headingStrats)
              DropdownMenuItem<String?>(value: name, child: Text(name)),
          ],
          onChanged: (val) {
            w.headingStratName = val;
            _notifyChanged();
          },
        ),
      ],
    );
  }

  Widget _buildWaypointListTile(int index, ColorScheme colorScheme) {
    final w = widget.goal.waypoints[index];
    final isSelected = _selectedWaypoint == index;

    return Card(
      elevation: 0,
      color: isSelected
          ? colorScheme.primaryContainer.withAlpha(120)
          : colorScheme.surfaceContainerHighest.withAlpha(80),
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        selected: isSelected,
        onTap: () => setState(() => _selectedWaypoint = index),
        title: Text(
          '#${index + 1}  (${w.anchor.x.toStringAsFixed(2)}, ${w.anchor.y.toStringAsFixed(2)})  ${w.holonomicAngle.degrees.toStringAsFixed(0)}°',
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline_rounded, size: 18),
          onPressed: () {
            final before = _cloneWaypoints();
            widget.goal.waypoints.removeAt(index);
            if (_selectedWaypoint == index) {
              _selectedWaypoint = null;
            } else if (_selectedWaypoint != null &&
                _selectedWaypoint! > index) {
              _selectedWaypoint = _selectedWaypoint! - 1;
            }
            _recordUndo(before, _cloneWaypoints());
            _notifyChanged();
          },
        ),
      ),
    );
  }
}