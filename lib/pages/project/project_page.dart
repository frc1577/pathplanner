import 'dart:async';
import 'dart:convert';

import 'package:file/file.dart';
import 'package:flutter/material.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:path/path.dart';
import 'package:pathplanner/pages/goal_editor_page.dart';
import 'package:pathplanner/widgets/editor/goalpicker_editor_page.dart';
import 'package:pathplanner/pages/project/project_item_card.dart';
import 'package:pathplanner/path/goal.dart';
import 'package:pathplanner/path/goal_picker.dart';
import 'package:pathplanner/path/waypoint.dart';
import 'package:pathplanner/services/pplib_telemetry.dart';
import 'package:pathplanner/util/prefs.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';
import 'package:pathplanner/widgets/conditional_widget.dart';
import 'package:pathplanner/widgets/dialogs/management_dialog.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/widgets/renamable_title.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undo/undo.dart';

class _GoalEntry {
  Goal goal;
  String? folder;
  DateTime lastModified;

  _GoalEntry({
    required this.goal,
    this.folder,
    DateTime? lastModified,
  }) : lastModified = lastModified ?? DateTime.now();

  String get name => goal.name;
  set name(String value) => goal.name = value;

  Map<String, dynamic> toFileJson() => {
        ...goal.toJson(),
        'folder': folder,
      };

  factory _GoalEntry.fromFileJson(
    Map<String, dynamic> json,
    DateTime lastModified,
  ) {
    return _GoalEntry(
      goal: Goal.fromJson(json),
      folder: json['folder'] as String?,
      lastModified: lastModified,
    );
  }
}

class _GoalPickerEntry {
  String name;
  GoalPicker picker;
  String? folder;
  DateTime lastModified;

  _GoalPickerEntry({
    required this.name,
    required this.picker,
    this.folder,
    DateTime? lastModified,
  }) : lastModified = lastModified ?? DateTime.now();

  Map<String, dynamic> toFileJson() => {
        'name': name,
        'folder': folder,
        ...picker.toJson(),
      };

  factory _GoalPickerEntry.fromFileJson(
    Map<String, dynamic> json,
    String fallbackName,
    DateTime lastModified,
  ) {
    return _GoalPickerEntry(
      name: (json['name'] as String?)?.isNotEmpty == true
          ? json['name'] as String
          : fallbackName,
      picker: GoalPicker.fromJson(json),
      folder: json['folder'] as String?,
      lastModified: lastModified,
    );
  }
}

class ProjectPage extends StatefulWidget {
  static Set<String> events = {};
  static _ProjectPageState? _instance;

  static List<Goal> get allGoals =>
      _instance?._goals.map((e) => e.goal).toList() ?? [];
  static List<GoalPicker> get allGoalPickers =>
      _instance?._goalPickers.map((e) => e.picker).toList() ?? [];

  final SharedPreferences prefs;
  final FieldImage fieldImage;
  final Directory pathplannerDirectory;
  final Directory choreoDirectory;
  final FileSystem fs;
  final ChangeStack undoStack;
  final bool shortcuts;
  final PPLibTelemetry? telemetry;
  final bool hotReload;
  final VoidCallback? onFoldersChanged;
  final VoidCallback? onProjectSettingsChanged;
  final bool simulatePath;
  final bool watchChorDir;

  static bool settingsUpdated = false;

  const ProjectPage({
    super.key,
    required this.prefs,
    required this.fieldImage,
    required this.pathplannerDirectory,
    required this.choreoDirectory,
    required this.fs,
    required this.undoStack,
    this.shortcuts = true,
    this.telemetry,
    this.hotReload = false,
    this.onFoldersChanged,
    this.onProjectSettingsChanged,
    this.simulatePath = false,
    this.watchChorDir = false,
  });

  @override
  State<ProjectPage> createState() => _ProjectPageState();
}

class _ProjectPageState extends State<ProjectPage> {
  final MultiSplitViewController _controller = MultiSplitViewController();

  // Left side: Goal tab | Right side: GoalPicker tab
  List<_GoalEntry> _goals = [];
  List<_GoalPickerEntry> _goalPickers = [];

  List<String> _goalFolders = [];
  List<String> _goalPickerFolders = [];

  late Directory _goalsDirectory;
  late Directory _goalPickersDirectory;

  late String _goalSortValue;
  late String _goalPickerSortValue;
  late bool _goalsCompact;
  late bool _goalPickersCompact;
  late int _goalGridCount;
  late int _goalPickerGridCount;

  String _goalSearchQuery = '';
  String _goalPickerSearchQuery = '';

  late TextEditingController _goalSearchController;
  late TextEditingController _goalPickerSearchController;

  bool _loading = true;

  String? _goalFolder;
  String? _goalPickerFolder;

  FileSystem get fs => widget.fs;

  @override
  void initState() {
    super.initState();
    ProjectPage._instance = this;

    _goalSearchController = TextEditingController();
    _goalPickerSearchController = TextEditingController();

    double leftWeight = widget.prefs.getDouble(PrefsKeys.projectLeftWeight) ??
        Defaults.projectLeftWeight;
    _controller.areas = [
      Area(weight: leftWeight, minimalWeight: 0.33),
      Area(weight: 1.0 - leftWeight, minimalWeight: 0.33),
    ];

    _goalSortValue = widget.prefs.getString(PrefsKeys.pathSortOption) ??
        Defaults.pathSortOption;
    _goalPickerSortValue = widget.prefs.getString(PrefsKeys.autoSortOption) ??
        Defaults.autoSortOption;
    _goalsCompact = widget.prefs.getBool(PrefsKeys.pathsCompactView) ??
        Defaults.pathsCompactView;
    _goalPickersCompact = widget.prefs.getBool(PrefsKeys.autosCompactView) ??
        Defaults.autosCompactView;

    _goalGridCount = _getCrossAxisCountForWeight(leftWeight);
    _goalPickerGridCount = _getCrossAxisCountForWeight(1.0 - leftWeight);

    _goalFolders = widget.prefs.getStringList(PrefsKeys.pathFolders) ??
        Defaults.pathFolders;
    _goalPickerFolders = widget.prefs.getStringList(PrefsKeys.autoFolders) ??
        Defaults.autoFolders;

    _load();
  }

  @override
  void dispose() {
    _goalSearchController.dispose();
    _goalPickerSearchController.dispose();
    if (ProjectPage._instance == this) ProjectPage._instance = null;
    super.dispose();
  }

  // ===========================================================================
  // DISK PERSISTENCE
  // ===========================================================================

  File _goalFile(String name) =>
      fs.file(join(_goalsDirectory.path, '$name.goal'));

  File _goalPickerFile(String name) =>
      fs.file(join(_goalPickersDirectory.path, '$name.goalpicker'));

  void _saveGoal(_GoalEntry entry) {
    entry.lastModified = DateTime.now();
    final file = _goalFile(entry.name);
    file.createSync(recursive: true);
    file.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(entry.toFileJson()),
    );
  }

  void _deleteGoalFile(String name) {
    final file = _goalFile(name);
    if (file.existsSync()) {
      file.deleteSync();
    }
  }

  void _saveGoalPicker(_GoalPickerEntry entry) {
    entry.lastModified = DateTime.now();
    final file = _goalPickerFile(entry.name);
    file.createSync(recursive: true);
    file.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(entry.toFileJson()),
    );
  }

  void _deleteGoalPickerFile(String name) {
    final file = _goalPickerFile(name);
    if (file.existsSync()) {
      file.deleteSync();
    }
  }

  Future<void> _load() async {
    _goalsDirectory =
        fs.directory(join(widget.pathplannerDirectory.path, 'goals'));
    _goalsDirectory.createSync(recursive: true);

    _goalPickersDirectory =
        fs.directory(join(widget.pathplannerDirectory.path, 'goalPickers'));
    _goalPickersDirectory.createSync(recursive: true);

    final List<_GoalEntry> loadedGoals = [];
    await for (final entity in _goalsDirectory.list()) {
      if (entity is File && entity.path.endsWith('.goal')) {
        try {
          final raw = await entity.readAsString();
          final jsonMap = jsonDecode(raw) as Map<String, dynamic>;
          final fallbackName = basenameWithoutExtension(entity.path);
          if ((jsonMap['name'] as String?)?.isNotEmpty != true) {
            jsonMap['name'] = fallbackName;
          }
          final entry = _GoalEntry.fromFileJson(
            jsonMap,
            entity.lastModifiedSync(),
          );
          if (!_goalFolders.contains(entry.folder)) {
            entry.folder = null;
          }
          loadedGoals.add(entry);
        } catch (_) {
          // Skip malformed goal files
        }
      }
    }

    final List<_GoalPickerEntry> loadedGoalPickers = [];
    await for (final entity in _goalPickersDirectory.list()) {
      if (entity is File && entity.path.endsWith('.goalpicker')) {
        try {
          final raw = await entity.readAsString();
          final jsonMap = jsonDecode(raw) as Map<String, dynamic>;
          final entry = _GoalPickerEntry.fromFileJson(
            jsonMap,
            basenameWithoutExtension(entity.path),
            entity.lastModifiedSync(),
          );
          if (!_goalPickerFolders.contains(entry.folder)) {
            entry.folder = null;
          }
          loadedGoalPickers.add(entry);
        } catch (_) {
          // Skip malformed goalPicker files
        }
      }
    }

    if (!mounted) return;

    setState(() {
      _goals = loadedGoals;
      _goalPickers = loadedGoalPickers;
      _goalFolder = null;
      _goalPickerFolder = null;

      if (_goals.isEmpty) {
        final defaultGoal = _GoalEntry(
          goal: Goal(
            name: 'Example Goal',
            waypoints: [
              Waypoint(anchor: const Translation2d(4.0, 6.0)),
            ],
          ),
        );
        _goals.add(defaultGoal);
        _saveGoal(defaultGoal);
      }

      if (_goalPickers.isEmpty) {
        final defaultPicker = _GoalPickerEntry(
          name: 'Example GoalPicker',
          picker: GoalPicker(
            startPose: const Pose2d(Translation2d(2.0, 7.0), Rotation2d()),
            goals: [
              _goals.first.goal.clone(),
            ],
          ),
        );
        _goalPickers.add(defaultPicker);
        _saveGoalPicker(defaultPicker);
      }

      _sortItems();
      _loading = false;
    });
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (ProjectPage.settingsUpdated) {
      ProjectPage.settingsUpdated = false;
    }

    return Stack(
      children: [
        Container(
          color: colorScheme.surfaceTint.withAlpha(15),
          child: MultiSplitViewTheme(
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
                setState(() {
                  _goalGridCount =
                      _getCrossAxisCountForWeight(_controller.areas[0].weight!);
                  _goalPickerGridCount = _getCrossAxisCountForWeight(
                      1.0 - _controller.areas[0].weight!);
                });
                widget.prefs.setDouble(PrefsKeys.projectLeftWeight,
                    _controller.areas[0].weight ?? Defaults.projectLeftWeight);
              },
              children: [
                _buildGoalsGrid(context),
                _buildGoalPickersGrid(context),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: FloatingActionButton(
              clipBehavior: Clip.antiAlias,
              tooltip: 'Manage Strats, ControllerSettings, Commands, Triggers, and Linked Waypoints',
              backgroundColor: colorScheme.surface,
              foregroundColor: colorScheme.onSurface,
              onPressed: () => showDialog(
                context: context,
              builder: (BuildContext context) => ManagementDialog(
                projectDir: widget.pathplannerDirectory.path,
                onLinkedRenamed: (String oldName, String newName) {
                  setState(() {
                    Pose2d? pose = Waypoint.linked.remove(oldName);
                    if (pose != null) {
                      Waypoint.linked[newName] = pose;
                      _syncLinkedWaypoints();
                    }
                  });
                },
                onLinkedDeleted: (String name) {
                  setState(() {
                    Waypoint.linked.remove(name);
                    for (final entry in _goals) {
                      bool changed = false;
                      for (final w in entry.goal.waypoints) {
                        if (w.linkedName == name) {
                          w.linkedName = null;
                          changed = true;
                        }
                      }
                      if (changed) _saveGoal(entry);
                    }
                    for (final gpEntry in _goalPickers) {
                      bool changed = false;
                      for (final g in gpEntry.picker.goals) {
                        for (final w in g.waypoints) {
                          if (w.linkedName == name) {
                            w.linkedName = null;
                            changed = true;
                          }
                        }
                      }
                      if (changed) _saveGoalPicker(gpEntry);
                    }
                  });
                },
                onControllerSettingDeleted: (String name) {
                  setState(() {
                    for (final entry in _goals) {
                      bool changed = false;
                      for (final w in entry.goal.waypoints) {
                        if (w.controllerSettingName == name) {
                          w.controllerSettingName = null;
                          changed = true;
                        }
                      }
                      if (changed) _saveGoal(entry);
                    }
                    for (final gpEntry in _goalPickers) {
                      bool changed = false;
                      for (final g in gpEntry.picker.goals) {
                        for (final w in g.waypoints) {
                          if (w.controllerSettingName == name) {
                            w.controllerSettingName = null;
                            changed = true;
                          }
                        }
                      }
                      if (changed) _saveGoalPicker(gpEntry);
                    }
                  });
                },
                onHeadingStratDeleted: (String name) {
                  setState(() {
                    for (final entry in _goals) {
                      bool changed = false;
                      for (final w in entry.goal.waypoints) {
                        if (w.headingStratName == name) {
                          w.headingStratName = null;
                          changed = true;
                        }
                      }
                      if (changed) _saveGoal(entry);
                    }
                    for (final gpEntry in _goalPickers) {
                      bool changed = false;
                      for (final g in gpEntry.picker.goals) {
                        for (final w in g.waypoints) {
                          if (w.headingStratName == name) {
                            w.headingStratName = null;
                            changed = true;
                          }
                        }
                      }
                      if (changed) _saveGoalPicker(gpEntry);
                    }
                  });
                },
              ),
              ),
              child: Stack(
                children: [
                  Container(color: colorScheme.surfaceTint.withAlpha(30)),
                  const Center(child: Icon(Icons.edit_note_rounded)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _syncLinkedWaypoints() {
    for (final entry in _goals) {
      bool changed = false;
      for (final w in entry.goal.waypoints) {
        if (w.linkedName != null && Waypoint.linked.containsKey(w.linkedName!)) {
          final link = Waypoint.linked[w.linkedName!]!;
          if (link.translation.getDistance(w.anchor) >= 0.01) {
            w.move(link.translation.x, link.translation.y);
            changed = true;
          }
        }
      }
      if (changed) _saveGoal(entry);
    }

    for (final gpEntry in _goalPickers) {
      bool changed = false;
      for (final g in gpEntry.picker.goals) {
        for (final w in g.waypoints) {
          if (w.linkedName != null &&
              Waypoint.linked.containsKey(w.linkedName!)) {
            final link = Waypoint.linked[w.linkedName!]!;
            if (link.translation.getDistance(w.anchor) >= 0.01) {
              w.move(link.translation.x, link.translation.y);
              changed = true;
            }
          }
        }
      }
      if (changed) _saveGoalPicker(gpEntry);
    }
  }

  // ===========================================================================
  // LEFT PANE: GOAL TAB
  // ===========================================================================

  Widget _buildGoalsGrid(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(left: 8.0, top: 8.0),
      child: Card(
        elevation: 0.0,
        margin: const EdgeInsets.all(0),
        color: colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              const SizedBox(height: 8),
              _buildOptionsRow(
                searchHint: 'Search for Goals...',
                addTooltip: 'Add new goal',
                sortValue: _goalSortValue,
                viewValue: _goalsCompact,
                onSortChanged: (value) {
                  widget.prefs.setString(PrefsKeys.pathSortOption, value);
                  setState(() {
                    _goalSortValue = value;
                    _sortItems();
                  });
                },
                onViewChanged: (value) {
                  widget.prefs.setBool(PrefsKeys.pathsCompactView, value);
                  setState(() {
                    _goalsCompact = value;
                  });
                },
                onSearchChanged: (value) {
                  setState(() {
                    _goalSearchQuery = value;
                  });
                },
                searchController: _goalSearchController,
                onAddFolder: () {
                  String folderName = 'New Folder';
                  while (_goalFolders.contains(folderName)) {
                    folderName = 'New $folderName';
                  }
                  setState(() {
                    _goalFolders.add(folderName);
                    _sortItems();
                  });
                  widget.prefs
                      .setStringList(PrefsKeys.pathFolders, _goalFolders);
                  widget.onFoldersChanged?.call();
                },
                onAddItem: _createNewGoal,
                isLeftTab: true,
              ),
              Expanded(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    _buildFolderHeader<_GoalEntry>(
                      currentFolder: _goalFolder,
                      folders: _goalFolders,
                      gridCount: _goalGridCount,
                      onSelectRoot: () => setState(() => _goalFolder = null),
                      onSelectFolder: (folder) =>
                          setState(() => _goalFolder = folder),
                      onMoveItemToFolder: (entry, targetFolder) {
                        setState(() {
                          entry.folder = targetFolder;
                          _saveGoal(entry);
                        });
                      },
                      onRenameFolder: (index, newName) {
                        if (newName == _goalFolders[index]) return;
                        if (_goalFolders.contains(newName)) {
                          _showDuplicateFolderDialog(context, newName);
                          return;
                        }
                        setState(() {
                          for (final entry in _goals) {
                            if (entry.folder == _goalFolders[index]) {
                              entry.folder = newName;
                              _saveGoal(entry);
                            }
                          }
                          _goalFolders[index] = newName;
                        });
                        widget.prefs
                            .setStringList(PrefsKeys.pathFolders, _goalFolders);
                        widget.onFoldersChanged?.call();
                      },
                    ),
                    if (_goalFolders.isNotEmpty) const SizedBox(height: 8),
                    GridView.count(
                      crossAxisCount:
                          _goalsCompact ? _goalGridCount + 1 : _goalGridCount,
                      childAspectRatio: _goalsCompact ? 2.5 : 1.55,
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      children: [
                        for (int i = 0; i < _goals.length; i++)
                          if (_goals[i].folder == _goalFolder &&
                              _goals[i]
                                  .name
                                  .toLowerCase()
                                  .contains(_goalSearchQuery.toLowerCase()))
                            _buildGoalCard(i, context),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoalCard(int i, BuildContext context) {
    final entry = _goals[i];

    final card = ProjectItemCard(
      name: entry.name,
      compact: _goalsCompact,
      fieldImage: widget.fieldImage,
      paths: [
        entry.goal.waypoints.map((w) => w.anchor).toList(),
      ],
      onDuplicated: () {
        final existingNames = _goals.map((e) => e.name).toSet();
        String newName = 'Copy of ${entry.name}';
        while (existingNames.contains(newName)) {
          newName = 'Copy of $newName';
        }

        final clonedGoal = entry.goal.clone()..name = newName;
        final duplicated = _GoalEntry(
          goal: clonedGoal,
          folder: entry.folder,
        );

        setState(() {
          _goals.add(duplicated);
          _saveGoal(duplicated);
          _sortItems();
        });
      },
      onDeleted: () {
        _deleteGoalFile(entry.name);
        setState(() {
          _goals.removeAt(i);
        });
      },
      onRenamed: (value) => _renameGoal(entry, value, context),
      onOpened: () => _openGoal(entry),
    );

    return LayoutBuilder(builder: (context, constraints) {
      return Draggable<_GoalEntry>(
        data: entry,
        feedback: SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: Opacity(opacity: 0.8, child: card),
        ),
        childWhenDragging: Container(),
        child: card,
      );
    });
  }

  void _createNewGoal() {
    final existingNames = _goals.map((e) => e.name).toSet();
    String name = 'New Goal';
    while (existingNames.contains(name)) {
      name = 'New $name';
    }

    final entry = _GoalEntry(
      goal: Goal(
        name: name,
        waypoints: [
          Waypoint(anchor: const Translation2d(4.0, 6.0)),
        ],
      ),
      folder: _goalFolder,
    );

    setState(() {
      _goals.add(entry);
      _saveGoal(entry);
      _sortItems();
    });
  }

  void _renameGoal(_GoalEntry entry, String newName, BuildContext context) {
    final existingNames = _goals.map((e) => e.name).toSet();
    if (existingNames.contains(newName)) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          ColorScheme colorScheme = Theme.of(context).colorScheme;
          return AlertDialog(
            backgroundColor: colorScheme.surface,
            surfaceTintColor: colorScheme.surfaceTint,
            title: const Text('Unable to Rename'),
            content: Text('The file "$newName.goal" already exists'),
            actions: [
              TextButton(
                onPressed: Navigator.of(context).pop,
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } else {
      final oldName = entry.name;
      setState(() {
        _deleteGoalFile(oldName);
        entry.name = newName;
        _saveGoal(entry);
        _sortItems();
      });
    }
  }

void _openGoal(_GoalEntry entry) async {
    await Navigator.push(
      this.context,
      MaterialPageRoute(
        builder: (context) => GoalEditorPage(
          prefs: widget.prefs,
          goal: entry.goal,
          fieldImage: widget.fieldImage,
          undoStack: widget.undoStack,
          shortcuts: widget.shortcuts,
          onRenamed: (value) => _renameGoal(entry, value, context),
          onGoalChanged: () {
            _saveGoal(entry);
          },
        ),
      ),
    );

    setState(() {
      _sortItems();
    });
  }

  /// Adds a newly created Goal from a GoalPicker into the project's Goals tab.
  /// Updates `goal.name` if a collision requires deduplicating the name.
  void _promoteGoalToProject(Goal goal) {
    final existingNames = _goals.map((e) => e.name).toSet();
    String targetName =
        goal.name.trim().isEmpty ? 'New Goal' : goal.name.trim();

    if (existingNames.contains(targetName)) {
      int suffix = 2;
      while (existingNames.contains('$targetName ($suffix)')) {
        suffix++;
      }
      targetName = '$targetName ($suffix)';
    }

    goal.name = targetName;

    final newEntry = _GoalEntry(
      goal: goal.clone(),
      folder: _goalFolder,
    );

    setState(() {
      _goals.add(newEntry);
      _saveGoal(newEntry);
      _sortItems();
    });
  }

  // ===========================================================================
  // RIGHT PANE: GOALPICKER TAB
  // ===========================================================================

  Widget _buildGoalPickersGrid(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(right: 8.0, top: 8.0),
      child: Card(
        elevation: 0.0,
        margin: const EdgeInsets.all(0),
        color: colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              const SizedBox(height: 8),
              _buildOptionsRow(
                searchHint: 'Search for GoalPickers...',
                addTooltip: 'Add new GoalPicker',
                sortValue: _goalPickerSortValue,
                viewValue: _goalPickersCompact,
                onSortChanged: (value) {
                  widget.prefs.setString(PrefsKeys.autoSortOption, value);
                  setState(() {
                    _goalPickerSortValue = value;
                    _sortItems();
                  });
                },
                onViewChanged: (value) {
                  widget.prefs.setBool(PrefsKeys.autosCompactView, value);
                  setState(() {
                    _goalPickersCompact = value;
                  });
                },
                onSearchChanged: (value) {
                  setState(() {
                    _goalPickerSearchQuery = value;
                  });
                },
                searchController: _goalPickerSearchController,
                onAddFolder: () {
                  String folderName = 'New Folder';
                  while (_goalPickerFolders.contains(folderName)) {
                    folderName = 'New $folderName';
                  }
                  setState(() {
                    _goalPickerFolders.add(folderName);
                    _sortItems();
                  });
                  widget.prefs
                      .setStringList(PrefsKeys.autoFolders, _goalPickerFolders);
                  widget.onFoldersChanged?.call();
                },
                onAddItem: _createNewGoalPicker,
                isLeftTab: false,
              ),
              Expanded(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    _buildFolderHeader<_GoalPickerEntry>(
                      currentFolder: _goalPickerFolder,
                      folders: _goalPickerFolders,
                      gridCount: _goalPickerGridCount,
                      onSelectRoot: () =>
                          setState(() => _goalPickerFolder = null),
                      onSelectFolder: (folder) =>
                          setState(() => _goalPickerFolder = folder),
                      onMoveItemToFolder: (entry, targetFolder) {
                        setState(() {
                          entry.folder = targetFolder;
                          _saveGoalPicker(entry);
                        });
                      },
                      onRenameFolder: (index, newName) {
                        if (newName == _goalPickerFolders[index]) return;
                        if (_goalPickerFolders.contains(newName)) {
                          _showDuplicateFolderDialog(context, newName);
                          return;
                        }
                        setState(() {
                          for (final entry in _goalPickers) {
                            if (entry.folder == _goalPickerFolders[index]) {
                              entry.folder = newName;
                              _saveGoalPicker(entry);
                            }
                          }
                          _goalPickerFolders[index] = newName;
                        });
                        widget.prefs.setStringList(
                            PrefsKeys.autoFolders, _goalPickerFolders);
                        widget.onFoldersChanged?.call();
                      },
                    ),
                    if (_goalPickerFolders.isNotEmpty)
                      const SizedBox(height: 8),
                    GridView.count(
                      crossAxisCount: _goalPickersCompact
                          ? _goalPickerGridCount + 1
                          : _goalPickerGridCount,
                      childAspectRatio: _goalPickersCompact ? 2.5 : 1.55,
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      children: [
                        for (int i = 0; i < _goalPickers.length; i++)
                          if (_goalPickers[i].folder == _goalPickerFolder &&
                              _goalPickers[i]
                                  .name
                                  .toLowerCase()
                                  .contains(_goalPickerSearchQuery.toLowerCase()))
                            _buildGoalPickerCard(i, context),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoalPickerCard(int i, BuildContext context) {
    final entry = _goalPickers[i];

    // Preview startPose + each goal's waypoints on the field thumbnail
    final previewPaths = <List<Translation2d>>[
      for (final goal in entry.picker.goals)
        [
          entry.picker.startPose.translation,
          ...goal.waypoints.map((w) => w.anchor),
        ],
    ];

    final card = ProjectItemCard(
      name: entry.name,
      compact: _goalPickersCompact,
      fieldImage: widget.fieldImage,
      paths: previewPaths,
      onDuplicated: () {
        final existingNames = _goalPickers.map((e) => e.name).toSet();
        String newName = 'Copy of ${entry.name}';
        while (existingNames.contains(newName)) {
          newName = 'Copy of $newName';
        }

        final duplicated = _GoalPickerEntry(
          name: newName,
          folder: entry.folder,
          picker: GoalPicker(
            startPose: entry.picker.startPose,
            goals: [
              for (final g in entry.picker.goals) g.clone(),
            ],
          ),
        );

        setState(() {
          _goalPickers.add(duplicated);
          _saveGoalPicker(duplicated);
          _sortItems();
        });
      },
      onDeleted: () {
        _deleteGoalPickerFile(entry.name);
        setState(() {
          _goalPickers.removeAt(i);
        });
      },
      onRenamed: (value) => _renameGoalPicker(entry, value, context),
      onOpened: () => _openGoalPicker(entry),
    );

    return LayoutBuilder(builder: (context, constraints) {
      return Draggable<_GoalPickerEntry>(
        data: entry,
        feedback: SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: Opacity(opacity: 0.8, child: card),
        ),
        childWhenDragging: Container(),
        child: card,
      );
    });
  }

  void _createNewGoalPicker() {
    final existingNames = _goalPickers.map((e) => e.name).toSet();
    String name = 'New GoalPicker';
    while (existingNames.contains(name)) {
      name = 'New $name';
    }

    final entry = _GoalPickerEntry(
      name: name,
      folder: _goalPickerFolder,
      picker: GoalPicker(
        startPose: const Pose2d(Translation2d(2.0, 7.0), Rotation2d()),
        goals: [
          Goal(
            name: 'Goal 1',
            waypoints: [
              Waypoint(anchor: const Translation2d(4.0, 6.0)),
            ],
          ),
        ],
      ),
    );

    setState(() {
      _goalPickers.add(entry);
      _saveGoalPicker(entry);
      _sortItems();
    });
  }

  void _renameGoalPicker(
      _GoalPickerEntry entry, String newName, BuildContext context) {
    final existingNames = _goalPickers.map((e) => e.name).toSet();

    if (existingNames.contains(newName)) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          ColorScheme colorScheme = Theme.of(context).colorScheme;
          return AlertDialog(
            backgroundColor: colorScheme.surface,
            surfaceTintColor: colorScheme.surfaceTint,
            title: const Text('Unable to Rename'),
            content: Text('The file "$newName.goalpicker" already exists'),
            actions: [
              TextButton(
                onPressed: Navigator.of(context).pop,
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } else {
      final oldName = entry.name;
      setState(() {
        _deleteGoalPickerFile(oldName);
        entry.name = newName;
        _saveGoalPicker(entry);
        _sortItems();
      });
    }
  }

  void _openGoalPicker(_GoalPickerEntry entry) async {
    await Navigator.push(
      this.context,
      MaterialPageRoute(
        builder: (context) => GoalPickerEditorPage(
          prefs: widget.prefs,
          name: entry.name,
          goalPicker: entry.picker,
          allGoals: _goals.map((e) => e.goal).toList(),
          fieldImage: widget.fieldImage,
          undoStack: widget.undoStack,
          shortcuts: widget.shortcuts,
          onRenamed: (value) => _renameGoalPicker(entry, value, context),
          onPromoteGoalToProject: _promoteGoalToProject,
          onGoalPickerChanged: () {
            _saveGoalPicker(entry);

            // Keep matching standalone project goals in sync if edited in the picker
            for (final pickerGoal in entry.picker.goals) {
              final idx = _goals.indexWhere((e) => e.name == pickerGoal.name);
              if (idx != -1) {
                _goals[idx].goal = pickerGoal.clone();
                _saveGoal(_goals[idx]);
              }
            }
          },
        ),
      ),
    );

    setState(() {
      _sortItems();
    });
  }

  // ===========================================================================
  // SHARED UI HELPERS
  // ===========================================================================

  Widget _buildFolderHeader<T extends Object>({
    required String? currentFolder,
    required List<String> folders,
    required int gridCount,
    required VoidCallback onSelectRoot,
    required ValueChanged<String> onSelectFolder,
    required void Function(T item, String? targetFolder) onMoveItemToFolder,
    required void Function(int index, String newName) onRenameFolder,
  }) {
    return ConditionalWidget(
      condition: currentFolder == null,
      falseChild: GridView.count(
        crossAxisCount: gridCount,
        childAspectRatio: 5.5,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          DragTarget<T>(
            onAcceptWithDetails: (details) =>
                onMoveItemToFolder(details.data, null),
            builder: (context, candidates, rejects) {
              ColorScheme colorScheme = Theme.of(context).colorScheme;
              return Card(
                elevation: 2,
                color: candidates.isNotEmpty
                    ? colorScheme.primary
                    : colorScheme.surface,
                surfaceTintColor: colorScheme.surfaceTint,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onSelectRoot,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.drive_file_move_rtl_outlined,
                          color: candidates.isNotEmpty
                              ? colorScheme.onPrimary
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Root Folder',
                              style: TextStyle(
                                fontSize: 20,
                                color: candidates.isNotEmpty
                                    ? colorScheme.onPrimary
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      trueChild: GridView.count(
        crossAxisCount: gridCount,
        childAspectRatio: 5.5,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (int i = 0; i < folders.length; i++)
            DragTarget<T>(
              onAcceptWithDetails: (details) =>
                  onMoveItemToFolder(details.data, folders[i]),
              builder: (context, candidates, rejects) {
                ColorScheme colorScheme = Theme.of(context).colorScheme;
                return Card(
                  elevation: 2,
                  color: candidates.isNotEmpty
                      ? colorScheme.primary
                      : colorScheme.surface,
                  surfaceTintColor: colorScheme.surfaceTint,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => onSelectFolder(folders[i]),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Row(
                        children: [
                          Icon(
                            Icons.folder_outlined,
                            color: candidates.isNotEmpty
                                ? colorScheme.onPrimary
                                : null,
                          ),
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: RenamableTitle(
                                title: folders[i],
                                textStyle: TextStyle(
                                  fontSize: 20,
                                  color: candidates.isNotEmpty
                                      ? colorScheme.onPrimary
                                      : null,
                                ),
                                onRename: (newName) =>
                                    onRenameFolder(i, newName),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  void _showDuplicateFolderDialog(BuildContext context, String newName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        ColorScheme colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          backgroundColor: colorScheme.surface,
          surfaceTintColor: colorScheme.surfaceTint,
          title: const Text('Unable to Rename'),
          content: Text('The folder "$newName" already exists'),
          actions: [
            TextButton(
              onPressed: Navigator.of(context).pop,
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOptionsRow({
    required String searchHint,
    required String addTooltip,
    required String sortValue,
    required bool viewValue,
    required ValueChanged<String> onSortChanged,
    required ValueChanged<bool> onViewChanged,
    required ValueChanged<String> onSearchChanged,
    required TextEditingController searchController,
    required VoidCallback onAddFolder,
    required VoidCallback onAddItem,
    required bool isLeftTab,
  }) {
    final bool isRootFolder =
        isLeftTab ? _goalFolder == null : _goalPickerFolder == null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.0),
      child: Column(
        children: [
          Row(
            children: [
              PopupMenuButton<bool>(
                initialValue: viewValue,
                tooltip: 'View options',
                icon: Icon(viewValue
                    ? Icons.view_list_rounded
                    : Icons.grid_view_rounded),
                itemBuilder: (context) => const [
                  PopupMenuItem(value: false, child: Text('Default')),
                  PopupMenuItem(value: true, child: Text('Compact')),
                ],
                onSelected: onViewChanged,
              ),
              PopupMenuButton<String>(
                initialValue: sortValue,
                tooltip: 'Sort options',
                icon: const Icon(Icons.sort_rounded),
                itemBuilder: (context) => _sortOptions(),
                onSelected: onSortChanged,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: searchHint,
                    prefixIcon: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: Icon(Icons.search_rounded),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  ),
                  onChanged: (value) {
                    Future.delayed(const Duration(milliseconds: 300), () {
                      if (value == searchController.text) {
                        onSearchChanged(value);
                      }
                    });
                  },
                ),
              ),
              const SizedBox(width: 14),
              IconButton.filledTonal(
                icon: Icon(isRootFolder
                    ? Icons.create_new_folder_outlined
                    : Icons.delete_forever_rounded),
                tooltip: isRootFolder
                    ? 'Add new folder'
                    : isLeftTab
                        ? 'Delete goal folder'
                        : 'Delete GoalPicker folder',
                onPressed: () {
                  if (isRootFolder) {
                    onAddFolder();
                  } else {
                    _confirmDeleteFolder(isLeftTab: isLeftTab);
                  }
                },
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: addTooltip,
                icon: const Icon(Icons.add_rounded),
                onPressed: onAddItem,
              ),
              const SizedBox(width: 8),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  void _confirmDeleteFolder({required bool isLeftTab}) {
    final targetFolder = isLeftTab ? _goalFolder : _goalPickerFolder;
    showDialog(
      context: this.context,
      builder: (context) {
        ColorScheme colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          backgroundColor: colorScheme.surface,
          surfaceTintColor: colorScheme.surfaceTint,
          title: const Text('Delete Folder'),
          content: SizedBox(
            width: 400,
            child: Text(
              'Are you sure you want to delete the folder "$targetFolder"?\n\nThis will also delete all ${isLeftTab ? "goals" : "GoalPickers"} within the folder. This cannot be undone.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: Navigator.of(context).pop,
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (isLeftTab) {
                  for (final entry in _goals) {
                    if (entry.folder == _goalFolder) {
                      _deleteGoalFile(entry.name);
                    }
                  }
                  setState(() {
                    _goals.removeWhere((e) => e.folder == _goalFolder);
                    _goalFolders.remove(_goalFolder);
                    _goalFolder = null;
                  });
                  widget.prefs
                      .setStringList(PrefsKeys.pathFolders, _goalFolders);
                } else {
                  for (final entry in _goalPickers) {
                    if (entry.folder == _goalPickerFolder) {
                      _deleteGoalPickerFile(entry.name);
                    }
                  }
                  setState(() {
                    _goalPickers
                        .removeWhere((e) => e.folder == _goalPickerFolder);
                    _goalPickerFolders.remove(_goalPickerFolder);
                    _goalPickerFolder = null;
                  });
                  widget.prefs
                      .setStringList(PrefsKeys.autoFolders, _goalPickerFolders);
                }
                widget.onFoldersChanged?.call();
              },
              child: const Text('DELETE'),
            ),
          ],
        );
      },
    );
  }

  int _getCrossAxisCountForWeight(double weight) {
    if (weight < 0.4) return 1;
    if (weight < 0.6) return 2;
    return 3;
  }

  void _sortItems() {
    switch (_goalSortValue) {
      case 'recent':
        _goals.sort((a, b) => b.lastModified.compareTo(a.lastModified));
        _goalFolders.sort((a, b) => a.compareTo(b));
        break;
      case 'nameDesc':
        _goals.sort((a, b) => b.name.compareTo(a.name));
        _goalFolders.sort((a, b) => b.compareTo(a));
        break;
      case 'nameAsc':
        _goals.sort((a, b) => a.name.compareTo(b.name));
        _goalFolders.sort((a, b) => a.compareTo(b));
        break;
    }

    switch (_goalPickerSortValue) {
      case 'recent':
        _goalPickers.sort((a, b) => b.lastModified.compareTo(a.lastModified));
        _goalPickerFolders.sort((a, b) => a.compareTo(b));
        break;
      case 'nameDesc':
        _goalPickers.sort((a, b) => b.name.compareTo(a.name));
        _goalPickerFolders.sort((a, b) => b.compareTo(a));
        break;
      case 'nameAsc':
        _goalPickers.sort((a, b) => a.name.compareTo(b.name));
        _goalPickerFolders.sort((a, b) => a.compareTo(b));
        break;
    }
  }

  List<PopupMenuItem<String>> _sortOptions() {
    return const [
      PopupMenuItem(value: 'recent', child: Text('Recent')),
      PopupMenuItem(value: 'nameAsc', child: Text('Name Ascending')),
      PopupMenuItem(value: 'nameDesc', child: Text('Name Descending')),
    ];
  }
}