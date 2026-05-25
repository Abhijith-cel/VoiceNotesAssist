import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'scan_screen.dart';
import 'history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final FlutterTts _tts = FlutterTts();

  @override
  void initState() {
    super.initState();
    WidgetsBindingObserver;
    _initTts();
    // Small delay so TTS is ready before speaking
    Future.delayed(const Duration(milliseconds: 800), () {
      _speak(
        'Welcome to Blind Notes AI. '
        'There are two buttons. '
        'Double tap the top purple button to scan a new note. '
        'Double tap the bottom green button to view your saved notes history.',
      );
    });
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
  }

  Future<void> _speak(String text) async {
    await _tts.stop();
    await _tts.speak(text);
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),

            // App title
            const Text(
              'Blind Notes AI',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'AI-powered note reader',
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
            const SizedBox(height: 60),

            // ── SCAN BUTTON ──
            Semantics(
              label: 'Scan Note button. Double tap to open camera and scan a note.',
              button: true,
              child: GestureDetector(
                onTap: () {
                  // Single tap = announce what this button does
                  HapticFeedback.lightImpact();
                  _speak('Scan Note button. Double tap to open camera.');
                },
                onDoubleTap: () {
                  HapticFeedback.mediumImpact();
                  _speak('Opening camera.');
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ScanScreen()),
                  );
                },
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  height: 160,
                  decoration: BoxDecoration(
                    color: Colors.deepPurple,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt, color: Colors.white, size: 60),
                      SizedBox(height: 12),
                      Text('SCAN NOTE',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold)),
                      Text('Double tap to open camera',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── HISTORY BUTTON ──
            Semantics(
              label: 'History button. Double tap to view your saved notes.',
              button: true,
              child: GestureDetector(
                onTap: () {
                  // Single tap = announce what this button does
                  HapticFeedback.lightImpact();
                  _speak('History button. Double tap to view saved notes.');
                },
                onDoubleTap: () {
                  HapticFeedback.mediumImpact();
                  _speak('Opening history.');
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HistoryScreen()),
                  );
                },
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  height: 160,
                  decoration: BoxDecoration(
                    color: Colors.teal.shade800,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, color: Colors.white, size: 60),
                      SizedBox(height: 12),
                      Text('HISTORY',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold)),
                      Text('Double tap to view saved notes',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ),

            const Spacer(),

            // Help text at bottom
            GestureDetector(
              onTap: () {
                _speak(
                  'Help. '
                  'Single tap any button to hear what it does. '
                  'Double tap any button to activate it. '
                  'Double tap Scan Note to open the camera. '
                  'Double tap History to see your saved notes.',
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.help_outline, color: Colors.white54, size: 20),
                    SizedBox(width: 8),
                    Text('Tap here for help',
                        style:
                            TextStyle(color: Colors.white54, fontSize: 14)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}