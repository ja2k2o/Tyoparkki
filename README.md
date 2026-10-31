# Työparkki

A tiny iOS 26 app + widget (Home Screen and CarPlay) showing free spaces in K1/K2 and Hiekkaparkki from https://parkkimaksu.fi/.
Available in English and Finnish, with Siri support.

## 1. Open and sign

1. Open `Tyoparkki.xcodeproj` in Xcode 26.
2. Select the project → target **Tyoparkki** → *Signing & Capabilities* → Team →
   your Personal Team. Do the same for **TyoparkkiWidget**. (Xcode remembers this.)
Bundle IDs: `com.github.ja2k2o.Tyoparkki` and `com.github.ja2k2o.Tyoparkki.Widget `(bundle IDs can't contain "ö"; the name shown on the Home Screen is "Työparkki").
With a Personal Team, the app has to be reinstalled from Xcode every 7 days.

## 2. Register plate

Set the plate in **Settings → Apps → Työparkki**. The field starts empty (iOS Settings pages don't support placeholder text, so the example "ABC-123" is in the note below the field). Country defaults to FIN. Spaces and hyphens don't matter: "ABC-123", "abc 123" and "ABC123" all work.
The widget can't read the Settings app's values directly, so the app copies them to a shared App Group (`group.com.github.ja2k2o.Tyoparkki`) whenever you open it or ask Siri. After changing the plate, open the app once (or ask Siri) and the widget follows.
If Xcode shows the App Group in red under *Signing & Capabilities* → App Groups, tick its checkbox or press the refresh button there so Xcode registers it for your team. Both targets must use the same group.

## 3. Data source

The app reads` https://parkkimaksu.fi/api/parkkimaksu/spaces?plateText=<plate>&plateCountry=<country>`. Each entry has a free-space count (`spaces`) and the halls it covers (`targets[].hallName`). K1 and K2 are reported as one shared group.
Areas and hall-name matching are in `Shared/ParkingModels.swift`; plate handling is in `Shared/PlateSettings.swift`, and the Settings page in `Tyoparkki/Settings.bundle`.

## 4. Language

The app and widget follow the iPhone's language. To use Finnish for this app only: Settings → Apps → Työparkki → Language.
Translations are in `Shared/Localizable.xcstrings` (app, widget and Siri answers) and`Tyoparkki/AppShortcuts.xcstrings` (Siri phrases). Open them in Xcode to edit.

## 5. Siri

Works right after install (open the app once if Siri doesn't find it at first). Also works in CarPlay, in the Shortcuts app and from the Action button.

| Finnish                          | English                              | Answers about |
|----------------------------------|--------------------------------------|---------------|
| "Työparkki vapaat paikat"        | "How many free spaces in Työparkki"  | Both areas    |
| "Tarkista Työparkki"             | "Check Työparkki"                    | Both areas    |
| "Näytä Työparkki"                | "Show Työparkki"                     | Both areas    |
| "Työparkki tilanne"              | "Työparkki free spaces"              | Both areas    |
| "Työparkki K1 ja K2"             | "Työparkki K1 and K2"                | K1/K2         |
| "Tarkista Työparkki K1 ja K2"    | "Check K1 and K2 in Työparkki"       | K1/K2         |
| "Työparkki Hiekkaparkki"         | "Työparkki Hiekkaparkki"             | Hiekkaparkki  |
| "Tarkista Työparkki Hiekkaparkki"| "Check Hiekkaparkki in Työparkki"    | Hiekkaparkki  |

Siri also accepts "Parkki" in place of "Työparkki" (set in `Tyoparkki/Info.plist`). Keep the app name in its base form; inflected forms like "Työparkista" won't match.

## 6. Widget & CarPlay

- Add the widget on the Home Screen (small size).
- Lock Screen: long-press the Lock Screen → Customize → Lock Screen → tap the widget area → Työparkki (the rectangular one). iOS draws it in one colour, so the numbers aren't green/orange/red there.
- In iOS 26, small widgets are available in CarPlay: add it from the widgets view on the car's screen, or in iPhone Settings → General → CarPlay → your car.
- iOS controls how often widgets refresh (roughly every 15–30 min). Opening the app or asking Siri fetches fresh numbers and updates the widget.

## Files

- `Shared/` – config, models, networking, translations (used by app and widget)
- `Tyoparkki/` – the app, Siri intents and phrases
- `TyoparkkiWidget/` – the WidgetKit extension
