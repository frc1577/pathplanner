import 'package:flutter/material.dart';

class TriggerPage extends StatefulWidget {
  final List<String> triggers;
  final ValueChanged<List<String>>? onChanged;

  const TriggerPage({
    super.key,
    required this.triggers,
    this.onChanged,
  });

  @override
  State<TriggerPage> createState() => _TriggerPageState();
}

class _TriggerPageState extends State<TriggerPage> {
  late List<String> _triggers;

  @override
  void initState() {
    super.initState();
    _triggers = List<String>.from(widget.triggers);
  }

  String _nextUniqueName() {
    final lowerSet = _triggers.map((e) => e.trim().toLowerCase()).toSet();
    var i = _triggers.length + 1;
    while (lowerSet.contains('new trigger $i')) {
      i++;
    }
    return 'New Trigger $i';
  }

  String? _findDuplicate() {
    final seen = <String>{};
    for (final item in _triggers) {
      final raw = item.trim();
      final normalized = raw.toLowerCase();
      if (normalized.isEmpty) continue;
      if (!seen.add(normalized)) return raw;
    }
    return null;
  }

  void _addTrigger() {
    setState(() {
      _triggers.add(_nextUniqueName());
      _notifyChanged();
    });
  }

  void _removeTrigger(int index) {
    setState(() {
      _triggers.removeAt(index);
      _notifyChanged();
    });
  }

  void _notifyChanged() {
    widget.onChanged?.call(List<String>.unmodifiable(_triggers));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Triggers'),
        actions: [
          TextButton(
            onPressed: () {
              final dup = _findDuplicate();
              if (dup != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Duplicate trigger name "$dup".'),
                  ),
                );
                return;
              }
              Navigator.of(context).pop(List<String>.unmodifiable(_triggers));
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
        itemCount: _triggers.length,
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.all(8.0),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _triggers[index],
                      decoration: const InputDecoration(
                        labelText: 'Trigger Name',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _triggers[index] = value;
                          _notifyChanged();
                        });
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _removeTrigger(index),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTrigger,
        child: const Icon(Icons.add),
      ),
    );
  }
}