import 'package:flutter/material.dart';
import 'package:pathplanner/pages/goal_editor_page.dart';
import 'package:pathplanner/path/goal.dart';
import 'package:pathplanner/path/goal_picker.dart';
import 'package:pathplanner/widgets/conditional_widget.dart';
import 'package:pathplanner/widgets/custom_appbar.dart';
import 'package:pathplanner/widgets/editor/split_goalpicker_editor.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/widgets/keyboard_shortcuts.dart';
import 'package:pathplanner/widgets/renamable_title.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undo/undo.dart';

class GoalPickerEditorPage extends StatefulWidget {
  final SharedPreferences prefs;
  final String name;
  final GoalPicker goalPicker;
  final List<Goal> allGoals;
  final FieldImage fieldImage;
  final ValueChanged<String> onRenamed;
  final ChangeStack undoStack;
  final bool shortcuts;
  final VoidCallback? onGoalPickerChanged;
  final ValueChanged<Goal>? onPromoteGoalToProject;

  const GoalPickerEditorPage({
    super.key,
    required this.prefs,
    required this.name,
    required this.goalPicker,
    required this.allGoals,
    required this.fieldImage,
    required this.onRenamed,
    required this.undoStack,
    this.shortcuts = true,
    this.onGoalPickerChanged,
    this.onPromoteGoalToProject,
  });

  @override
  State<GoalPickerEditorPage> createState() => _GoalPickerEditorPageState();
}

class _GoalPickerEditorPageState extends State<GoalPickerEditorPage> {
  late String _currentName;

  @override
  void initState() {
    super.initState();
    _currentName = widget.name;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final editorWidget = SplitGoalPickerEditor(
      prefs: widget.prefs,
      goalPicker: widget.goalPicker,
      allGoals: widget.allGoals,
      fieldImage: widget.fieldImage,
      undoStack: widget.undoStack,
      onGoalPickerChanged: widget.onGoalPickerChanged,
      onPromoteGoalToProject: widget.onPromoteGoalToProject,
      onEditGoalPressed: (goal) async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GoalEditorPage(
              prefs: widget.prefs,
              goal: goal,
              fieldImage: widget.fieldImage,
              undoStack: ChangeStack(),
              shortcuts: widget.shortcuts,
              onRenamed: (newName) => goal.name = newName,
              onGoalChanged: widget.onGoalPickerChanged,
            ),
          ),
        );
        widget.onGoalPickerChanged?.call();
        setState(() {});
      },
    );

    return Scaffold(
      appBar: CustomAppBar(
        titleWidget: RenamableTitle(
          title: _currentName,
          textStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurface,
          ),
          onRename: (value) {
            _currentName = value;
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
            child: editorWidget,
          ),
        ),
        falseChild: editorWidget,
      ),
    );
  }
}