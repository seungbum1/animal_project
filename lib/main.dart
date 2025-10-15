import 'package:animal_project/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

// The main function needs to be async to wait for initialization.
void main() async {
  // Ensure that Flutter bindings are initialized before calling native code.
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Initialize locale data for Korean. This line was missing.
  await initializeDateFormatting('ko_KR', null);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Define the app's global theme.
      theme: ThemeData(
        fontFamily: 'NotoSansKR',
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSwatch().copyWith(
          background: const Color(0xFFFFF7E7), // Background color
          primary: const Color(0xFFC06362),    // Primary point color (burgundy)
          secondary: const Color(0xFFD9D9D9),   // Profile picture background
          onSurface: const Color(0xFF616161),   // Text color for charts and graphs
        ),
      ),
      // Set the initial screen of the app.
      home: const SplashScreen(),
    );
  }
}
