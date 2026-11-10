-- Host + start button, 30 second answer countdown, and who-has-answered for the presence row.
alter table wtb_rooms
  add column host_id uuid references wtb_players(id) on delete set null,
  add column started boolean not null default false;
alter table wtb_rounds add column deadline timestamptz;

-- Rooms that already exist keep playing: first joiner is host, game counts as started.
update wtb_rooms r set started = true,
  host_id = (select id from wtb_players p where p.room_code = r.code order by created_at limit 1);

create or replace function wtb_join(p_code text, p_name text) returns json language plpgsql security definer set search_path = public as $$
declare c text := upper(trim(p_code)); n text := trim(p_name); cnt int; me wtb_players;
begin
  if c !~ '^[A-Z0-9]{4}$' then raise exception 'Room codes are 4 letters or numbers.'; end if;
  if n is null or length(n) < 1 or length(n) > 20 then raise exception 'Names are 1 to 20 characters.'; end if;
  insert into wtb_rooms(code) values (c) on conflict do nothing;
  select count(*) into cnt from wtb_players where room_code = c;
  if cnt >= 12 then raise exception 'This room is full.'; end if;
  insert into wtb_players(room_code, name, color) values (c, n, cnt % 8) returning * into me;
  update wtb_rooms set host_id = me.id where code = c and host_id is null;
  perform wtb_ping(c);
  return json_build_object('player_id', me.id, 'token', me.token, 'code', c);
end $$;

-- Host taps Go: everyone leaves the waiting room.
create function wtb_start(p_token uuid) returns void language plpgsql security definer set search_path = public as $$
declare me wtb_players; room wtb_rooms; cnt int;
begin
  me := wtb_me(p_token);
  select * into room from wtb_rooms where code = me.room_code;
  if room.host_id is distinct from me.id then raise exception 'Only the host can start the game.'; end if;
  select count(*) into cnt from wtb_players where room_code = me.room_code;
  if cnt < 2 then raise exception 'Wait for at least one more person.'; end if;
  update wtb_rooms set started = true where code = me.room_code;
  perform wtb_ping(me.room_code);
end $$;

create or replace function wtb_ask(p_token uuid, p_question text) returns uuid language plpgsql security definer set search_path = public as $$
declare me wtb_players; r wtb_rounds; q text := trim(p_question); cnt int; new_id uuid;
begin
  me := wtb_me(p_token);
  if not (select started from wtb_rooms where code = me.room_code) then raise exception 'Waiting for the host to start.'; end if;
  r := wtb_current_round(me.room_code);
  if r.id is not null and r.phase <> 'reveal' then raise exception 'A round is already going.'; end if;
  if wtb_next_asker(me.room_code) <> me.id then raise exception 'It is not your turn to ask.'; end if;
  if q is null or length(q) < 3 or length(q) > 200 then raise exception 'Questions are 3 to 200 characters.'; end if;
  select count(*) into cnt from wtb_players where room_code = me.room_code;
  if cnt < 2 then raise exception 'Wait for at least one more person.'; end if;
  insert into wtb_rounds(room_code, number, asker_id, question, phase, expected_answers, expected_votes, deadline)
  values (me.room_code, coalesce(r.number, 0) + 1, me.id, q, 'answer', cnt, cnt, clock_timestamp() + interval '30 seconds')
  returning id into new_id;
  perform wtb_ping(me.room_code);
  return new_id;
end $$;

-- Close answering now: make sure the bot has an answer, then shuffle into voting.
create function wtb_close_answers(p_round uuid) returns void language plpgsql security definer set search_path = public as $$
declare fallback text[] := array['honestly no clue lol','probably pizza','my moms car','idk depends on the day','nothing really'];
begin
  insert into wtb_answers(round_id, is_bot, body) values (p_round, true, fallback[1 + floor(random() * 5)::int]) on conflict do nothing;
  perform wtb_to_judge(p_round);
end $$;

-- Any player calls this when the countdown hits zero. Does nothing before the deadline.
create function wtb_tick(p_token uuid) returns void language plpgsql security definer set search_path = public as $$
declare me wtb_players; r wtb_rounds;
begin
  me := wtb_me(p_token);
  r := wtb_current_round(me.room_code);
  if r.id is null or r.phase <> 'answer' or r.deadline is null or clock_timestamp() < r.deadline then return; end if;
  perform wtb_close_answers(r.id);
  perform wtb_ping(me.room_code);
end $$;

-- Host skips ahead: answering -> voting, voting -> results.
create or replace function wtb_force(p_token uuid) returns void language plpgsql security definer set search_path = public as $$
declare me wtb_players; r wtb_rounds;
begin
  me := wtb_me(p_token);
  r := wtb_current_round(me.room_code);
  if r.id is null then return; end if;
  if (select host_id from wtb_rooms where code = me.room_code) is distinct from me.id then raise exception 'Only the host can skip ahead.'; end if;
  if r.phase = 'answer' then perform wtb_close_answers(r.id);
  elsif r.phase = 'judge' then perform wtb_reveal(r.id);
  end if;
  perform wtb_ping(me.room_code);
end $$;

create or replace function wtb_state(p_token uuid) returns json language plpgsql stable security definer set search_path = public as $$
declare me wtb_players; room wtb_rooms; r wtb_rounds; ans json; players json; my_vote uuid; answered int; i_answered boolean; voted int; asked json;
  answered_ids json; bot_answered boolean;
begin
  me := wtb_me(p_token);
  select * into room from wtb_rooms where code = me.room_code;
  r := wtb_current_round(me.room_code);
  select json_agg(json_build_object('id', id, 'name', name, 'color', color, 'score', score) order by created_at)
    into players from wtb_players where room_code = me.room_code;
  select json_agg(question order by number) into asked from wtb_rounds where room_code = me.room_code;
  if r.id is not null then
    select count(*), json_agg(author_id) filter (where not is_bot), bool_or(is_bot)
      into answered, answered_ids, bot_answered from wtb_answers where round_id = r.id;
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
    'now', clock_timestamp(),
    'host_id', room.host_id,
    'started', room.started,
    'me', json_build_object('id', me.id, 'name', me.name, 'color', me.color, 'score', me.score),
    'players', coalesce(players, '[]'::json),
    'asked', coalesce(asked, '[]'::json),
    'next_asker', wtb_next_asker(me.room_code),
    'round', case when r.id is null then null else json_build_object(
      'id', r.id, 'number', r.number, 'asker_id', r.asker_id, 'question', r.question, 'phase', r.phase,
      'expected_answers', r.expected_answers, 'expected_votes', r.expected_votes,
      'answered', answered, 'voted', voted, 'i_answered', i_answered, 'my_vote', my_vote,
      'answered_ids', coalesce(answered_ids, '[]'::json), 'bot_answered', coalesce(bot_answered, false),
      'can_answer', me.id <> r.asker_id and me.created_at <= r.created_at,
      'created_at', r.created_at, 'deadline', r.deadline) end,
    'answers', coalesce(ans, '[]'::json));
end $$;

revoke execute on function wtb_close_answers(uuid) from public, anon, authenticated;
revoke execute on function wtb_start(uuid), wtb_tick(uuid) from public;
grant execute on function wtb_start(uuid), wtb_tick(uuid) to anon, authenticated;
