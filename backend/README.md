# ViceDex backend

Two halves, split by what the data actually is:

| | Static content | Community data |
| --- | --- | --- |
| What | Cheats, vehicles, secrets | Votes, submissions, reports |
| Where | A generated JSON **content pack** | Postgres (Supabase) |
| Why there | Read-only, identical for everyone, must work offline | Per-user writes that need auth rules and moderation |
| Built by | `ingest/build_pack.py` | `supabase/migrations/*.sql` |

The app reads the pack and writes to Postgres. It never writes content, and the
pack never holds user data.

---

## Where the data comes from

The only machine-readable, openly licensed source of GTA VI content today is the
**GTA Wiki** (`gta.fandom.com`), through its MediaWiki API. It is CC BY-SA 3.0,
so every record the pipeline emits carries a source URL and the licence string,
and the app shows that credit on the detail screens. That is a licence
obligation, not a courtesy.

| Pack section | Wiki page | State as of 2026-11-14 |
| --- | --- | --- |
| GTA VI cheats | `Cheats in GTA VI` | **Empty.** See below. |
| Legacy cheats | `Cheats in GTA V` | 43 real codes, PS / Xbox / PC |
| Vehicles | `Vehicles in GTA VI/table` | ~250 entries from trailers, screenshots and leaks |
| Secrets | `Secrets and Easter Eggs in GTA VI` | Page does not exist yet |

### There are no GTA VI cheat codes

GTA VI releases on **19 November 2026**. The wiki's cheats page, edited
2026-11-12, states that Rockstar has not confirmed whether the game has cheat
codes at all, and that no code or activation method has been revealed. Its
PS5 and Xbox tables contain a single "No confirmed cheats" row.

So the pipeline emits **zero** GTA VI cheats. It does not invent any, and it
does not promote pre-launch rumours. Instead it ships GTA V's real codes as a
clearly-labelled reference set (`game: "V"`, surfaced in the app as "GTA V
codes · reference") so the library has genuine content, and it attaches a
notice explaining why. The parser is written against the same table layout the
VI page already uses, so **the day editors fill those tables in, a re-run picks
the codes up with no code change.**

### Status mapping

`verified` means *tested in the released game*. A scrape cannot establish that,
so nothing from the wiki is ever marked verified except GTA V codes, where it is
true. Everything else:

- officially shown (trailer, screenshot, Rockstar site) → `unverified`
- leaks only (the September 2022 leaks) → `rumour`

`backend/tests/test_parsers.py` asserts this, and so does
`test/bundled_pack_test.dart` on the app side.

### Other sources considered

- **Rockstar Social Club / official API** — no public GTA VI endpoints exist.
- **`DurtyFree/gta-v-data-dumps`** — excellent model/handling dumps, but GTA V
  only, extracted from game files. Useful later for measured vehicle stats; it
  cannot describe GTA VI.
- **`nmec/gtav-vehicle-stats`** — per-vehicle speed/class/value, again GTA V.
- Fan sites (GTABase, GTABoom) — no API, and scraping them has no licence
  covering reuse. Not used.

Once the game is out, measured vehicle performance has to come from in-game
testing, which is what the `performance` map and the submissions table are for.

---

## The content pack

One JSON document: `packs/latest.json`, also copied to
`../assets/content_pack.json` as the app's offline fallback.

```jsonc
{
  "version": 1,
  "generatedAt": "2026-11-14T12:36:36Z",
  "etag": "c297aff54fb2f5ab",   // hash of the records only
  "counts":   { "cheatsVI": 0, "cheatsLegacy": 43, "vehicles": 250, "secrets": 0 },
  "notices":  [ { "scope": "cheats", "title": "...", "body": "..." } ],
  "cheats":   [ { "id": "...", "sequences": { "ps5": ["○","△"] }, "provenance": {...} } ],
  "vehicles": [ ... ],
  "secrets":  [ ... ]
}
```

`etag` hashes the records only, not `generatedAt`. A rebuild that finds no
change keeps the same etag, so the app's `If-None-Match` request gets a 304 and
nothing is downloaded or re-rendered.

### Build it

```sh
cd backend
PYTHONPATH=. python3 -m ingest.build_pack            # writes packs/ + ../assets/
PYTHONPATH=. python3 -m ingest.build_pack --check    # validate only, no writes
PYTHONPATH=. python3 -m ingest.build_pack --no-cache # bypass the 1h wiki cache
```

Python 3.9+, standard library only — no pip install. Wiki responses are cached
in `backend/.wikicache` for an hour; if the API is unreachable a stale cache is
served rather than failing the build.

`ingest/normalize.py:validate` rejects a pack the app could not render:
unknown enum spellings, duplicate ids, performance values outside 0..1, or a
cheat marked verified with no code. A failed validation writes nothing.

### Serve it

Any static host. The only requirements are `ETag` support and CORS for the web
build:

```
Cache-Control: public, max-age=300, stale-while-revalidate=86400
Access-Control-Allow-Origin: *
```

Point the app at it with `--dart-define=VICEDEX_PACK_URL=.../latest.json`.
With no URL set the app runs on the bundled copy alone, which is a supported
mode, not a broken one.

### Keep it fresh

Launch week is when the wiki moves fastest. A scheduled rebuild, e.g. GitHub
Actions hourly:

```yaml
- run: PYTHONPATH=. python3 -m ingest.build_pack --no-cache --out dist
- run: |  # only publish when the content actually changed
    test "$(jq -r .etag dist/latest.json)" != "$(jq -r .etag live/latest.json)" \
      && aws s3 cp dist/latest.json s3://$BUCKET/vicedex/latest.json
```

Watch the printed counts. A sudden drop means the wiki's layout changed and a
parser needs attention — the parsers degrade to fewer records rather than
crashing, which is safe but silent.

---

## Postgres (Supabase)

```
supabase/migrations/
  0001_init.sql        tables, enums, the cheat_tallies source
  0002_rls.sql         row level security + the public tallies function
  0003_rate_limit.sql  per-device submission and report caps
```

Apply with `supabase db push`, or `psql -f` each in order.

### Tables

- **`devices`** — an anonymous uuid the app generates on first run. No personal
  data. `blocked` stops an abusive device's writes from counting.
- **`votes`** — one row per `(device, cheat, platform)`. A code can work on PS5
  and fail on Xbox, so platform is part of the key.
- **`submissions`** — community cheats, `pending` until a moderator acts. These
  never reach the pack directly; an approved row is folded in as `unverified`.
- **`reports`** — "this is wrong / stopped working".
- **`favourites`** — optional cloud backup; the device copy stays authoritative.
- **`pack_releases`** — lets the app ask whether a newer pack exists.

### Security model

The app uses the **anon key**, which is public by design, so RLS is the entire
boundary. Identity travels as an `x-device-id` header, read by
`current_device()`.

- A device reads and writes only its own rows.
- A pending submission is **not** public content — nobody else can read it.
- Individual votes are private; the aggregate is public through the
  `cheat_tallies()` security-definer function. (A plain view would inherit the
  restrictive policy and return only your own votes.)
- Moderation columns are writable only by an authenticated user carrying a
  `moderator` claim.
- A device cannot unblock itself: the update policy pins `blocked = false`.
- Rate limits (10 submissions, 20 reports per hour) are enforced by triggers in
  the database, not the client, because the client is public.

Never put the **service-role key** in the app. It bypasses RLS.

> **Not yet executed.** This machine has no Postgres or Docker, so the
> migrations are reviewed but unrun. Apply them against a scratch project and
> expect to fix small things — the `auth.users` reference in `submissions`
> requires Supabase's auth schema, so on plain Postgres either create it or drop
> that foreign key.

---

## Tests

```sh
cd backend && PYTHONPATH=. python3 -m unittest discover -s tests -t .   # 24 tests
cd .. && flutter test                                                   # 40 tests
```

The Python tests run the parsers against pinned wikitext fixtures covering the
cases that silently lose data: a table with repeated header rows (every vehicle
otherwise collapses into the first column's class), PlayStation code cells that
open with a bare `|` and continue on the next line (every PS code otherwise
vanishes), commented-out draft tables, phone-number sections, and the live VI
page's "No confirmed cheats" row.

## Layout

```
backend/
  ingest/
    wiki.py              MediaWiki client, disk cache, stale-on-failure
    normalize.py         slugs, keywords, pack validation
    build_pack.py        CLI: assemble, validate, write, bundle
    sources/
      wiki_cheats.py     Effect|Code tables -> per-platform glyph sequences
      wiki_vehicles.py   class-column tables -> vehicles + provenance
      wiki_secrets.py    area-heading bullets -> secrets (page not live yet)
  packs/                 generated: v1.json, latest.json
  supabase/migrations/   schema, RLS, rate limits
  tests/                 parser + validation tests
```
