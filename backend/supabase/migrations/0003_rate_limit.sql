-- Submission and report rate limits.
--
-- The anon key is public, so these caps are enforced in the database rather
-- than the client. A device gets a modest hourly budget; past it the insert
-- fails with a readable message the app surfaces in the submit sheet.

create or replace function enforce_submission_rate() returns trigger
language plpgsql as $$
declare
  recent int;
begin
  select count(*) into recent
  from submissions
  where device_id = new.device_id
    and created_at > now() - interval '1 hour';

  if recent >= 10 then
    raise exception 'submission rate limit reached: try again later'
      using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

create trigger submissions_rate_limit before insert on submissions
  for each row execute function enforce_submission_rate();

create or replace function enforce_report_rate() returns trigger
language plpgsql as $$
declare
  recent int;
begin
  select count(*) into recent
  from reports
  where device_id = new.device_id
    and created_at > now() - interval '1 hour';

  if recent >= 20 then
    raise exception 'report rate limit reached: try again later'
      using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

create trigger reports_rate_limit before insert on reports
  for each row execute function enforce_report_rate();

-- Duplicate guard: the same device reporting the same cheat twice while the
-- first report is still pending adds nothing to the queue.
create unique index reports_one_pending_per_cheat
  on reports (device_id, cheat_id, coalesce(platform::text, ''))
  where state = 'pending';
