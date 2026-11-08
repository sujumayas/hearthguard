-- Limits on the play logs, so a player (or a script with their token) can
-- only write what the game writes, in amounts the game writes. RLS already
-- keeps everyone to their own rows; this caps how much and which columns.
-- The bounds are looser than the game's (5 chapters, 6 waves, level 30), so
-- new content doesn't start failing rows.

-- Only what the game needs. The API never offers TRUNCATE, but there's no
-- reason to grant it, or DELETE, or anything to the bare publishable key.
revoke all on public.plays, public.play_events, public.guest_claims from anon, authenticated;

-- When the row reached the server. started_at is the game's clock, so a play
-- logged offline and sent later keeps its real start time.
alter table public.plays add column received_at timestamptz not null default now();
create index plays_user_received on public.plays (user_id, received_at desc);
alter table public.plays alter column started_at drop default;

-- Plays sent before started_at came from the game got the time they arrived.
update public.plays set started_at = ended_at - make_interval(secs => duration_s)
  where ended_at is not null and ended_at < started_at;

grant select on public.plays, public.play_events to authenticated;
grant insert (id, started_at, mode, match_seed, party_size, hero_class, hero_name, platform, build)
  on public.plays to authenticated;
-- The summary the game keeps up to date, and the outcome at the end.
grant update (chapter, wave, duration_s, level, kills, deaths, damage_done, damage_taken, gold,
  hearth_frac, final, outcome, ended_at)
  on public.plays to authenticated;
grant insert (play_id, seq, t, kind, chapter, wave, slot, data)
  on public.play_events to authenticated;

alter table public.plays
  add constraint plays_sizes check (
    length(hero_class) <= 24 and length(coalesce(hero_name, '')) <= 32
    and length(coalesce(platform, '')) <= 40 and length(coalesce(build, '')) <= 40
    and pg_column_size(final) <= 16384),
  add constraint plays_ranges check (
    party_size between 1 and 3 and chapter between 0 and 9 and wave between 0 and 9
    and level between 1 and 99 and kills >= 0 and deaths >= 0 and gold >= 0
    and damage_done >= 0 and damage_taken >= 0 and duration_s between 0 and 86400
    and (hearth_frac is null or hearth_frac between 0 and 1)),
  add constraint plays_ended check (ended_at is null or ended_at >= started_at - interval '5 minutes');

-- seq is unique per play, so this also caps a play at 10,000 events. A
-- 15 minute game makes about 200.
alter table public.play_events
  add constraint play_events_ranges check (
    seq between 0 and 9999 and t between 0 and 86400 and slot between -1 and 2
    and (chapter is null or chapter between 0 and 9) and (wave is null or wave between 0 and 9)
    and length(kind) <= 32 and pg_column_size(data) <= 32768);

-- A start time the game could have sent (logs wait up to a while offline),
-- and at most 30 new plays an hour per player, counted by arrival so an old
-- started_at can't dodge it. Runs as the player, so RLS keeps the count to
-- their own plays, which is the point.
create function public.plays_before_insert()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.received_at := now();
  if new.started_at is null then
    new.started_at := now();
  end if;
  if new.started_at > now() + interval '5 minutes' or new.started_at < now() - interval '30 days' then
    raise exception 'started_at out of range' using errcode = 'P0001';
  end if;
  if (select count(*) from public.plays
      where user_id = new.user_id and received_at > now() - interval '1 hour') >= 30 then
    raise exception 'too many plays this hour' using errcode = 'P0001';
  end if;
  return new;
end;
$$;

create trigger plays_before_insert before insert on public.plays
  for each row execute function public.plays_before_insert();

revoke execute on function public.plays_before_insert() from public, anon, authenticated;
