import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatefulWidget {
  final bool musicEnabled;
  final bool menuMusicEnabled;
  final bool sfxEnabled;
  final ValueChanged<bool> onMusicChanged;
  final ValueChanged<bool> onMenuMusicChanged;
  final ValueChanged<bool> onSfxChanged;
  final VoidCallback onBack;

  const SettingsScreen({
    super.key,
    required this.musicEnabled,
    required this.menuMusicEnabled,
    required this.sfxEnabled,
    required this.onMusicChanged,
    required this.onMenuMusicChanged,
    required this.onSfxChanged,
    required this.onBack,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _musicEnabled;
  late bool _menuMusicEnabled;
  late bool _sfxEnabled;

  @override
  void initState() {
    super.initState();
    _musicEnabled = widget.musicEnabled;
    _menuMusicEnabled = widget.menuMusicEnabled;
    _sfxEnabled = widget.sfxEnabled;
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              'assets/images/background.jpg',
              fit: BoxFit.cover,
            ),
          ),

          // Settings UI
          Column(
            children: [
              AppBar(
                backgroundColor: Colors.black.withOpacity(0.3),
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: widget.onBack,
                ),
                title: const Text('Settings',
                    style: TextStyle(color: Colors.white)),
                centerTitle: true,
              ),
              Expanded(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    constraints: const BoxConstraints(maxWidth: 400),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Game Music
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.music_note,
                                    color: Colors.lightBlueAccent),
                                SizedBox(width: 12),
                                Text('Game Music',
                                    style: TextStyle(
                                        fontSize: 18, color: Colors.white)),
                              ],
                            ),
                            Switch(
                              value: _musicEnabled,
                              activeColor: Colors.lightBlueAccent,
                              onChanged: (value) async {
                                setState(() => _musicEnabled = value);
                                widget.onMusicChanged(value);
                                final prefs =
                                    await SharedPreferences.getInstance();
                                prefs.setBool('music_enabled', value);
                              },
                            ),
                          ],
                        ),
                        const Divider(color: Colors.white24, height: 32),

                        // Menu Music
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.library_music,
                                    color: Colors.purpleAccent),
                                SizedBox(width: 12),
                                Text('Menu Music',
                                    style: TextStyle(
                                        fontSize: 18, color: Colors.white)),
                              ],
                            ),
                            Switch(
                              value: _menuMusicEnabled,
                              activeColor: Colors.purpleAccent,
                              onChanged: (value) async {
                                setState(() => _menuMusicEnabled = value);
                                widget.onMenuMusicChanged(value);
                                final prefs =
                                    await SharedPreferences.getInstance();
                                prefs.setBool('menu_music_enabled', value);
                                if (value) {
                                  FlameAudio.bgm.play('menu_music.mp3');
                                } else {
                                  FlameAudio.bgm.stop();
                                }
                              },
                            ),
                          ],
                        ),
                        const Divider(color: Colors.white24, height: 32),

                        // SFX
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.volume_up,
                                    color: Colors.orangeAccent),
                                SizedBox(width: 12),
                                Text('Sound Effects',
                                    style: TextStyle(
                                        fontSize: 18, color: Colors.white)),
                              ],
                            ),
                            Switch(
                              value: _sfxEnabled,
                              activeColor: Colors.orangeAccent,
                              onChanged: (value) async {
                                setState(() => _sfxEnabled = value);
                                widget.onSfxChanged(value);
                                final prefs =
                                    await SharedPreferences.getInstance();
                                prefs.setBool('sfx_enabled', value);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),

                        // Social / Contact buttons
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.pinkAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 14),
                          ),
                          icon:
                              const Icon(Icons.camera_alt, color: Colors.white),
                          label: const Text("Follow us on Instagram",
                              style: TextStyle(color: Colors.white)),
                          onPressed: () {
                            _launchUrl(
                                "https://www.instagram.com/mtsquared.techs/?igsh=MWJhNzVnM2FhM243cQ%3D%3D");
                          },
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 14),
                          ),
                          icon: const Icon(Icons.public, color: Colors.white),
                          label: const Text("Visit our Website",
                              style: TextStyle(color: Colors.white)),
                          onPressed: () {
                            _launchUrl("https://mtsqtechs.com");
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
