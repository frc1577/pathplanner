import 'dart:math';

class TrapezoidProfile {
  int _direction = 1;
  final Constraints _constraints;
  State _current = State();

  double _endAccel = 0;
  double _endFullVelocity = 0;
  double _endDecel = 0;

  TrapezoidProfile(this._constraints);

  State calculate(double t, State current, State goal) {
    _direction = _shouldFlipAcceleration(current, goal) ? -1 : 1;
    _current = _direct(current);
    goal = _direct(goal);

    if (_current.velocity.abs() > _constraints.maxVelocity) {
      _current.velocity = _current.velocity.sign * _constraints.maxVelocity;
    }

    double cutoffBegin = _current.velocity / _constraints.maxAcceleration;
    double cutoffDistBegin =
        cutoffBegin * cutoffBegin * _constraints.maxAcceleration / 2.0;

    double cutoffEnd = goal.velocity / _constraints.maxAcceleration;
    double cutoffDistEnd =
        cutoffEnd * cutoffEnd * _constraints.maxAcceleration / 2.0;

    double fullTrapezoidDist =
        cutoffDistBegin + (goal.position - _current.position) + cutoffDistEnd;
    double accelerationTime =
        _constraints.maxVelocity / _constraints.maxAcceleration;

    double fullVelocityDist =
        fullTrapezoidDist -
        accelerationTime * accelerationTime * _constraints.maxAcceleration;

    if (fullVelocityDist < 0) {
      accelerationTime =
          sqrt(fullTrapezoidDist / _constraints.maxAcceleration);
      fullVelocityDist = 0;
    }

    _endAccel = accelerationTime - cutoffBegin;
    _endFullVelocity =
        _endAccel + fullVelocityDist / _constraints.maxVelocity;
    _endDecel = _endFullVelocity + accelerationTime - cutoffEnd;

    State result = State(_current.position, _current.velocity);

    if (t < _endAccel) {
      result.velocity += t * _constraints.maxAcceleration;
      result.position += (_current.velocity +
              t * _constraints.maxAcceleration / 2.0) *
          t;
    } else if (t < _endFullVelocity) {
      result.velocity = _constraints.maxVelocity;
      result.position += (_current.velocity +
              _endAccel * _constraints.maxAcceleration / 2.0) *
              _endAccel +
          _constraints.maxVelocity * (t - _endAccel);
    } else if (t <= _endDecel) {
      result.velocity = goal.velocity +
          (_endDecel - t) * _constraints.maxAcceleration;
      double timeLeft = _endDecel - t;
      result.position = goal.position -
          (goal.velocity + timeLeft * _constraints.maxAcceleration / 2.0) *
              timeLeft;
    } else {
      result = goal;
    }

    return _direct(result);
  }

  double totalTime() {
    return _endDecel;
  }

  bool isFinished(double t) {
    return t >= totalTime();
  }

  bool _shouldFlipAcceleration(State initial, State goal) {
    return initial.position > goal.position;
  }

  State _direct(State input) {
    return State(input.position * _direction, input.velocity * _direction);
  }
}

class Constraints {
  final double maxVelocity;
  final double maxAcceleration;

  Constraints(this.maxVelocity, this.maxAcceleration) {
    if (maxVelocity < 0 || maxAcceleration < 0) {
      throw ArgumentError('Constraints must be non-negative');
    }
  }
}

class State {
  double position;
  double velocity;

  State([this.position = 0, this.velocity = 0]);

  @override
  bool operator ==(Object other) {
    return other is State &&
        position == other.position &&
        velocity == other.velocity;
  }

  @override
  int get hashCode => Object.hash(position, velocity);
}

class PIDController {
  double _kp;
  double _ki;
  double _kd;
  double _iZone = double.infinity;
  final double _period;

  double _maximumIntegral = 1.0;
  double _minimumIntegral = -1.0;
  double _maximumInput = 0;
  double _minimumInput = 0;

  bool _continuous = false;

  double _error = 0;
  double _errorDerivative = 0;
  double _prevError = 0;
  double _totalError = 0;

  double _errorTolerance = 0.05;
  double _errorDerivativeTolerance = double.infinity;

  double _setpoint = 0;
  double _measurement = 0;

  bool _haveMeasurement = false;
  bool _haveSetpoint = false;

  PIDController(this._kp, this._ki, this._kd, [this._period = 0.02]) {
    if (_kp < 0 || _ki < 0 || _kd < 0 || _period <= 0) {
      throw ArgumentError('Invalid PIDController parameters');
    }
  }

  void setPID(double kp, double ki, double kd) {
    _kp = kp;
    _ki = ki;
    _kd = kd;
  }

  void setP(double kp) => _kp = kp;
  void setI(double ki) => _ki = ki;
  void setD(double kd) => _kd = kd;

  void setIZone(double iZone) {
    if (iZone < 0) {
      throw ArgumentError('IZone must be non-negative');
    }
    _iZone = iZone;
  }

  double getP() => _kp;
  double getI() => _ki;
  double getD() => _kd;
  double getIZone() => _iZone;
  double getPeriod() => _period;
  double getErrorTolerance() => _errorTolerance;
  double getErrorDerivativeTolerance() => _errorDerivativeTolerance;
  double getAccumulatedError() => _totalError;

  void setSetpoint(double setpoint) {
    _setpoint = setpoint;
    _haveSetpoint = true;

    if (_continuous) {
      double errorBound = (_maximumInput - _minimumInput) / 2.0;
      _error = _inputModulus(_setpoint - _measurement, -errorBound, errorBound);
    } else {
      _error = _setpoint - _measurement;
    }

    _errorDerivative = (_error - _prevError) / _period;
  }

  double getSetpoint() => _setpoint;

  bool atSetpoint() {
    return _haveMeasurement &&
        _haveSetpoint &&
        _error.abs() < _errorTolerance &&
        _errorDerivative.abs() < _errorDerivativeTolerance;
  }

  void enableContinuousInput(double minimumInput, double maximumInput) {
    _continuous = true;
    _minimumInput = minimumInput;
    _maximumInput = maximumInput;
  }

  void disableContinuousInput() {
    _continuous = false;
  }

  bool isContinuousInputEnabled() => _continuous;

  void setIntegratorRange(double minimumIntegral, double maximumIntegral) {
    _minimumIntegral = minimumIntegral;
    _maximumIntegral = maximumIntegral;
  }

  void setTolerance(double errorTolerance, [double errorDerivativeTolerance = double.infinity]) {
    _errorTolerance = errorTolerance;
    _errorDerivativeTolerance = errorDerivativeTolerance;
  }

  double getError() => _error;
  double getErrorDerivative() => _errorDerivative;

  double calculate(double measurement, [double? setpoint]) {
    if (setpoint != null) {
      _setpoint = setpoint;
      _haveSetpoint = true;
    }

    _measurement = measurement;
    _prevError = _error;
    _haveMeasurement = true;

    if (_continuous) {
      double errorBound = (_maximumInput - _minimumInput) / 2.0;
      _error = _inputModulus(_setpoint - _measurement, -errorBound, errorBound);
    } else {
      _error = _setpoint - _measurement;
    }

    _errorDerivative = (_error - _prevError) / _period;

    if (_error.abs() > _iZone) {
      _totalError = 0;
    } else if (_ki != 0) {
      _totalError = _clamp(
        _totalError + _error * _period,
        _minimumIntegral / _ki,
        _maximumIntegral / _ki,
      );
    }

    return _kp * _error + _ki * _totalError + _kd * _errorDerivative;
  }

  void reset() {
    _error = 0;
    _prevError = 0;
    _totalError = 0;
    _errorDerivative = 0;
    _haveMeasurement = false;
  }

  double _inputModulus(double input, double minimumInput, double maximumInput) {
    double modulus = maximumInput - minimumInput;
    double result = (input - minimumInput) % modulus + minimumInput;
    return result < minimumInput ? result + modulus : result;
  }

  double _clamp(double value, double min, double max) {
    return value < min ? min : (value > max ? max : value);
  }
}

class ProfiledPIDController {
  final PIDController _controller;
  double _minimumInput = 0;
  double _maximumInput = 0;

  Constraints _constraints;
  late TrapezoidProfile _profile;
  State _goal = State();
  State _setpoint = State();

  ProfiledPIDController(
    double kp,
    double ki,
    double kd,
    this._constraints, [
    double period = 0.02,
  ]) : _controller = PIDController(kp, ki, kd, period) {
    _profile = TrapezoidProfile(_constraints);
  }

  void setPID(double kp, double ki, double kd) {
    _controller.setPID(kp, ki, kd);
  }

  void setP(double kp) => _controller.setP(kp);
  void setI(double ki) => _controller.setI(ki);
  void setD(double kd) => _controller.setD(kd);

  void setIZone(double iZone) => _controller.setIZone(iZone);
  double getP() => _controller.getP();
  double getI() => _controller.getI();
  double getD() => _controller.getD();
  double getIZone() => _controller.getIZone();
  double getPeriod() => _controller.getPeriod();
  double getPositionTolerance() => _controller.getErrorTolerance();
  double getVelocityTolerance() => _controller.getErrorDerivativeTolerance();
  double getAccumulatedError() => _controller.getAccumulatedError();

  void setGoal(State goal) {
    _goal = goal;
  }

  void setGoalPosition(double goal) {
    _goal = State(goal, 0);
  }

  State getGoal() => _goal;

  bool atGoal() {
    return atSetpoint() && _goal == _setpoint;
  }

  void setConstraints(Constraints constraints) {
    _constraints = constraints;
    _profile = TrapezoidProfile(_constraints);
  }

  Constraints getConstraints() => _constraints;

  State getSetpoint() => _setpoint;

  bool atSetpoint() => _controller.atSetpoint();

  void enableContinuousInput(double minimumInput, double maximumInput) {
    _controller.enableContinuousInput(minimumInput, maximumInput);
    _minimumInput = minimumInput;
    _maximumInput = maximumInput;
  }

  void disableContinuousInput() {
    _controller.disableContinuousInput();
  }

  void setIntegratorRange(double minimumIntegral, double maximumIntegral) {
    _controller.setIntegratorRange(minimumIntegral, maximumIntegral);
  }

  void setTolerance(double positionTolerance, [double velocityTolerance = double.infinity]) {
    _controller.setTolerance(positionTolerance, velocityTolerance);
  }

  double getPositionError() => _controller.getError();
  double getVelocityError() => _controller.getErrorDerivative();

  double calculate(double measurement) {
    if (_controller.isContinuousInputEnabled()) {
      double errorBound = (_maximumInput - _minimumInput) / 2.0;
      double goalMinDistance = _inputModulus(_goal.position - measurement, -errorBound, errorBound);
      double setpointMinDistance =
          _inputModulus(_setpoint.position - measurement, -errorBound, errorBound);

      _goal.position = goalMinDistance + measurement;
      _setpoint.position = setpointMinDistance + measurement;
    }

    _setpoint = _profile.calculate(getPeriod(), _setpoint, _goal);
    return _controller.calculate(measurement, _setpoint.position);
  }

  double calculateWithGoal(double measurement, State goal) {
    setGoal(goal);
    return calculate(measurement);
  }

  double calculateWithGoalPosition(double measurement, double goal) {
    setGoalPosition(goal);
    return calculate(measurement);
  }

  double calculateWithConstraints(
    double measurement,
    State goal,
    Constraints constraints,
  ) {
    setConstraints(constraints);
    return calculateWithGoal(measurement, goal);
  }

  void reset(State measurement) {
    _controller.reset();
    _setpoint = measurement;
  }

  void resetPosition(double measuredPosition, [double measuredVelocity = 0]) {
    reset(State(measuredPosition, measuredVelocity));
  }

  double _inputModulus(double input, double minimumInput, double maximumInput) {
    double modulus = maximumInput - minimumInput;
    double result = (input - minimumInput) % modulus + minimumInput;
    return result < minimumInput ? result + modulus : result;
  }
}