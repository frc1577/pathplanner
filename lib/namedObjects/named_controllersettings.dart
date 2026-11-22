import 'package:pathplanner/namedObjects/controller_settings.dart';

class NamedControllerSettings extends ControllerSettings {
  String? name;

  NamedControllerSettings({this.name});

  NamedControllerSettings.fromDataJson(Map<String, dynamic> json)
      : this(name: json['name']);

  @override
  Map<String, dynamic> dataToJson() {
    return {
      'name': name,
    };
  }

  @override
  ControllerSettings clone() {
    return NamedControllerSettings(name: name);
  }

  @override
  bool operator ==(Object other) =>
      other is NamedControllerSettings && other.name == name;

  @override
  int get hashCode => Object.hash(name, name);
}