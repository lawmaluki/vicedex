-- Row level security.
--
-- The app talks to Supabase with the anon key, so the policies below are the
-- only thing standing between an anonymous client and the data. Rules:
--
--   * A device may read and write its own rows, and nothing else of its kind.
--   * Nobody anonymous can read another device's submissions or reports. A
--     pending submission is not public content.
--   * Aggregate vote tallies are public, individual votes are not.
--   * Moderation state is writable only by a moderator (an authenticated user
--     carrying the `moderator` role claim).
--
-- The device identity travels in a request header, surfaced by PostgREST as a
-- GUC. The app sets it on every call; a request without it can write nothing.

create or replace function current_device() returns uuid
language plpgsql stable as $$
declare
  raw text;
begin
  raw := nullif(current_setting('request.headers', true)::json ->> 'x-device-id', '');
  if raw is null then
    return null;
  end if;
  return raw::uuid;
exception when others then
  -- Malformed header: treat as no identity rather than erroring the query.
  return null;
end;
$$;

create or replace function is_moderator() returns boolean
language sql stable as $$
  select coalesce(
    (current_setting('request.jwt.claims', true)::json ->> 'role') = 'moderator'
    or (current_setting('request.jwt.claims', true)::json -> 'app_metadata' ->> 'moderator')::boolean,
    false
  );
$$;

alter table devices       enable row level security;
alter table votes         enable row level security;
alter table submissions   enable row level security;
alter table reports       enable row level security;
alter table favourites    enable row level security;
alter table pack_releases enable row level security;

-- --- devices ---------------------------------------------------------------
-- A client may register itself and refresh its own last_seen, nothing more.
create policy devices_insert_self on devices
  for insert to anon, authenticated
  with check (id = current_device());

create policy devices_select_self on devices
  for select to anon, authenticated
  using (id = current_device() or is_moderator());

create policy devices_update_self on devices
  for update to anon, authenticated
  using (id = current_device())
  -- A device must not unblock itself.
  with check (id = current_device() and blocked = false);

create policy devices_moderate on devices
  for all to authenticated
  using (is_moderator()) with check (is_moderator());

-- --- votes -----------------------------------------------------------------
create policy votes_rw_self on votes
  for all to anon, authenticated
  using (device_id = current_device())
  with check (
    device_id = current_device()
    and not exists (select 1 from devices d where d.id = current_device() and d.blocked)
  );

create policy votes_moderate on votes
  for select to authenticated using (is_moderator());

-- Tallies are exposed through a security-invoker view, which would inherit the
-- restrictive policy above. Expose the aggregate through a function instead, so
-- counts are public while individual votes stay private.
create or replace function cheat_tallies(cheat_ids text[] default null)
returns table (cheat_id text, platform platform, works bigint, fails bigint,
               last_vote_at timestamptz)
language sql stable security definer set search_path = public as $$
  select v.cheat_id, v.platform,
         count(*) filter (where v.value = 1),
         count(*) filter (where v.value = -1),
         max(v.updated_at)
  from votes v
  join devices d on d.id = v.device_id
  where not d.blocked
    and (cheat_ids is null or v.cheat_id = any (cheat_ids))
  group by v.cheat_id, v.platform;
$$;

grant execute on function cheat_tallies(text[]) to anon, authenticated;

-- --- submissions -----------------------------------------------------------
create policy submissions_insert on submissions
  for insert to anon, authenticated
  with check (
    device_id = current_device()
    and state = 'pending'
    and not exists (select 1 from devices d where d.id = current_device() and d.blocked)
  );

create policy submissions_select_own on submissions
  for select to anon, authenticated
  using (device_id = current_device() or is_moderator());

create policy submissions_moderate on submissions
  for update to authenticated
  using (is_moderator()) with check (is_moderator());

-- --- reports ---------------------------------------------------------------
create policy reports_insert on reports
  for insert to anon, authenticated
  with check (
    device_id = current_device()
    and state = 'pending'
    and not exists (select 1 from devices d where d.id = current_device() and d.blocked)
  );

create policy reports_select_own on reports
  for select to anon, authenticated
  using (device_id = current_device() or is_moderator());

create policy reports_moderate on reports
  for update to authenticated
  using (is_moderator()) with check (is_moderator());

-- --- favourites ------------------------------------------------------------
create policy favourites_rw_self on favourites
  for all to anon, authenticated
  using (device_id = current_device())
  with check (device_id = current_device());

-- --- pack_releases ---------------------------------------------------------
-- Readable by everyone: this is how the app finds out a newer pack exists.
create policy pack_releases_read on pack_releases
  for select to anon, authenticated using (true);

create policy pack_releases_write on pack_releases
  for all to authenticated
  using (is_moderator()) with check (is_moderator());
