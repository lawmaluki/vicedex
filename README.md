# ViceDex – GTA VI companion (Flutter, frontend only)

An unofficial, fan-made companion for Grand Theft Auto VI. Not affiliated with or endorsed by Rockstar Games.

The visual style is flat and dark: near-black background, rose-pink accent, translucent cards, Inter type and Phosphor icons, with a floating pill nav.

## Run it

Requires Flutter 3.35 or newer.

```bash
cd vicedex_app
flutter create . --project-name vicedex --platforms=android,ios,web
flutter pub get
flutter run
```

`flutter create .` only generates the platform folders (android/, ios/, web/). It leaves `lib/` and `pubspec.yaml` alone. It skips files that already exist, so the included `test/widget_test.dart` is kept (run it with `flutter test`).

## What's in it

From the MVP feature guide:

| Priority | Feature | Where |
| --- | --- | --- |
| P0 | Cheat directory | `screens/cheat_library_screen.dart` |
| P0 | Platform selector (PS5 / Xbox / PC) | Platform strip + detail switch; shared in `AppState` |
| P0 | Search and categories | Quick Cheat Finder (centre nav button) + category chips |
| P0 | Copy cheat code | Detail screen: one tap copies the sequence |
| P0 | Verification status | Verified / Unverified / Rumour badges, meters, finder filter |
| P1 | Favourites | Star on any cheat; Favourites tab (swipe to remove) |
| P1 | Vehicle directory | Vehicles tab: class filter, search, stats sheet |
| P1 | Easter eggs and secrets | Map & Secrets tab |
| P2 | Interactive map | Placeholder card on Map & Secrets |
| P2 | Community submissions | "+" button opens the submit form |

## Project layout

```
lib/
  main.dart                 app entry, theme, state scope
  theme/app_theme.dart      colours and type (Outfit via google_fonts)
  models/models.dart        Cheat, Vehicle, Secret, platform/status/category enums
  data/mock_data.dart       placeholder content – replace with your backend
  state/app_state.dart      platform, favourites, votes (in memory)
  widgets/common.dart       glass card, sequence chips, meters, badges, chips…
  widgets/floating_nav.dart floating pill nav with the glowing centre button
  screens/                  one file per screen + the submit and report sheets
```

## Important: the data is placeholder

Rockstar has not confirmed any GTA VI cheat codes. Every cheat, vehicle and secret in `mock_data.dart` is marked **Rumour** and labelled as a placeholder in the UI. When you add a backend (Supabase was the suggested option), only mark an entry **Verified** after it has been tested in the released game.

## Next steps when you add a backend

- Replace `MockData` with a repository that loads from Supabase.
- Persist favourites and votes (shared_preferences locally, Supabase later).
- Send submissions and reports to a moderation table instead of showing a snackbar.
