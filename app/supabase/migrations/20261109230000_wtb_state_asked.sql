-- wtb_state also returns the questions already asked in this room, so the app can skip them in suggestions.
create or replace function wtb_state(p_token uuid) returns json language plpgsql stable security definer set search_path = public as $$
declare me wtb_players; r wtb_rounds; ans json; players json; my_vote uuid; answered int; i_answered boolean; voted int; asked json;
begin
  me := wtb_me(p_token);
  r := wtb_current_round(me.room_code);
  select json_agg(json_build_object('id', id, 'name', name, 'color', color, 'score', score) order by created_at)
    into players from wtb_players where room_code = me.room_code;
  select json_agg(question order by number) into asked from wtb_rounds where room_code = me.room_code;
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
    'asked', coalesce(asked, '[]'::json),
    'next_asker', wtb_next_asker(me.room_code),
    'round', case when r.id is null then null else json_build_object(
      'id', r.id, 'number', r.number, 'asker_id', r.asker_id, 'question', r.question, 'phase', r.phase,
      'expected_answers', r.expected_answers, 'expected_votes', r.expected_votes,
      'answered', answered, 'voted', voted, 'i_answered', i_answered, 'my_vote', my_vote,
      'can_answer', me.id <> r.asker_id and me.created_at <= r.created_at,
      'created_at', r.created_at) end,
    'answers', coalesce(ans, '[]'::json));
end $$;
