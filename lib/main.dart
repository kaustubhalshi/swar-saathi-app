import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:swar_music_app/services/notification_service.dart';
import 'package:swar_music_app/services/revenuecat_service.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, // Make status bar transparent
      systemNavigationBarColor: Colors.transparent, // Make nav bar transparent
      statusBarIconBrightness: Brightness.dark, // Or light
      systemNavigationBarIconBrightness: Brightness.dark, // Or light
    ),
  );

  await Firebase.initializeApp();
  // Initialize subscription service
  try {
    final revenueCatService = RevenueCatService();
    await revenueCatService.initialize();
  } catch (e) {
    print('Failed to initialize RevenueCat: $e');
  }

  await NotificationService().initialize();

  runApp(SwarSathiApp());
}

class SwarSathiApp extends StatelessWidget {
  const SwarSathiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Swar Sathi',
      theme: ThemeData(
        primaryColor: Color(0xFFFF6B35),
        fontFamily: 'Outfit',
        visualDensity: VisualDensity.adaptivePlatformDensity, colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.deepOrange).copyWith(background: Color(0xFFF7F3E9)),
      ),
      home: SplashScreen(),
      routes: {
        '/onboarding': (context) => OnboardingScreen(),
        '/login': (context) => LoginScreen(),
        '/home': (context) => HomeScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
