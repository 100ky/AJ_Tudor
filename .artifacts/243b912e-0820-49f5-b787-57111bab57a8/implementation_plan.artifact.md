# Přidání tlačítka pro smazání lekce v historii

Tento plán popisuje přidání funkce pro smazání konkrétní lekce (chatu) z historie aplikace. Tlačítko bude umístěno v detailu lekce vedle tlačítka pro analýzu a bude vyžadovat potvrzení uživatelem.

## Navrhované změny

### Repozitář

#### [MODIFY] [session_repository.dart](file:///D:/Programovani/AJ_Tudor/lib/data/repositories/session_repository.dart)
- Přidání metody `deleteSession(int sessionId)`, která v transakci smaže lekci i všechny související záznamy (transkripty, logy chyb).

### UI (Historie)

#### [MODIFY] [history_screen.dart](file:///D:/Programovani/AJ_Tudor/lib/features/history/history_screen.dart)
- Úprava `_SessionDetailSheetState`:
    - Přidání metody `_confirmDelete`, která zobrazí `AlertDialog` s dotazem, zda si uživatel přeje lekci opravdu smazat.
    - Přidání metody `_deleteSession`, která zavolá repozitář a po úspěšném smazání zavře detail (bottom sheet) i dialog.
    - Přidání `IconButton` s ikonou koše (`Icons.delete_outline`) do horní lišty detailu, vedle tlačítka analýzy.

## Ověřovací plán

### Ruční ověření
1. Přejít do sekce **Historie**.
2. Otevřít detail libovolné lekce.
3. Kliknout na novou ikonu koše v pravém horním rohu.
4. Ověřit, že se zobrazí potvrzovací dialog v češtině.
5. Zvolit **Zrušit** a ověřit, že lekce nebyla smazána.
6. Znovu kliknout na smazat a zvolit **Smazat**.
7. Ověřit, že:
    - Detail lekce se zavřel.
    - Lekce zmizela ze seznamu historie.
    - (Volitelně přes logy) Všechna data v DB byla korektně odstraněna.
