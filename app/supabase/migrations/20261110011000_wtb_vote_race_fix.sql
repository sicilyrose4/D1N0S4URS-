-- Two votes landing at the same moment could each count 1 and neither reveal. Lock the round before counting.
create or replace function wtb_vote(p_token uuid, p_answer uuid) returns void language plpgsql security definer set search_path = public as $$
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
  perform 1 from wtb_rounds where id = r.id for update;
  select count(*) into n from wtb_votes where round_id = r.id;
  if n >= r.expected_votes then perform wtb_reveal(r.id); end if;
  perform wtb_ping(me.room_code);
end $$;
