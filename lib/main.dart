import 'package:flutter/material.dart';
import 'screens/auth_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ExoManiaApp());
}

class ExoManiaApp extends StatelessWidget {
  const ExoManiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EXOmania',
      // هنا بنخلي الـ Theme الأساسي داكن عشان تأثير النيون يظ
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(
          0xFF0D0D1A,
        ), // لون كحلي غامق جداً يميل للأسود
      ),
      home: const AuthScreen(),
    );
  }
}
