import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:pathplanner/path/waypoint.dart';

class ManagementDialog extends StatefulWidget {
  final String? projectDir;
  final Function(String, String) onLinkedRenamed;
  final Function(String) onLinkedDeleted;
  final Function(String, String)? onControllerSettingRenamed;
  final Function(String)? onControllerSettingDeleted;
  final Function(String, String)? onHeadingStratRenamed;
  final Function(String)? onHeadingStratDeleted;
  final Function(String, String)? onCommandRenamed;
  final Function(String)? onCommandDeleted;
  final Function(String, String)? onTriggerRenamed;
  final Function(String)? onTriggerDeleted;
  final VoidCallback? onSettingsChanged;

  const ManagementDialog({
    super.key,
    this.projectDir,
    required this.onLinkedRenamed,
    required this.onLinkedDeleted,
    this.onControllerSettingRenamed,
    this.onControllerSettingDeleted,
    this.onHeadingStratRenamed,
    this.onHeadingStratDeleted,
    this.onCommandRenamed,
    this.onCommandDeleted,
    this.onTriggerRenamed,
    this.onTriggerDeleted,
    this.onSettingsChanged,
  });

  @override
  State<ManagementDialog> createState() => _ManagementDialogState();
}

class _ManagementDialogState extends State<ManagementDialog> {
  static final Map<String, List<String>> _fallbackLists = {
    'controllerSettings': [],
    'headingStrats': [],
    'commands': [],
    'triggers': [],
  };

  Map<String, dynamic> _settingsJson = {};
  final Map<String, List<String>> _entries = {
    'controllerSettings': [],
    'headingStrats': [],
    'commands': [],
    'triggers': [],
  };

  File? get _settingsFile {
    final dir = widget.projectDir;
    if (dir == null || dir.isEmpty) return null;
    return File(p.join(dir, 'settings.json'));
  }

  @override
  void initState() {
    super.initState();
    _loadFromSettingsJson();
  }

  void _loadFromSettingsJson() {
    final file = _settingsFile;
    if (file != null && file.existsSync()) {
      try {
        final raw = file.readAsStringSync().trim();
        final decoded = raw.isEmpty ? {} : jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          _settingsJson = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        _settingsJson = {};
      }
    }

    for (final key in _entries.keys) {
      final rawList = _settingsJson[key];
      if (rawList is List) {
        final parsed = <String>[];
        for (final item in rawList) {
          if (item is String && item.trim().isNotEmpty) {
            parsed.add(item.trim());
          } else if (item is Map && item['name'] is String) {
            final name = (item['name'] as String).trim();
            if (name.isNotEmpty) parsed.add(name);
          }
        }
        _entries[key] = parsed;
        _fallbackLists[key] = List<String>.from(parsed);
      } else {
        _entries[key] = List<String>.from(_fallbackLists[key] ?? const []);
      }
    }
  }

  void _saveToSettingsJson() {
    for (final key in _entries.keys) {
      final existing = _settingsJson[key];
      if (existing is List && existing.isNotEmpty && existing.first is Map) {
        final existingByName = <String, Map<String, dynamic>>{};
        for (final item in existing) {
          if (item is Map && item['name'] is String) {
            existingByName[item['name'] as String] =
                Map<String, dynamic>.from(item);
          }
        }
        _settingsJson[key] = [
          for (final name in _entries[key]!)
            existingByName[name] ?? {'name': name},
        ];
      } else {
        _settingsJson[key] = List<String>.from(_entries[key]!);
      }
      _fallbackLists[key] = List<String>.from(_entries[key]!);
    }

    final file = _settingsFile;
    if (file != null) {
      file.parent.createSync(recursive: true);
      const encoder = JsonEncoder.withIndent('  ');
      file.writeAsStringSync(encoder.convert(_settingsJson));
    }

    widget.onSettingsChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 760,
        height: 460,
        child: Column(
          children: [
            Expanded(
              child: DefaultTabController(
                length: 5,
                child: Scaffold(
                  backgroundColor: Colors.transparent,
                  appBar: AppBar(
                    automaticallyImplyLeading: false,
                    backgroundColor: Colors.transparent,
                    title: const TabBar(
                      isScrollable: true,
                      tabs: [
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.link),
                              SizedBox(width: 6),
                              Text('Linked Waypoints'),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.tune_rounded),
                              SizedBox(width: 6),
                              Text('Controller Settings'),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.explore_rounded),
                              SizedBox(width: 6),
                              Text('Heading Strats'),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.terminal_rounded),
                              SizedBox(width: 6),
                              Text('Commands'),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bolt_rounded),
                              SizedBox(width: 6),
                              Text('Triggers'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  body: TabBarView(
                    children: [
                      _buildLinkedTab(),
                      _buildNamedListTab(
                        keyName: 'controllerSettings',
                        singularLabel: 'Controller Setting',
                        emptyText: 'No Controller Settings in settings.json',
                        onRenamed: widget.onControllerSettingRenamed,
                        onDeleted: widget.onControllerSettingDeleted,
                      ),
                      _buildNamedListTab(
                        keyName: 'headingStrats',
                        singularLabel: 'Heading Strat',
                        emptyText: 'No Heading Strats in settings.json',
                        onRenamed: widget.onHeadingStratRenamed,
                        onDeleted: widget.onHeadingStratDeleted,
                      ),
                      _buildNamedListTab(
                        keyName: 'commands',
                        singularLabel: 'Command',
                        emptyText: 'No Commands in settings.json',
                        onRenamed: widget.onCommandRenamed,
                        onDeleted: widget.onCommandDeleted,
                      ),
                      _buildNamedListTab(
                        keyName: 'triggers',
                        singularLabel: 'Trigger',
                        emptyText: 'No Triggers in settings.json',
                        onRenamed: widget.onTriggerRenamed,
                        onDeleted: widget.onTriggerDeleted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 8.0,
                horizontal: 12.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: Navigator.of(context).pop,
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNamedListTab({
    required String keyName,
    required String singularLabel,
    required String emptyText,
    Function(String, String)? onRenamed,
    Function(String)? onDeleted,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final items = _entries[keyName] ?? const <String>[];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Text(
                '$singularLabel${items.length == 1 ? '' : 's'} (${items.length})',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const Spacer(),
              FilledButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: Text('Add $singularLabel'),
                onPressed: () => _showAddEntryDialog(
                  keyName: keyName,
                  singularLabel: singularLabel,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 12),
        Expanded(
          child: items.isEmpty
              ? Center(child: Text(emptyText))
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final entryName = items[index];
                      return ListTile(
                        title: Text(entryName),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Tooltip(
                              message: 'Rename $singularLabel',
                              waitDuration: const Duration(milliseconds: 500),
                              child: IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _showRenameEntryDialog(
                                  keyName: keyName,
                                  singularLabel: singularLabel,
                                  originalName: entryName,
                                  onRenamed: onRenamed,
                                ),
                              ),
                            ),
                            Tooltip(
                              message: 'Remove $singularLabel',
                              waitDuration: const Duration(milliseconds: 500),
                              child: IconButton(
                                icon: Icon(
                                  Icons.delete_forever_rounded,
                                  color: colorScheme.error,
                                ),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        backgroundColor: colorScheme.surface,
                                        surfaceTintColor:
                                            colorScheme.surfaceTint,
                                        title: Text('Remove $singularLabel'),
                                        content: Text(
                                          'Are you sure you want to remove "$entryName"? This cannot be undone.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: Navigator.of(context).pop,
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              setState(() {
                                                _entries[keyName]
                                                    ?.remove(entryName);
                                                _saveToSettingsJson();
                                                onDeleted?.call(entryName);
                                              });
                                              Navigator.of(context).pop();
                                            },
                                            child: const Text('Confirm'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  void _showAddEntryDialog({
    required String keyName,
    required String singularLabel,
  }) {
    final controller = TextEditingController();
    final items = _entries[keyName]!;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        final colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          backgroundColor: colorScheme.surface,
          surfaceTintColor: colorScheme.surfaceTint,
          title: Text('Add $singularLabel'),
          content: SizedBox(
            height: 42,
            width: 400,
            child: TextField(
              controller: controller,
              autofocus: true,
              style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                labelText: '$singularLabel Name',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onSubmitted: (_) => _submitNewEntry(
                context: context,
                keyName: keyName,
                singularLabel: singularLabel,
                name: controller.text.trim(),
                items: items,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: Navigator.of(context).pop,
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => _submitNewEntry(
                context: context,
                keyName: keyName,
                singularLabel: singularLabel,
                name: controller.text.trim(),
                items: items,
              ),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _submitNewEntry({
    required BuildContext context,
    required String keyName,
    required String singularLabel,
    required String name,
    required List<String> items,
  }) {
    if (name.isEmpty) return;
    if (items.contains(name)) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('A $singularLabel with that name already exists'),
        ),
      );
      return;
    }

    Navigator.of(context).pop();
    setState(() {
      items.add(name);
      _saveToSettingsJson();
    });
  }

  void _showRenameEntryDialog({
    required String keyName,
    required String singularLabel,
    required String originalName,
    Function(String, String)? onRenamed,
  }) {
    final controller = TextEditingController(text: originalName);
    final items = _entries[keyName]!;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        final colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          backgroundColor: colorScheme.surface,
          surfaceTintColor: colorScheme.surfaceTint,
          title: Text('Rename $singularLabel'),
          content: SizedBox(
            height: 42,
            width: 400,
            child: TextField(
              controller: controller,
              autofocus: true,
              style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                labelText: '$singularLabel Name',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: Navigator.of(context).pop,
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final newName = controller.text.trim();
                if (newName.isEmpty || newName == originalName) {
                  Navigator.of(context).pop();
                } else if (items.contains(newName)) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'A $singularLabel with that name already exists'),
                    ),
                  );
                } else {
                  Navigator.of(context).pop();
                  setState(() {
                    final idx = items.indexOf(originalName);
                    if (idx != -1) {
                      items[idx] = newName;
                    } else {
                      items.add(newName);
                    }
                    _saveToSettingsJson();
                    onRenamed?.call(originalName, newName);
                  });
                }
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLinkedTab() {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    if (Waypoint.linked.isEmpty) {
      return const Center(child: Text('No Linked Waypoints in Project'));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: ListView(
        shrinkWrap: true,
        children: [
          for (String waypointName in Waypoint.linked.keys)
            ListTile(
              title: Text(waypointName),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Tooltip(
                    message: 'Rename linked waypoint',
                    waitDuration: const Duration(milliseconds: 500),
                    child: IconButton(
                      onPressed: () => _showRenameLinkedDialog(waypointName),
                      icon: const Icon(Icons.edit),
                    ),
                  ),
                  Tooltip(
                    message: 'Remove linked waypoint',
                    waitDuration: const Duration(milliseconds: 500),
                    child: IconButton(
                      onPressed: () {
                        showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              ColorScheme colorScheme =
                                  Theme.of(context).colorScheme;
                              return AlertDialog(
                                backgroundColor: colorScheme.surface,
                                surfaceTintColor: colorScheme.surfaceTint,
                                title: const Text('Remove Linked Waypoint'),
                                content: Text(
                                    'Are you sure you want to remove the linked waypoint "$waypointName"? This cannot be undone.'),
                                actions: [
                                  TextButton(
                                    onPressed: Navigator.of(context).pop,
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        widget.onLinkedDeleted(waypointName);
                                      });

                                      Navigator.of(context).pop();
                                    },
                                    child: const Text('Confirm'),
                                  ),
                                ],
                              );
                            });
                      },
                      icon: Icon(
                        Icons.delete_forever_rounded,
                        color: colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showRenameLinkedDialog(String originalName) {
    TextEditingController controller =
        TextEditingController(text: originalName);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        ColorScheme colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          backgroundColor: colorScheme.surface,
          surfaceTintColor: colorScheme.surfaceTint,
          title: const Text('Rename Linked Waypoint'),
          content: SizedBox(
            height: 42,
            width: 400,
            child: TextField(
              controller: controller,
              style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                labelText: 'Waypoint Name',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: Navigator.of(context).pop,
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (controller.text == originalName) {
                  Navigator.of(context).pop();
                } else if (Waypoint.linked.containsKey(controller.text)) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'A linked waypoint with that name already exists'),
                    ),
                  );
                } else {
                  Navigator.of(context).pop();
                  setState(() {
                    widget.onLinkedRenamed(originalName, controller.text);
                  });
                }
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }
}