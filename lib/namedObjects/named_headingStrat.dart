import 'package:pathplanner/namedObjects/heading_strat.dart';

class NamedHeadingStrat extends HeadingStrat {
  String? name;

  NamedHeadingStrat({this.name});

  NamedHeadingStrat.fromDataJson(Map<String, dynamic> json)
      : this(name: json['name']);

  @override
  Map<String, dynamic> dataToJson() {
    return {
      'name': name,
    };
  }

  @override
  HeadingStrat clone() {
    return NamedHeadingStrat(name: name);
  }

  @override
  bool operator ==(Object other) =>
      other is NamedHeadingStrat && other.name == name;

  @override
  int get hashCode => Object.hash(name, name);
}