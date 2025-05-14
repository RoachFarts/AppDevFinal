// lib/widgets/sensor_card.dart
import 'package:flutter/material.dart';

class SensorCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData iconData;
  final Color statusColor;
  final String? statusText;

  const SensorCard({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
    required this.iconData,
    required this.statusColor,
    this.statusText,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(iconData, size: 28.0, color: statusColor),
                const SizedBox(width: 10.0),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8.0),
            Text(
              '$value ${unit.isNotEmpty ? unit : ''}'.trim(),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
            ),
            if (statusText != null && statusText!.isNotEmpty) ...[
              const SizedBox(height: 6.0),
              Text(
                statusText!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}