import 'package:flutter/material.dart';

class HeadingStratsPage extends StatefulWidget {
  final List<String> strats;
  final ValueChanged<List<String>>? onChanged;
  const HeadingStratsPage({
    super.key,
    required this.strats,
    this.onChanged,
  });

  @override
  State<HeadingStratsPage> createState() => _ControllerSettingsPageState();
}

class _ControllerSettingsPageState extends State<HeadingStratsPage> {
  late List<String> strats;

  @override
  void initState() {
    super.initState();
    strats = List<String>.from(widget.strats);
  }

  String _nextUniqueName() {
    final lowerSet = strats.map((e) => e.trim().toLowerCase()).toSet();
    var i = strats.length + 1;
    while (lowerSet.contains('new strat $i')) {
      i++;
    }
    return 'New Strat $i';
  }

  String? _findDuplicate() {
    final seen = <String>{};
    for (final item in strats) {
      final raw = item.trim();
      final normalized = raw.toLowerCase();
      if (normalized.isEmpty) continue;
      if (!seen.add(normalized)) return raw;
    }
    return null;
  }

  void _addCommand() {
    setState(() {
      strats.add(_nextUniqueName());
      _notifyChanged();
    });
  }

  void _removeCommand(int index) {
    setState(() {
      strats.removeAt(index);
      _notifyChanged();
    });
  }

  void _notifyChanged() {
    widget.onChanged?.call(List<String>.unmodifiable(strats));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Strats'),
        actions: [
          TextButton(
            onPressed: () {
              final dup = _findDuplicate();
              if (dup != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Duplicate strat name "$dup".'),
                  ),
                );
                return;
              }
              Navigator.of(context).pop(List<String>.unmodifiable(strats));
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
        itemCount: strats.length,
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.all(8.0),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: strats[index],
                      decoration: const InputDecoration(
                        labelText: 'Strat Name',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          strats[index] = value;
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