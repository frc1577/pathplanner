import 'package:pathplanner/commands/trigger.dart';

class NamedTrigger extends Trigger {
  String? name;

  NamedTrigger({this.name});

  NamedTrigger.fromDataJson(Map<String, dynamic> json)
      : this(name: json['name']);

  @override
  Map<String, dynamic> dataToJson() {
    return {
      'name': name,
    };
  }

  @override
  Trigger clone() {
    return NamedTrigger(name: name);
  }

  @override
  bool operator ==(Object other) =>
      other is NamedTrigger && other.name == name;

  @override
  int get hashCode => Object.hash(name, name);
}