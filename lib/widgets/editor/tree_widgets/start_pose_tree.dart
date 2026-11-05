import 'package:flutter/material.dart';
import 'package:pathplanner/path/goal_picker.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/tree_card_node.dart';
import 'package:pathplanner/widgets/number_text_field.dart';
import 'package:undo/undo.dart';

class StartPoseTree extends StatelessWidget {
  final GoalPicker path;
  final VoidCallback? onPathChanged;
  final ChangeStack undoStack;

  const StartPoseTree({
    super.key,
    required this.path,
    this.onPathChanged,
    required this.undoStack,
  });

  @override
  Widget build(BuildContext context) {
    return TreeCardNode(
      title: const Text('Start Pose'),
      leading: const Icon(Icons.start_rounded),
      initiallyExpanded: true,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6.0),
          child: Row(
            children: [
              Expanded(
                child: NumberTextField(
                  initialValue: path.startPose.x,
                  label: 'X Position (M)',
                  onSubmitted: (value) {
                    if (value != null) {
                      _addChange(() => path.startPose = Pose2d(
                          Translation2d(value, path.startPose.y),
                          path.startPose.rotation));
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: NumberTextField(
                  initialValue: path.startPose.y,
                  label: 'Y Position (M)',
                  onSubmitted: (value) {
                    if (value != null) {
                      _addChange(() => path.startPose = Pose2d(
                          Translation2d(path.startPose.x, value),
                          path.startPose.rotation));
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: NumberTextField(
                  initialValue: path.startPose.rotation.degrees,
                  label: 'Rotation (Deg)',
                  onSubmitted: (value) {
                    if (value != null) {
                      _addChange(() => path.startPose = Pose2d(
                          path.startPose.translation,
                          Rotation2d.fromDegrees(value)));
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _addChange(VoidCallback execute) {
    undoStack.add(Change(
      path.startPose,
      () {
        execute.call();
        path.rebuildPath();
        onPathChanged?.call();
      },
      (oldValue) {
        path.startPose = oldValue;
        path.rebuildPath();
        onPathChanged?.call();
      },
    ));
  }
}
