-- Play logs: one row per play in `plays`, and everything that happened in it
-- in `play_events`. Each player writes only their own rows. Guests are
-- Supabase anonymous users, and a guest's plays move to their account
-- through a one-time claim code when they sign in.

create table public.plays (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  outcome text check (outcome in ('victory', 'defeat', 'quit', 'disconnected')),
  mode text not null check (mode in ('solo', 'host', 'join')),
  match_seed bigint,
  party_size smallint not null default 1,
  hero_class text not null,
  hero_name text,
  platform text,
  build text,
  -- The furthest point reached, 0-based like the game's own counters.
  chapter smallint not null default 0,
  wave smallint not null default 0,
  duration_s real not null default 0,
  level smallint not null default 1,
  kills integer not null default 0,
  deaths integer not null default 0,
  damage_done real not null default 0,
  damage_taken real not null default 0,
  gold integer not null default 0,
  hearth_frac real,
  -- Ranks, talents, belt and stats at the last update.
  final jsonb not null default '{}'
);

create index plays_user_started on public.plays (user_id, started_at desc);
create index plays_seed on public.plays (match_seed);

create table public.play_events (
  id bigint generated always as identity primary key,
  play_id uuid not null references public.plays (id) on delete cascade,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  -- Order within the play. With the unique key, a batch resent after a
  -- timeout doesn't double up.
  seq integer not null,
  t real not null,
  kind text not null,
  chapter smallint,
  wave smallint,
  -- The hero it's about, or -1 for the match (waves, the Hearth).
  slot smallint not null default -1,
  data jsonb not null default '{}',
  created_at timestamptz not null default now(),
  unique (play_id, seq)
);

create index play_events_kind on public.play_events (kind, created_at desc);
create index play_events_user on public.play_events (user_id);

alter table public.plays enable row level security;
alter table public.play_events enable row level security;

create policy "Players add their own plays" on public.plays
  for insert to authenticated
  with check (user_id = (select auth.uid()));

create policy "Players update their own unfinished plays" on public.plays
  for update to authenticated
  using (user_id = (select auth.uid()) and ended_at is null)
  with check (user_id = (select auth.uid()));

create policy "Players read their own plays" on public.plays
  for select to authenticated
  using (user_id = (select auth.uid()));

create policy "Players add events to their own plays" on public.play_events
  for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (select 1 from public.plays p where p.id = play_id and p.user_id = (select auth.uid()))
  );

create policy "Players read their own events" on public.play_events
  for select to authenticated
  using (user_id = (select auth.uid()));

-- Guest claims. No policies: only the two functions below touch it.
create table public.guest_claims (
  code text primary key,
  guest_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

create index guest_claims_guest on public.guest_claims (guest_id);

alter table public.guest_claims enable row level security;

-- Called by a guest just before signing in. Returns a secret code that only
-- this guest's game knows.
create function public.issue_guest_claim()
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  c text;
begin
  if auth.uid() is null or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) is not true then
    raise exception 'only a guest can issue a claim';
  end if;
  c := encode(extensions.gen_random_bytes(24), 'hex');
  insert into public.guest_claims (code, guest_id) values (c, auth.uid());
  return c;
end;
$$;

-- Called by the account after signing in. Moves the guest's plays and
-- events to it and returns how many plays moved.
create function public.redeem_guest_claim(claim text)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  g uuid;
  n integer;
begin
  if auth.uid() is null or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'sign in to an account to redeem a claim';
  end if;
  delete from public.guest_claims
    where code = claim and created_at > now() - interval '30 days'
    returning guest_id into g;
  if g is null then
    return 0;
  end if;
  update public.plays set user_id = auth.uid() where user_id = g;
  get diagnostics n = row_count;
  update public.play_events set user_id = auth.uid() where user_id = g;
  delete from public.guest_claims where guest_id = g;
  return n;
end;
$$;

revoke execute on function public.issue_guest_claim() from public, anon;
revoke execute on function public.redeem_guest_claim(text) from public, anon;
grant execute on function public.issue_guest_claim() to authenticated;
grant execute on function public.redeem_guest_claim(text) to authenticated;
