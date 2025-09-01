import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: widget.onBack,
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSettingTile(
                icon: Icons.music_note,
                title: 'Game Music',
                subtitle: 'Background music during gameplay',
                color: Colors.lightBlueAccent,
                value: _musicEnabled,
                onChanged: (value) async {
                  setState(() => _musicEnabled = value);
                  widget.onMusicChanged(value);
                  final prefs = await SharedPreferences.getInstance();
                  prefs.setBool('music_enabled', value);
                },
              ),
              const SizedBox(height: 16),
              _buildSettingTile(
                icon: Icons.queue_music,
                title: 'Menu Music',
                subtitle: 'Theme music in the main menu',
                color: Colors.purpleAccent,
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
              const SizedBox(height: 16),
              _buildSettingTile(
                icon: Icons.volume_up,
                title: 'Sound Effects',
                subtitle: 'Enable in-game sound effects',
                color: Colors.orangeAccent,
                value: _sfxEnabled,
                onChanged: (value) async {
                  setState(() => _sfxEnabled = value);
                  widget.onSfxChanged(value);
                  final prefs = await SharedPreferences.getInstance();
                  prefs.setBool('sfx_enabled', value);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 14, color: Colors.white.withOpacity(0.7))),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: color,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
