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
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600)),
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
                        // Audio Settings Section
                        Container(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            children: [
                              Icon(Icons.settings_outlined,
                                  color: Colors.white.withOpacity(0.8),
                                  size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Audio Settings',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.7),
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Game Music
                        _buildSettingRow(
                          icon: Icons.music_note,
                          iconColor: Colors.lightBlueAccent,
                          title: 'Game Music',
                          value: _musicEnabled,
                          onChanged: (value) async {
                            setState(() => _musicEnabled = value);
                            widget.onMusicChanged(value);
                            final prefs = await SharedPreferences.getInstance();
                            prefs.setBool('music_enabled', value);
                          },
                        ),

                        // Menu Music
                        _buildSettingRow(
                          icon: Icons.library_music,
                          iconColor: Colors.purpleAccent,
                          title: 'Menu Music',
                          value: _menuMusicEnabled,
                          onChanged: (value) async {
                            setState(() => _menuMusicEnabled = value);
                            widget.onMenuMusicChanged(value);
                            final prefs = await SharedPreferences.getInstance();
                            prefs.setBool('menu_music_enabled', value);
                            if (value) {
                              FlameAudio.bgm.play('menu_music.mp3');
                            } else {
                              FlameAudio.bgm.stop();
                            }
                          },
                        ),

                        // SFX
                        _buildSettingRow(
                          icon: Icons.volume_up,
                          iconColor: Colors.orangeAccent,
                          title: 'Sound Effects',
                          value: _sfxEnabled,
                          onChanged: (value) async {
                            setState(() => _sfxEnabled = value);
                            widget.onSfxChanged(value);
                            final prefs = await SharedPreferences.getInstance();
                            prefs.setBool('sfx_enabled', value);
                          },
                        ),

                        const SizedBox(height: 32),

                        // About Section
                        Container(
                          padding: const EdgeInsets.only(top: 16),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color: Colors.white.withOpacity(0.1),
                                width: 1,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.info_outline,
                                      color: Colors.white.withOpacity(0.8),
                                      size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'About',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white.withOpacity(0.7),
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Professional contact links
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildContactButton(
                                      icon: Icons.language,
                                      label: 'Website',
                                      onPressed: () =>
                                          _launchUrl("https://mtsqtechs.com"),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildContactButton(
                                      icon: Icons.camera_alt_outlined,
                                      label: 'Instagram',
                                      onPressed: () => _launchUrl(
                                          "https://www.instagram.com/mtsquared.techs/?igsh=MWJhNzVnM2FhM243cQ%3D%3D"),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // Version/Company info
                              Center(
                                child: Text(
                                  'Made by MT² Technologies',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.5),
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                            ],
                          ),
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

  Widget _buildSettingRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Switch(
            value: value,
            activeColor: iconColor,
            inactiveThumbColor: Colors.grey,
            inactiveTrackColor: Colors.grey.withOpacity(0.3),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildContactButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: Colors.white.withOpacity(0.8),
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
