import 'dart:math';

import 'package:flutter/material.dart';
import 'package:pathplanner/path/goal.dart';
import 'package:pathplanner/path/waypoint.dart';
import 'package:pathplanner/services/goal_picker_sync_service.dart';
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
  bool _draggingHeading = false;
  List<Waypoint>? _dragStartSnapshot;
  late String _lastKnownName;

  @override
  void initState() {
    super.initState();
    _lastKnownName = widget.goal.name;
  }

  void _notifyChanged({String? previousName}) {
    final prev = previousName ?? _lastKnownName;
    GoalPickerSyncService.syncGoalAcrossPickersAndSave(
      updatedGoal: widget.goal,
      previousName: prev,
    );
    _lastKnownName = widget.goal.name;
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

  bool _isNearAnchor(Waypoint w, Translation2d pos, double radius) {
    return (w.anchor - pos).norm <= radius;
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
                                if (_isNearAnchor(w, pos, anchorR)) {
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
                                  if (_isNearAnchor(w, pos, anchorR)) {
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
                                  if (_isNearAnchor(widget.goal.waypoints[i],
                                      pos, anchorR)) {
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
                                  final w = widget.goal.waypoints[i];
                                  if (w.isLocked) continue;
                                  if (_isNearAnchor(w, pos, anchorR)) {
                                    _dragStartSnapshot = _cloneWaypoints();
                                    _draggingWaypoint = i;
                                    _draggingHeading = false;
                                    setState(() => _selectedWaypoint = i);
                                    return;
                                  }
                                }
                              },
                              onPanUpdate: (details) {
                                if (_draggingWaypoint == null) return;
                                final pos = _offsetToField(
                                    details.localPosition, scale);
                                final w =
                                    widget.goal.waypoints[_draggingWaypoint!];
                                if (_draggingHeading) {
                                  final angle = atan2(
                                    pos.y - w.anchor.y,
                                    pos.x - w.anchor.x,
                                  );
                                } else {
                                  w.move(pos.x, pos.y);
                                }
                                _notifyChanged();
                              },
                              onPanEnd: (_) {
                                if (_draggingWaypoint != null) {
                                  if (_dragStartSnapshot != null) {
                                    _recordUndo(
                                        _dragStartSnapshot!, _cloneWaypoints());
                                  }
                                  _draggingWaypoint = null;
                                  _draggingHeading = false;
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
                _buildStoreDropdown(
                  label: 'Command',
                  noneLabel: 'No Command',
                  currentValue: widget.goal.command,
                  options: CommandsStore.commands,
                  onChanged: (val) {
                    widget.goal.command = val ?? '';
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
                  _buildStoreDropdown(
                    label: 'Success Condition',
                    noneLabel: 'No Trigger',
                    currentValue: widget.goal.successCondition,
                    options:
                        TriggersStore.triggers.map((t) => t.name).toList(),
                    onChanged: (val) {
                      widget.goal.successCondition = val ?? '';
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
                  _buildStoreDropdown(
                    label: 'Failure Condition',
                    noneLabel: 'No Trigger',
                    currentValue: widget.goal.failiureCondition,
                    options:
                        TriggersStore.triggers.map((t) => t.name).toList(),
                    onChanged: (val) {
                      widget.goal.failiureCondition = val ?? '';
                      _notifyChanged();
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildStoreDropdown(
                    label: 'Backup Goal',
                    noneLabel: 'No Backup Goal',
                    currentValue: widget.goal.backUpGoal,
                    options: GoalsStore.goals
                        .map((g) => g.name)
                        .where((name) => name != widget.goal.name.trim())
                        .toList(),
                    onChanged: (val) {
                      widget.goal.backUpGoal = val ?? '';
                      _notifyChanged();
                    },
                  ),
                ],
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
            final previousName = _lastKnownName;
            widget.goal.name = value;
            widget.onRenamed.call(value);
            _notifyChanged(previousName: previousName);
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

  Widget _buildStoreDropdown({
    required String label,
    required String noneLabel,
    required String currentValue,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    final seen = <String>{};
    final items = <DropdownMenuItem<String?>>[
      DropdownMenuItem<String?>(value: null, child: Text(noneLabel)),
    ];

    for (final opt in options) {
      if (opt.isNotEmpty && seen.add(opt)) {
        items.add(DropdownMenuItem<String?>(value: opt, child: Text(opt)));
      }
    }

    final selected = currentValue.isEmpty ? null : currentValue;
    if (selected != null && !seen.contains(selected)) {
      items.insert(
        1,
        DropdownMenuItem<String?>(
          value: selected,
          child: Text('Unknown ($selected)'),
        ),
      );
    }

    return DropdownButtonFormField<String?>(
      value: selected,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      items: items,
      onChanged: onChanged,
    );
  }

  Widget _buildSelectedWaypointCard(
    Waypoint w,
    int index,
    ColorScheme colorScheme,
  ) {
    final controllers =
        ControllerSettingsStore.settings.map((e) => e.name).toList();
    final headingStrats =
        HeadingStratsStore.headingStrats.map((e) => e.name).toList();

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
              icon: Icon(
                  w.isLocked ? Icons.lock_rounded : Icons.lock_open_rounded),
              onPressed: () {
                final before = _cloneWaypoints();
                w.isLocked = !w.isLocked;
                _recordUndo(before, _cloneWaypoints());
                _notifyChanged();
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                key: ValueKey('wp_${index}_tolM_${w.toleranceM}'),
                initialValue: w.toleranceM.toString(),
                enabled: !w.isLocked,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: false),
                decoration: const InputDecoration(
                  labelText: 'Tolerance (m)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onFieldSubmitted: (val) {
                  final parsed = double.tryParse(val);
                  if (parsed != null && parsed >= 0) {
                    final before = _cloneWaypoints();
                    w.toleranceM = parsed;
                    _recordUndo(before, _cloneWaypoints());
                    _notifyChanged();
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                key: ValueKey('wp_${index}_tolDeg_${w.toleranceDeg}'),
                initialValue: w.toleranceDeg.toString(),
                enabled: !w.isLocked,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: false),
                decoration: const InputDecoration(
                  labelText: 'Tolerance (°)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onFieldSubmitted: (val) {
                  final parsed = double.tryParse(val);
                  if (parsed != null && parsed >= 0) {
                    final before = _cloneWaypoints();
                    w.toleranceDeg = parsed;
                    _recordUndo(before, _cloneWaypoints());
                    _notifyChanged();
                  }
                },
              ),
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
          onChanged: w.isLocked
              ? null
              : (val) {
                  final before = _cloneWaypoints();
                  w.controllerSettingName = val;
                  _recordUndo(before, _cloneWaypoints());
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
          onChanged: w.isLocked
              ? null
              : (val) {
                  final before = _cloneWaypoints();
                  w.headingStratName = val;
                  _recordUndo(before, _cloneWaypoints());
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
          '#${index + 1}  (${w.anchor.x.toStringAsFixed(2)},${w.anchor.y.toStringAsFixed(2)})',
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