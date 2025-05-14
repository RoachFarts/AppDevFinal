// lib/models/sensor_data.dart
import 'package:flutter/material.dart'; // For Color

class SensorData {
  final double? temperature;
  final String? unitTemperature;
  final double? humidity;
  final String? unitHumidity;
  final int? distance;
  final String? unitDistance;
  final int? mq137DigitalState;
  final String? mq137Interpretation;

  final bool hasError;
  final String errorMessage;

  // Configuration for interpretation (adjust these to your tank and preferences)
  // Temperature (Celsius)
  static const double optimalTempMin = 24.0;
  static const double optimalTempMax = 27.0;
  static const double lowTempWarnThreshold = 22.0; // Below this is "Too Cold!"
  static const double highTempWarnThreshold = 29.0; // Above this is "Too Hot!"

  // Water Level (derived from HC-SR04 distance)
  // These need to be calibrated for YOUR specific tank and sensor setup.
  // Example: Sensor is mounted above the water.
  // 'distance' is the measurement from the sensor to the water surface.
  static const double sensorDistanceWhenTankFullCm = 5.0; // Distance (cm) from sensor to water when tank is ideally full.
  static const double sensorDistanceWhenTankEmptyCm = 35.0; // Distance (cm) from sensor to water when tank is considered empty (or to tank bottom if preferred).
                                                          // Ensure Empty > Full. Max water column height = Empty - Full.

  SensorData({
    this.temperature,
    this.unitTemperature,
    this.humidity,
    this.unitHumidity,
    this.distance,
    this.unitDistance,
    this.mq137DigitalState,
    this.mq137Interpretation,
    this.hasError = false,
    this.errorMessage = '',
  });

  factory SensorData.fromJson(Map<String, dynamic> json) {
    double? parseDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    int? parseInt(dynamic value) {
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    bool errorPresent = json['temperature'] == 'error_read' ||
        json['humidity'] == 'error_read' ||
        json['distance'] == 'error_range' ||
        json['temperature'] == 'N/A';

    String determinedErrorMessage = "";
    if (json['temperature'] == 'N/A') determinedErrorMessage = 'AHT20 sensor not found or not reporting temperature.';
    if (json['humidity'] == 'N/A' && determinedErrorMessage.isEmpty) determinedErrorMessage = 'AHT20 sensor not found or not reporting humidity.';
    if (json['temperature'] == 'error_read' && determinedErrorMessage.isEmpty) determinedErrorMessage = 'Error reading temperature from AHT20.';
    if (json['humidity'] == 'error_read' && determinedErrorMessage.isEmpty) determinedErrorMessage = 'Error reading humidity from AHT20.';
    if (json['distance'] == 'error_range' && determinedErrorMessage.isEmpty) determinedErrorMessage = 'HC-SR04 distance sensor error or out of range.';


    return SensorData(
      temperature: parseDouble(json['temperature']),
      unitTemperature: json['unit_temperature'] ?? 'C',
      humidity: parseDouble(json['humidity']),
      unitHumidity: json['unit_humidity'] ?? '%',
      distance: parseInt(json['distance']),
      unitDistance: json['unit_distance'] ?? 'cm',
      mq137DigitalState: parseInt(json['mq137_digital_state']),
      mq137Interpretation: json['mq137_interpretation'],
      hasError: errorPresent,
      errorMessage: determinedErrorMessage,
    );
  }

  factory SensorData.error(String message) {
    return SensorData(hasError: true, errorMessage: message);
  }

  // --- Data Interpretation for Fish Tank Health ---

  String get temperatureStatus {
    if (temperature == null) return "N/A";
    if (temperature! < lowTempWarnThreshold) return "Too Cold!";
    if (temperature! < optimalTempMin) return "Cool";
    if (temperature! <= optimalTempMax) return "Optimal";
    if (temperature! <= highTempWarnThreshold) return "Warm";
    return "Too Hot!";
  }

  Color get temperatureStatusColor {
    if (temperature == null) return Colors.grey;
    String status = temperatureStatus;
    if (status == "Too Cold!" || status == "Too Hot!") return Colors.red.shade700;
    if (status == "Cool" || status == "Warm") return Colors.orange.shade600;
    return Colors.green.shade700;
  }

  double? get waterLevelPercentage {
    if (distance == null || sensorDistanceWhenTankEmptyCm <= sensorDistanceWhenTankFullCm) return null; // Invalid config or no data

    // Water in tank = (Total measurable depth) - (Air gap from full level)
    // Total measurable depth = sensorDistanceWhenTankEmptyCm - sensorDistanceWhenTankFullCm
    // Current air gap = distance - sensorDistanceWhenTankFullCm
    // Water height = (sensorDistanceWhenTankEmptyCm - sensorDistanceWhenTankFullCm) - (distance - sensorDistanceWhenTankFullCm)
    // Water height = sensorDistanceWhenTankEmptyCm - distance
    double currentWaterHeight = sensorDistanceWhenTankEmptyCm - distance!.toDouble();
    double maxWaterHeight = sensorDistanceWhenTankEmptyCm - sensorDistanceWhenTankFullCm;

    if (maxWaterHeight <= 0) return null; // Avoid division by zero or negative if config is wrong

    double percentage = (currentWaterHeight / maxWaterHeight) * 100.0;
    return percentage.clamp(0.0, 100.0); // Clamp between 0% and 100%
  }

  String get waterLevelStatus {
    final p = waterLevelPercentage;
    if (p == null) return "N/A (Check Config)";
    if (p < 20) return "Critically Low!";
    if (p < 50) return "Low"; // Adjusted threshold
    if (p <= 95) return "Optimal"; // Optimal up to 95% to allow some headroom
    return "Very High / Check Sensor"; // If it's > 95%, could be near overflow or sensor issue
  }

  Color get waterLevelStatusColor {
    final p = waterLevelPercentage;
    if (p == null) return Colors.grey;
    if (p < 20) return Colors.red.shade700;
    if (p < 50) return Colors.orange.shade600;
    if (p <= 95) return Colors.green.shade700;
    return Colors.blue.shade400; // For "Very High"
  }

  // MQ-137 Interpretation:
  // ESP32 code: `(mq137DigitalValue == HIGH) ? "Gas detected above threshold" : "Gas below threshold"`
  // ESP32 comment: "Typically, DOUT goes LOW when gas is detected above the threshold."
  // This means if your specific MQ-137 module's DOUT goes LOW on detection,
  // the ESP32's current interpretation string would be "Gas below threshold" when ammonia is HIGH.
  // YOU MUST VERIFY THIS FOR YOUR MODULE.
  // For this code, we assume the string `mq137Interpretation` from ESP32 is the source of truth for "alert".
  String get ammoniaAlertStatus {
    if (mq137Interpretation == null) return "N/A";
    // Assuming "Gas detected above threshold" is the alert condition.
    if (mq137Interpretation!.toLowerCase().contains("above threshold")) {
      return "High Ammonia/Gas Detected!";
    }
    return "Levels Normal";
  }

  Color get ammoniaAlertColor {
    if (mq137Interpretation == null) return Colors.grey;
    if (ammoniaAlertStatus.contains("High")) return Colors.red.shade700;
    return Colors.green.shade700;
  }

  String get overallHealthSummary {
    if (hasError && errorMessage.isNotEmpty) return "Error: $errorMessage";
    if (temperatureStatus == "Too Cold!" || temperatureStatus == "Too Hot!") return "Warning: Temperature critical!";
    if (waterLevelStatus == "Critically Low!") return "Warning: Water level critical!";
    if (ammoniaAlertStatus.contains("High")) return "Warning: High Ammonia/Gas levels!";

    bool tempOk = temperatureStatus == "Optimal" || temperatureStatus == "Cool" || temperatureStatus == "Warm";
    bool waterOk = waterLevelStatus == "Optimal" || waterLevelStatus == "Low"; // "Low" might be acceptable temporarily
    bool ammoniaOk = ammoniaAlertStatus == "Levels Normal";

    if (tempOk && waterOk && ammoniaOk) {
      if (temperatureStatus == "Optimal" && waterLevelStatus == "Optimal") {
        return "Tank health is Optimal.";
      }
      return "Tank conditions are Acceptable. Monitor closely.";
    }
    // If not all are explicitly OK, but no critical warnings, imply general caution.
    return "Check individual parameters; some may be suboptimal.";
  }

  Color get overallHealthColor {
    if (hasError) return Colors.red.shade900;
    String summary = overallHealthSummary;
    if (summary.contains("critical!") || summary.contains("High Ammonia/Gas")) return Colors.red.shade700;
    if (summary.contains("Warning:") || summary.contains("suboptimal")) return Colors.orange.shade600;
    if (summary.contains("Optimal")) return Colors.green.shade700;
    return Colors.blueGrey; // For "Acceptable" or other states
  }
}