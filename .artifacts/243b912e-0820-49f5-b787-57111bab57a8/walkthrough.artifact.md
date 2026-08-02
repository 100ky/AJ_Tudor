# Smazání lekce v historii

Do historie konverzací byla přidána možnost smazat konkrétní lekci. Funkce obsahuje potvrzovací dialog, aby se zabránilo náhodnému smazání dat.

## Provedené změny

### Datová vrstva
- V `SessionRepository` byla vytvořena metoda `deleteSession`, která v jedné transakci odstraní:
    - Všechny záznamy hovoru (transkripty).
    - Všechny zaznamenané lingvistické chyby.
    - Samotný záznam o lekci.

### Uživatelské rozhraní
- Do horní části detailu lekce (v historii) byla přidána ikona koše.
- Po kliknutí na ikonu se zobrazí standardní `AlertDialog` v češtině.
- Při potvrzení smazání se detail lekce automaticky zavře a uživatel je informován zprávou (SnackBar).

## Ukázka změn

```dart
// history_screen.dart - Tlačítko a potvrzovací logika
IconButton(
  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
  tooltip: 'Smazat lekci',
  onPressed: _isDeleting ? null : _confirmDelete,
),
```

> [!TIP]
> Smazání lekce je trvalé a neodvolatelné. Data jsou okamžitě odstraněna z lokální SQLite databáze.
