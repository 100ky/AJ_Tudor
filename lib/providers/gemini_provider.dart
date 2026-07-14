import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/gemini/gemini_live_client.dart';
import 'audio_provider.dart';
import 'config_provider.dart';

final geminiLiveClientProvider = Provider<GeminiLiveClient?>((ref) {
  final apiKey = ref.watch(apiKeyProvider);
  final playbackService = ref.watch(audioPlaybackServiceProvider);
  
  if (apiKey == null || apiKey.isEmpty) return null;
  
  final client = GeminiLiveClient(apiKey, playbackService);
  ref.onDispose(() => client.disconnect());
  
  return client;
});
