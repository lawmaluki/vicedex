# ViceDex – GTA VI companion (Flutter + backend)

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
  models/models.dart        Cheat, Vehicle, Secret, Provenance, enums
  data/content_pack.dart    the static content snapshot the app renders
  data/pack_codec.dart      JSON -> models, tolerant of bad records
  data/pack_store.dart      bundled asset + HTTP refresh with ETag
  data/backend_client.dart  Supabase REST: votes, submissions, reports
  data/backend_config.dart  --dart-define endpoints
  data/local_store.dart     key/value interface for device-local state
  data/content_repository.dart  the one entry point the UI uses
  state/app_state.dart      load status, platform, favourites, votes, tallies
  widgets/common.dart       glass card, sequence chips, meters, notices, credits
  widgets/floating_nav.dart floating pill nav with the glowing centre button
  screens/                  one file per screen + the submit and report sheets

backend/
  ingest/                   Python pipeline: GTA Wiki -> content pack
  packs/                    generated latest.json
  supabase/migrations/      schema, row level security, rate limits
  README.md                 where the data comes from, and how to run it
assets/content_pack.json    generated; bundled for offline use
```

## Where the data comes from

Real data, not placeholders. `backend/ingest` pulls from the **GTA Wiki**
MediaWiki API (CC BY-SA 3.0) and builds a validated JSON content pack:

| Section | Count today | Source |
| --- | --- | --- |
| GTA VI cheats | **0** | Nothing is confirmed — see below |
| GTA V cheats (reference) | 43 | `Cheats in GTA V`, real codes for PS / Xbox / PC |
| GTA VI vehicles | ~250 | `Vehicles in GTA VI/table`, from trailers, screenshots and leaks |
| Secrets | 0 | The GTA VI page does not exist yet |

Attribution travels with every record and is shown on the detail screens,
because the licence requires it.

### There are still no GTA VI cheat codes

The game lands on 19 November 2026. As of 12 November, Rockstar has not
confirmed whether it has cheat codes at all. So the app ships **no invented
GTA VI codes**: the library shows GTA V's real codes, labelled "GTA V codes ·
reference", with a notice explaining why. The pipeline is already pointed at
the GTA VI cheats page and will pick up real codes the moment they appear.

`verified` is reserved for codes tested in a released game, and nothing
scraped from a wiki can earn it. Officially shown content is `unverified`;
leaked content is `rumour`. Tests on both sides of the stack enforce this.

## Running it with a backend

Everything works with no backend at all — the pack is bundled, so the library,
vehicles, search and favourites are fully usable offline. Voting and submitting
need a server, and say so when it is absent.

```bash
# 1. Build the content pack (Python 3.9+, stdlib only)
cd backend && PYTHONPATH=. python3 -m ingest.build_pack

# 2. Apply the schema to a Supabase project
supabase db push

# 3. Run the app against both
cd .. && flutter run \
  --dart-define=VICEDEX_PACK_URL=https://cdn.example.com/vicedex/latest.json \
  --dart-define=VICEDEX_SUPABASE_URL=https://xxxx.supabase.co \
  --dart-define=VICEDEX_SUPABASE_ANON_KEY=ey...
```

The anon key is a public, RLS-scoped credential and is meant to ship in the
client. The service-role key must never appear there.

See [backend/README.md](backend/README.md) for the data sources evaluated, the
pack format, the schema and the security model.

## Tests

```bash
flutter test                                                      # 40 tests
cd backend && PYTHONPATH=. python3 -m unittest discover -s tests -t .   # 24 tests
```

## Still to do

- Supply a real `LocalStore` (e.g. `shared_preferences`) so favourites, votes
  and the device id survive a restart; the interface is already in place and
  everything above it is written against it.
- A moderator view over the `submissions` and `reports` queues.
- Measured vehicle performance, which can only come from the released game.
