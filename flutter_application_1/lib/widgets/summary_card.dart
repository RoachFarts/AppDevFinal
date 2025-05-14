// lib/widgets/summary_card.dart
import 'package:flutter/material.dart';

class SummaryCard extends StatelessWidget {
  final String summaryText;
  final Color backgroundColor;
  final IconData iconData;

  const SummaryCard({
    super.key,
    required this.summaryText,
    required this.backgroundColor,
    required this.iconData,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3.0,
      color: backgroundColor.withOpacity(0.15), // Light background color
      margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 4.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: <Widget>[
            Icon(iconData, size: 32.0, color: backgroundColor),
            const SizedBox(width: 12.0),
            Expanded(
              child: Text(
                summaryText,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: backgroundColor.computeLuminance() > 0.5
                          ? Colors.black87 // Dark text for light backgrounds
                          : Colors.white, // Light text for dark backgrounds
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}