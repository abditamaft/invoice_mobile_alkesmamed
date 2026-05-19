import 'package:flutter/material.dart';
import 'screens/login_screen.dart'; // 🔥 Pastikan import ini ada!

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Alkes Mamed Admin',
      debugShowCheckedModeBanner:
          false, // Menghilangkan pita "DEBUG" di pojok kanan atas biar pro
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF11213D)),
        useMaterial3: true,
      ),
      // 🔥 KUNCI UTAMANYA DI SINI: Arahkan tampilan pertama ke halaman Login
      home: const LoginScreen(),
    );
  }
}
