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
  late List<dynamic> _headingStrats;
  String _innerType = HeadingStratKinds.simple;

  static const List<String> _supportedKinds = [
    HeadingStratKinds.simple,
    HeadingStratKinds.faceTarget,
    HeadingStratKinds.named,
  ];

  String _sanitizeType(String? rawType) {
    if (rawType != null && _supportedKinds.contains(rawType)) {
      return rawType;
    }
    return HeadingStratKinds.simple;
  }

  @override
  void initState() {
    super.initState();
    _headingStrats = widget.headingStrats
        .map((strat) => <String, Object?>{
              'name': strat.name,
              'type': _sanitizeType(strat.type),
              'degrees': strat.degrees,
              'targetX': strat.targetX,
              'targetY': strat.targetY,
              'offsetDeg': strat.offsetDeg,
              'innerType': _sanitizeType(strat.innerType) ==
                      HeadingStratKinds.faceTarget
                  ? HeadingStratKinds.faceTarget
                  : HeadingStratKinds.simple,
            })
        .toList(growable: true);
  }

  String _nextUniqueName() {
    final lowerSet = _headingStrats
        .map((m) => (m['name']?.toString() ?? '').trim().toLowerCase())
        .toSet();
    var i = _headingStrats.length + 1;
    while (lowerSet.contains('new heading strat $i')) {
      i++;
    }
    return 'New Heading Strat $i';
  }

  String? _findDuplicateName() {
    final seen = <String>{};
    for (final m in _headingStrats) {
      final raw = m['name']?.toString().trim() ?? '';
      final normalized = raw.toLowerCase();
      if (normalized.isEmpty) continue;
      if (!seen.add(normalized)) return raw;
    }
    return null;
  }

  void _addHeadingStrat({String type = HeadingStratKinds.simple}) {
    final sanitizedType = _sanitizeType(type);
    final isNamed = sanitizedType == HeadingStratKinds.named;
    if (isNamed) {
      _innerType = HeadingStratKinds.simple;
    }

    setState(() {
      _headingStrats.add(<String, Object?>{
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'name': _nextUniqueName(),
        'type': sanitizedType,
        'degrees': 0.0,
        'targetX': 0.0,
        'targetY': 0.0,
        'offsetDeg': 0.0,
        'innerType': isNamed ? _innerType : HeadingStratKinds.simple,
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
          name: entry['name'].toString(),
          type: _sanitizeType(entry['type']?.toString()),
          degrees: (entry['degrees'] as num).toDouble(),
          targetX: (entry['targetX'] as num).toDouble(),
          targetY: (entry['targetY'] as num).toDouble(),
          offsetDeg: (entry['offsetDeg'] as num).toDouble(),
          innerType:
              entry['innerType']?.toString() ?? HeadingStratKinds.simple,
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
            onPressed: () => _addHeadingStrat(),
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () {
              final dup = _findDuplicateName();
              if (dup != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Duplicate heading strat name "$dup".'),
                  ),
                );
                return;
              }

              final out = [
                for (final entry in _headingStrats)
                  HeadingStrat(
                    name: entry['name'].toString().trim(),
                    type: _sanitizeType(entry['type']?.toString()),
                    degrees: (entry['degrees'] as num).toDouble(),
                    targetX: (entry['targetX'] as num).toDouble(),
                    targetY: (entry['targetY'] as num).toDouble(),
                    offsetDeg: (entry['offsetDeg'] as num).toDouble(),
                    innerType: entry['innerType']?.toString() ??
                        HeadingStratKinds.simple,
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
          final type = _sanitizeType(strat['type']?.toString());
          final innerType =
              strat['innerType']?.toString() ?? HeadingStratKinds.simple;
          final bool isNamed = type == HeadingStratKinds.named;
          final bool needsSimpleHeading = type == HeadingStratKinds.simple ||
              (isNamed && innerType == HeadingStratKinds.simple);
          final bool needsTarget = type == HeadingStratKinds.faceTarget ||
              (isNamed && innerType == HeadingStratKinds.faceTarget);

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
                        if (value == HeadingStratKinds.named) {
                          strat['innerType'] =
                              strat['innerType'] ?? HeadingStratKinds.simple;
                        }
                        _notifyChanged();
                      });
                    },
                  ),
                  if (isNamed) ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: innerType,
                      decoration: const InputDecoration(labelText: 'Inner Type'),
                      items: [
                        DropdownMenuItem<String>(
                          value: HeadingStratKinds.simple,
                          child: Text(
                            HeadingStratKinds.labelFor(HeadingStratKinds.simple),
                          ),
                        ),
                        DropdownMenuItem<String>(
                          value: HeadingStratKinds.faceTarget,
                          child: Text(
                            HeadingStratKinds.labelFor(
                                HeadingStratKinds.faceTarget),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          strat['innerType'] = value;
                          _innerType = value;
                          _notifyChanged();
                        });
                      },
                    ),
                  ],
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