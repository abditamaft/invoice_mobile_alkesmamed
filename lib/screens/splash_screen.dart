import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'login_screen.dart'; // Ganti ke LoginScreen setelah loading selesai
import 'package:shared_preferences/shared_preferences.dart';
import 'dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // Warna Brand Alkes Mamed (Samakan dengan Login/Dashboard)
  static const Color kPrimary = Color(0xFF11213D);
  static const Color kAccent = Color(0xFFF9C895);

  @override
  void initState() {
    super.initState();
    // 🔥 DURASI SPLASH SCREEN (misal 3.5 detik)
    Timer(const Duration(milliseconds: 3500), () {
      _checkLoginStatus();
    });
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final String? adminName = prefs.getString('admin_name');
    final int? loginTimestamp = prefs.getInt('login_timestamp');

    if (adminName != null && loginTimestamp != null) {
      final loginTime = DateTime.fromMillisecondsSinceEpoch(loginTimestamp);
      final now = DateTime.now();
      final diff = now.difference(loginTime).inDays;

      // 🔥 Jika belum 7 hari, langsung masuk Dashboard
      if (diff < 7) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardScreen(adminName: adminName),
          ),
        );
        return;
      }
    }

    // Jika tidak ada sesi atau sudah expired → ke Login
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Latar putih bersih
      body: Stack(
        children: [
          // Bagian Tengah: Logo & Nama
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 🔥 ANIMASI LOGO PT MIG
                Container(
                      height: 120,
                      width: 120,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        image: DecorationImage(
                          image: AssetImage('assets/images/logo_mig.png'),
                          fit: BoxFit.contain,
                        ),
                      ),
                    )
                    .animate()
                    .fadeIn(
                      duration: 800.ms,
                      curve: Curves.easeIn,
                    ) // Muncul pelan
                    .scale(
                      delay: 200.ms,
                      duration: 600.ms,
                      begin: const Offset(0.8, 0.8),
                      end: const Offset(1.0, 1.0),
                      curve: Curves.easeOutBack,
                    ), // Sedikit membesar

                const SizedBox(height: 25),

                // 🔥 ANIMASI TEKS NAMA APK
                Text(
                      "Invoice Alkesmamed",
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: kPrimary,
                        letterSpacing: 0.5,
                      ),
                    )
                    .animate()
                    .fadeIn(
                      delay: 1000.ms,
                      duration: 600.ms,
                    ) // Muncul setelah logo
                    .slideY(
                      begin: 0.3,
                      end: 0,
                      curve: Curves.easeOutCubic,
                    ), // Geser sedikit dari bawah

                const SizedBox(height: 5),

                // 🔥 ANIMASI SLOGAN KECIL
                Text(
                  "Sistem Manajemen Invoice PT. MIG",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w400,
                  ),
                ).animate().fadeIn(delay: 1400.ms, duration: 500.ms),
              ],
            ),
          ),

          // Bagian Bawah: Loading Indicator (Opsional tapi Pro)
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Center(
              child: const SizedBox(
                width: 40,
                height: 3,
                child: LinearProgressIndicator(
                  backgroundColor: Color(0xFFE0E0E0),
                  valueColor: AlwaysStoppedAnimation<Color>(kAccent),
                ),
              ).animate().fadeIn(delay: 1800.ms).scale(delay: 1800.ms),
            ),
          ),
        ],
      ),
    );
  }
}
