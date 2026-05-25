/// Per-session language singleton.
/// Holds the current language (English / Kannada) and notifies listeners.
/// Resets to English on every app restart (no persistence needed).

class LanguageService {
  LanguageService._();
  static final LanguageService instance = LanguageService._();

  // ── Current language ──────────────────────────────────
  bool _isKannada = false;
  bool get isKannada => _isKannada;

  String get ttsLocale     => _isKannada ? 'kn-IN' : 'en-US';
  String get languageName  => _isKannada ? 'Kannada' : 'English';

  // ── Listeners ─────────────────────────────────────────
  final List<void Function()> _listeners = [];

  void addListener(void Function() listener) {
    _listeners.add(listener);
  }

  void removeListener(void Function() listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners() {
    for (final l in _listeners) {
      l();
    }
  }

  // ── Switch language ───────────────────────────────────
  void switchToKannada() {
    if (!_isKannada) {
      _isKannada = true;
      _notifyListeners();
    }
  }

  void switchToEnglish() {
    if (_isKannada) {
      _isKannada = false;
      _notifyListeners();
    }
  }

  void toggle() {
    _isKannada = !_isKannada;
    _notifyListeners();
  }

  // ── Translated strings ────────────────────────────────
  // Each method returns the correct language string.

  String welcome() => _isKannada
      ? 'ಬ್ಲೈಂಡ್ ನೋಟ್ಸ್ ಎಐಗೆ ಸ್ವಾಗತ. '
        'ಎರಡು ಬಟನ್‌ಗಳಿವೆ. '
        'ಹೊಸ ಟಿಪ್ಪಣಿ ಸ್ಕ್ಯಾನ್ ಮಾಡಲು ಮೇಲಿನ ನೇರಳೆ ಬಟನ್ ಅನ್ನು ಎರಡು ಬಾರಿ ತಟ್ಟಿ. '
        'ಉಳಿಸಿದ ಟಿಪ್ಪಣಿಗಳ ಇತಿಹಾಸ ನೋಡಲು ಕೆಳಗಿನ ಹಸಿರು ಬಟನ್ ಅನ್ನು ಎರಡು ಬಾರಿ ತಟ್ಟಿ.'
      : 'Welcome to Blind Notes AI. '
        'There are two buttons. '
        'Double tap the top purple button to scan a new note. '
        'Double tap the bottom green button to view your saved notes history.';

  String scanButtonDesc() => _isKannada
      ? 'ಟಿಪ್ಪಣಿ ಸ್ಕ್ಯಾನ್ ಬಟನ್. ಕ್ಯಾಮೆರಾ ತೆರೆಯಲು ಎರಡು ಬಾರಿ ತಟ್ಟಿ.'
      : 'Scan Note button. Double tap to open camera.';

  String historyButtonDesc() => _isKannada
      ? 'ಇತಿಹಾಸ ಬಟನ್. ಉಳಿಸಿದ ಟಿಪ್ಪಣಿಗಳು ನೋಡಲು ಎರಡು ಬಾರಿ ತಟ್ಟಿ.'
      : 'History button. Double tap to view saved notes.';

  String openingCamera() => _isKannada ? 'ಕ್ಯಾಮೆರಾ ತೆರೆಯಲಾಗುತ್ತಿದೆ.' : 'Opening camera.';
  String openingHistory() => _isKannada ? 'ಇತಿಹಾಸ ತೆರೆಯಲಾಗುತ್ತಿದೆ.' : 'Opening history.';

  String switchedToKannada() =>
      'ಭಾಷೆ ಕನ್ನಡಕ್ಕೆ ಬದಲಾಯಿಸಲಾಗಿದೆ. ಎಲ್ಲ ಉತ್ತರಗಳು ಇನ್ನು ಕನ್ನಡದಲ್ಲಿ ಇರುತ್ತವೆ.';
  String switchedToEnglish() => 'Language switched to English. All responses will now be in English.';

  String languageButtonDesc() => _isKannada
      ? 'ಭಾಷೆ ಬಟನ್: ಕನ್ನಡ. ಇಂಗ್ಲಿಷ್‌ಗೆ ಬದಲಾಯಿಸಲು ಎರಡು ಬಾರಿ ತಟ್ಟಿ.'
      : 'Language button: English. Double tap to switch to Kannada.';

  String helpText() => _isKannada
      ? 'ಸಹಾಯ. '
        'ಯಾವ ಬಟನ್ ಎಂದು ತಿಳಿಯಲು ಒಮ್ಮೆ ತಟ್ಟಿ. '
        'ಬಟನ್ ಒತ್ತಲು ಎರಡು ಬಾರಿ ತಟ್ಟಿ. '
        'ಕನ್ನಡಕ್ಕೆ ಬದಲಾಯಿಸಲು ಕನ್ನಡ ಬಟನ್ ಎರಡು ಬಾರಿ ತಟ್ಟಿ.'
      : 'Help. '
        'Single tap any button to hear what it does. '
        'Double tap any button to activate it. '
        'Double tap the language button to switch to Kannada.';

  // ── Result screen strings ─────────────────────────────
  String groqSystemPrompt() => _isKannada
      ? 'ನೀವು ಒಬ್ಬ ಸಹಾಯಕ. ದೃಷ್ಟಿ ವಿಕಲಾಂಗರಿಗಾಗಿ ಟಿಪ್ಪಣಿಗಳನ್ನು ಸರಳ ಮತ್ತು ಸ್ಪಷ್ಟ ಕನ್ನಡದಲ್ಲಿ ಸಂಕ್ಷೇಪಿಸಿ. ಉತ್ತರವನ್ನು ಕನ್ನಡದಲ್ಲೇ ನೀಡಿ.'
      : 'You are a helpful assistant that summarizes notes clearly and simply for blind people.';

  String groqShortPrompt(String text) => _isKannada
      ? 'ಈ ಟಿಪ್ಪಣಿಯನ್ನು ದೃಷ್ಟಿ ವಿಕಲಾಂಗ ವ್ಯಕ್ತಿಗಾಗಿ 2-3 ಸರಳ ಕನ್ನಡ ವಾಕ್ಯಗಳಲ್ಲಿ ಸಂಕ್ಷೇಪಿಸಿ:\n\n$text'
      : 'Summarize this note in 2-3 simple sentences for a blind person:\n\n$text';

  String groqDetailedPrompt(String text) => _isKannada
      ? 'ಈ ಟಿಪ್ಪಣಿಯ ಪ್ರಮುಖ ಅಂಶಗಳ ಸಮೇತ ವಿಸ್ತೃತ ಸಾರಾಂಶವನ್ನು ದೃಷ್ಟಿ ವಿಕಲಾಂಗ ವ್ಯಕ್ತಿಗಾಗಿ ಕನ್ನಡದಲ್ಲಿ ನೀಡಿ:\n\n$text'
      : 'Give a detailed summary with key points of this note for a blind person:\n\n$text';

  String noInternetFallback(String rawText) => _isKannada
      ? 'ಇಂಟರ್ನೆಟ್ ಸಂಪರ್ಕ ಇಲ್ಲ. ಟಿಪ್ಪಣಿಯನ್ನು ನೇರವಾಗಿ ಓದಲಾಗುತ್ತಿದೆ. $rawText'
      : 'No internet connection. Reading your note directly. $rawText';

  String aiSummarizing() => _isKannada ? 'ಎಐ ಸಾರಾಂಶ ತಯಾರಿಸುತ್ತಿದೆ...' : 'AI is summarizing...';

  String readAloudDesc() => _isKannada
      ? 'ಜೋರಾಗಿ ಓದಿ ಬಟನ್. ಸಾರಾಂಶ ಕೇಳಲು ಎರಡು ಬಾರಿ ತಟ್ಟಿ.'
      : 'Read aloud button. Double tap to hear the summary.';

  String readAloudDescFallback() => _isKannada
      ? 'ಜೋರಾಗಿ ಓದಿ ಬಟನ್. ಟಿಪ್ಪಣಿ ಕೇಳಲು ಎರಡು ಬಾರಿ ತಟ್ಟಿ.'
      : 'Read aloud button. Double tap to hear the note.';

  // ── History screen strings ────────────────────────────
  String historyWelcome(int count) => _isKannada
      ? '$count ಉಳಿಸಿದ ಟಿಪ್ಪಣಿ${count == 1 ? '' : 'ಗಳು'} ಕಂಡುಬಂದಿವೆ. '
        'ಪ್ರಸ್ತುತ ಟಿಪ್ಪಣಿ ಕೇಳಲು ಓದಿ ಎಂದು ಹೇಳಿ, '
        'ಅಥವಾ ಎಲ್ಲ ಆದೇಶಗಳಿಗಾಗಿ ಸಹಾಯ ಎಂದು ಹೇಳಿ.'
      : '$count saved note${count == 1 ? '' : 's'} found. '
        'Say read to hear the current note, '
        'or say help to hear all voice commands.';

  String historyEmpty() => _isKannada
      ? 'ಇನ್ನೂ ಉಳಿಸಿದ ಟಿಪ್ಪಣಿಗಳಿಲ್ಲ. ಮೊದಲು ಟಿಪ್ಪಣಿ ಸ್ಕ್ಯಾನ್ ಮಾಡಿ.'
      : 'No saved notes yet. Scan a note first.';

  String historyCommandUnknown() => _isKannada
      ? 'ಆದೇಶ ಗುರುತಿಸಲಾಗಿಲ್ಲ. ಎಲ್ಲ ಆದೇಶಗಳಿಗಾಗಿ ಸಹಾಯ ಎಂದು ಹೇಳಿ.'
      : 'Command not recognised. Say help to hear all commands.';

  String historyHelp() => _isKannada
      ? 'ಲಭ್ಯ ಧ್ವನಿ ಆದೇಶಗಳು. '
        'ನ್ಯಾವಿಗೇಶನ್: ಮುಂದೆ, ಹಿಂದೆ, ಮೊದಲ, ಕೊನೆ, ಮೂರನೇ ತೆರೆ, ಎಷ್ಟು, ಎಲ್ಲ ಪಟ್ಟಿ. '
        'ಪ್ಲೇಬ್ಯಾಕ್: ಓದಿ, ಚಿಕ್ಕ, ವಿವರ, ನಿಲ್ಲಿಸಿ, ಪುನರಾವರ್ತಿಸಿ, ವೇಗ ಹೆಚ್ಚಿಸಿ, ವೇಗ ಕಡಿಮೆ ಮಾಡಿ. '
        'ನಿರ್ವಹಣೆ: ಅಳಿಸಿ, ಎಲ್ಲ ಅಳಿಸಿ, ಹಂಚಿ. '
        'ಇತರ: ಮನೆ, ಸಹಾಯ, ಕನ್ನಡಕ್ಕೆ ಬದಲಾಯಿಸಿ, ಇಂಗ್ಲಿಷ್‌ಗೆ ಬದಲಾಯಿಸಿ.'
      : 'Available voice commands. '
        'Navigation: next, previous, first, last, open 3, how many, list all, show today, show yesterday, show all. '
        'Playback: read, short, detailed, stop, repeat, faster, slower, what is this. '
        'Management: delete, delete all, share. '
        'Other: home, help, switch to Kannada, switch to English.';

  String noteDescription(int current, int total, String date, int wordCount) =>
      _isKannada
          ? 'ಟಿಪ್ಪಣಿ $current of $total. '
            '$date ದಿನಾಂಕದಂದು ಉಳಿಸಲಾಗಿದೆ. '
            'ಸುಮಾರು $wordCount ಪದಗಳು. '
            'ಸಾರಾಂಶ ಕೇಳಲು ಓದಿ ಎಂದು ಹೇಳಿ.'
          : 'Note $current of $total. '
            'Saved on $date. '
            'About $wordCount words. '
            'Say read to hear the summary.';

  String deleteConfirmPrompt(int noteNum, String date) => _isKannada
      ? 'ಖಚಿತವಾಗಿ $noteNum ನೇ ಟಿಪ್ಪಣಿ, $date ದಿನಾಂಕದ್ದನ್ನು ಅಳಿಸಬೇಕೇ? ಹೌದು ಎಂದು ದೃಢಪಡಿಸಿ ಅಥವಾ ಇಲ್ಲ ಎಂದು ರದ್ದು ಮಾಡಿ.'
      : 'Are you sure you want to delete note $noteNum, saved on $date? Say yes to confirm or no to cancel.';

  String deleteCancelled() => _isKannada ? 'ಅಳಿಸುವಿಕೆ ರದ್ದು.' : 'Delete cancelled.';

  String deleteAllPrompt(int count) => _isKannada
      ? 'ಎಚ್ಚರಿಕೆ! ಎಲ್ಲ $count ಟಿಪ್ಪಣಿಗಳನ್ನು ಶಾಶ್ವತವಾಗಿ ಅಳಿಸಲಾಗುತ್ತದೆ. ದೃಢಪಡಿಸಲು ಹೌದು ಎಂದು ಅಥವಾ ರದ್ದು ಮಾಡಲು ಇಲ್ಲ ಎಂದು ಹೇಳಿ.'
      : 'Warning! This will permanently delete all $count notes. Say yes to confirm or no to cancel.';

  String deleteAllCancelled() => _isKannada
      ? 'ಎಲ್ಲ ಅಳಿಸುವಿಕೆ ರದ್ದು. ನಿಮ್ಮ ಟಿಪ್ಪಣಿಗಳು ಸುರಕ್ಷಿತ.'
      : 'Delete all cancelled. Your notes are safe.';

  String deleteAllDone() => _isKannada
      ? 'ಎಲ್ಲ ಟಿಪ್ಪಣಿಗಳು ಅಳಿಸಲಾಗಿದೆ. ಇತಿಹಾಸ ಖಾಲಿ. ಹೊಸ ಟಿಪ್ಪಣಿ ಸ್ಕ್ಯಾನ್ ಮಾಡಿ ಪ್ರಾರಂಭಿಸಿ.'
      : 'All notes deleted. History is now empty. Scan a new note to get started.';

  String sharedToClipboard() => _isKannada
      ? 'ಸಾರಾಂಶ ಕ್ಲಿಪ್‌ಬೋರ್ಡ್‌ಗೆ ನಕಲಿಸಲಾಗಿದೆ. ವಾಟ್ಸ್‌ಆ್ಯಪ್ ಅಥವಾ ಯಾವುದೇ ಆ್ಯಪ್‌ನಲ್ಲಿ ಅಂಟಿಸಬಹುದು.'
      : 'Summary copied to clipboard. You can paste it in WhatsApp or any app.';

  String speedSet(int pct) => _isKannada
      ? 'ವೇಗ $pct ಶೇಕಡಾಕ್ಕೆ ಹೊಂದಿಸಲಾಗಿದೆ.'
      : 'Speed set to $pct percent.';

  // ── Scan screen strings ───────────────────────────────
  String scanReady() => _isKannada
      ? 'ಸ್ಕ್ಯಾನ್ ಸ್ಕ್ರೀನ್ ಸಿದ್ಧ. '
        'ಆಟೋ ಕ್ಯಾಪ್ಚರ್ ಪ್ರಾರಂಭಿಸಲು ಹಸಿರು ಬಟನ್ ಎರಡು ಬಾರಿ ತಟ್ಟಿ. '
        'ಟಿಪ್ಪಣಿ ಮೇಲೆ ಫೋನ್ ಸಮತಟ್ಟಾಗಿ ಹಿಡಿದು ಸ್ಥಿರವಾಗಿರಿ. '
        'ಸಿದ್ಧವಾದಾಗ ಆ್ಯಪ್ ಸ್ವಯಂಚಾಲಿತವಾಗಿ ಕ್ಯಾಪ್ಚರ್ ಮಾಡುತ್ತದೆ.'
      : 'Scan screen ready. '
        'Double tap the green button to start auto capture. '
        'Hold phone flat over your note and stay still. '
        'The app will automatically capture when ready.';



  String noteCaptured() => _isKannada
      ? 'ಟಿಪ್ಪಣಿ ಕ್ಯಾಪ್ಚರ್ ಆಗಿದೆ! ಎಐಗೆ ಕಳುಹಿಸಲಾಗುತ್ತಿದೆ.'
      : 'Note captured! Sending to AI.';

  String noTextFound() => _isKannada
      ? 'ಯಾವ ಪಠ್ಯವೂ ಕಂಡುಬಂದಿಲ್ಲ. '
        'ಟಿಪ್ಪಣಿ ಸಮತಟ್ಟಾಗಿ ಮತ್ತು ಚೆನ್ನಾಗಿ ಬೆಳಗಿದ ಸ್ಥಳದಲ್ಲಿ ಇದೆ ಎಂದು ಖಚಿತಪಡಿಸಿ. '
        'ಮತ್ತೆ ಆಟೋ ಮೋಡ್ ಪ್ರಯತ್ನಿಸಲು ಹಸಿರು ಬಟನ್ ಎರಡು ಬಾರಿ ತಟ್ಟಿ.'
      : 'No text found. '
        'Make sure the note is flat and well lit. '
        'Double tap green button to try auto mode again.';
}