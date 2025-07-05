import 'package:flutter/material.dart';

class MenuScreen extends StatelessWidget {
  final VoidCallback onPlay;
  final VoidCallback onSettings;
  final VoidCallback onSkins;

  const MenuScreen({
    Key? key,
    required this.onPlay,
    required this.onSettings,
    required this.onSkins,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: const Color(0xFF0a0a1a),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 2),
            Text(
              'Magnet Walker',
              style: TextStyle(
                fontSize: screenSize.width * 0.12,
                fontWeight: FontWeight.bold,
                color: Colors.cyanAccent,
                letterSpacing: 2.0,
                shadows: [
                  Shadow(
                    offset: Offset(0, 0),
                    blurRadius: 16,
                    color: Colors.cyanAccent.withOpacity(0.5),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            SizedBox(
              width: screenSize.width * 0.7,
              child: ElevatedButton(
                onPressed: onPlay,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pinkAccent,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 8,
                ),
                child: const Text(
                  'Play',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: screenSize.width * 0.7,
              child: ElevatedButton.icon(
                onPressed: onSkins,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8844ff),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 8,
                ),
                icon: const Text(
                  '👕',
                  style: TextStyle(fontSize: 20),
                ),
                label: const Text(
                  'Skins',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: screenSize.width * 0.7,
              child: OutlinedButton(
                onPressed: onSettings,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.cyanAccent, width: 2),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Colors.cyanAccent,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ),
            const Spacer(flex: 3),
          ],
        ),
      ),
    );
  }
}
