import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/app_data.dart';
import '../../../routing/app_router.dart';
import '../services/pin_storage_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    navigate();
  }

  Future<void> navigate() async {
    try {
      await const PinStorageService().initializeDefaults();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('logged_in');

      await Future<void>.delayed(const Duration(seconds: 2));

      if (!mounted) return;
      context.go(AppRouter.roleSelection);
    } catch (_) {
      if (!mounted) return;
      context.go(AppRouter.roleSelection);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D47A1),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.storefront_rounded,
                size: 72,
                color: Colors.white,
              ),
              const SizedBox(height: 14),
              FutureBuilder<String>(
                future: AppData.getShopName(),
                builder: (context, snapshot) {
                  return Text(
                    snapshot.data ?? 'ભારત પ્રોવિઝન હાપા',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              const SizedBox(
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
