import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const Color colorMainBlue = Color(0xFF11213D);
  static const Color colorSubGrey = Color(0xFFADAFC6);
  static const Color colorAccentOrange = Color(0xFFF9C895);
  static const Color colorInputBg = Color(0xFFF5F6F8);

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  int _failedAttempts = 0;
  bool _isLocked = false;
  int _secondsRemaining = 120;
  Timer? _timer;
  bool _isLoading = false;

  void _startCountdown() {
    setState(() {
      _isLocked = true;
      _secondsRemaining = 120;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _timer?.cancel();
        setState(() {
          _isLocked = false;
          _failedAttempts = 0;
        });
      }
    });
  }

  Future<void> _handleLogin() async {
    if (_isLocked) {
      _showLockedDialog();
      return;
    }

    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email dan Password tidak boleh kosong!")),
      );
      return;
    }

    setState(() => _isLoading = true);

    const String apiUrl = "https://alkesmamed.com/api/login-mobile";

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Accept": "application/json"},
        body: {
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
        },
      );

      print("Response API: ${response.body}");

      if (response.statusCode == 200) {
        var responseData = jsonDecode(response.body);
        _failedAttempts = 0;

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Login Berhasil!"),
            backgroundColor: Colors.green,
          ),
        );

        String adminName = responseData['user']['name'];

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardScreen(adminName: adminName),
          ),
          (route) => false,
        );
      } else {
        _failedAttempts++;
        var errorData = jsonDecode(response.body);

        // 🔥 AUTO CLEAR FIELD JIKA GAGAL
        _emailController.clear();
        _passwordController.clear();

        if (_failedAttempts >= 3) {
          _startCountdown();
          _showLockedDialog();
        } else {
          // 🔥 MUNCULKAN POPUP ERROR YANG MENARIK
          _showErrorPopup(
            errorData['message'] ?? 'Email atau Password salah!',
            3 - _failedAttempts,
          );
        }
      }
    } catch (e) {
      _emailController.clear();
      _passwordController.clear();
      _showErrorPopup(
        "Koneksi Error: Pastikan internet aktif atau server merespon!",
        3 - _failedAttempts,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- POPUP ERROR GAGAL LOGIN ---
  void _showErrorPopup(String message, int sisaPercobaan) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 50,
                ),
              ).animate().shake(duration: 500.ms), // Animasi getar
              const SizedBox(height: 20),
              Text(
                "Login Gagal!",
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: colorMainBlue,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                "Sisa percobaan: $sisaPercobaan",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorMainBlue,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    "Coba Lagi",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- POPUP TERKUNCI ---
  void _showLockedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Akses Terblokir", textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_clock, color: Colors.red, size: 60),
            const SizedBox(height: 15),
            const Text("Terlalu banyak percobaan gagal. Tunggu:"),
            const SizedBox(height: 10),
            Text(
              "${(_secondsRemaining ~/ 60).toString().padLeft(2, '0')}:${(_secondsRemaining % 60).toString().padLeft(2, '0')}",
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: colorMainBlue,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            children: [
              const SizedBox(height: 80),

              // 🔥 KEMBALI MENGGUNAKAN LOGO ASLI BOS
              Center(
                child:
                    Container(
                          height: 140,
                          width: 140,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            image: DecorationImage(
                              image: AssetImage('assets/images/logo_mig.png'),
                              fit: BoxFit.contain,
                            ),
                          ),
                        )
                        .animate()
                        .fadeIn(duration: 600.ms)
                        .scale(curve: Curves.easeOutBack),
              ),

              const SizedBox(height: 40),

              Text(
                "Portal Admin",
                style: GoogleFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: colorMainBlue,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                "Silakan masuk menggunakan akun admin Alkes Mamed.",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: colorSubGrey, fontSize: 13),
              ),

              const SizedBox(height: 40),

              _buildFieldInput(
                "Email Admin",
                _emailController,
                Icons.email_outlined,
              ),
              const SizedBox(height: 15),
              _buildFieldInput(
                "Password",
                _passwordController,
                Icons.lock_outline,
                isSecret: true,
              ),

              const SizedBox(height: 30),

              SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: (_isLocked || _isLoading)
                          ? null
                          : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isLocked
                            ? Colors.grey
                            : colorAccentOrange,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              _isLocked
                                  ? "Terkunci ($_secondsRemaining s)"
                                  : "Masuk ke Sistem",
                              style: const TextStyle(
                                color: colorMainBlue,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  )
                  .animate(onPlay: (c) => c.repeat())
                  .shimmer(delay: 3.seconds, color: Colors.white24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldInput(
    String hint,
    TextEditingController ctrl,
    IconData icon, {
    bool isSecret = false,
  }) {
    return TextField(
      controller: ctrl,
      obscureText: isSecret,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: colorSubGrey),
        hintText: hint,
        hintStyle: GoogleFonts.poppins(color: colorSubGrey, fontSize: 14),
        filled: true,
        fillColor: colorInputBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
      ),
    );
  }
}
