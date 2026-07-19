# Zachování postupu po přeinstalaci aplikace

Tento plán popisuje, jak zajistit, aby herní postup a nastavení zůstaly zachovány i v případě, že aplikaci z telefonu ručně odinstalujete a znovu nainstalujete (např. stažením nové verze APK), aniž byste museli implementovat složitý cloudový systém s přihlašováním.

## Navržené řešení

Využijeme nativní funkci systému Android **Auto Backup** (Zálohování do Google Disku). Tato funkce automaticky nahraje data vaší aplikace (do 25 MB) na Google účet uživatele a při příští instalaci je automaticky obnoví.

### Klíčové body řešení:
1.  **Konfigurace zálohování:** Nastavíme pravidla, která soubory (databázi a nastavení) má Android zálohovat.
2.  **AndroidManifest:** Povolíme zálohování v konfiguračním souboru aplikace.
3.  **Omezení:** Data v `flutter_secure_storage` (API klíč) se z bezpečnostních důvodů standardně nezálohují (klíče pro šifrování jsou vázány na konkrétní instalaci). Postup (databáze) a běžná nastavení (hlas, model) se však obnoví.

## Navržené změny

### [Android] Konfigurace zálohování

#### [NEW] [backup_rules.xml](file:///C:/Users/tosma/OneDrive/Desktop/AJ_Tudor/android/app/src/main/res/xml/backup_rules.xml)
Vytvoříme soubor s pravidly pro starší verze Androidu (do verze 11).
- Zahrneme soubor `db.sqlite` (vaše databáze).
- Zahrneme složku `shared_prefs` (nastavení aplikace).

#### [NEW] [data_extraction_rules.xml](file:///C:/Users/tosma/OneDrive/Desktop/AJ_Tudor/android/app/src/main/res/xml/data_extraction_rules.xml)
Vytvoříme soubor pro Android 12 a novější, který specifikuje pravidla pro cloudové zálohování a přenos mezi zařízeními.

#### [MODIFY] [AndroidManifest.xml](file:///C:/Users/tosma/OneDrive/Desktop/AJ_Tudor/android/app/src/main/AndroidManifest.xml)
- Přidáme atributy `android:allowBackup="true"`.
- Propojíme nově vytvořené soubory s pravidly.

## Alternativní možnosti (pro budoucno)
Pokud byste v budoucnu chtěli mít 100% kontrolu a synchronizaci mezi více zařízeními (např. tablet a mobil), bylo by nutné:
1.  Implementovat **Firebase Firestore** (ukládání postupu do cloudu v reálném čase).
2.  Přidat **Google Sign-In** (aby aplikace věděla, komu postup patří).

## Ověřovací plán

### Ruční ověření
1.  Spustit aplikaci, vytvořit nějaký postup (např. absolvovat jednu lekci).
2.  Změnit nějaké nastavení (např. vybrat jiný hlas Gemini).
3.  V nastavení telefonu zkontrolovat, zda je zálohování pro aplikaci aktivní (může trvat, než Android zálohu provede).
4.  Odinstalovat aplikaci.
5.  Znovu nainstalovat (přes APK nebo IDE) a ověřit, zda je postup a nastavení zpět.

> [!WARNING]
> Automatické zálohování na Androidu může trvat i několik hodin (obvykle probíhá v noci, když je telefon na nabíječce a na Wi-Fi). Pro okamžité testování lze zálohu vynutit přes příkazovou řádku (ADB).

Schvalujete tento postup pomocí Android Auto Backup?
