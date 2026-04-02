import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onNavigateToLogin;

  const SplashScreen({required this.onNavigateToLogin, super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      widget.onNavigateToLogin();
    } catch (e, stack) {
      debugPrint('SplashScreen error: $e');
      debugPrintStack(stackTrace: stack);
      if (!mounted) return;
      widget.onNavigateToLogin();
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0D47A1),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.storefront_rounded, size: 72, color: Colors.white),
              SizedBox(height: 14),
              Text(
                'Bharat Provision',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 16),
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
