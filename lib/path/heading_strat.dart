import 'package:pathplanner/util/wpimath/geometry.dart';

class HeadingStratKinds {
  static const String simple = 'SimpleHeadingStrat';
  static const String simpleOnCondition = 'SimpleHeadingStratOnCondition';
  static const String faceTarget = 'FaceTargetHeadingStrat';
  static const String faceTargetOnCondition =
      'FaceTargetHeadingStratOnCondition';

  static const List<String> values = [
    simple,
    simpleOnCondition,
    faceTarget,
    faceTargetOnCondition,
  ];

  static String labelFor(String kind) {
    switch (kind) {
      case simple:
        return 'Simple Heading Strat';
      case simpleOnCondition:
        return 'Simple Heading Strat On Condition';
      case faceTarget:
        return 'Face Target Heading Strat';
      case faceTargetOnCondition:
        return 'Face Target Heading Strat On Condition';
      default:
        return kind;
    }
  }
}

class HeadingStrat {
  final String id;
  String name;
  String type;
  double degrees;
  double targetX;
  double targetY;
  double offsetDeg;
  double falseDegrees;
  String? falseHeadingStratId;
  String condition;

  HeadingStrat({
    required this.id,
    required this.name,
    required this.type,
    required this.degrees,
    required this.targetX,
    required this.targetY,
    required this.offsetDeg,
    required this.falseDegrees,
    this.falseHeadingStratId,
    required this.condition,
  });

  factory HeadingStrat.fromJson(Map<String, dynamic> json) {
    double readDouble(dynamic value, double defaultValue) {
      if (value == null) return defaultValue;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? defaultValue;
    }

    return HeadingStrat(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? HeadingStratKinds.simple,
      degrees: readDouble(json['degrees'], readDouble(json['headingDeg'], 0.0)),
      targetX: readDouble(json['targetX'], 0.0),
      targetY: readDouble(json['targetY'], 0.0),
      offsetDeg:
          readDouble(json['offsetDeg'], readDouble(json['headingDeg'], 0.0)),
      falseDegrees: readDouble(json['falseDegrees'], 0.0),
      falseHeadingStratId: json['falseHeadingStratId']?.toString(),
      condition: json['condition']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'degrees': degrees,
      'targetX': targetX,
      'targetY': targetY,
      'offsetDeg': offsetDeg,
      'falseDegrees': falseDegrees,
      'falseHeadingStratId': falseHeadingStratId,
      'condition': condition,
    };
  }

  HeadingStrat clone() {
    return HeadingStrat(
      id: id,
      name: name,
      type: type,
      degrees: degrees,
      targetX: targetX,
      targetY: targetY,
      offsetDeg: offsetDeg,
      falseDegrees: falseDegrees,
      falseHeadingStratId: falseHeadingStratId,
      condition: condition,
    );
  }

  bool get isSimple =>
      type == HeadingStratKinds.simple ||
      type == HeadingStratKinds.simpleOnCondition;

  bool get isFaceTarget =>
      type == HeadingStratKinds.faceTarget ||
      type == HeadingStratKinds.faceTargetOnCondition;

  Rotation2d? resolveHeading(
    Translation2d robotPose, {
    List<HeadingStrat> headingStrats = const [],
  }) {
    return _resolveHeading(robotPose, headingStrats, <String>{});
  }

  Rotation2d? _resolveHeading(
    Translation2d robotPose,
    List<HeadingStrat> headingStrats,
    Set<String> resolvingIds,
  ) {
    if ((type == HeadingStratKinds.simpleOnCondition ||
            type == HeadingStratKinds.faceTargetOnCondition) &&
        !_conditionMatches(robotPose)) {
      final fallback = falseHeadingStratId == null
          ? null
          : headingStrats.cast<HeadingStrat?>().firstWhere(
                (strat) => strat?.id == falseHeadingStratId,
                orElse: () => null,
              );
      if (fallback != null && resolvingIds.add(id)) {
        return fallback._resolveHeading(robotPose, headingStrats, resolvingIds);
      }
      return Rotation2d.fromDegrees(falseDegrees);
    }

    if (isFaceTarget) {
      final directionToTarget = Translation2d(targetX, targetY) - robotPose;
      return directionToTarget.angle + Rotation2d.fromDegrees(offsetDeg);
    }

    return Rotation2d.fromDegrees(degrees);
  }

  bool _conditionMatches(Translation2d robotPose) {
    if (condition.trim().isEmpty) return false;

    try {
      return _BooleanExpressionParser(condition, robotPose.x.toDouble()).parse();
    } on FormatException {
      return false;
    }
  }
}

class _BooleanExpressionParser {
  final String expression;
  final double robotPose;
  int _index = 0;

  _BooleanExpressionParser(this.expression, this.robotPose);

  bool parse() {
    final result = _parseOr();
    _skipWhitespace();
    if (_index != expression.length) {
      throw const FormatException('Unexpected token');
    }
    return result;
  }

  bool _parseOr() {
    var result = _parseAnd();
    while (_match('||')) {
      result = _parseAnd() || result;
    }
    return result;
  }

  bool _parseAnd() {
    var result = _parsePrimary();
    while (_match('&&')) {
      result = _parsePrimary() && result;
    }
    return result;
  }

  bool _parsePrimary() {
    _skipWhitespace();
    if (_match('(')) {
      final result = _parseOr();
      if (!_match(')')) {
        throw const FormatException('Missing closing parenthesis');
      }
      return result;
    }

    final token = _readToken();
    if (token == 'true') return true;
    if (token == 'false') return false;
    if (token != 'robotPose') throw const FormatException('Unknown value');

    _skipWhitespace();
    final operator = _readOperator();
    final value = _readNumber();
    switch (operator) {
      case '>':
        return robotPose > value;
      case '>=':
        return robotPose >= value;
      case '<':
        return robotPose < value;
      case '<=':
        return robotPose <= value;
      case '==':
        return robotPose == value;
      case '!=':
        return robotPose != value;
      default:
        throw const FormatException('Unknown operator');
    }
  }

  String _readToken() {
    _skipWhitespace();
    final start = _index;
    while (_index < expression.length &&
        RegExp(r'[A-Za-z]').hasMatch(expression[_index])) {
      _index++;
    }
    if (start == _index) throw const FormatException('Expected value');
    return expression.substring(start, _index);
  }

  String _readOperator() {
    for (final operator in const ['>=', '<=', '==', '!=', '>', '<']) {
      if (_match(operator)) return operator;
    }
    throw const FormatException('Expected comparison operator');
  }

  double _readNumber() {
    _skipWhitespace();
    final match = RegExp(r'[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?')
        .matchAsPrefix(expression, _index);
    if (match == null) throw const FormatException('Expected number');
    _index = match.end;
    return double.parse(match.group(0)!);
  }

  bool _match(String value) {
    _skipWhitespace();
    if (!expression.startsWith(value, _index)) return false;
    _index += value.length;
    return true;
  }

  void _skipWhitespace() {
    while (_index < expression.length && expression[_index].trim().isEmpty) {
      _index++;
    }
  }
}
