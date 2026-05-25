import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';
import 'dart:math';
import '../services/language_service.dart';
import 'result_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  CameraController? _controller;
  final FlutterTts _tts = FlutterTts();
  final _lang = LanguageService.instance;

  bool _isProcessing = false;
  bool _autoModeActive = false;
  bool _isCountingDown = false;
  bool _firstReading = true;

  String _guidance = 'Hold camera over the note';
  String _statusIcon = '🔍';
  int _countdownValue = 3;

  // Motion detection
  StreamSubscription? _accelerometerSub;
  double _previousX = 0, _previousY = 0, _previousZ = 0;

  // Timers
  Timer? _steadyTimer;
  Timer? _countdownTimer;
  Timer? _guidanceTimer;

  // Motion history
  final List<double> _motionHistory = [];
  static const int _historySize = 8;
  static const double _steadyThreshold = 3.5;
  static const double _movingThreshold = 5.0;

  bool _waitingToCountdown = false;

  @override
  void initState() {
    super.initState();
    _lang.addListener(_onLanguageChanged);
    _initTts();
    _initCamera();
  }

  @override
  void dispose() {
    _lang.removeListener(_onLanguageChanged);
    _accelerometerSub?.cancel();
    _steadyTimer?.cancel();
    _countdownTimer?.cancel();
    _guidanceTimer?.cancel();
    _controller?.dispose();
    _tts.stop();
    super.dispose();
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _initTts() async {
    await _tts.setLanguage(_lang.ttsLocale);
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
  }

  Future<void> _speak(String text) async {
    await _tts.stop();
    await _tts.setLanguage(_lang.ttsLocale);
    await _tts.speak(text);
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      _speak(_lang.isKannada
          ? 'ಈ ಸಾಧನದಲ್ಲಿ ಕ್ಯಾಮೆರಾ ಕಂಡುಬಂದಿಲ್ಲ.'
          : 'No camera found on this device.');
      return;
    }
    _controller = CameraController(
      cameras[0],
      ResolutionPreset.high,
      enableAudio: false,
    );
    await _controller!.initialize();
    if (mounted) setState(() {});
    await Future.delayed(const Duration(milliseconds: 500));
    _speak(_lang.scanReady());
  }

  // ── START AUTO MODE ──
  void _startAutoMode() {
    if (_isProcessing || _autoModeActive) return;

    final isKannada = _lang.isKannada;
    setState(() {
      _autoModeActive = true;
      _firstReading = true;
      _waitingToCountdown = false;
      _motionHistory.clear();
      _guidance = isKannada
          ? 'ಟಿಪ್ಪಣಿ ಮೇಲೆ ಫೋನ್ ಹಿಡಿದು ಸ್ಥಿರವಾಗಿರಿ...'
          : 'Hold phone over your note and stay still...';
      _statusIcon = '🎯';
    });

    HapticFeedback.mediumImpact();
    _speak(isKannada
        ? 'ಆಟೋ ಮೋಡ್ ಪ್ರಾರಂಭ. ಟಿಪ್ಪಣಿ ಮೇಲೆ ಫೋನ್ ಸ್ಥಿರವಾಗಿ ಹಿಡಿಯಿರಿ.'
        : 'Auto mode started. Hold phone still over your note.');
    _startMotionDetection();
  }

  // ── STOP AUTO MODE ──
  void _stopAutoMode() {
    _accelerometerSub?.cancel();
    _steadyTimer?.cancel();
    _countdownTimer?.cancel();
    _guidanceTimer?.cancel();

    if (mounted) {
      final isKannada = _lang.isKannada;
      setState(() {
        _autoModeActive = false;
        _isCountingDown = false;
        _waitingToCountdown = false;
        _firstReading = true;
        _motionHistory.clear();
        _guidance = isKannada
            ? 'ಆಟೋ ಮೋಡ್ ಆಫ್. ಕೈಯಿಂದ ಸ್ಕ್ಯಾನ್ ಮಾಡಲು ಕೆಳಗಿನ ಬಟನ್ ಎರಡು ಬಾರಿ ತಟ್ಟಿ.'
            : 'Auto mode OFF. Double tap bottom button to scan manually.';
        _statusIcon = '🔍';
      });
    }
  }

  // ── MOTION DETECTION ──
  void _startMotionDetection() {
    _accelerometerSub?.cancel();
    _motionHistory.clear();
    _firstReading = true;

    _accelerometerSub = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 200),
    ).listen((AccelerometerEvent event) {
      if (!mounted || _isProcessing || !_autoModeActive) return;

      if (_firstReading) {
        _previousX = event.x;
        _previousY = event.y;
        _previousZ = event.z;
        _firstReading = false;
        return;
      }

      final dx = event.x - _previousX;
      final dy = event.y - _previousY;
      final dz = event.z - _previousZ;
      final motion = sqrt(dx * dx + dy * dy + dz * dz);

      _previousX = event.x;
      _previousY = event.y;
      _previousZ = event.z;

      _motionHistory.add(motion);
      if (_motionHistory.length > _historySize) _motionHistory.removeAt(0);
      if (_motionHistory.length < 4) return;

      final avgMotion =
          _motionHistory.reduce((a, b) => a + b) / _motionHistory.length;
      _processMotion(avgMotion, event);
    });
  }

  void _processMotion(double avgMotion, AccelerometerEvent event) {
    if (_isProcessing) return;
    final isKannada = _lang.isKannada;

    if (avgMotion <= _steadyThreshold) {
      if (!_isCountingDown && !_waitingToCountdown) _onPhoneSteady();
      if (!_isCountingDown) {
        _setGuidance(
          isKannada ? '✅ ಚೆನ್ನಾಗಿದೆ! ಸ್ಥಿರವಾಗಿ ಹಿಡಿಯಿರಿ...' : '✅ Good! Hold steady...',
          '',
        );
      }
    } else if (avgMotion > _movingThreshold) {
      if (_isCountingDown) {
        _cancelCountdown();
      } else if (_waitingToCountdown) {
        _steadyTimer?.cancel();
        setState(() {
          _waitingToCountdown = false;
          _statusIcon = '🎯';
        });
      }
      _setGuidanceWithSpeech(event);
    } else {
      if (!_isCountingDown) {
        _setGuidance(
          isKannada ? 'ಸ್ವಲ್ಪ ಸ್ಥಿರ... ಹಾಗೇ ಇರಿ' : 'Almost steady... keep still',
          '',
        );
      }
    }
  }

  void _setGuidanceWithSpeech(AccelerometerEvent event) {
    final isKannada = _lang.isKannada;
    String guidance = '';
    String spoken = '';

    if (event.x > 4.0) {
      guidance = isKannada ? '⬅️ ಫೋನ್ ಸ್ವಲ್ಪ ಎಡಕ್ಕೆ ವಾಲಿಸಿ' : '⬅️ Tilt phone slightly LEFT';
      spoken = isKannada ? 'ಎಡಕ್ಕೆ ವಾಲಿಸಿ' : 'Tilt left';
    } else if (event.x < -4.0) {
      guidance = isKannada ? '➡️ ಫೋನ್ ಸ್ವಲ್ಪ ಬಲಕ್ಕೆ ವಾಲಿಸಿ' : '➡️ Tilt phone slightly RIGHT';
      spoken = isKannada ? 'ಬಲಕ್ಕೆ ವಾಲಿಸಿ' : 'Tilt right';
    } else if (event.y < 1.0) {
      guidance = isKannada ? '📏 ಟಿಪ್ಪಣಿಗೆ ಹತ್ತಿರ ತನ್ನಿ' : '📏 Move phone CLOSER to the note';
      spoken = isKannada ? 'ಹತ್ತಿರ ತನ್ನಿ' : 'Move closer';
    } else if (event.y > 6.0) {
      guidance = isKannada ? '📏 ಫೋನ್ ಸ್ವಲ್ಪ ದೂರ ತನ್ನಿ' : '📏 Move phone FURTHER from the note';
      spoken = isKannada ? 'ದೂರ ತನ್ನಿ' : 'Move back a little';
    } else {
      guidance = isKannada ? '✋ ಹೆಚ್ಚು ಚಲಿಸಬೇಡಿ. ತುಂಬಾ ಸ್ಥಿರವಾಗಿ ಹಿಡಿಯಿರಿ...' : '✋ Too much movement. Hold very still...';
      spoken = isKannada ? 'ಸ್ಥಿರವಾಗಿ ಹಿಡಿಯಿರಿ' : 'Hold still';
    }
    _setGuidance(guidance, spoken);
  }

  void _setGuidance(String guidance, String spoken) {
    if (!mounted) return;
    if (_guidance == guidance) return;
    setState(() => _guidance = guidance);
    if (spoken.isNotEmpty) {
      _guidanceTimer?.cancel();
      _guidanceTimer = Timer(const Duration(seconds: 2), () {
        if (_autoModeActive && !_isCountingDown && !_isProcessing && mounted) {
          _speak(spoken);
        }
      });
    }
  }

  void _onPhoneSteady() {
    if (_isCountingDown || _isProcessing || !_autoModeActive) return;
    if (_waitingToCountdown) return;
    setState(() => _waitingToCountdown = true);
    _steadyTimer?.cancel();
    _steadyTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted && _autoModeActive && !_isCountingDown && !_isProcessing) {
        setState(() => _waitingToCountdown = false);
        _startCountdown();
      } else {
        setState(() => _waitingToCountdown = false);
      }
    });
  }

  void _startCountdown() {
    if (_isCountingDown || _isProcessing || !mounted) return;
    setState(() {
      _isCountingDown = true;
      _countdownValue = 3;
      _guidance = _lang.isKannada ? '📸 3 ಸೆಕೆಂಡಿನಲ್ಲಿ ಕ್ಯಾಪ್ಚರ್...' : '📸 Capturing in 3...';
      _statusIcon = '⏱️';
    });
    HapticFeedback.lightImpact();
    _speak('3');

    _countdownTimer =
        Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      _countdownValue--;
      if (_countdownValue > 0) {
        setState(() {
          _guidance = _lang.isKannada
              ? '📸 $_countdownValue ಸೆಕೆಂಡಿನಲ್ಲಿ ಕ್ಯಾಪ್ಚರ್...'
              : '📸 Capturing in $_countdownValue...';
        });
        HapticFeedback.lightImpact();
        _speak('$_countdownValue');
      } else {
        timer.cancel();
        setState(() {
          _isCountingDown = false;
          _guidance = _lang.isKannada ? '📸 ಕ್ಯಾಪ್ಚರ್ ಮಾಡಲಾಗುತ್ತಿದೆ!' : '📸 Capturing now!';
          _statusIcon = '📸';
        });
        HapticFeedback.heavyImpact();
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted && !_isProcessing) _captureAndProcess();
        });
      }
    });
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _isCountingDown = false;
      _waitingToCountdown = false;
      _guidance = _lang.isKannada
          ? '✋ ಚಲಿಸಿದಿರಿ! ಮತ್ತೆ ಸ್ಥಿರವಾಗಿ ಹಿಡಿಯಿರಿ...'
          : '✋ Moved! Hold very still again...';
      _statusIcon = '🎯';
    });
    HapticFeedback.vibrate();
    _speak(_lang.isKannada ? 'ಚಲಿಸಿದಿರಿ. ಮತ್ತೆ ಸ್ಥಿರವಾಗಿ ಹಿಡಿಯಿರಿ.' : 'Moved. Hold still again.');
  }

  // ── CAPTURE: use multi-script recognizer ──
  Future<void> _captureAndProcess() async {
    if (_isProcessing || _controller == null || !mounted) return;

    _accelerometerSub?.cancel();
    _steadyTimer?.cancel();
    _countdownTimer?.cancel();

    final isKannada = _lang.isKannada;
    setState(() {
      _isProcessing = true;
      _isCountingDown = false;
      _waitingToCountdown = false;
      _autoModeActive = false;
      _guidance = isKannada ? '🔄 ಟಿಪ್ಪಣಿ ಓದಲಾಗುತ್ತಿದೆ...' : '🔄 Reading your note...';
      _statusIcon = '🔄';
    });

    try {
      final image = await _controller!.takePicture();
      final inputImage = InputImage.fromFilePath(image.path);

      String text = '';

      // ML Kit Latin recognizer handles both printed English and Kannada text.
      // We use a single recognizer regardless of language mode — the Groq
      // prompt then summarises the extracted text in the correct language.
      final recognizer = TextRecognizer(
        script: TextRecognitionScript.latin,
      );
      final result = await recognizer.processImage(inputImage);
      await recognizer.close();
      text = result.text.trim();

      if (text.isEmpty) {
        HapticFeedback.vibrate();
        await _speak(_lang.noTextFound());
        if (mounted) {
          setState(() {
            _guidance = isKannada ? '❌ ಪಠ್ಯ ಸಿಗಲಿಲ್ಲ. ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ.' : '❌ No text found. Try again.';
            _statusIcon = '❌';
            _isProcessing = false;
          });
        }
        return;
      }

      HapticFeedback.mediumImpact();
      await _speak(_lang.noteCaptured());

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ResultScreen(scannedText: text),
          ),
        );
        setState(() => _isProcessing = false);
      }
    } catch (e) {
      HapticFeedback.vibrate();
      _speak(isKannada
          ? 'ದೋಷ ಸಂಭವಿಸಿದೆ. ದಯವಿಟ್ಟು ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ.'
          : 'Error capturing. Please try again.');
      if (mounted) {
        setState(() {
          _guidance = isKannada
              ? '❌ ದೋಷ. ದಯವಿಟ್ಟು ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ.'
              : '❌ Error. Please try again.';
          _statusIcon = '❌';
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKannada = _lang.isKannada;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _speak(isKannada
                          ? 'ಹಿಂದೆ ಬಟನ್. ಹಿಂದೆ ಹೋಗಲು ಎರಡು ಬಾರಿ ತಟ್ಟಿ.'
                          : 'Back button. Double tap to go back.');
                    },
                    onDoubleTap: () {
                      _stopAutoMode();
                      _tts.stop();
                      Navigator.pop(context);
                    },
                    child: const Icon(Icons.arrow_back,
                        color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isKannada ? 'ಟಿಪ್ಪಣಿ ಸ್ಕ್ಯಾನ್' : 'Scan Note',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  // Language pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isKannada
                          ? Colors.orange.shade900
                          : Colors.indigo.shade900,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isKannada ? 'ಕನ್ನಡ' : 'EN',
                      style: TextStyle(
                          color: isKannada
                              ? Colors.orangeAccent
                              : Colors.indigoAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _autoModeActive
                          ? Colors.green.shade700
                          : Colors.grey.shade800,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _autoModeActive
                          ? (isKannada ? '● ಆಟೋ ಆನ್' : '● AUTO ON')
                          : (isKannada ? '○ ಆಟೋ ಆಫ್' : '○ AUTO OFF'),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

            // ── AUTO MODE BUTTON ──
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                _speak(_autoModeActive
                    ? (isKannada
                        ? 'ಆಟೋ ಮೋಡ್ ಆನ್. ನಿಲ್ಲಿಸಲು ಎರಡು ಬಾರಿ ತಟ್ಟಿ.'
                        : 'Auto mode is ON. Double tap to stop.')
                    : (isKannada
                        ? 'ಆಟೋ ಕ್ಯಾಪ್ಚರ್ ಬಟನ್. ಪ್ರಾರಂಭಿಸಲು ಎರಡು ಬಾರಿ ತಟ್ಟಿ.'
                        : 'Auto capture button. Double tap to start.'));
              },
              onDoubleTap: () {
                if (_autoModeActive) {
                  _stopAutoMode();
                } else {
                  _startAutoMode();
                }
              },
              child: Container(
                margin: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _autoModeActive
                      ? Colors.green.shade800
                      : Colors.indigo.shade800,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _autoModeActive
                          ? Icons.stop_circle
                          : Icons.motion_photos_auto,
                      color: Colors.white,
                      size: 26,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _autoModeActive
                          ? (isKannada
                              ? 'ಆಟೋ ಮೋಡ್ ನಿಲ್ಲಿಸಲು ಎರಡು ಬಾರಿ ತಟ್ಟಿ'
                              : 'Double tap to STOP auto mode')
                          : (isKannada
                              ? 'ಆಟೋ ಕ್ಯಾಪ್ಚರ್ ಪ್ರಾರಂಭಿಸಲು ಎರಡು ಬಾರಿ ತಟ್ಟಿ'
                              : 'Double tap to START auto capture'),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),

            // ── Camera preview ──
            Expanded(
              child: Stack(
                children: [
                  _controller != null && _controller!.value.isInitialized
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: CameraPreview(_controller!),
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircularProgressIndicator(
                                  color: Colors.deepPurple),
                              const SizedBox(height: 16),
                              Text(
                                isKannada
                                    ? 'ಕ್ಯಾಮೆರಾ ಪ್ರಾರಂಭಿಸಲಾಗುತ್ತಿದೆ...'
                                    : 'Starting camera...',
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          )),

                  // Countdown overlay
                  if (_isCountingDown)
                    Center(
                      child: Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(65),
                          border:
                              Border.all(color: Colors.orange, width: 3),
                        ),
                        child: Center(
                          child: Text(
                            '$_countdownValue',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 80,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),

                  // Processing overlay
                  if (_isProcessing)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(
                                color: Colors.deepPurple),
                            const SizedBox(height: 16),
                            Text(
                              isKannada
                                  ? 'ಟಿಪ್ಪಣಿ ಓದಲಾಗುತ್ತಿದೆ...'
                                  : 'Reading your note...',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 18),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Guidance box ──
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _isCountingDown
                    ? Colors.orange.shade900
                    : _waitingToCountdown
                        ? Colors.teal.shade900
                        : _autoModeActive
                            ? Colors.green.shade900
                            : Colors.grey.shade900,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_statusIcon,
                      style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _guidance,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 15),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),

            // ── Manual scan button ──
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                _speak(isKannada
                    ? 'ಕೈಯಿಂದ ಸ್ಕ್ಯಾನ್. ಈಗ ಕ್ಯಾಪ್ಚರ್ ಮಾಡಲು ಎರಡು ಬಾರಿ ತಟ್ಟಿ.'
                    : 'Manual scan. Double tap to capture now.');
              },
              onDoubleTap: () {
                _stopAutoMode();
                _captureAndProcess();
              },
              child: Container(
                margin: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                height: 70,
                decoration: BoxDecoration(
                  color: _isProcessing
                      ? Colors.grey.shade700
                      : Colors.deepPurple,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.camera_alt,
                          color: Colors.white, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        isKannada
                            ? 'ಕೈಯಿಂದ ಸ್ಕ್ಯಾನ್ ಮಾಡಲು ಎರಡು ಬಾರಿ ತಟ್ಟಿ'
                            : 'Double tap to scan manually',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
