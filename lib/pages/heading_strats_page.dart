import 'package:flutter/material.dart';
import 'package:pathplanner/path/heading_strat.dart';

class HeadingStratsPage extends StatefulWidget {
  final List<HeadingStrat> headingStrats;
  final ValueChanged<List<HeadingStrat>>? onChanged;

  const HeadingStratsPage({
    super.key,
    required this.headingStrats,
    this.onChanged,
  });

  @override
  State<HeadingStratsPage> createState() => _HeadingStratsPageState();
}

class _HeadingStratsPageState extends State<HeadingStratsPage> {
  late List<Map<String, Object?>> _headingStrats;

  @override
  void initState() {
    super.initState();
    _headingStrats = widget.headingStrats
        .map((strat) => <String, Object?>{
              'id': strat.id,
              'name': strat.name,
              'type': strat.type,
              'degrees': strat.degrees,
              'targetX': strat.targetX,
              'targetY': strat.targetY,
              'offsetDeg': strat.offsetDeg,
              'condition': strat.condition,
            })
        .toList(growable: true);
  }

  void _addHeadingStrat() {
    setState(() {
      _headingStrats.add(<String, Object?>{
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'name': 'New Heading Strat',
        'type': HeadingStratKinds.simple,
        'degrees': 0.0,
        'targetX': 0.0,
        'targetY': 0.0,
        'offsetDeg': 0.0,
        'condition': '',
      });
      _notifyChanged();
    });
  }

  void _removeHeadingStrat(int index) {
    setState(() {
      _headingStrats.removeAt(index);
      _notifyChanged();
    });
  }

  void _notifyChanged() {
    widget.onChanged?.call([
      for (final entry in _headingStrats)
        HeadingStrat(
          id: entry['id'].toString(),
          name: entry['name'].toString(),
          type: entry['type'].toString(),
          degrees: (entry['degrees'] as num).toDouble(),
          targetX: (entry['targetX'] as num).toDouble(),
          targetY: (entry['targetY'] as num).toDouble(),
          offsetDeg: (entry['offsetDeg'] as num).toDouble(),
          condition: entry['condition'].toString(),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Heading Strats'),
        actions: [
          TextButton(
            onPressed: _addHeadingStrat,
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () {
              final out = [
                for (final entry in _headingStrats)
                  HeadingStrat(
                    id: entry['id'].toString(),
                    name: entry['name'].toString(),
                    type: entry['type'].toString(),
                    degrees: (entry['degrees'] as num).toDouble(),
                    targetX: (entry['targetX'] as num).toDouble(),
                    targetY: (entry['targetY'] as num).toDouble(),
                    offsetDeg: (entry['offsetDeg'] as num).toDouble(),
                    condition: entry['condition'].toString(),
                  ),
              ];
              Navigator.of(context).pop(out);
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
        itemCount: _headingStrats.length,
        itemBuilder: (context, index) {
          final strat = _headingStrats[index];
          final type = strat['type'].toString();
          final bool needsCondition =
              type == HeadingStratKinds.simpleOnCondition ||
                  type == HeadingStratKinds.faceTargetOnCondition;
          final bool needsSimpleHeading = type == HeadingStratKinds.simple ||
              type == HeadingStratKinds.simpleOnCondition;
          final bool needsTarget = type == HeadingStratKinds.faceTarget ||
              type == HeadingStratKinds.faceTargetOnCondition;

          return Card(
            margin: const EdgeInsets.all(8.0),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Heading Strat ${index + 1}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _removeHeadingStrat(index),
                      ),
                    ],
                  ),
                  TextFormField(
                    initialValue: strat['name']?.toString(),
                    decoration: const InputDecoration(labelText: 'Name'),
                    onChanged: (value) {
                      setState(() {
                        strat['name'] = value;
                        _notifyChanged();
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: type,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: [
                      for (final kind in HeadingStratKinds.values)
                        DropdownMenuItem<String>(
                          value: kind,
                          child: Text(HeadingStratKinds.labelFor(kind)),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        strat['type'] = value;
                        _notifyChanged();
                      });
                    },
                  ),
                  if (needsSimpleHeading) ...[
                    const SizedBox(height: 8),
                    _NumberFormField(
                      initialValue: (strat['degrees'] as num).toDouble(),
                      label: 'Heading (Deg)',
                      onChanged: (value) {
                        setState(() {
                          strat['degrees'] = value;
                          _notifyChanged();
                        });
                      },
                    ),
                  ],
                  if (needsTarget) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _NumberFormField(
                            initialValue: (strat['targetX'] as num).toDouble(),
                            label: 'Target X (M)',
                            onChanged: (value) {
                              setState(() {
                                strat['targetX'] = value;
                                _notifyChanged();
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _NumberFormField(
                            initialValue: (strat['targetY'] as num).toDouble(),
                            label: 'Target Y (M)',
                            onChanged: (value) {
                              setState(() {
                                strat['targetY'] = value;
                                _notifyChanged();
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _NumberFormField(
                      initialValue: (strat['offsetDeg'] as num).toDouble(),
                      label: 'Offset (Deg)',
                      onChanged: (value) {
                        setState(() {
                          strat['offsetDeg'] = value;
                          _notifyChanged();
                        });
                      },
                    ),
                  ],
                  if (needsCondition) ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: strat['condition']?.toString(),
                      decoration: const InputDecoration(
                        labelText: 'Condition',
                        hintText: 'Leave blank until implemented',
                      ),
                      onChanged: (value) {
                        setState(() {
                          strat['condition'] = value;
                          _notifyChanged();
                        });
                      },
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NumberFormField extends StatelessWidget {
  final double initialValue;
  final String label;
  final ValueChanged<double> onChanged;

  const _NumberFormField({
    required this.initialValue,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: initialValue.toString(),
      decoration: InputDecoration(labelText: label),
      keyboardType: TextInputType.number,
      onChanged: (value) {
        onChanged(double.tryParse(value) ?? 0.0);
      },
    );
  }
}
