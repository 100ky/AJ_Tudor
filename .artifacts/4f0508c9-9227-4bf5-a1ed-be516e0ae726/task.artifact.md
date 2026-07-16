# TODO List - Vizuální vylepšení hlasového chatu

- [ ] **Fáze 1: Audio Backend (Hlasitost AI)**
    - [ ] Přidat výpočet hlasitosti (RMS) do `AudioPlaybackService`
    - [ ] Exponovat `playbackVolumeStream` v `AudioSessionController`
- [ ] **Fáze 2: UI Komponenty**
    - [ ] Zobecnit `WaveformVisualizer` pro příjem libovolného streamu
    - [ ] Přidat plynulejší animace a vylepšený design vln
- [ ] **Fáze 3: Hlavní obrazovka (VoiceTutorScreen)**
    - [ ] Integrovat vizualizaci pro stav `TutorState.speaking`
    - [ ] Vylepšit "Ambient Orb" (stíny, pulzování)
    - [ ] Začistit zobrazení transkriptu a styl bublin
- [ ] **Fáze 4: Verifikace**
    - [ ] Otestovat na reálném zařízení odezvu vln na hlas AI
