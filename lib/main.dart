import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/staff/staff_dashboard_screen.dart';
import 'screens/driver/driver_dashboard_screen.dart';
import 'services/auth_api_service.dart';

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
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthApiService _authService = AuthApiService();
  bool _isLoading = true;
  Widget? _startScreen;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final loggedIn = await _authService.isLoggedIn();
    if (!loggedIn) {
      setState(() {
        _startScreen = const LoginScreen();
        _isLoading = false;
      });
      return;
    }

    final role = await _authService.getRole();
    if (role != null) {
      final roleUpper = role.toUpperCase();
      Widget nextScreen;
      if (roleUpper == 'ADMIN') {
        nextScreen = AdminDashboardScreen(onLogout: _handleLogout);
      } else if (roleUpper == 'STAFF') {
        nextScreen = StaffDashboardScreen(onLogout: _handleLogout);
      } else if (roleUpper == 'DRIVER') {
        nextScreen = DriverDashboardScreen(onLogout: _handleLogout);
      } else {
        nextScreen = const HomeScreen();
      }
      setState(() {
        _startScreen = nextScreen;
        _isLoading = false;
      });
    } else {
      setState(() {
        _startScreen = const LoginScreen();
        _isLoading = false;
      });
    }
  }

  void _handleLogout() async {
    await _authService.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF16A34A)),
          ),
        ),
      );
    }
    return _startScreen ?? const LoginScreen();
  }
}
