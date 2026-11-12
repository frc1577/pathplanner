import 'package:flutter/material.dart';
import 'package:pathplanner/pages/controller_settings_page.dart';
import 'package:pathplanner/pages/heading_strats_page.dart';
import 'package:pathplanner/path/goal.dart';
import 'package:pathplanner/path/goal_picker.dart';
import 'package:pathplanner/path/heading_strat.dart';
import 'package:pathplanner/path/waypoint.dart';
import 'package:pathplanner/services/physics_sim_service.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/item_count.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/tree_card_node.dart';
import 'package:pathplanner/widgets/number_text_field.dart';
import 'package:undo/undo.dart';

class GoalsTree extends StatefulWidget {
  final GoalPicker path;
  final ChangeStack undoStack;
  final VoidCallback? onPathChanged;
  final VoidCallback? onControllerSettingsChanged;

  const GoalsTree({
    super.key,
    required this.path,
    required this.undoStack,
    this.onPathChanged,
    this.onControllerSettingsChanged,
  });

  @override
  State<GoalsTree> createState() => _GoalsTreeState();
}

class _GoalsTreeState extends State<GoalsTree> {
  final Map<Goal, int> _selectedTabs = {};
  final Map<Goal, TextEditingController> _commandControllers = {};
  final Map<Goal, TextEditingController> _endCondControllers = {};

  List<Goal> _cloneGoals() =>
      [for (final goal in widget.path.goals) goal.clone()];

  TextEditingController _getController(
    Map<Goal, TextEditingController> controllers,
    Goal goal,
    String initialValue,
  ) {
    return controllers.putIfAbsent(
      goal,
      () => TextEditingController(text: initialValue),
    );
  }

  void _restoreGoals(List<Goal> goals) {
    widget.path.goals = [for (final goal in goals) goal.clone()];
    widget.path.rebuildPath();
    widget.onPathChanged?.call();
  }

  void _changeGoals(void Function() change) {
    final oldGoals = _cloneGoals();

    widget.undoStack.add(Change(
      oldGoals,
      () {
        setState(() {
          change();
          widget.path.rebuildPath();
          widget.onPathChanged?.call();
        });
      },
      (oldValue) {
        setState(() => _restoreGoals(oldValue));
      },
    ));
  }

  void _addGoal() {
    _changeGoals(() {
      final previous = widget.path.waypoints.isEmpty
          ? const Translation2d(0.0, 0.0)
          : widget.path.waypoints.last.anchor;

      widget.path.goals.add(Goal(
        waypoints: [
          Waypoint(
            anchor: previous + const Translation2d(1.0, 0.0),
          ),
        ],
      ));
    });
  }

  void _deleteGoal(int index) {
    if (widget.path.goals.length <= 1) return;

    _changeGoals(() {
      widget.path.goals.removeAt(index);
    });
  }

  void _moveGoal(int index, int direction) {
    final newIndex = index + direction;

    if (newIndex < 0 || newIndex >= widget.path.goals.length) return;

    _changeGoals(() {
      final goal = widget.path.goals.removeAt(index);
      widget.path.goals.insert(newIndex, goal);
    });
  }

  void _addWaypoint(int goalIndex) {
    _changeGoals(() {
      final goal = widget.path.goals[goalIndex];

      final previous = goal.waypoints.isEmpty
          ? widget.path.startPose.translation
          : goal.waypoints.last.anchor;

      goal.waypoints.add(Waypoint(
        anchor: previous + const Translation2d(1.0, 0.0),
      ));
    });
  }

  void _deleteWaypoint(int goalIndex, int waypointIndex) {
    if (widget.path.goals[goalIndex].waypoints.length <= 1) return;

    _changeGoals(() {
      widget.path.goals[goalIndex].waypoints.removeAt(waypointIndex);
    });
  }

  void _updateWaypoint(Waypoint waypoint, void Function() update) {
    setState(() {
      update();
      widget.path.rebuildPath();
    });

    widget.onPathChanged?.call();
  }

  @override
  void dispose() {
    for (final controller in _commandControllers.values) {
      controller.dispose();
    }

    for (final controller in _endCondControllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TreeCardNode(
      title: const Text('Goals'),
      leading: const Icon(Icons.flag_circle_outlined),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ItemCount(count: widget.path.goals.length),
          IconButton(
            tooltip: 'Add Goal',
            onPressed: _addGoal,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      initiallyExpanded: true,
      children: [
        for (int index = 0; index < widget.path.goals.length; index++)
          _buildGoal(index, widget.path.goals[index]),
      ],
    );
  }

  Widget _buildGoal(int index, Goal goal) {
    final selectedTab = _selectedTabs[goal] ?? 0;

    return TreeCardNode(
      key: ValueKey('goal_${index}_${goal.waypoints.length}'),
      title: Text('Goal ${index + 1}'),
      leading: const Icon(Icons.flag_outlined),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Move Goal Up',
            onPressed: index == 0 ? null : () => _moveGoal(index, -1),
            icon: const Icon(Icons.arrow_upward),
          ),
          IconButton(
            tooltip: 'Move Goal Down',
            onPressed: index == widget.path.goals.length - 1
                ? null
                : () => _moveGoal(index, 1),
            icon: const Icon(Icons.arrow_downward),
          ),
          IconButton(
            tooltip: 'Delete Goal',
            onPressed: widget.path.goals.length <= 1
                ? null
                : () => _deleteGoal(index),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      initiallyExpanded: true,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: 0,
                label: Text('Waypoints'),
                icon: Icon(Icons.location_on_outlined),
              ),
              ButtonSegment(
                value: 1,
                label: Text('States'),
                icon: Icon(Icons.terminal),
              ),
            ],
            selected: {selectedTab},
            onSelectionChanged: (selection) {
              setState(() {
                _selectedTabs[goal] = selection.first;
              });
            },
          ),
        ),
        const SizedBox(height: 8),
        if (selectedTab == 0) ...[
          TreeCardNode(
            key: ValueKey(
                'waypoints_sub_tree_${index}_${goal.waypoints.length}'),
            title: const Text('Waypoints'),
            leading: const Icon(Icons.location_on_outlined),
            elevation: 1,
            indent: 8,
            initiallyExpanded: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ItemCount(count: goal.waypoints.length),
                IconButton(
                  tooltip: 'Add Waypoint',
                  onPressed: () => _addWaypoint(index),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            children: [
              for (int waypointIndex = 0;
                  waypointIndex < goal.waypoints.length;
                  waypointIndex++)
                _buildWaypointCard(
                  index,
                  waypointIndex,
                  goal.waypoints[waypointIndex],
                ),
            ],
          ),
        ] else ...[
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextFormField(
                  controller: _getController(
                    _commandControllers,
                    goal,
                    goal.command,
                  ),
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Command',
                    hintText: 'Enter command...',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    goal.command = value;
                    widget.onPathChanged?.call();
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _getController(
                    _endCondControllers,
                    goal,
                    goal.endCond,
                  ),
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'End Condition',
                    hintText: 'Enter end condition...',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    goal.endCond = value;
                    widget.onPathChanged?.call();
                  },
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildWaypointCard(
    int goalIndex,
    int waypointIndex,
    Waypoint waypoint,
  ) {
    return TreeCardNode(
      key: ObjectKey(waypoint),
      elevation: 0,
      indent: 4,
      title: Text('Waypoint ${waypointIndex + 1}'),
      leading: const Icon(Icons.location_on_outlined),
      initiallyExpanded: true,
      trailing: IconButton(
        tooltip: 'Delete Waypoint',
        onPressed: widget.path.goals[goalIndex].waypoints.length <= 1
            ? null
            : () => _deleteWaypoint(goalIndex, waypointIndex),
        icon: const Icon(Icons.delete_outline),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Expanded(
                child: NumberTextField(
                  initialValue: waypoint.anchor.x,
                  label: 'X Position (M)',
                  enabled: !waypoint.isLocked,
                  onSubmitted: (value) => value == null
                      ? null
                      : _updateWaypoint(
                          waypoint,
                          () => waypoint.move(value, waypoint.anchor.y),
                        ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: NumberTextField(
                  initialValue: waypoint.anchor.y,
                  label: 'Y Position (M)',
                  enabled: !waypoint.isLocked,
                  onSubmitted: (value) => value == null
                      ? null
                      : _updateWaypoint(
                          waypoint,
                          () => waypoint.move(waypoint.anchor.x, value),
                        ),
                ),
              ),
            ],
          ),
        ),
        _buildWaypointDropdownRow(
          label: 'Heading Strat',
          value: waypoint.headingStratId,
          items: [
            for (final strat in HeadingStratsStore.settings)
              DropdownMenuItem(
                value: strat.id,
                child: Text(strat.name),
              ),
          ],
          onChanged: waypoint.isLocked
              ? null
              : (value) => _updateWaypoint(
                    waypoint,
                    () => waypoint.headingStratId = value,
                  ),
          onGearPressed: () async {
            final updatedStrats =
                await Navigator.of(context).push<List<HeadingStrat>>(
              MaterialPageRoute(
                builder: (context) => HeadingStratsPage(
                  headingStrats: HeadingStratsStore.settings,
                ),
              ),
            );
            if (updatedStrats != null) {
              setState(() {
                HeadingStratsStore.setSettings(updatedStrats);
              });
              widget.onPathChanged?.call();
            }
          },
          gearTooltip: 'Edit Heading Strategies',
        ),
        _buildWaypointDropdownRow(
          label: 'Controller Setting',
          value: waypoint.controllerSettingName,
          items: [
            for (final setting in ControllerSettingsStore.settings)
              DropdownMenuItem(
                value: setting.name,
                child: Text(setting.name),
              ),
          ],
          onChanged: waypoint.isLocked
              ? null
              : (value) => _updateWaypoint(
                    waypoint,
                    () => waypoint.controllerSettingName = value,
                  ),
          onGearPressed: () async {
            final updatedSettings =
                await Navigator.of(context).push<List<ControllerSetting>>(
              MaterialPageRoute(
                builder: (context) => ControllerSettingsPage(
                  controllerSettings: ControllerSettingsStore.settings,
                ),
              ),
            );
            if (updatedSettings != null) {
              setState(() {
                ControllerSettingsStore.setSettings(updatedSettings);
              });
              widget.onControllerSettingsChanged?.call();
            }
          },
          gearTooltip: 'Edit Controller Settings',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Expanded(
                child: NumberTextField(
                  initialValue: waypoint.tolerance,
                  label: 'Arrival Tolerance (M)',
                  enabled: !waypoint.isLocked,
                  onSubmitted: (value) => value == null
                      ? null
                      : _updateWaypoint(
                          waypoint,
                          () => waypoint.tolerance = value,
                        ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: NumberTextField(
                  initialValue: waypoint.toleranceDeg,
                  label: 'Rotation Tolerance (Deg)',
                  enabled: !waypoint.isLocked,
                  onSubmitted: (value) => value == null
                      ? null
                      : _updateWaypoint(
                          waypoint,
                          () => waypoint.toleranceDeg = value,
                        ),
                ),
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            tooltip: waypoint.isLocked
                ? 'Unlock Waypoint'
                : 'Lock Waypoint',
            onPressed: () => _updateWaypoint(
              waypoint,
              () => waypoint.isLocked = !waypoint.isLocked,
            ),
            icon: Icon(
              waypoint.isLocked ? Icons.lock : Icons.lock_open,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWaypointDropdownRow({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?>? onChanged,
    required VoidCallback onGearPressed,
    required String gearTooltip,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: value,
              decoration: InputDecoration(labelText: label),
              isExpanded: true,
              items: items,
              onChanged: onChanged,
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: gearTooltip,
            onPressed: onGearPressed,
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
    );
  }
}