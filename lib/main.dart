import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'screens/payment_callback_screen.dart';
import 'screens/splash_screen.dart';
import 'services/supabase_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (SupabaseService.isConfigured) {
    await SupabaseService.initialize();
  }
  runApp(const AlmamouraApp());
}

/// Root widget for the Almamoura Film Festival app prototype.
class AlmamouraApp extends StatelessWidget {
  const AlmamouraApp({super.key});

  @override
  Widget build(BuildContext context) {
    final callbackPaymentId =
        kIsWeb ? Uri.base.queryParameters['payment_id'] : null;
    return MaterialApp(
      title: 'Almamoura Film Festival',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
      home: callbackPaymentId == null || callbackPaymentId.isEmpty
          ? const SplashScreen()
          : PaymentCallbackScreen(paymentId: callbackPaymentId),
    );
  }
}
