-- ViceDex backend: the dynamic half.
--
-- Static content (cheats, vehicles, secrets) is not stored here. It is built by
-- backend/ingest into a signed, content-hashed JSON pack and served from a CDN,
-- because it is read-only, identical for every user and must work offline.
--
-- What lives here is the part that cannot be precomputed: community votes on
-- whether a cheat works, submissions, and reports -- plus the moderation queue
-- that gates them. Nothing a user writes is readable by other users until a
-- moderator approves it.

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------------
-- Enums, mirroring lib/models/models.dart
-- ---------------------------------------------------------------------------
create type platform as enum ('ps5', 'xbox', 'pc');
create type verification_status as enum ('verified', 'unverified', 'rumour');
create type cheat_category as enum ('weapons', 'vehicles', 'player', 'world');
create type moderation_state as enum ('pending', 'approved', 'rejected', 'merged');

-- ---------------------------------------------------------------------------
-- Devices: anonymous identity so votes can be rate-limited and de-duplicated
-- without accounts. The app generates a random uuid on first run and keeps it
-- locally; no personal data is stored against it.
-- ---------------------------------------------------------------------------
create table devices (
  id          uuid primary key default gen_random_uuid(),
  created_at  timestamptz not null default now(),
  last_seen   timestamptz not null default now(),
  -- Set when a device is abusing submissions; its writes stop counting.
  blocked     boolean not null default false
);

-- ---------------------------------------------------------------------------
-- Votes: does this cheat actually work?
-- One row per (device, cheat, platform) -- a code can work on PS5 and fail on
-- Xbox, so platform is part of the key.
-- ---------------------------------------------------------------------------
create table votes (
  device_id   uuid not null references devices (id) on delete cascade,
  cheat_id    text not null,
  platform    platform not null,
  -- +1 works, -1 does not work.
  value       smallint not null check (value in (-1, 1)),
  game_build  text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  primary key (device_id, cheat_id, platform)
);

create index votes_cheat_idx on votes (cheat_id, platform);

-- Public vote tallies are exposed through the cheat_tallies() function in
-- 0002_rls.sql, not a view: individual votes stay private, counts do not.

-- ---------------------------------------------------------------------------
-- Submissions: a community-contributed cheat awaiting moderation.
-- These never reach the app's content pack directly. A moderator approves one,
-- and the next ingest run folds approved rows into the pack as `unverified`.
-- ---------------------------------------------------------------------------
create table submissions (
  id            uuid primary key default gen_random_uuid(),
  device_id     uuid not null references devices (id) on delete cascade,
  title         text not null check (char_length(trim(title)) between 3 and 120),
  category      cheat_category not null,
  summary       text check (char_length(summary) <= 500),
  platform      platform not null,
  -- The button sequence, one glyph per element, as the app's chips render it.
  sequence      text[] not null check (
                  array_length(sequence, 1) between 1 and 24
                  and array_position(sequence, null) is null
                ),
  source_note   text check (char_length(source_note) <= 500),
  state         moderation_state not null default 'pending',
  -- Set by a moderator; surfaced to the submitter, never to other users.
  review_note   text,
  reviewed_at   timestamptz,
  reviewed_by   uuid references auth.users (id),
  -- Which content-pack cheat this was merged into, once approved.
  merged_cheat_id text,
  created_at    timestamptz not null default now()
);

create index submissions_state_idx on submissions (state, created_at desc);
create index submissions_device_idx on submissions (device_id, created_at desc);

-- ---------------------------------------------------------------------------
-- Reports: "this cheat is listed wrong / stopped working".
-- ---------------------------------------------------------------------------
create table reports (
  id          uuid primary key default gen_random_uuid(),
  device_id   uuid not null references devices (id) on delete cascade,
  cheat_id    text not null,
  platform    platform,
  reason      text not null check (char_length(trim(reason)) between 3 and 500),
  game_build  text,
  state       moderation_state not null default 'pending',
  created_at  timestamptz not null default now()
);

create index reports_state_idx on reports (state, created_at desc);
create index reports_cheat_idx on reports (cheat_id);

-- ---------------------------------------------------------------------------
-- Favourites: optional cloud copy, so a device can restore its stars.
-- The app keeps the authoritative local copy; this is a backup, not a source.
-- ---------------------------------------------------------------------------
create table favourites (
  device_id   uuid not null references devices (id) on delete cascade,
  entity_kind text not null check (entity_kind in ('cheat', 'vehicle', 'secret')),
  entity_id   text not null,
  created_at  timestamptz not null default now(),
  primary key (device_id, entity_kind, entity_id)
);

-- ---------------------------------------------------------------------------
-- Pack releases: lets the app ask "is there a newer pack than mine?" without
-- downloading the whole thing.
-- ---------------------------------------------------------------------------
create table pack_releases (
  version      int not null,
  etag         text not null,
  url          text not null,
  bytes        int,
  generated_at timestamptz not null,
  published_at timestamptz not null default now(),
  is_current   boolean not null default true,
  primary key (version, etag)
);

create unique index pack_releases_current_idx
  on pack_releases (version) where is_current;

-- ---------------------------------------------------------------------------
-- updated_at upkeep
-- ---------------------------------------------------------------------------
create or replace function touch_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger votes_touch before update on votes
  for each row execute function touch_updated_at();
