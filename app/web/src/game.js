// All game state comes from the database through the wtb_* functions.
// A realtime "changed" ping tells every phone to refetch; presence shows who is online and typing.
import { createClient } from "@supabase/supabase-js";
import { useCallback, useEffect, useRef, useState } from "react";

const URL = "https://nyvndatcrxyylcmqmwwl.supabase.co";
// Public anon key: safe in the browser. Tables are locked; only the game functions are callable.
const ANON =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im55dm5kYXRjcnh5eWxjbXFtd3dsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzcyMjkzOTMsImV4cCI6MjA5MjgwNTM5M30.yrlmrYvBOY3LxN3Pgz31Tpr2WQscPhX2YmimIWuA03s";
export const sb = createClient(URL, ANON);

const KEY = "wtb-session";
const load = () => {
  try { return JSON.parse(localStorage.getItem(KEY)) } catch { return null }
};
const save = (s) => {
  try { s ? localStorage.setItem(KEY, JSON.stringify(s)) : localStorage.removeItem(KEY) } catch { /* private mode */ }
};

async function rpc(name, args) {
  const { data, error } = await sb.rpc(name, args);
  if (error) throw new Error(error.message);
  return data;
}

export function useGame() {
  const [session, setSession] = useState(load);
  const [state, setState] = useState(null);
  const [online, setOnline] = useState({}); // player id -> { typing }
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const chan = useRef(null);

  const refresh = useCallback(async () => {
    if (!session) return;
    try {
      setState(await rpc("wtb_state", { p_token: session.token }));
    } catch (e) {
      if (/not found/i.test(e.message)) { save(null); setSession(null); setState(null) }
    }
  }, [session]);

  // Live updates + presence for the current room. Polling is a safety net for flaky phone connections.
  useEffect(() => {
    if (!session) return;
    refresh();
    const c = sb.channel(`wtb:${session.code}`, { config: { presence: { key: session.player_id } } });
    c.on("broadcast", { event: "changed" }, refresh)
      .on("presence", { event: "sync" }, () => {
        const ps = c.presenceState(), next = {};
        for (const id in ps) next[id] = { typing: ps[id].some((m) => m.typing) };
        setOnline(next);
      })
      .subscribe((status) => { if (status === "SUBSCRIBED") c.track({ typing: false }) });
    chan.current = c;
    const poll = setInterval(refresh, 4000);
    return () => { clearInterval(poll); sb.removeChannel(c); chan.current = null };
  }, [session, refresh]);

  const run = (fn) => async (...args) => {
    setBusy(true); setError("");
    try { await fn(...args); await refresh(); return true }
    catch (e) { setError(e.message); return false }
    finally { setBusy(false) }
  };

  const join = run(async (code, name) => {
    const s = await rpc("wtb_join", { p_code: code, p_name: name });
    save(s); setSession(s);
  });
  const newCode = () => rpc("wtb_new_code");
  const ask = run(async (q) => {
    const roundId = await rpc("wtb_ask", { p_token: session.token, p_question: q });
    // The hidden AI player answers in the background.
    sb.functions.invoke("bot-answer", { body: { round_id: roundId } });
  });
  const answer = run(async (body) => {
    await rpc("wtb_answer", { p_token: session.token, p_body: body });
    chan.current?.track({ typing: false });
  });
  const vote = run((id) => rpc("wtb_vote", { p_token: session.token, p_answer: id }));
  const force = run(() => rpc("wtb_force", { p_token: session.token }));
  const setTyping = (typing) => chan.current?.track({ typing });
  const leave = () => { save(null); setSession(null); setState(null) };

  return { session, state, online, error, setError, busy, join, newCode, ask, answer, vote, force, setTyping, leave };
}

// Which screen to show, shared by every visual style.
export function screenFor(g, askOpen) {
  if (!g.session) return "join";
  const s = g.state;
  if (!s) return "loading";
  const r = s.round;
  const myTurn = s.next_asker === s.me.id;
  if (!r || (r.phase === "reveal" && askOpen && myTurn)) return myTurn ? "ask" : "lobby";
  if (r.phase === "answer") return r.can_answer && !r.i_answered ? "answer" : "waiting";
  if (r.phase === "judge") return "judge";
  return "reveal";
}

export const COLORS = ["#ff9500", "#5856d6", "#34c759", "#ff2d55", "#007aff", "#af52de", "#ff3b30", "#00c7be"];
export const nameOf = (s, id) => s?.players.find((p) => p.id === id)?.name ?? "Someone";
