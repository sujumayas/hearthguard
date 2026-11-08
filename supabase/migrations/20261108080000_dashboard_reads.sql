-- Read-only access for the playtest dashboard (dashboards/). RLS keeps each
-- player to their own plays, so the dashboard reads through these two
-- functions instead. They run as the owner, take the publishable key, and
-- return play data only. No emails or other account details leave.

-- Every play, newest first, with whether the player is a guest.
create function public.dashboard_plays(lim integer default 500)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(r order by r.started_at desc), '[]'::jsonb)
  from (
    select p.id, p.user_id, coalesce(u.is_anonymous, false) as guest,
      p.started_at, p.ended_at, p.received_at, p.outcome, p.mode, p.party_size,
      p.hero_class, p.hero_name, p.platform, p.build, p.chapter, p.wave,
      p.duration_s, p.level, p.kills, p.deaths, p.damage_done, p.damage_taken,
      p.gold, p.hearth_frac,
      (select count(*) from public.play_events e where e.play_id = p.id) as events
    from public.plays p
    join auth.users u on u.id = p.user_id
    order by p.started_at desc
    limit least(greatest(lim, 1), 2000)
  ) r;
$$;

-- One play with all its events, in order.
create function public.dashboard_play(play uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'play', (select to_jsonb(p) - 'user_id' from public.plays p where p.id = play),
    'events', (select coalesce(jsonb_agg(to_jsonb(e) - 'user_id' order by e.seq), '[]'::jsonb)
               from public.play_events e where e.play_id = play));
$$;

revoke execute on function public.dashboard_plays(integer) from public;
revoke execute on function public.dashboard_play(uuid) from public;
grant execute on function public.dashboard_plays(integer) to anon, authenticated;
grant execute on function public.dashboard_play(uuid) to anon, authenticated;
