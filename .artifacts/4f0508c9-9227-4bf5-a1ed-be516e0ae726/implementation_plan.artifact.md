# Vizuální vylepšení hlasového chatu (AI Visualizer)

Cílem je, aby aplikace AJ Tudor působila živěji a profesionálněji. Aktuálně vidíme vlny jen když mluví uživatel. Přidáme vizualizaci i pro promluvy AI tutora a vylepšíme celkovou estetiku.

## Navrhované změny

### 1. Audio Vizualizace pro AI (Tutor Speaking)

Aktuálně `WaveformVisualizer` reaguje jen na mikrofon. Musíme zajistit, aby reagoval i na zvuk, který přichází z Gemini API.

- **[MODIFY] [audio_playback_service.dart](file:///C:/Users/tosma/OneDrive/Desktop/AJ_Tudor/lib/services/audio/audio_playback_service.dart):**
    - Přidání `StreamController<double>` pro hlasitost přehrávaného zvuku.
    - Výpočet RMS (hlasitosti) z příchozích PCM dat před jejich odesláním do reproduktoru.
- **[MODIFY] [waveform_visualizer.dart](file:///C:/Users/tosma/OneDrive/Desktop/AJ_Tudor/lib/features/conversation/widgets/waveform_visualizer.dart):**
    - Úprava, aby mohl přijímat libovolný stream hlasitosti (nejen z capture service).
    - Vylepšení vizuálního stylu (např. barvy, plynulejší animace).

### 2. Dynamické UI v VoiceTutorScreen

- **[MODIFY] [voice_tutor_screen.dart](file:///C:/Users/tosma/OneDrive/Desktop/AJ_Tudor/lib/features/conversation/voice_tutor_screen.dart):**
    - Použití `WaveformVisualizer` i ve stavu `TutorState.speaking` (ale s jinou barvou - např. fialovou).
    - Vylepšení "Ambient Orbu" (středové sféry) - přidání vícenásobného stínování a plynulejších přechodů mezi stavy.
    - Úprava zobrazení transkriptu pro lepší čitelnost.

### 3. AudioSessionController Bridge

- **[MODIFY] [audio_session_controller.dart](file:///C:/Users/tosma/OneDrive/Desktop/AJ_Tudor/lib/services/audio/audio_session_controller.dart):**
    - Expozice jednotného `playbackVolumeStream`.

## Verifikace

### Manuální testování
- Spuštění hlasového chatu.
- Ověření, že vlny reagují na můj hlas (zelená/modrá).
- Ověření, že vlny reagují na hlas tutora (fialová).
- Kontrola plynulosti animací na reálném zařízení (Samsung A528B).
