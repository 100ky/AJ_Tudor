# Stabilize Voice Chat and Prevent Freezes

The user reports that the app freezes during voice chat. Logs show significant frame skipping and unexpected WebSocket closures. I will optimize the UI performance and strengthen the reconnection logic.

## User Review Required

> [!NOTE]
> I will implement a "Throttling" mechanism for the volume visualizer. Instead of updating the UI for every tiny audio chunk, it will update at a maximum of 30FPS. This should significantly reduce the CPU load on the main thread.

## Proposed Changes

### UI Performance Optimization

#### [MODIFY] [audio_capture_service.dart](file:///C:/Users/tosma/OneDrive/Desktop/AJ_Tudor/lib/services/audio/audio_capture_service.dart)
- Throttling for `volumeStream`: Limit volume updates to avoid overloading the UI thread with too many repaints.

#### [MODIFY] [waveform_visualizer.dart](file:///C:/Users/tosma/OneDrive/Desktop/AJ_Tudor/lib/features/conversation/widgets/waveform_visualizer.dart)
- Minor optimizations to the `CustomPainter` to ensure it only repaints when necessary.

### Connection Resilience

#### [MODIFY] [gemini_live_client.dart](file:///C:/Users/tosma/OneDrive/Desktop/AJ_Tudor/lib/services/gemini/gemini_live_client.dart)
- Improve `connect` method to ensure old channels are properly cleaned up before creating new ones.
- Add a timeout for the setup message to prevent hanging in the `connecting` state.

#### [MODIFY] [voice_tutor_agent.dart](file:///C:/Users/tosma/OneDrive/Desktop/AJ_Tudor/lib/services/agents/voice_tutor_agent.dart)
- Add a watchdog timer to detect if the model stops responding for too long and trigger an automatic reconnect.
- Ensure the state is correctly reset to `listening` after a successful reconnection.

## Verification Plan

### Manual Verification
- Start a long voice session (5+ minutes).
- Simulate network instability (toggle Wi-Fi) and verify that the app recovers without freezing.
- Observe the waveform visualizer to ensure it remains smooth but doesn't cause frame drops.
