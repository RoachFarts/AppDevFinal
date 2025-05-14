// lib/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import '../models/sensor_data.dart';
import '../services/esp32_service.dart';
import '../widgets/sensor_card.dart';
import '../widgets/summary_card.dart';
import 'dart:async'; // For Timer

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final Esp32Service _esp32Service = Esp32Service();
  SensorData? _sensorData;
  bool _isLoading = false;
  String _currentEspIp = "";
  Timer? _refreshTimer;

  final TextEditingController _ipController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentEspIp = _esp32Service.getEspIpAddress();
    _ipController.text = _currentEspIp;
    _fetchData(); // Initial fetch
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _ipController.dispose();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel(); // Cancel any existing timer
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!_isLoading) { // Only refresh if not already loading
        _fetchData(showLoadingIndicator: false); // Fetch silently in background
      }
    });
  }

  Future<void> _fetchData({bool showLoadingIndicator = true}) async {
    if (_currentEspIp.isEmpty) {
       if (mounted) {
        setState(() {
          _sensorData = SensorData.error("Set ESP32 IP Address first.");
          _isLoading = false;
        });
      }
      return;
    }

    if (showLoadingIndicator && mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    final data = await _esp32Service.fetchSensorData();
    if (mounted) { // Check if the widget is still in the tree
      setState(() {
        _sensorData = data;
        _isLoading = false;
      });
    }
  }

  void _showSetIpDialog() {
    _ipController.text = _esp32Service.getEspIpAddress(); // Ensure current IP is shown
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Set ESP32 IP Address"),
          content: TextField(
            controller: _ipController,
            decoration: const InputDecoration(hintText: "e.g., 192.168.1.100"),
            keyboardType: TextInputType.url,
          ),
          actions: <Widget>[
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text("Save"),
              onPressed: () {
                if (mounted) {
                  setState(() {
                    _currentEspIp = _ipController.text.trim();
                    _esp32Service.setEspIpAddress(_currentEspIp);
                  });
                }
                Navigator.of(context).pop();
                _fetchData(); // Fetch data with the new IP
                _startAutoRefresh(); // Restart timer with new IP potentially
              },
            ),
          ],
        );
      },
    );
  }

  IconData _getSummaryIcon(SensorData data) {
    if (data.hasError) return Icons.error_outline;
    String summary = data.overallHealthSummary.toLowerCase();
    if (summary.contains("critical") || summary.contains("high ammonia")) return Icons.warning_amber_rounded;
    if (summary.contains("warning") || summary.contains("suboptimal")) return Icons.info_outline_rounded;
    if (summary.contains("optimal")) return Icons.check_circle_outline_rounded;
    return Icons.thermostat_auto_rounded; // Default
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Anemone 🐟"),
        actions: <Widget>[
           IconButton(
            icon: const Icon(Icons.settings_ethernet),
            tooltip: "Set ESP32 IP",
            onPressed: _showSetIpDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh Data",
            onPressed: _isLoading ? null : () => _fetchData(),
          ),
        ],
      ),
      body: _isLoading && _sensorData == null // Show loading only if no data yet
          ? const Center(child: CircularProgressIndicator())
          : _buildDashboardContent(),
      floatingActionButton: FloatingActionButton(
        onPressed: _isLoading ? null : () => _fetchData(),
        tooltip: 'Refresh',
        child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white,)) : const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildDashboardContent() {
    if (_sensorData == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Could not load sensor data. Ensure ESP32 is connected and IP is correct.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.redAccent),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.settings_ethernet),
                label: const Text("Set/Check ESP32 IP"),
                onPressed: _showSetIpDialog,
              )
            ],
          ),
        ),
      );
    }

    // If there's an error message from sensor data object itself (e.g. sensor not found)
    // but we still have the _sensorData object.
    Widget errorBanner = const SizedBox.shrink();
    if (_sensorData!.hasError && _sensorData!.errorMessage.isNotEmpty) {
        errorBanner = Container(
            color: Colors.red.withOpacity(0.1),
            padding: const EdgeInsets.symmetric(horizontal:16.0, vertical: 8.0),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _sensorData!.errorMessage,
                    style: TextStyle(color: Colors.red.shade800, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          );
    }


    return RefreshIndicator(
      onRefresh: () => _fetchData(),
      child: ListView(
        padding: const EdgeInsets.all(10.0),
        children: <Widget>[
          errorBanner, // Show error from sensor data if any
          if (_isLoading && _sensorData != null) // Show a subtle loading bar on top if refreshing existing data
            const Padding(
              padding: EdgeInsets.only(bottom: 8.0),
              child: LinearProgressIndicator(),
            ),

          SummaryCard(
            summaryText: _sensorData!.overallHealthSummary,
            backgroundColor: _sensorData!.overallHealthColor,
            iconData: _getSummaryIcon(_sensorData!),
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(), // Disable GridView's own scrolling
            crossAxisSpacing: 8.0,
            mainAxisSpacing: 8.0,
            childAspectRatio: 1.2, // Adjust for card height
            children: <Widget>[
              SensorCard(
                title: "Temperature",
                value: _sensorData!.temperature?.toStringAsFixed(1) ?? "--",
                unit: _sensorData!.unitTemperature ?? "°C",
                iconData: Icons.thermostat_outlined,
                statusColor: _sensorData!.temperatureStatusColor,
                statusText: _sensorData!.temperatureStatus,
              ),
              SensorCard(
                title: "Water Level",
                value: _sensorData!.waterLevelPercentage?.toStringAsFixed(0) ?? "--",
                unit: "%",
                iconData: Icons.opacity_outlined, // water drop icon
                statusColor: _sensorData!.waterLevelStatusColor,
                statusText: _sensorData!.waterLevelStatus,
              ),
              SensorCard(
                title: "Ammonia/Air",
                value: _sensorData!.mq137Interpretation ?? "N/A", // Show interpretation string
                unit: "", // No unit for interpretation string
                iconData: Icons.air_outlined,
                statusColor: _sensorData!.ammoniaAlertColor,
                statusText: _sensorData!.ammoniaAlertStatus,
              ),
              SensorCard(
                title: "Air Humidity",
                value: _sensorData!.humidity?.toStringAsFixed(1) ?? "--",
                unit: _sensorData!.unitHumidity ?? "%",
                iconData: Icons.water_drop_outlined, // different icon from water level
                statusColor: Colors.blueGrey, // Neutral color, or define status for it
                statusText: "${_sensorData!.humidity?.toStringAsFixed(0) ?? '--'}% (Near Sensor)",
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 20.0, bottom: 10.0),
            child: Text(
              "Raw Data:\n"
              "  Distance: ${_sensorData!.distance ?? 'N/A'} ${_sensorData!.unitDistance ?? 'cm'}\n"
              "  MQ-137 Digital: ${_sensorData!.mq137DigitalState ?? 'N/A'}\n"
              "Connected to ESP32 at: $_currentEspIp",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}