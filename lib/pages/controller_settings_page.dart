import 'package:flutter/material.dart';

class ControllerSettingsPage extends StatefulWidget {
  final List<String> settings;
  final ValueChanged<List<String>>? onChanged;
  const ControllerSettingsPage({
    super.key,
    required this.settings,
    this.onChanged,
  });

  @override
  State<ControllerSettingsPage> createState() => _ControllerSettingsPageState();
}

class _ControllerSettingsPageState extends State<ControllerSettingsPage> {
  late List<String> settings;

  @override
  void initState() {
    super.initState();
    settings = List<String>.from(widget.settings);
  }

  String _nextUniqueName() {
    final lowerSet = settings.map((e) => e.trim().toLowerCase()).toSet();
    var i = settings.length + 1;
    while (lowerSet.contains('new setting $i')) {
      i++;
    }
    return 'New Setting $i';
  }

  String? _findDuplicate() {
    final seen = <String>{};
    for (final item in settings) {
      final raw = item.trim();
      final normalized = raw.toLowerCase();
      if (normalized.isEmpty) continue;
      if (!seen.add(normalized)) return raw;
    }
    return null;
  }

  void _addCommand() {
    setState(() {
      settings.add(_nextUniqueName());
      _notifyChanged();
    });
  }

  void _removeCommand(int index) {
    setState(() {
      settings.removeAt(index);
      _notifyChanged();
    });
  }

  void _notifyChanged() {
    widget.onChanged?.call(List<String>.unmodifiable(settings));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          TextButton(
            onPressed: () {
              final dup = _findDuplicate();
              if (dup != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Duplicate setting name "$dup".'),
                  ),
                );
                return;
              }
              Navigator.of(context).pop(List<String>.unmodifiable(settings));
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: settings.length,
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.all(8.0),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: settings[index],
                      decoration: const InputDecoration(
                        labelText: 'Setting Name',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          settings[index] = value;
                          _notifyChanged();
                        });
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _removeCommand(index),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addCommand,
        child: const Icon(Icons.add),
      ),
    );
  }
}