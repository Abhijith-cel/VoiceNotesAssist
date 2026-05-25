import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/database_service.dart';
import '../services/language_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final _lang = LanguageService.instance;

  List<Map<String, dynamic>> _notes = [];
  List<Map<String, dynamic>> _filteredNotes = [];
  bool _isLoading = true;
  bool _isListening = false;
  bool _speechAvailable = false;

  // Playback state
  int _currentIndex = 0;
  double _ttsRate = 0.45;
  String _lastSpoken = '';
  bool _awaitingDeleteConfirm = false;
  bool _awaitingDeleteAllConfirm = false;
  int _deleteAllConfirmCount = 0;
  String _activeFilter = 'all';

  @override
  void initState() {
    super.initState();
    _lang.addListener(_onLanguageChanged);
    _initTts();
    _initSpeech();
    _initLoad();
  }

  @override
  void dispose() {
    _lang.removeListener(_onLanguageChanged);
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  // ── TTS ──────────────────────────────────────────────
  Future<void> _initTts() async {
    await _tts.setLanguage(_lang.ttsLocale);
    await _tts.setSpeechRate(_ttsRate);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
  }

  Future<void> _speak(String text) async {
    await _tts.stop();
    _lastSpoken = text;
    await _tts.setLanguage(_lang.ttsLocale);
    await _tts.setSpeechRate(_ttsRate);
    await _tts.speak(text);
  }

  Future<void> _stopSpeaking() async => await _tts.stop();

  // ── SPEECH RECOGNITION ───────────────────────────────
  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onError: (e) => debugPrint('Speech error: $e'),
    );
    if (mounted) setState(() {});
  }

  Future<void> _startListening() async {
    if (!_speechAvailable || _isListening) return;
    await _stopSpeaking();
    setState(() => _isListening = true);
    HapticFeedback.mediumImpact();

    _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          final command = result.recognizedWords.toLowerCase().trim();
          debugPrint('History voice command: "$command"');
          _handleVoiceCommand(command);
          setState(() => _isListening = false);
        }
      },
      listenFor: const Duration(seconds: 6),
      pauseFor: const Duration(seconds: 2),
      cancelOnError: true,
      partialResults: false,
    );
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
  }

  // ── VOICE COMMAND ROUTER ──────────────────────────────
  void _handleVoiceCommand(String cmd) {
    // ── Language switching (works in either language) ──
    if (cmd.contains('kannada') ||
        cmd.contains('ಕನ್ನಡ') ||
        cmd.contains('switch to kannada') ||
        cmd.contains('change to kannada')) {
      _lang.switchToKannada();
      _speak(_lang.switchedToKannada());
      return;
    }
    if (cmd.contains('english') ||
        cmd.contains('switch to english') ||
        cmd.contains('change to english')) {
      _lang.switchToEnglish();
      _speak(_lang.switchedToEnglish());
      return;
    }

    // ── Delete confirmation flow ──
    if (_awaitingDeleteConfirm) {
      if (cmd.contains('yes') ||
          cmd.contains('delete') ||
          cmd.contains('confirm') ||
          cmd.contains('ಹೌದು')) {
        _confirmDeleteCurrent();
      } else {
        setState(() => _awaitingDeleteConfirm = false);
        _speak(_lang.deleteCancelled());
      }
      return;
    }

    if (_awaitingDeleteAllConfirm) {
      if (cmd.contains('yes') ||
          cmd.contains('confirm') ||
          cmd.contains('ಹೌದು')) {
        _deleteAllConfirmCount++;
        if (_deleteAllConfirmCount >= 2) {
          _confirmDeleteAll();
        } else {
          _speak(_lang.isKannada
              ? 'ಖಚಿತವಾಗಿ ಎಲ್ಲ ${_filteredNotes.length} ಟಿಪ್ಪಣಿಗಳನ್ನು ಅಳಿಸಬೇಕೇ? ಮತ್ತೊಮ್ಮೆ ಹೌದು ಎಂದು ಹೇಳಿ.'
              : 'Are you absolutely sure? Say yes again to delete all ${_filteredNotes.length} notes permanently.');
        }
      } else {
        setState(() {
          _awaitingDeleteAllConfirm = false;
          _deleteAllConfirmCount = 0;
        });
        _speak(_lang.deleteAllCancelled());
      }
      return;
    }

    // ── Navigation ──
    if (cmd.contains('next') || cmd.contains('ಮುಂದೆ')) {
      _goNext();
    } else if (cmd.contains('previous') ||
        cmd.contains('prev') ||
        cmd.contains('back') ||
        cmd.contains('ಹಿಂದೆ')) {
      _goPrevious();
    } else if (cmd.contains('first') || cmd.contains('ಮೊದಲ')) {
      _goFirst();
    } else if (cmd.contains('last') || cmd.contains('ಕೊನೆ')) {
      _goLast();
    } else if (_parseOpenNumber(cmd) != null) {
      _goToIndex(_parseOpenNumber(cmd)! - 1);
    } else if (cmd.contains('how many') ||
        cmd.contains('count') ||
        cmd.contains('ಎಷ್ಟು')) {
      _speakCount();
    } else if (cmd.contains('list all') ||
        cmd.contains('read all') ||
        cmd.contains('ಎಲ್ಲ ಪಟ್ಟಿ')) {
      _readAllTitles();

    // ── Date filters ──
    } else if (cmd.contains('today') || cmd.contains('ಇಂದು')) {
      _filterByDate('today');
    } else if (cmd.contains('yesterday') || cmd.contains('ನಿನ್ನೆ')) {
      _filterByDate('yesterday');
    } else if (cmd.contains('show all') ||
        cmd.contains('all notes') ||
        cmd.contains('clear filter') ||
        cmd.contains('ಎಲ್ಲ ತೋರಿಸಿ')) {
      _clearFilter();

    // ── Playback ──
    } else if ((cmd.contains('read') ||
            cmd.contains('play') ||
            cmd.contains('hear') ||
            cmd.contains('ಓದಿ')) &&
        !cmd.contains('read all')) {
      _readCurrentItem();
    } else if (cmd.contains('short') || cmd.contains('ಚಿಕ್ಕ')) {
      _readCurrentItemShort();
    } else if (cmd.contains('detail') || cmd.contains('ವಿವರ')) {
      _readCurrentItemDetailed();
    } else if (cmd.contains('stop') ||
        cmd.contains('pause') ||
        cmd.contains('quiet') ||
        cmd.contains('ನಿಲ್ಲಿಸಿ')) {
      _stopSpeaking();
    } else if (cmd.contains('repeat') ||
        cmd.contains('again') ||
        cmd.contains('ಪುನರಾವರ್ತಿಸಿ')) {
      _repeatLast();
    } else if (cmd.contains('faster') ||
        cmd.contains('speed up') ||
        cmd.contains('ವೇಗ ಹೆಚ್ಚಿಸಿ')) {
      _adjustSpeed(0.1);
    } else if (cmd.contains('slower') ||
        cmd.contains('slow down') ||
        cmd.contains('ವೇಗ ಕಡಿಮೆ')) {
      _adjustSpeed(-0.1);
    } else if (cmd.contains('what is this') ||
        cmd.contains('describe') ||
        cmd.contains('info') ||
        cmd.contains('ವಿವರಿಸಿ')) {
      _describeCurrentItem();

    // ── Management ──
    } else if (cmd.contains('delete all') ||
        cmd.contains('clear history') ||
        cmd.contains('clear all') ||
        cmd.contains('ಎಲ್ಲ ಅಳಿಸಿ')) {
      _askDeleteAll();
    } else if (cmd.contains('delete') ||
        cmd.contains('remove') ||
        cmd.contains('ಅಳಿಸಿ')) {
      _askDeleteCurrent();
    } else if (cmd.contains('share') ||
        cmd.contains('send') ||
        cmd.contains('ಹಂಚಿ')) {
      _shareCurrentItem();

    // ── Global ──
    } else if (cmd.contains('home') || cmd.contains('ಮನೆ')) {
      _goHome();
    } else if (cmd.contains('help') ||
        cmd.contains('commands') ||
        cmd.contains('what can') ||
        cmd.contains('ಸಹಾಯ')) {
      _readHelp();

    // ── Unknown ──
    } else {
      HapticFeedback.vibrate();
      _speak(_lang.historyCommandUnknown());
    }
  }

  // ── NAVIGATION ACTIONS ────────────────────────────────
  void _goNext() {
    if (_filteredNotes.isEmpty) {
      _speak(_lang.isKannada ? 'ಯಾವ ಟಿಪ್ಪಣಿಗಳೂ ಇಲ್ಲ.' : 'No notes available.');
      return;
    }
    if (_currentIndex < _filteredNotes.length - 1) {
      setState(() => _currentIndex++);
      HapticFeedback.lightImpact();
      _describeCurrentItem();
    } else {
      HapticFeedback.vibrate();
      _speak(_lang.isKannada
          ? 'ಕೊನೆಯ ಟಿಪ್ಪಣಿ. ಇದು ${_filteredNotes.length} ರಲ್ಲಿ ${_filteredNotes.length}.'
          : 'Already at the last note. That is note ${_filteredNotes.length} of ${_filteredNotes.length}.');
    }
  }

  void _goPrevious() {
    if (_filteredNotes.isEmpty) {
      _speak(_lang.isKannada ? 'ಯಾವ ಟಿಪ್ಪಣಿಗಳೂ ಇಲ್ಲ.' : 'No notes available.');
      return;
    }
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      HapticFeedback.lightImpact();
      _describeCurrentItem();
    } else {
      HapticFeedback.vibrate();
      _speak(_lang.isKannada
          ? 'ಇದು ಮೊದಲ ಟಿಪ್ಪಣಿ.'
          : 'Already at the first note.');
    }
  }

  void _goFirst() {
    if (_filteredNotes.isEmpty) {
      _speak(_lang.isKannada ? 'ಯಾವ ಟಿಪ್ಪಣಿಗಳೂ ಇಲ್ಲ.' : 'No notes available.');
      return;
    }
    setState(() => _currentIndex = 0);
    HapticFeedback.lightImpact();
    _speak(_lang.isKannada ? 'ಮೊದಲ ಟಿಪ್ಪಣಿ.' : 'First note.');
    _describeCurrentItem();
  }

  void _goLast() {
    if (_filteredNotes.isEmpty) {
      _speak(_lang.isKannada ? 'ಯಾವ ಟಿಪ್ಪಣಿಗಳೂ ಇಲ್ಲ.' : 'No notes available.');
      return;
    }
    setState(() => _currentIndex = _filteredNotes.length - 1);
    HapticFeedback.lightImpact();
    _speak(_lang.isKannada ? 'ಕೊನೆಯ ಟಿಪ್ಪಣಿ.' : 'Last note.');
    _describeCurrentItem();
  }

  void _goToIndex(int index) {
    if (_filteredNotes.isEmpty) {
      _speak(_lang.isKannada ? 'ಯಾವ ಟಿಪ್ಪಣಿಗಳೂ ಇಲ್ಲ.' : 'No notes available.');
      return;
    }
    if (index < 0 || index >= _filteredNotes.length) {
      _speak(_lang.isKannada
          ? 'ಟಿಪ್ಪಣಿ ${index + 1} ಇಲ್ಲ. ${_filteredNotes.length} ಟಿಪ್ಪಣಿಗಳಿವೆ.'
          : 'Note ${index + 1} does not exist. There are ${_filteredNotes.length} notes.');
      return;
    }
    setState(() => _currentIndex = index);
    HapticFeedback.lightImpact();
    _describeCurrentItem();
  }

  int? _parseOpenNumber(String cmd) {
    final patterns = ['open ', 'item ', 'number ', 'note ', 'go to '];
    for (final p in patterns) {
      if (cmd.contains(p)) {
        final rest = cmd.split(p).last.trim();
        final n = int.tryParse(rest.split(' ').first);
        if (n != null) return n;
      }
    }
    final wordNumbers = {
      'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5,
      'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10,
    };
    for (final entry in wordNumbers.entries) {
      if (cmd.contains('open ${entry.key}') ||
          cmd.contains('item ${entry.key}') ||
          cmd.contains('note ${entry.key}')) {
        return entry.value;
      }
    }
    return null;
  }

  void _speakCount() {
    final total = _filteredNotes.length;
    if (total == 0) {
      _speak(_lang.isKannada ? 'ಯಾವ ಟಿಪ್ಪಣಿಗಳೂ ಇಲ್ಲ.' : 'No notes found.');
    } else if (_activeFilter != 'all') {
      _speak(_lang.isKannada
          ? '$total ಟಿಪ್ಪಣಿ${total == 1 ? '' : 'ಗಳು'} ಕಂಡುಬಂದಿವೆ.'
          : '$total note${total == 1 ? '' : 's'} found for $_activeFilter.');
    } else {
      _speak(_lang.isKannada
          ? 'ಒಟ್ಟು $total ಉಳಿಸಿದ ಟಿಪ್ಪಣಿ${total == 1 ? '' : 'ಗಳಿವೆ'}.'
          : 'You have $total saved note${total == 1 ? '' : 's'} in total.');
    }
  }

  Future<void> _readAllTitles() async {
    if (_filteredNotes.isEmpty) {
      _speak(_lang.isKannada ? 'ಪಟ್ಟಿ ಮಾಡಲು ಟಿಪ್ಪಣಿಗಳಿಲ್ಲ.' : 'No notes to list.');
      return;
    }
    final buffer = StringBuffer(
      _lang.isKannada
          ? '${_filteredNotes.length} ಟಿಪ್ಪಣಿಗಳ ಪಟ್ಟಿ. '
          : 'Listing ${_filteredNotes.length} notes. ',
    );
    for (int i = 0; i < _filteredNotes.length; i++) {
      final note = _filteredNotes[i];
      final preview =
          (note['summary'] as String).split(' ').take(6).join(' ');
      buffer.write(
          '${_lang.isKannada ? 'ಟಿಪ್ಪಣಿ' : 'Note'} ${i + 1}: $preview. ');
    }
    _speak(buffer.toString());
  }

  // ── DATE FILTER ───────────────────────────────────────
  void _filterByDate(String filter) {
    final now = DateTime.now();
    String datePrefix;
    if (filter == 'today') {
      datePrefix = now.toString().substring(0, 10);
    } else {
      final yesterday = now.subtract(const Duration(days: 1));
      datePrefix = yesterday.toString().substring(0, 10);
    }

    final filtered = _notes
        .where((n) => (n['date'] as String? ?? '').startsWith(datePrefix))
        .toList();

    setState(() {
      _filteredNotes = filtered;
      _currentIndex = 0;
      _activeFilter = filter;
    });

    final filterLabel = _lang.isKannada
        ? (filter == 'today' ? 'ಇಂದು' : 'ನಿನ್ನೆ')
        : filter;

    if (filtered.isEmpty) {
      _speak(_lang.isKannada
          ? '$filterLabel ಯಾವ ಟಿಪ್ಪಣಿಗಳೂ ಇಲ್ಲ.'
          : 'No notes found for $filter.');
    } else {
      _speak(_lang.isKannada
          ? '$filterLabel ${filtered.length} ಟಿಪ್ಪಣಿ${filtered.length == 1 ? '' : 'ಗಳು'} ತೋರಿಸಲಾಗುತ್ತಿದೆ.'
          : 'Showing ${filtered.length} note${filtered.length == 1 ? '' : 's'} from $filter.');
    }
  }

  void _clearFilter() {
    setState(() {
      _filteredNotes = List.from(_notes);
      _currentIndex = 0;
      _activeFilter = 'all';
    });
    _speak(_lang.isKannada
        ? 'ಎಲ್ಲ ${_notes.length} ಟಿಪ್ಪಣಿಗಳು ತೋರಿಸಲಾಗುತ್ತಿದೆ.'
        : 'Showing all ${_notes.length} notes.');
  }

  // ── PLAYBACK ──────────────────────────────────────────
  void _readCurrentItem() {
    if (_filteredNotes.isEmpty) {
      _speak(_lang.isKannada ? 'ಯಾವ ಟಿಪ್ಪಣಿಗಳೂ ಇಲ್ಲ.' : 'No notes available.');
      return;
    }
    final note = _filteredNotes[_currentIndex];
    final summary = note['summary'] as String? ?? 'No summary.';
    _speak(
        '${_lang.isKannada ? 'ಟಿಪ್ಪಣಿ' : 'Note'} ${_currentIndex + 1}. $summary');
  }

  void _readCurrentItemShort() {
    if (_filteredNotes.isEmpty) {
      _speak(_lang.isKannada ? 'ಯಾವ ಟಿಪ್ಪಣಿಗಳೂ ಇಲ್ಲ.' : 'No notes available.');
      return;
    }
    final note = _filteredNotes[_currentIndex];
    final summary = note['summary'] as String? ?? '';
    final sentences = summary.split(RegExp(r'(?<=[.!?।])\s+'));
    final short = sentences.take(2).join(' ');
    _speak(
        '${_lang.isKannada ? 'ಚಿಕ್ಕ ಸಾರಾಂಶ' : 'Short summary'}: $short');
  }

  void _readCurrentItemDetailed() {
    if (_filteredNotes.isEmpty) {
      _speak(_lang.isKannada ? 'ಯಾವ ಟಿಪ್ಪಣಿಗಳೂ ಇಲ್ಲ.' : 'No notes available.');
      return;
    }
    final note = _filteredNotes[_currentIndex];
    final text = note['scanned_text'] as String? ?? '';
    final summary = note['summary'] as String? ?? '';
    _speak(_lang.isKannada
        ? 'ವಿವರ. ಅಸಲಿ ಪಠ್ಯ: $text. ಸಾರಾಂಶ: $summary'
        : 'Detailed. Original text: $text. Summary: $summary');
  }

  void _repeatLast() {
    if (_lastSpoken.isEmpty) {
      _speak(_lang.isKannada
          ? 'ಇನ್ನೂ ಏನೂ ಓದಿಲ್ಲ.'
          : 'Nothing to repeat yet.');
    } else {
      _tts.stop().then((_) => _tts.speak(_lastSpoken));
    }
  }

  void _adjustSpeed(double delta) {
    _ttsRate = (_ttsRate + delta).clamp(0.1, 1.0);
    _tts.setSpeechRate(_ttsRate);
    final pct = (_ttsRate * 100).round();
    _speak(_lang.speedSet(pct));
    if (mounted) setState(() {});
  }

  void _describeCurrentItem() {
    if (_filteredNotes.isEmpty) {
      _speak(_lang.isKannada ? 'ಯಾವ ಟಿಪ್ಪಣಿಗಳೂ ಇಲ್ಲ.' : 'No notes available.');
      return;
    }
    final note = _filteredNotes[_currentIndex];
    final date = note['date'] as String? ?? 'unknown date';
    final summary = note['summary'] as String? ?? '';
    final wordCount = summary.split(' ').length;
    _speak(_lang.noteDescription(
        _currentIndex + 1, _filteredNotes.length, date, wordCount));
  }

  // ── MANAGEMENT ────────────────────────────────────────
  void _askDeleteCurrent() {
    if (_filteredNotes.isEmpty) {
      _speak(_lang.isKannada
          ? 'ಅಳಿಸಲು ಯಾವ ಟಿಪ್ಪಣಿಗಳೂ ಇಲ್ಲ.'
          : 'No notes to delete.');
      return;
    }
    final note = _filteredNotes[_currentIndex];
    final date = note['date'] as String? ?? '';
    setState(() => _awaitingDeleteConfirm = true);
    HapticFeedback.mediumImpact();
    _speak(_lang.deleteConfirmPrompt(_currentIndex + 1, date));
  }

  Future<void> _confirmDeleteCurrent() async {
    if (_filteredNotes.isEmpty) return;
    final note = _filteredNotes[_currentIndex];
    final id = note['id'] as int;
    await DatabaseService.deleteNote(id);
    HapticFeedback.heavyImpact();
    await _loadNotes();
    if (!mounted) return;
    setState(() => _awaitingDeleteConfirm = false);
    if (_filteredNotes.isEmpty) {
      _speak(_lang.isKannada
          ? 'ಟಿಪ್ಪಣಿ ಅಳಿಸಲಾಗಿದೆ. ಇನ್ನು ಟಿಪ್ಪಣಿಗಳಿಲ್ಲ.'
          : 'Note deleted. No more notes remaining.');
    } else {
      _speak(_lang.isKannada
          ? 'ಟಿಪ್ಪಣಿ ಅಳಿಸಲಾಗಿದೆ. ${_filteredNotes.length} ಟಿಪ್ಪಣಿ${_filteredNotes.length == 1 ? '' : 'ಗಳು'} ಉಳಿದಿವೆ.'
          : 'Note deleted. ${_filteredNotes.length} note${_filteredNotes.length == 1 ? '' : 's'} remaining. '
              'Now on note ${_currentIndex + 1}.');
    }
  }

  void _askDeleteAll() {
    if (_filteredNotes.isEmpty) {
      _speak(_lang.isKannada
          ? 'ಅಳಿಸಲು ಯಾವ ಟಿಪ್ಪಣಿಗಳೂ ಇಲ್ಲ.'
          : 'No notes to delete.');
      return;
    }
    setState(() {
      _awaitingDeleteAllConfirm = true;
      _deleteAllConfirmCount = 0;
    });
    HapticFeedback.heavyImpact();
    _speak(_lang.deleteAllPrompt(_filteredNotes.length));
  }

  Future<void> _confirmDeleteAll() async {
    await DatabaseService.deleteAllNotes();
    HapticFeedback.heavyImpact();
    if (!mounted) return;
    setState(() {
      _awaitingDeleteAllConfirm = false;
      _deleteAllConfirmCount = 0;
      _awaitingDeleteConfirm = false;
      _notes = [];
      _filteredNotes = [];
      _currentIndex = 0;
      _activeFilter = 'all';
      _isLoading = false;
    });
    _speak(_lang.deleteAllDone());
  }

  Future<void> _shareCurrentItem() async {
    if (_filteredNotes.isEmpty) {
      _speak(_lang.isKannada ? 'ಹಂಚಲು ಯಾವ ಟಿಪ್ಪಣಿಗಳೂ ಇಲ್ಲ.' : 'No notes to share.');
      return;
    }
    final note = _filteredNotes[_currentIndex];
    final summary = note['summary'] as String? ?? '';
    final date = note['date'] as String? ?? '';
    await Clipboard.setData(ClipboardData(
      text: _lang.isKannada
          ? '$date ದಿನಾಂಕದ ಟಿಪ್ಪಣಿ:\n\n$summary'
          : 'Note from $date:\n\n$summary',
    ));
    HapticFeedback.mediumImpact();
    _speak(_lang.sharedToClipboard());
  }

  // ── GLOBAL ────────────────────────────────────────────
  void _goHome() {
    _stopSpeaking();
    Navigator.pop(context);
  }

  void _readHelp() => _speak(_lang.historyHelp());

  // ── DATA LOADING ──────────────────────────────────────
  Future<void> _loadNotes() async {
    final notes = await DatabaseService.getNotes();
    if (!mounted) return;

    List<Map<String, dynamic>> filtered;
    if (_activeFilter == 'all') {
      filtered = List.from(notes);
    } else {
      final now = DateTime.now();
      final date = _activeFilter == 'today'
          ? now.toString().substring(0, 10)
          : now.subtract(const Duration(days: 1)).toString().substring(0, 10);
      filtered = notes
          .where((n) => (n['date'] as String? ?? '').startsWith(date))
          .toList();
    }

    setState(() {
      _notes = notes;
      _filteredNotes = filtered;
      _isLoading = false;
      if (_currentIndex >= filtered.length) {
        _currentIndex = filtered.isEmpty ? 0 : filtered.length - 1;
      }
    });
  }

  Future<void> _initLoad() async {
    final notes = await DatabaseService.getNotes();
    if (!mounted) return;
    setState(() {
      _notes = notes;
      _filteredNotes = List.from(notes);
      _isLoading = false;
    });
    if (notes.isEmpty) {
      _speak(_lang.historyEmpty());
    } else {
      _speak(_lang.historyWelcome(notes.length));
    }
  }

  // ── BUILD ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isKannada = _lang.isKannada;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(isKannada),
            if (_filteredNotes.isNotEmpty) _buildCurrentItemBanner(isKannada),
            if (_activeFilter != 'all') _buildFilterChip(isKannada),
            _buildStatusBar(isKannada),
            Expanded(child: _buildNotesList(isKannada)),
            _buildVoiceBar(isKannada),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isKannada) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _speak(isKannada
                  ? 'ಹಿಂದೆ ಬಟನ್. ಮನೆಗೆ ಹೋಗಲು ಎರಡು ಬಾರಿ ತಟ್ಟಿ.'
                  : 'Back button. Double tap to go home.');
            },
            onDoubleTap: _goHome,
            child:
                const Icon(Icons.arrow_back, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 12),
          Text(
            isKannada ? 'ಉಳಿಸಿದ ಟಿಪ್ಪಣಿಗಳು' : 'Saved Notes',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          // Language pill
          GestureDetector(
            onTap: () => _speak(_lang.languageButtonDesc()),
            onDoubleTap: () {
              if (isKannada) {
                _lang.switchToEnglish();
                _speak(_lang.switchedToEnglish());
              } else {
                _lang.switchToKannada();
                _speak(_lang.switchedToKannada());
              }
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isKannada
                    ? Colors.orange.shade900
                    : Colors.indigo.shade900,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                isKannada ? 'ಕನ್ನಡ' : 'EN',
                style: TextStyle(
                  color: isKannada
                      ? Colors.orangeAccent
                      : Colors.indigoAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Speed indicator
          GestureDetector(
            onTap: () => _speak(_lang.speedSet((_ttsRate * 100).round())),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.indigo.shade900,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${(_ttsRate * 100).round()}%',
                style:
                    const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentItemBanner(bool isKannada) {
    if (_filteredNotes.isEmpty) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => _speak(isKannada
          ? 'ಪ್ರಸ್ತುತ ಟಿಪ್ಪಣಿ ${_currentIndex + 1} of ${_filteredNotes.length}. ಸಾರಾಂಶ ಕೇಳಲು ಓದಿ ಎಂದು ಹೇಳಿ.'
          : 'Currently on note ${_currentIndex + 1} of ${_filteredNotes.length}. Say read to hear it.'),
      onDoubleTap: _readCurrentItem,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.deepPurple.shade900,
          borderRadius: BorderRadius.circular(10),
          border:
              Border.all(color: Colors.deepPurpleAccent.withAlpha(120)),
        ),
        child: Row(
          children: [
            const Icon(Icons.touch_app,
                color: Colors.deepPurpleAccent, size: 18),
            const SizedBox(width: 8),
            Text(
              isKannada
                  ? 'ಟಿಪ್ಪಣಿ ${_currentIndex + 1} of ${_filteredNotes.length} ಆಯ್ಕೆಮಾಡಲಾಗಿದೆ'
                  : 'Note ${_currentIndex + 1} of ${_filteredNotes.length} selected',
              style:
                  const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const Spacer(),
            Text(
              _filteredNotes[_currentIndex]['date'] ?? '',
              style:
                  const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(bool isKannada) {
    final filterLabel = isKannada
        ? (_activeFilter == 'today' ? 'ಇಂದು' : 'ನಿನ್ನೆ')
        : _activeFilter;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.teal.shade900,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.filter_list,
                    color: Colors.tealAccent, size: 14),
                const SizedBox(width: 6),
                Text(
                  '${isKannada ? 'ತೋರಿಸಲಾಗುತ್ತಿದೆ' : 'Showing'}: $filterLabel',
                  style: const TextStyle(
                      color: Colors.tealAccent, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _clearFilter,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade800,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isKannada ? 'ಎಲ್ಲ ತೋರಿಸಿ' : 'Show all',
                style:
                    const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar(bool isKannada) {
    String message = '';
    Color color = Colors.grey.shade900;
    Color textColor = Colors.white54;

    if (_isListening) {
      message = isKannada
          ? '🎙️ ಆಲಿಸಲಾಗುತ್ತಿದೆ... ಆದೇಶ ಹೇಳಿ'
          : '🎙️ Listening... speak your command';
      color = Colors.green.shade900;
      textColor = Colors.greenAccent;
    } else if (_awaitingDeleteConfirm) {
      message = isKannada
          ? '⚠️ ದೃಢಪಡಿಸಲು "ಹೌದು" ಅಥವಾ ರದ್ದಿಗೆ "ಇಲ್ಲ" ಎಂದು ಹೇಳಿ'
          : '⚠️ Say "yes" to confirm delete, or "no" to cancel';
      color = Colors.red.shade900;
      textColor = Colors.redAccent;
    } else if (_awaitingDeleteAllConfirm) {
      message = isKannada
          ? '🚨 ಎಲ್ಲ ಟಿಪ್ಪಣಿಗಳನ್ನು ಅಳಿಸಲು ಮತ್ತೊಮ್ಮೆ "ಹೌದು" ಹೇಳಿ'
          : '🚨 Say "yes" again to delete ALL notes';
      color = Colors.deepOrange.shade900;
      textColor = Colors.orangeAccent;
    }

    if (message.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: color, borderRadius: BorderRadius.circular(10)),
      child: Text(message,
          style: TextStyle(color: textColor, fontSize: 13),
          textAlign: TextAlign.center),
    );
  }

  Widget _buildNotesList(bool isKannada) {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.deepPurple));
    }
    if (_filteredNotes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.note_alt_outlined,
                color: Colors.white24, size: 80),
            const SizedBox(height: 16),
            Text(
              _activeFilter != 'all'
                  ? (isKannada
                      ? '$_activeFilter ಯಾವ ಟಿಪ್ಪಣಿಗಳೂ ಇಲ್ಲ'
                      : 'No notes for $_activeFilter')
                  : (isKannada
                      ? 'ಇನ್ನೂ ಉಳಿಸಿದ ಟಿಪ್ಪಣಿಗಳಿಲ್ಲ'
                      : 'No saved notes yet'),
              style:
                  const TextStyle(color: Colors.white54, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              isKannada
                  ? '"ಎಲ್ಲ ತೋರಿಸಿ" ಎಂದು ಹೇಳಿ'
                  : 'Say "show all" to see all notes',
              style:
                  const TextStyle(color: Colors.white24, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filteredNotes.length,
      itemBuilder: (context, index) {
        final note = _filteredNotes[index];
        final isSelected = index == _currentIndex;

        return GestureDetector(
          onTap: () {
            setState(() => _currentIndex = index);
            HapticFeedback.lightImpact();
            _describeCurrentItem();
          },
          onDoubleTap: () {
            setState(() => _currentIndex = index);
            HapticFeedback.mediumImpact();
            _readCurrentItem();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.deepPurple.shade900
                  : Colors.grey.shade900,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? Colors.deepPurpleAccent
                    : Colors.deepPurple.withAlpha(60),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (isSelected)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: const BoxDecoration(
                          color: Colors.deepPurpleAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    Text(
                      '${isKannada ? 'ಟಿಪ್ಪಣಿ' : 'Note'} ${index + 1}',
                      style: TextStyle(
                        color: isSelected
                            ? Colors.deepPurpleAccent
                            : Colors.deepPurple.shade200,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _speak(isKannada
                          ? 'ಅಳಿಸಿ ಬಟನ್. ಟಿಪ್ಪಣಿ ${index + 1} ಅಳಿಸಲು ಎರಡು ಬಾರಿ ತಟ್ಟಿ.'
                          : 'Delete button. Double tap to delete note ${index + 1}.'),
                      onDoubleTap: () {
                        setState(() => _currentIndex = index);
                        _askDeleteCurrent();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        child: const Icon(Icons.delete_outline,
                            color: Colors.red, size: 22),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  note['summary'] ?? '',
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 14, height: 1.5),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.access_time,
                        color: Colors.white24, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      note['date'] ?? '',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isSelected
                      ? (isKannada
                          ? 'ಆಯ್ಕೆ — ಓದಿ, ಚಿಕ್ಕ, ವಿವರ, ಅಳಿಸಿ, ಹಂಚಿ ಎಂದು ಹೇಳಿ'
                          : 'Selected — say read, short, detailed, delete, share')
                      : (isKannada
                          ? 'ತಟ್ಟಿ ಆಯ್ಕೆ · ಎರಡು ಬಾರಿ ತಟ್ಟಿ ಓದಿ'
                          : 'Tap to select · Double tap to read'),
                  style: TextStyle(
                    color: isSelected
                        ? Colors.deepPurple.shade200
                        : Colors.white24,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVoiceBar(bool isKannada) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        border: Border(top: BorderSide(color: Colors.white.withAlpha(20))),
      ),
      child: Row(
        children: [
          // Help button
          GestureDetector(
            onTap: () => _speak(isKannada
                ? 'ಸಹಾಯ ಬಟನ್. ಎಲ್ಲ ಆದೇಶಗಳಿಗಾಗಿ ಎರಡು ಬಾರಿ ತಟ್ಟಿ.'
                : 'Tap help button. Double tap for voice commands list.'),
            onDoubleTap: _readHelp,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.grey.shade800,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.help_outline,
                  color: Colors.white54, size: 24),
            ),
          ),

          const SizedBox(width: 12),

          // Main voice button
          Expanded(
            child: GestureDetector(
              onTap: _speechAvailable
                  ? (_isListening ? _stopListening : _startListening)
                  : () => _speak(isKannada
                      ? 'ಮೈಕ್ ಲಭ್ಯವಿಲ್ಲ.'
                      : 'Microphone not available.'),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 52,
                decoration: BoxDecoration(
                  color: _isListening
                      ? Colors.green.shade800
                      : _awaitingDeleteConfirm || _awaitingDeleteAllConfirm
                          ? Colors.red.shade800
                          : Colors.deepPurple,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_isListening ? Icons.mic : Icons.mic_none,
                        color: Colors.white, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      _isListening
                          ? (isKannada ? 'ಆಲಿಸಲಾಗುತ್ತಿದೆ...' : 'Listening...')
                          : _awaitingDeleteConfirm
                              ? (isKannada
                                  ? 'ಹೌದು ಅಥವಾ ಇಲ್ಲ ಹೇಳಿ'
                                  : 'Say yes or no')
                              : _awaitingDeleteAllConfirm
                                  ? (isKannada
                                      ? 'ಹೌದು ಅಥವಾ ಇಲ್ಲ ಹೇಳಿ'
                                      : 'Say yes or no')
                                  : (isKannada
                                      ? 'ಆದೇಶ ಹೇಳಲು ತಟ್ಟಿ'
                                      : 'Tap to speak a command'),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Stop TTS button
          GestureDetector(
            onTap: () {
              _stopSpeaking();
              HapticFeedback.lightImpact();
            },
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.grey.shade800,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.stop_circle_outlined,
                  color: Colors.white54, size: 24),
            ),
          ),
        ],
      ),
    );
  }
}
