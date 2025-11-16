import 'package:flutter/material.dart';
import 'connect_page.dart';

class AppColors {
  static const Color bgDark = Color(0xFF222222);
  static const Color bgLight = Color(0xFFeeeeee);
}

class OnboardPage extends StatelessWidget {
  const OnboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      body: ListView(
        children: [
          const SizedBox(height: 40),

          // Logo
          Image.asset('assets/images/peppy_logo.jpeg', width: 80, height: 80),
          const SizedBox(height: 40),

          // Title text
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              'your safety,\nyour control,\nyour peppy.',
              textAlign: TextAlign.left,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 48,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 60),

          // Buttons
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24.0),
            child: ElevatedButton.icon(
              onPressed: () async {},
              icon: const Icon(Icons.email_outlined, size: 20),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
                child: Text(
                  'Continue With Email',
                  style: TextStyle(fontSize: 15),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24.0),
            child: ElevatedButton.icon(
              onPressed: () async {},
              icon: const Icon(Icons.g_mobiledata_rounded, size: 30),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
                child: Text(
                  'Continue With Google',
                  style: TextStyle(fontSize: 15),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24.0),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ConnectPage()),
                );
              },
              icon: const Icon(Icons.person, size: 25),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
                child: Text(
                  'Continue As Guest',
                  style: TextStyle(fontSize: 15),
                ),
              ),
            ),
          ),

          const SizedBox(height: 100),

          // ⚖️ Terms & Privacy Text
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 16.0,
            ),
            child: Text.rich(
              TextSpan(
                text: 'By continuing, you agree to our ',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontSize: 13,
                ),
                children: [
                  TextSpan(
                    text: 'Terms of Service',
                    style: TextStyle(
                      color: isDark ? Colors.blue[300] : Colors.blue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const TextSpan(text: ' and '),
                  TextSpan(
                    text: 'Privacy Policy.',
                    style: TextStyle(
                      color: isDark ? Colors.blue[300] : Colors.blue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
