-- Who's the Bot? game. All tables locked (RLS on, no policies); clients use the wtb_* RPCs only.
create table wtb_rooms (
  code text primary key check (code ~ '^[A-Z0-9]{4}$'),
  created_at timestamptz not null default now()
);
create table wtb_players (
  id uuid primary key default gen_random_uuid(),
  room_code text not null references wtb_rooms(code) on delete cascade,
  name text not null,
  color int not null default 0,
  token uuid not null unique default gen_random_uuid(),
  score int not null default 0,
  created_at timestamptz not null default clock_timestamp()
);
create table wtb_rounds (
  id uuid primary key default gen_random_uuid(),
  room_code text not null references wtb_rooms(code) on delete cascade,
  number int not null,
  asker_id uuid not null references wtb_players(id) on delete cascade,
  question text not null,
  phase text not null check (phase in ('answer','judge','reveal')),
  expected_answers int not null,
  expected_votes int not null,
  created_at timestamptz not null default clock_timestamp(),
  unique (room_code, number)
);
create table wtb_answers (
  id uuid primary key default gen_random_uuid(),
  round_id uuid not null references wtb_rounds(id) on delete cascade,
  author_id uuid references wtb_players(id) on delete cascade,
  is_bot boolean not null default false,
  body text not null,
  label text,
  created_at timestamptz not null default clock_timestamp(),
  unique (round_id, author_id)
);
create unique index wtb_one_bot_per_round on wtb_answers(round_id) where is_bot;
create table wtb_votes (
  round_id uuid not null references wtb_rounds(id) on delete cascade,
  voter_id uuid not null references wtb_players(id) on delete cascade,
  answer_id uuid not null references wtb_answers(id) on delete cascade,
  primary key (round_id, voter_id)
);
create index on wtb_players(room_code);
create index on wtb_rounds(room_code);
create index on wtb_answers(round_id);

alter table wtb_rooms enable row level security;
alter table wtb_players enable row level security;
alter table wtb_rounds enable row level security;
alter table wtb_answers enable row level security;
alter table wtb_votes enable row level security;
revoke all on wtb_rooms, wtb_players, wtb_rounds, wtb_answers, wtb_votes from anon, authenticated;

-- ---------- internal helpers ----------
create function wtb_ping(p_code text) returns void language sql security definer set search_path = public as $$
  select realtime.send(jsonb_build_object('at', now()), 'changed', 'wtb:' || p_code, false);
$$;

create function wtb_me(p_token uuid) returns wtb_players language plpgsql security definer set search_path = public as $$
declare me wtb_players;
begin
  select * into me from wtb_players where token = p_token;
  if not found then raise exception 'Player not found. Rejoin the room.'; end if;
  return me;
end $$;

create function wtb_current_round(p_code text) returns wtb_rounds language sql stable security definer set search_path = public as $$
  select * from wtb_rounds where room_code = p_code order by number desc limit 1;
$$;

create function wtb_next_asker(p_code text) returns uuid language plpgsql stable security definer set search_path = public as $$
declare last_asker uuid; last_at timestamptz; nxt uuid;
begin
  select r.asker_id, p.created_at into last_asker, last_at
    from wtb_rounds r join wtb_players p on p.id = r.asker_id
   where r.room_code = p_code order by r.number desc limit 1;
  if last_asker is not null then
    select id into nxt from wtb_players where room_code = p_code and created_at > last_at order by created_at limit 1;
  end if;
  if nxt is null then
    select id into nxt from wtb_players where room_code = p_code order by created_at limit 1;
  end if;
  return nxt;
end $$;

create function wtb_to_judge(p_round uuid) returns void language plpgsql security definer set search_path = public as $$
begin
  update wtb_answers a set label = chr(64 + s.rn::int)
    from (select id, row_number() over (order by random()) rn from wtb_answers where round_id = p_round) s
   where a.id = s.id;
  update wtb_rounds set phase = 'judge' where id = p_round and phase = 'answer';
end $$;

create function wtb_maybe_judge(p_round uuid) returns void language plpgsql security definer set search_path = public as $$
declare r wtb_rounds; n int;
begin
  select * into r from wtb_rounds where id = p_round for update;
  if r.phase <> 'answer' then return; end if;
  select count(*) into n from wtb_answers where round_id = p_round;
  if n >= r.expected_answers then perform wtb_to_judge(p_round); end if;
end $$;

create function wtb_reveal(p_round uuid) returns void language plpgsql security definer set search_path = public as $$
begin
  update wtb_rounds set phase = 'reveal' where id = p_round and phase = 'judge';
  if not found then return; end if;
  update wtb_players p set score = score + 2
    from wtb_votes v join wtb_answers a on a.id = v.answer_id
   where v.round_id = p_round and a.is_bot and p.id = v.voter_id;
end $$;

-- ---------- public RPCs ----------
create function wtb_new_code() returns text language plpgsql security definer set search_path = public as $$
declare c text; alphabet text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
begin
  loop
    c := '';
    for i in 1..4 loop c := c || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1); end loop;
    exit when not exists (select 1 from wtb_rooms where code = c);
  end loop;
  return c;
end $$;

create function wtb_join(p_code text, p_name text) returns json language plpgsql security definer set search_path = public as $$
declare c text := upper(trim(p_code)); n text := trim(p_name); cnt int; me wtb_players;
begin
  if c !~ '^[A-Z0-9]{4}$' then raise exception 'Room codes are 4 letters or numbers.'; end if;
  if n is null or length(n) < 1 or length(n) > 20 then raise exception 'Names are 1 to 20 characters.'; end if;
  insert into wtb_rooms(code) values (c) on conflict do nothing;
  select count(*) into cnt from wtb_players where room_code = c;
  if cnt >= 12 then raise exception 'This room is full.'; end if;
  insert into wtb_players(room_code, name, color) values (c, n, cnt % 8) returning * into me;
  perform wtb_ping(c);
  return json_build_object('player_id', me.id, 'token', me.token, 'code', c);
end $$;

create function wtb_state(p_token uuid) returns json language plpgsql stable security definer set search_path = public as $$
declare me wtb_players; r wtb_rounds; ans json; players json; my_vote uuid; answered int; i_answered boolean; voted int;
begin
  me := wtb_me(p_token);
  r := wtb_current_round(me.room_code);
  select json_agg(json_build_object('id', id, 'name', name, 'color', color, 'score', score) order by created_at)
    into players from wtb_players where room_code = me.room_code;
  if r.id is not null then
    select count(*) into answered from wtb_answers where round_id = r.id;
    select exists(select 1 from wtb_answers where round_id = r.id and author_id = me.id) into i_answered;
    select answer_id into my_vote from wtb_votes where round_id = r.id and voter_id = me.id;
    select count(*) into voted from wtb_votes where round_id = r.id;
    if r.phase in ('judge','reveal') then
      select json_agg(json_build_object(
          'id', a.id, 'label', a.label, 'body', a.body, 'mine', a.author_id = me.id,
          'is_bot', case when r.phase = 'reveal' then a.is_bot end,
          'author', case when r.phase = 'reveal' then p.name end,
          'author_color', case when r.phase = 'reveal' then p.color end,
          'votes', case when r.phase = 'reveal' then (select count(*) from wtb_votes v where v.answer_id = a.id) end
        ) order by a.label)
        into ans from wtb_answers a left join wtb_players p on p.id = a.author_id where a.round_id = r.id;
    end if;
  end if;
  return json_build_object(
    'room', me.room_code,
    'me', json_build_object('id', me.id, 'name', me.name, 'color', me.color, 'score', me.score),
    'players', coalesce(players, '[]'::json),
    'next_asker', wtb_next_asker(me.room_code),
    'round', case when r.id is null then null else json_build_object(
      'id', r.id, 'number', r.number, 'asker_id', r.asker_id, 'question', r.question, 'phase', r.phase,
      'expected_answers', r.expected_answers, 'expected_votes', r.expected_votes,
      'answered', answered, 'voted', voted, 'i_answered', i_answered, 'my_vote', my_vote,
      'can_answer', me.id <> r.asker_id and me.created_at <= r.created_at,
      'created_at', r.created_at) end,
    'answers', coalesce(ans, '[]'::json));
end $$;

create function wtb_ask(p_token uuid, p_question text) returns uuid language plpgsql security definer set search_path = public as $$
declare me wtb_players; r wtb_rounds; q text := trim(p_question); cnt int; new_id uuid;
begin
  me := wtb_me(p_token);
  r := wtb_current_round(me.room_code);
  if r.id is not null and r.phase <> 'reveal' then raise exception 'A round is already going.'; end if;
  if wtb_next_asker(me.room_code) <> me.id then raise exception 'It is not your turn to ask.'; end if;
  if q is null or length(q) < 3 or length(q) > 200 then raise exception 'Questions are 3 to 200 characters.'; end if;
  select count(*) into cnt from wtb_players where room_code = me.room_code;
  if cnt < 2 then raise exception 'Wait for at least one more person.'; end if;
  insert into wtb_rounds(room_code, number, asker_id, question, phase, expected_answers, expected_votes)
  values (me.room_code, coalesce(r.number, 0) + 1, me.id, q, 'answer', cnt, cnt)
  returning id into new_id;
  perform wtb_ping(me.room_code);
  return new_id;
end $$;

create function wtb_answer(p_token uuid, p_body text) returns void language plpgsql security definer set search_path = public as $$
declare me wtb_players; r wtb_rounds; b text := trim(p_body);
begin
  me := wtb_me(p_token);
  r := wtb_current_round(me.room_code);
  if r.id is null or r.phase <> 'answer' then raise exception 'Answers are closed.'; end if;
  if r.asker_id = me.id then raise exception 'The asker does not answer.'; end if;
  if me.created_at > r.created_at then raise exception 'You joined mid-round. You can play next round.'; end if;
  if b is null or length(b) < 1 or length(b) > 160 then raise exception 'Answers are 1 to 160 characters.'; end if;
  insert into wtb_answers(round_id, author_id, body) values (r.id, me.id, b)
    on conflict (round_id, author_id) do update set body = excluded.body;
  perform wtb_maybe_judge(r.id);
  perform wtb_ping(me.room_code);
end $$;

create function wtb_bot_answer(p_round uuid, p_body text) returns void language plpgsql security definer set search_path = public as $$
declare r wtb_rounds;
begin
  select * into r from wtb_rounds where id = p_round;
  if r.id is null or r.phase <> 'answer' then return; end if;
  insert into wtb_answers(round_id, is_bot, body) values (p_round, true, left(trim(p_body), 160)) on conflict do nothing;
  perform wtb_maybe_judge(p_round);
  perform wtb_ping(r.room_code);
end $$;

create function wtb_vote(p_token uuid, p_answer uuid) returns void language plpgsql security definer set search_path = public as $$
declare me wtb_players; r wtb_rounds; a wtb_answers; n int;
begin
  me := wtb_me(p_token);
  r := wtb_current_round(me.room_code);
  if r.id is null or r.phase <> 'judge' then raise exception 'Voting is closed.'; end if;
  select * into a from wtb_answers where id = p_answer and round_id = r.id;
  if a.id is null then raise exception 'That answer is not in this round.'; end if;
  if a.author_id = me.id then raise exception 'You cannot vote for your own answer.'; end if;
  insert into wtb_votes(round_id, voter_id, answer_id) values (r.id, me.id, p_answer)
    on conflict (round_id, voter_id) do update set answer_id = excluded.answer_id;
  select count(*) into n from wtb_votes where round_id = r.id;
  if n >= r.expected_votes then perform wtb_reveal(r.id); end if;
  perform wtb_ping(me.room_code);
end $$;

-- Asker can push a stuck round forward (someone left, bot slow).
create function wtb_force(p_token uuid) returns void language plpgsql security definer set search_path = public as $$
declare me wtb_players; r wtb_rounds; fallback text[] := array['honestly no clue lol','the smell of rain on hot pavement','probably pizza','my moms car','idk, depends on the day'];
begin
  me := wtb_me(p_token);
  r := wtb_current_round(me.room_code);
  if r.id is null then return; end if;
  if r.asker_id <> me.id then raise exception 'Only the asker can skip ahead.'; end if;
  if r.phase = 'answer' then
    if not exists (select 1 from wtb_answers where round_id = r.id and is_bot) then
      insert into wtb_answers(round_id, is_bot, body) values (r.id, true, fallback[1 + floor(random() * 5)::int]);
    end if;
    perform wtb_to_judge(r.id);
  elsif r.phase = 'judge' then
    perform wtb_reveal(r.id);
  end if;
  perform wtb_ping(me.room_code);
end $$;

-- Lock down execution: only the public RPCs are callable by app clients.
revoke execute on function wtb_ping(text), wtb_me(uuid), wtb_current_round(text), wtb_next_asker(text),
  wtb_to_judge(uuid), wtb_maybe_judge(uuid), wtb_reveal(uuid), wtb_bot_answer(uuid, text) from public, anon, authenticated;
grant execute on function wtb_bot_answer(uuid, text) to service_role;
revoke execute on function wtb_new_code(), wtb_join(text, text), wtb_state(uuid), wtb_ask(uuid, text),
  wtb_answer(uuid, text), wtb_vote(uuid, uuid), wtb_force(uuid) from public;
grant execute on function wtb_new_code(), wtb_join(text, text), wtb_state(uuid), wtb_ask(uuid, text),
  wtb_answer(uuid, text), wtb_vote(uuid, uuid), wtb_force(uuid) to anon, authenticated;
