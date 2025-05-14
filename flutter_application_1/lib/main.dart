// lib/main.dart
import 'package:flutter/material.dart';
import 'screens/dashboard_screen.dart';

void main() {
  runApp(const FishTankApp());
}

class FishTankApp extends StatelessWidget {
  const FishTankApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Anemone 🐟',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        // useMaterial3: true, // Uncomment if you want to try Material 3
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.teal,
          brightness: Brightness.light,
        ).copyWith(
          secondary: Colors.amberAccent,
        ),
        appBarTheme: const AppBarTheme(
          elevation: 1.0,
          // backgroundColor: Colors.teal, // If not using primarySwatch for appBar
          // foregroundColor: Colors.white, // For text/icons on appBar
        ),
        cardTheme: CardTheme(
          elevation: 2.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: const DashboardScreen(),
    );
  }
}