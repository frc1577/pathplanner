import 'package:pathplanner/namedObjects/command.dart';

class NamedCommand extends Command {
  String? name;

  NamedCommand({this.name});

  NamedCommand.fromDataJson(Map<String, dynamic> json)
      : this(name: json['name']);

  @override
  Map<String, dynamic> dataToJson() {
    return {
      'name': name,
    };
  }

  @override
  Command clone() {
    return NamedCommand(name: name);
  }

  @override
  bool operator ==(Object other) =>
      other is NamedCommand && other.name == name;

  @override
  int get hashCode => Object.hash(name, name);
}