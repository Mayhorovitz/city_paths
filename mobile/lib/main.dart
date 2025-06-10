import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:city_path/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
    print('Environment loaded successfully');
    final apiKey = dotenv.env['MAPS_API_KEY'];
    print('API Key found: ${apiKey != null}');
    if (apiKey != null) {
      print('API Key length: ${apiKey.length}');
      print('API Key starts with: ${apiKey.substring(0, 10)}...');
    }
    print('All env keys: ${dotenv.env.keys.toList()}');
  } catch (e) {
    print('Error loading .env file: $e');
  }

  runApp(const CityPathApp());
}

class CityPathApp extends StatelessWidget {
  const CityPathApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'City Path',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(
          0xFFF9F2E9,
        ), // App background color
      ),
      home: const SplashScreen(), // Start with splash screen
      debugShowCheckedModeBanner: false,
    );
  }
}
