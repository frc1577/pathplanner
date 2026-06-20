import 'package:flutter/material.dart';
import 'package:pathplanner/services/physics_sim_service.dart';
import 'package:pathplanner/services/save_service.dart';

class ControllerSettingsPage extends StatefulWidget {
  final List<ControllerSetting> controllerSettings;
  final ValueChanged<List<ControllerSetting>>? onChanged;

  const ControllerSettingsPage({
    super.key,
    required this.controllerSettings,
    this.onChanged,
  });

  @override
  _ControllerSettingsPageState createState() => _ControllerSettingsPageState();
}

class _ControllerSettingsPageState extends State<ControllerSettingsPage> {
  late List<Map<String, Object?>> _controllerSettings;

  @override
  void initState() {
    super.initState();
    // Use mutable maps for editing, convert back on save
  _controllerSettings = widget.controllerSettings
    .map((c) => <String, Object?>{
        'id': c.id,
        'name': c.name,
        'kp': c.kp,
        'ki': c.ki,
        'kd': c.kd,
        'cruiseVelocity': c.cruiseVelocity,
        'maxAcceleration': c.maxAcceleration,
        'angularKp': c.angularKp,
        'angularKi': c.angularKi,
        'angularKd': c.angularKd,
        'angularMaxVelocity': c.angularMaxVelocity,
        'angularMaxAcceleration': c.angularMaxAcceleration,
      })
    .toList(growable: true);
  }

  void _addControllerSetting() {
    setState(() {
      _controllerSettings.add(<String, Object?>{
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'name': 'New Setting',
        'kp': 0.0,
        'ki': 0.0,
        'kd': 0.0,
        'cruiseVelocity': 0.0,
        'maxAcceleration': 0.0,
        'angularKp': 0.0,
        'angularKi': 0.0,
        'angularKd': 0.0,
        'angularMaxVelocity': 0.0,
        'angularMaxAcceleration': 0.0,
      });
      _notifyChanged();
    });
  }

  void _removeControllerSetting(int index) {
    setState(() {
      _controllerSettings.removeAt(index);
      _notifyChanged();
    });
  }

  void _notifyChanged() {
    if (widget.onChanged != null) {
      widget.onChanged!(List.unmodifiable(_controllerSettings.map((m) => ControllerSetting(
            id: m['id'].toString(),
            name: m['name'].toString(),
            kp: (m['kp'] as num).toDouble(),
            ki: (m['ki'] as num).toDouble(),
            kd: (m['kd'] as num).toDouble(),
            cruiseVelocity: (m['cruiseVelocity'] as num).toDouble(),
            maxAcceleration: (m['maxAcceleration'] as num).toDouble(),
            angularKp: (m['angularKp'] as num).toDouble(),
            angularKi: (m['angularKi'] as num).toDouble(),
            angularKd: (m['angularKd'] as num).toDouble(),
            angularMaxVelocity: (m['angularMaxVelocity'] as num).toDouble(),
            angularMaxAcceleration: (m['angularMaxAcceleration'] as num).toDouble(),
          ))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Controller Settings'),
        actions: [
          TextButton(
            onPressed: () async {
              final controller = TextEditingController();

              final res = await showDialog<bool?>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Import Controllers'),
                  content: SizedBox(
                    width: 600,
                    child: TextField(
                      controller: controller,
                      maxLines: 15,
                      decoration: const InputDecoration(
                        hintText: 'Paste Java controller blocks here',
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Import'),
                    ),
                  ],
                ),
              );

              if (res == true) {
                final text = controller.text;
                final parsed = SaveService.importFromJavaControllers(text);
                if (parsed.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('No controller blocks found or parse failed.'),
                  ));
                } else {
                  setState(() {
                    for (final s in parsed) {
                      _controllerSettings.add({
                        'id': s.id,
                        'name': s.name,
                        'kp': s.kp,
                        'ki': s.ki,
                        'kd': s.kd,
                        'cruiseVelocity': s.cruiseVelocity,
                        'maxAcceleration': s.maxAcceleration,
                        'angularKp': s.angularKp,
                        'angularKi': s.angularKi,
                        'angularKd': s.angularKd,
                        'angularMaxVelocity': s.angularMaxVelocity,
                        'angularMaxAcceleration': s.angularMaxAcceleration,
                      });
                    }
                    _notifyChanged();
                  });

                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Imported ${parsed.length} controller(s).'),
                  ));
                }
              }
            },
            child: const Text('Import', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () {
        // Return updated settings as typed ControllerSetting list
        final out = _controllerSettings
          .map((m) => ControllerSetting(
            id: m['id'].toString(),
            name: m['name'].toString(),
            kp: (m['kp'] as num).toDouble(),
            ki: (m['ki'] as num).toDouble(),
            kd: (m['kd'] as num).toDouble(),
            cruiseVelocity: (m['cruiseVelocity'] as num).toDouble(),
            maxAcceleration: (m['maxAcceleration'] as num).toDouble(),
            angularKp: (m['angularKp'] as num).toDouble(),
            angularKi: (m['angularKi'] as num).toDouble(),
            angularKd: (m['angularKd'] as num).toDouble(),
            angularMaxVelocity: (m['angularMaxVelocity'] as num).toDouble(),
            angularMaxAcceleration: (m['angularMaxAcceleration'] as num).toDouble(),
            ))
          .toList(growable: false);
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
        itemCount: _controllerSettings.length,
        itemBuilder: (context, index) {
          final setting = _controllerSettings[index];
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
                      Text('Controller ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _removeControllerSetting(index),
                      ),
                    ],
                  ),
                  TextFormField(
                    initialValue: setting['name']?.toString(),
                    decoration: const InputDecoration(labelText: 'Name'),
                    onChanged: (value) {
                      setState(() {
                        setting['name'] = value;
                        _notifyChanged();
                      });
                    },
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: setting['kp'].toString(),
                          decoration: const InputDecoration(labelText: 'kp'),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            setState(() {
                              setting['kp'] = double.tryParse(value) ?? 0.0;
                              _notifyChanged();
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          initialValue: setting['ki'].toString(),
                          decoration: const InputDecoration(labelText: 'ki'),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            setState(() {
                              setting['ki'] = double.tryParse(value) ?? 0.0;
                              _notifyChanged();
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          initialValue: setting['kd'].toString(),
                          decoration: const InputDecoration(labelText: 'kd'),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            setState(() {
                              setting['kd'] = double.tryParse(value) ?? 0.0;
                              _notifyChanged();
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: setting['cruiseVelocity'].toString(),
                          decoration: const InputDecoration(labelText: 'Cruise Velocity'),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            setState(() {
                              setting['cruiseVelocity'] = double.tryParse(value) ?? 0.0;
                              _notifyChanged();
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          initialValue: setting['maxAcceleration'].toString(),
                          decoration: const InputDecoration(labelText: 'Max Acceleration'),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            setState(() {
                              setting['maxAcceleration'] = double.tryParse(value) ?? 0.0;
                              _notifyChanged();
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: setting['angularKp'].toString(),
                          decoration: const InputDecoration(labelText: 'angularKp'),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            setState(() {
                              setting['angularKp'] = double.tryParse(value) ?? 0.0;
                              _notifyChanged();
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          initialValue: setting['angularKi'].toString(),
                          decoration: const InputDecoration(labelText: 'angularKi'),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            setState(() {
                              setting['angularKi'] = double.tryParse(value) ?? 0.0;
                              _notifyChanged();
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          initialValue: setting['angularKd'].toString(),
                          decoration: const InputDecoration(labelText: 'angularKd'),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            setState(() {
                              setting['angularKd'] = double.tryParse(value) ?? 0.0;
                              _notifyChanged();
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: setting['angularMaxVelocity'].toString(),
                          decoration: const InputDecoration(labelText: 'angularMaxVelocity'),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            setState(() {
                              setting['angularMaxVelocity'] = double.tryParse(value) ?? 0.0;
                              _notifyChanged();
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          initialValue: setting['angularMaxAcceleration'].toString(),
                          decoration: const InputDecoration(labelText: 'angularMaxAcceleration'),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            setState(() {
                              setting['angularMaxAcceleration'] = double.tryParse(value) ?? 0.0;
                              _notifyChanged();
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addControllerSetting,
        child: const Icon(Icons.add),
      ),
    );
  }
}