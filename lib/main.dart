import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const RentCarApp());
}

class RentCarApp extends StatelessWidget {
  const RentCarApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Primary green accent matching web (green-600)
    const primaryGreen = Color(0xFF16A34A);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Car Rental Mobile',
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: primaryGreen,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryGreen,
          primary: primaryGreen,
          secondary: const Color(0xFF15803D), // green-700
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF9FAFB),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 1,
          iconTheme: IconThemeData(color: Colors.black87),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryGreen,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
