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
      backgroundColor: const Color(0xFF101020),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: widget.onBack,
        ),
        title: const Text('Settings', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.music_note, color: Colors.lightBlueAccent),
                      SizedBox(width: 12),
                      Text('Game Music',
                          style: TextStyle(fontSize: 18, color: Colors.white)),
                    ],
                  ),
                  Switch(
                    value: _musicEnabled,
                    activeColor: Colors.lightBlueAccent,
                    onChanged: (value) async {
                      setState(() => _musicEnabled = value);
                      widget.onMusicChanged(value);
                      final prefs = await SharedPreferences.getInstance();
                      prefs.setBool('music_enabled', value);
                    },
                  ),
                ],
              ),
              const Divider(color: Colors.white24, height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.music_note, color: Colors.purpleAccent),
                      SizedBox(width: 12),
                      Text('Menu Music',
                          style: TextStyle(fontSize: 18, color: Colors.white)),
                    ],
                  ),
                  Switch(
                    value: _menuMusicEnabled,
                    activeColor: Colors.purpleAccent,
                    onChanged: (value) async {
                      setState(() => _menuMusicEnabled = value);
                      widget.onMenuMusicChanged(value);
                      final prefs = await SharedPreferences.getInstance();
                      prefs.setBool('menu_music_enabled', value);
                    },
                  ),
                ],
              ),
              const Divider(color: Colors.white24, height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.volume_up, color: Colors.orangeAccent),
                      SizedBox(width: 12),
                      Text('Sound Effects',
                          style: TextStyle(fontSize: 18, color: Colors.white)),
                    ],
                  ),
                  Switch(
                    value: _sfxEnabled,
                    activeColor: Colors.orangeAccent,
                    onChanged: (value) async {
                      setState(() => _sfxEnabled = value);
                      widget.onSfxChanged(value);
                      final prefs = await SharedPreferences.getInstance();
                      prefs.setBool('sfx_enabled', value);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
