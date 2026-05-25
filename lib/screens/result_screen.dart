import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/database_service.dart';
import '../services/language_service.dart';

class ResultScreen extends StatefulWidget {
  final String scannedText;
  const ResultScreen({super.key, required this.scannedText});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final FlutterTts _tts = FlutterTts();
  final _lang = LanguageService.instance;

  String _summary = '';
  bool _isLoading = true;
  String _summaryMode = 'short';

  // Fallback state
  bool _isFallbackMode = false;
  String _fallbackReason = '';

  // 🔑 Groq API key
  static const String _apiKey ='YOUR_API_KEY';

  @override
  void initState() {
    super.initState();
    _lang.addListener(_onLanguageChanged);
    _getSummary();
  }

  @override
  void dispose() {
    _lang.removeListener(_onLanguageChanged);
    _tts.stop();
    super.dispose();
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _speak(String text) async {
    await _tts.stop();
    await _tts.setLanguage(_lang.ttsLocale);
    await _tts.setSpeechRate(0.45);
    await _tts.speak(text);
  }

  Future<void> _stopSpeaking() async => await _tts.stop();

  // ── FALLBACK: read raw scanned text ──────────────────
  Future<void> _useFallback(String reason) async {
    final rawText = widget.scannedText;
    await DatabaseService.saveNote(rawText, rawText);
    if (!mounted) return;
    setState(() {
      _summary = rawText;
      _isFallbackMode = true;
      _fallbackReason = reason;
      _isLoading = false;
    });
    HapticFeedback.vibrate();
    await _speak(_lang.noInternetFallback(rawText));
  }

  // ── MAIN: get AI summary ──────────────────────────────
  Future<void> _getSummary() async {
    setState(() {
      _isLoading = true;
      _summary = '';
      _isFallbackMode = false;
      _fallbackReason = '';
    });

    if (_apiKey.trim().isEmpty || _apiKey.startsWith('gsk_XXXX')) {
      await _useFallback('API key not configured.');
      return;
    }

    // ── Build prompt in the active language ──
    final prompt = _summaryMode == 'short'
        ? _lang.groqShortPrompt(widget.scannedText)
        : _lang.groqDetailedPrompt(widget.scannedText);

    try {
      final response = await http
          .post(
            Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
            },
            body: jsonEncode({
              'model': 'llama-3.1-8b-instant',
              'messages': [
                {
                  'role': 'system',
                  // System prompt switches language too
                  'content': _lang.groqSystemPrompt(),
                },
                {'role': 'user', 'content': prompt},
              ],
              'max_tokens': 1024,
              'temperature': 0.5,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final summary = data['choices'][0]['message']['content'];
        await DatabaseService.saveNote(widget.scannedText, summary);
        if (!mounted) return;
        setState(() {
          _summary = summary;
          _isFallbackMode = false;
          _isLoading = false;
        });
        HapticFeedback.mediumImpact();
        await _speak(summary);
      } else {
        final errorBody = jsonDecode(response.body);
        final errorMsg =
            errorBody['error']?['message'] ?? 'API error ${response.statusCode}';
        await _useFallback(errorMsg);
      }
    } on http.ClientException {
      await _useFallback('No internet connection.');
    } on Exception catch (e) {
      final msg = e.toString();
      if (msg.contains('TimeoutException') || msg.contains('timeout')) {
        await _useFallback('Connection timed out.');
      } else if (msg.contains('SocketException') ||
          msg.contains('NetworkException') ||
          msg.contains('Failed host lookup')) {
        await _useFallback('No internet connection.');
      } else {
        await _useFallback('Could not reach AI service.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            if (_isFallbackMode) _buildFallbackBanner(),
            if (!_isFallbackMode && !_isLoading) _buildModeToggle(),
            const SizedBox(height: 16),
            _buildContent(),
            const SizedBox(height: 16),
            _buildActionButtons(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── TOP BAR ───────────────────────────────────────────
  Widget _buildTopBar() {
    final isKannada = _lang.isKannada;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              _stopSpeaking();
              Navigator.pop(context);
            },
            child:
                const Icon(Icons.arrow_back, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          Text(
            _isFallbackMode
                ? (isKannada ? 'ಟಿಪ್ಪಣಿ ಪಠ್ಯ' : 'Raw Note Text')
                : (isKannada ? 'ಎಐ ಸಾರಾಂಶ' : 'AI Summary'),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold),
          ),
          if (_isFallbackMode) ...[
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.orange.shade900,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isKannada ? 'ಆಫ್‌ಲೈನ್' : 'OFFLINE',
                style: const TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
          const Spacer(),
          // Language indicator pill
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isKannada
                  ? Colors.orange.shade900
                  : Colors.indigo.shade900,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isKannada ? 'ಕನ್ನಡ' : 'EN',
              style: TextStyle(
                color: isKannada ? Colors.orangeAccent : Colors.indigoAccent,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── FALLBACK BANNER ───────────────────────────────────
  Widget _buildFallbackBanner() {
    final isKannada = _lang.isKannada;
    return GestureDetector(
      onTap: () => _speak(
        isKannada
            ? 'ಇಂಟರ್ನೆಟ್ ಇಲ್ಲ. ಅಸಲಿ ಸ್ಕ್ಯಾನ್ ಪಠ್ಯ ತೋರಿಸಲಾಗುತ್ತಿದೆ. ಎಐ ಸಾರಾಂಶ ಪ್ರಯತ್ನಿಸಲು ರಿಟ್ರೈ ಎರಡು ಬಾರಿ ತಟ್ಟಿ.'
            : 'No internet. Showing raw scanned text. '
                'Connect to internet and double tap retry for AI summary.',
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.shade900,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.orangeAccent.withAlpha(80)),
        ),
        child: Row(
          children: [
            const Icon(Icons.wifi_off, color: Colors.orangeAccent, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isKannada
                        ? 'ಇಂಟರ್ನೆಟ್ ಇಲ್ಲ — ಅಸಲಿ ಪಠ್ಯ ತೋರಿಸಲಾಗುತ್ತಿದೆ'
                        : 'No internet — showing raw text',
                    style: const TextStyle(
                        color: Colors.orangeAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                  if (_fallbackReason.isNotEmpty)
                    Text(
                      _fallbackReason,
                      style: const TextStyle(
                          color: Colors.orange, fontSize: 11),
                    ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _speak(isKannada
                  ? 'ರಿಟ್ರೈ ಬಟನ್. ಎಐ ಸಾರಾಂಶ ಪ್ರಯತ್ನಿಸಲು ಎರಡು ಬಾರಿ ತಟ್ಟಿ.'
                  : 'Retry button. Double tap to try AI summary again.'),
              onDoubleTap: () {
                setState(() => _summaryMode = 'short');
                _getSummary();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.shade700,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isKannada ? 'ಮತ್ತೆ ಪ್ರಯತ್ನ' : 'Retry AI',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── MODE TOGGLE (short / detailed) ────────────────────
  Widget _buildModeToggle() {
    final isKannada = _lang.isKannada;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _modeButton(isKannada ? 'ಚಿಕ್ಕ' : 'Short', 'short'),
          const SizedBox(width: 12),
          _modeButton(isKannada ? 'ವಿವರ' : 'Detailed', 'detailed'),
        ],
      ),
    );
  }

  Widget _modeButton(String label, String mode) {
    final isSelected = _summaryMode == mode;
    return GestureDetector(
      onTap: () => _speak(_lang.isKannada
          ? '$label ಮೋಡ್. ಬದಲಾಯಿಸಲು ಎರಡು ಬಾರಿ ತಟ್ಟಿ.'
          : '$label summary mode. Double tap to switch.'),
      onDoubleTap: () {
        setState(() => _summaryMode = mode);
        _getSummary();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.deepPurple : Colors.grey.shade800,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: const TextStyle(color: Colors.white, fontSize: 14)),
      ),
    );
  }

  // ── MAIN CONTENT ──────────────────────────────────────
  Widget _buildContent() {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _isFallbackMode
              ? Colors.orange.shade900.withAlpha(40)
              : Colors.grey.shade900,
          borderRadius: BorderRadius.circular(16),
          border: _isFallbackMode
              ? Border.all(color: Colors.orangeAccent.withAlpha(60))
              : null,
        ),
        child: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: Colors.deepPurple),
                    const SizedBox(height: 16),
                    Text(
                      _lang.aiSummarizing(),
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                child: Text(
                  _summary,
                  style: TextStyle(
                    color: _isFallbackMode
                        ? Colors.orange.shade100
                        : Colors.white,
                    fontSize: 18,
                    height: 1.6,
                  ),
                ),
              ),
      ),
    );
  }

  // ── ACTION BUTTONS ────────────────────────────────────
  Widget _buildActionButtons() {
    final isKannada = _lang.isKannada;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Read aloud
          Expanded(
            child: GestureDetector(
              onTap: () => _speak(_isFallbackMode
                  ? _lang.readAloudDescFallback()
                  : _lang.readAloudDesc()),
              onDoubleTap: () => _speak(_summary),
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.deepPurple,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.volume_up, color: Colors.white),
                    const SizedBox(height: 4),
                    Text(
                      isKannada ? 'ಓದಿ' : 'Read Aloud',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Stop
          Expanded(
            child: GestureDetector(
              onTap: () => _speak(isKannada
                  ? 'ನಿಲ್ಲಿಸಿ ಬಟನ್. ಓದುವಿಕೆ ನಿಲ್ಲಿಸಲು ಎರಡು ಬಾರಿ ತಟ್ಟಿ.'
                  : 'Stop button. Double tap to stop reading.'),
              onDoubleTap: _stopSpeaking,
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.red.shade900,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.stop, color: Colors.white),
                    const SizedBox(height: 4),
                    Text(
                      isKannada ? 'ನಿಲ್ಲಿಸಿ' : 'Stop',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Retry / Refresh
          Expanded(
            child: GestureDetector(
              onTap: () => _speak(
                isKannada
                    ? (_isFallbackMode
                        ? 'ಮತ್ತೆ ಪ್ರಯತ್ನ ಬಟನ್. ಇಂಟರ್ನೆಟ್‌ನೊಂದಿಗೆ ಎಐ ಸಾರಾಂಶ ಪಡೆಯಲು ಎರಡು ಬಾರಿ ತಟ್ಟಿ.'
                        : 'ಮತ್ತೆ ಪ್ರಯತ್ನ ಬಟನ್. ಹೊಸ ಸಾರಾಂಶ ಪಡೆಯಲು ಎರಡು ಬಾರಿ ತಟ್ಟಿ.')
                    : (_isFallbackMode
                        ? 'Retry AI button. Double tap to try AI summary with internet.'
                        : 'Retry button. Double tap to get a new summary.'),
              ),
              onDoubleTap: _getSummary,
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  color: _isFallbackMode
                      ? Colors.orange.shade800
                      : Colors.teal.shade800,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                        _isFallbackMode ? Icons.wifi : Icons.refresh,
                        color: Colors.white),
                    const SizedBox(height: 4),
                    Text(
                      isKannada
                          ? (_isFallbackMode ? 'ಮತ್ತೆ' : 'ಮತ್ತೆ')
                          : (_isFallbackMode ? 'Try AI' : 'Retry'),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

