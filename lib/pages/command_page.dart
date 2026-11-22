import 'package:flutter/material.dart';

class CommandPage extends StatefulWidget {
  final List<String> commands;
  final ValueChanged<List<String>>? onChanged;
  const CommandPage({
    super.key,
    required this.commands,
    this.onChanged,
  });

  @override
  State<CommandPage> createState() => _CommandPageState();
}

class _CommandPageState extends State<CommandPage> {
  late List<String> _commands;

  @override
  void initState() {
    super.initState();
    _commands = List<String>.from(widget.commands);
  }

  String _nextUniqueName() {
    final lowerSet = _commands.map((e) => e.trim().toLowerCase()).toSet();
    var i = _commands.length + 1;
    while (lowerSet.contains('new command $i')) {
      i++;
    }
    return 'New Command $i';
  }

  String? _findDuplicate() {
    final seen = <String>{};
    for (final item in _commands) {
      final raw = item.trim();
      final normalized = raw.toLowerCase();
      if (normalized.isEmpty) continue;
      if (!seen.add(normalized)) return raw;
    }
    return null;
  }

  void _addCommand() {
    setState(() {
      _commands.add(_nextUniqueName());
      _notifyChanged();
    });
  }

  void _removeCommand(int index) {
    setState(() {
      _commands.removeAt(index);
      _notifyChanged();
    });
  }

  void _notifyChanged() {
    widget.onChanged?.call(List<String>.unmodifiable(_commands));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Commands'),
        actions: [
          TextButton(
            onPressed: () {
              final dup = _findDuplicate();
              if (dup != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Duplicate command name "$dup".'),
                  ),
                );
                return;
              }
              Navigator.of(context).pop(List<String>.unmodifiable(_commands));
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
        itemCount: _commands.length,
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.all(8.0),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _commands[index],
                      decoration: const InputDecoration(
                        labelText: 'Command Name',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _commands[index] = value;
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