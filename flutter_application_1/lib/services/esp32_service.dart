// lib/services/esp32_service.dart
import 'dart:convert';
import 'dart:async'; // For TimeoutException
import 'package:http/http.dart' as http;
import '../models/sensor_data.dart';

class Esp32Service {
  String _esp32Ip = "192.168.1.26"; 

  void setEspIpAddress(String ip) {
    _esp32Ip = ip.trim();
  }

  String getEspIpAddress() {
    return _esp32Ip;
  }

  Future<SensorData> fetchSensorData() async {
    if (_esp32Ip.isEmpty) {
      return SensorData.error("ESP32 IP Address is not set.");
    }
    final String urlString = 'http://$_esp32Ip/data';
    // print('Attempting to fetch data from: $urlString');

    try {
      final response = await http.get(Uri.parse(urlString)).timeout(const Duration(seconds: 7));

      if (response.statusCode == 200) {
        // print('Data received: ${response.body}');
        try {
          final Map<String, dynamic> data = jsonDecode(response.body);
          return SensorData.fromJson(data);
        } catch (e) {
          // print('Error parsing JSON: $e');
          // print('Problematic JSON string: ${response.body}');
          return SensorData.error("Failed to parse data from ESP32. Invalid JSON format.");
        }
      } else {
        // print('Failed to load sensor data. Status code: ${response.statusCode}');
        // print('Response body: ${response.body}');
        return SensorData.error(
            'ESP32 Connection Error (Status ${response.statusCode}). Check IP & server.');
      }
    } on TimeoutException {
      // print('Connection to $urlString timed out.');
      return SensorData.error('Connection to ESP32 timed out. Check IP & Wi-Fi.');
    } on http.ClientException catch (e) { // Catches socket exceptions, host lookup errors etc.
        // print('HTTP Client Exception: $e');
        if (e.message.contains("Failed host lookup") || e.message.contains("No address associated")) {
            return SensorData.error('Invalid ESP32 IP Address or device not found on network.');
        } else if (e.message.contains("Connection refused")) {
            return SensorData.error('Connection refused by ESP32. Server might not be running.');
        }
        return SensorData.error('Network error connecting to ESP32: ${e.message}.');
    }
    catch (e) {
      // print('An unexpected error occurred: $e');
      return SensorData.error('Unexpected error: ${e.toString()}');
    }
  }
}