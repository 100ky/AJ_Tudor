# Fix Gradle Build and Gemini Live API Deprecation

This plan addresses two critical issues identified in the logs:
1.  **Gradle Build Failure on Windows**: A "different roots" error caused by the project and Flutter cache residing on different drives.
2.  **Gemini Live API Deprecation**: The WebSocket connection closes with error 1007 because `media_chunks` is deprecated in favor of specific modality fields like `audio`.

## Proposed Changes

### 1. Android Configuration
To fix the Gradle build error, we will disable Kotlin's incremental compilation. This avoids the path calculation bug on Windows when working across multiple drives.

#### [MODIFY] [gradle.properties](file:///D:/Programovani/AJ_Tudor/android/gradle.properties)
- Add `kotlin.incremental=false` to ensure stable builds on Windows.

---

### 2. Gemini Live Client
To fix the WebSocket connection issue, we will update the data structure used when sending audio chunks to the Gemini Multimodal Live API.

#### [MODIFY] [gemini_live_client.dart](file:///D:/Programovani/AJ_Tudor/lib/services/gemini/gemini_live_client.dart)
- In `sendAudioChunk`, replace the `mediaChunks` list with a single `audio` object containing `data` and `mimeType`.

## Verification Plan

### Automated Tests
- N/A (Build and runtime connectivity issues are best verified manually in this context).

### Manual Verification
1.  **Build Verification**: Run `flutter clean` and then `flutter build apk` (or `flutter run`) to ensure the "different roots" error no longer appears in the Gradle logs.
2.  **API Verification**: Run the app and start a voice session. Monitor the logs to confirm that the WebSocket connection is established and maintained without the "Code 1007" error. Confirm that audio data is successfully sent and processed by the tutor.
