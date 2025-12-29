// Gyro (deg/s) and accel (g's) data.
class ImuSample {
  final DateTime timestamp;

  // Gyroscope (angular velocity in degrees/second)
  final double gyroX;
  final double gyroY;
  final double gyroZ;

  // Accelerometer (linear acceleration in g's)
  final double accelX;
  final double accelY;
  final double accelZ;

  const ImuSample({
    required this.timestamp,
    required this.gyroX,
    required this.gyroY,
    required this.gyroZ,
    required this.accelX,
    required this.accelY,
    required this.accelZ,
  });

  Map<String, String> toCsvValues() {
    return {
      'GYRO_X': gyroX.toStringAsFixed(6),
      'GYRO_Y': gyroY.toStringAsFixed(6),
      'GYRO_Z': gyroZ.toStringAsFixed(6),
      'ACCEL_X': accelX.toStringAsFixed(6),
      'ACCEL_Y': accelY.toStringAsFixed(6),
      'ACCEL_Z': accelZ.toStringAsFixed(6),
    };
  }
}
