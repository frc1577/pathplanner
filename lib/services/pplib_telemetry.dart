import 'dart:convert';
import 'dart:typed_data';

import 'package:nt4/nt4.dart';
import 'package:pathplanner/path/goal.dart';
import 'package:pathplanner/path/goal_picker.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';

class PPLibTelemetry {
  late NT4Client _client;
  late NT4Subscription _velSub;
  late NT4Subscription _currentPoseSub;
  late NT4Subscription _activePathSub;
  late NT4Subscription _targetPoseSub;

  late NT4Topic _hotReloadPathTopic;
  late NT4Topic _hotReloadAutoTopic;
  late NT4Topic _hotReloadGoalTopic;
  late NT4Topic _hotReloadGoalPickerTopic;

  bool _isConnected = false;

  PPLibTelemetry({required String serverBaseAddress}) {
    _client = NT4Client(
      serverBaseAddress: serverBaseAddress,
      onConnect: () => _isConnected = true,
      onDisconnect: () => _isConnected = false,
    );

    _velSub = _client.subscribePeriodic('/PathPlanner/vel', 0.033);
    _currentPoseSub =
        _client.subscribePeriodic('/PathPlanner/currentPose', 0.033);
    _activePathSub = _client.subscribeAllSamples('/PathPlanner/activePath');
    _targetPoseSub =
        _client.subscribePeriodic('/PathPlanner/targetPose', 0.033);

    _hotReloadPathTopic = _client.publishNewTopic(
        '/PathPlanner/HotReload/hotReloadPath', NT4TypeStr.typeStr);
    _hotReloadAutoTopic = _client.publishNewTopic(
        '/PathPlanner/HotReload/hotReloadAuto', NT4TypeStr.typeStr);
    _hotReloadGoalTopic = _client.publishNewTopic(
        '/PathPlanner/HotReload/hotReloadGoal', NT4TypeStr.typeStr);
    _hotReloadGoalPickerTopic = _client.publishNewTopic(
        '/PathPlanner/HotReload/hotReloadGoalPicker', NT4TypeStr.typeStr);
  }

  void setServerAddress(String serverAddress) {
    _client.setServerBaseAddress(serverAddress);
  }

  String getServerAddress() {
    return _client.serverBaseAddress;
  }


  void hotReloadGoal(Goal goal) {
    Map<String, dynamic> msgJson = {
      'name': goal.name,
      'goal': goal.toJson(),
    };

    _client.addSample(_hotReloadGoalTopic, jsonEncode(msgJson));
  }

  void hotReloadGoalPicker(String name, GoalPicker goalPicker) {
    Map<String, dynamic> msgJson = {
      'name': name,
      'goalPicker': goalPicker.toJson(),
    };

    _client.addSample(_hotReloadGoalPickerTopic, jsonEncode(msgJson));
  }

  Stream<List<num>> velocitiesStream() {
    return _velSub.stream().map((vels) =>
        (vels as List?)?.map((e) => e as num).toList() ?? [0, 0, 0, 0]);
  }

  Stream<Pose2d?> currentPoseStream() {
    return _currentPoseSub.stream().map((pose) => (pose is List<int>)
        ? Pose2d.fromBytes(Uint8List.fromList(pose))
        : null);
  }

  Stream<List<Pose2d>?> currentPathStream() {
    return _activePathSub.stream().map((poses) => (poses is List<int>)
        ? Pose2d.listFromBytes(Uint8List.fromList(poses))
        : null);
  }

  Stream<bool> connectionStatusStream() {
    return _client.connectionStatusStream().asBroadcastStream();
  }

  Stream<Pose2d?> targetPoseStream() {
    return _targetPoseSub.stream().map((pose) => (pose is List<int>)
        ? Pose2d.fromBytes(Uint8List.fromList(pose))
        : null);
  }

  bool get isConnected => _isConnected;
}