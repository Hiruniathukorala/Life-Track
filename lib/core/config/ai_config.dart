/// AI configuration for LifeTrack
///
/// To enable Gemini-powered mood detection:
///   1. Visit https://aistudio.google.com/app/apikey
///   2. Create a free API key
///   3. Replace the placeholder below with your key
///
/// The app works fully without a key using its built-in smart analysis.
class AiConfig {
  static const String geminiApiKey = 'AIzaSyBWihWCozOuQREjqV0-F9AWv_DA8_i0xJ8';

  /// Returns true when a real API key has been set.
  static bool get isConfigured =>
      geminiApiKey.isNotEmpty &&
      geminiApiKey != 'YOUR_GEMINI_API_KEY_HERE';
}
