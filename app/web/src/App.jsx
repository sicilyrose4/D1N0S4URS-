import { useEffect, useRef, useState } from "react";
import { useGame, screenFor, nameOf } from "./game.js";
import { useSecondsLeft, haptic, QrSheet } from "./ui.jsx";
import * as music from "./music.js";
import SkinAssistant from "./SkinAssistant.jsx";

const pref = (k, d) => { try { return localStorage.getItem(k) ?? d } catch { return d } };
const setPref = (k, v) => { try { localStorage.setItem(k, v) } catch { /* private mode */ } };

export default function App() {
  const g = useGame();
  const params = new URLSearchParams(location.search);
  const [askOpen, setAskOpen] = useState(false);
  const [qr, setQr] = useState(false);
  const [hold, setHold] = useState(true);
  const [form, setForm] = useState({ code: (params.get("room") || "").toUpperCase(), name: pref("wtb-name", "") });

  const s = g.state, r = s?.round;
  const real = screenFor(g, askOpen);
  // Keep the loading scan up for a moment after joining so people actually see it.
  const screen = hold && real !== "join" ? "loading" : real;
  const left = useSecondsLeft(r?.phase === "answer" ? r.deadline : null, s?.skew);
  const isHost = !!s && s.host_id === s.me.id;
  const [sound, setSound] = useState(() => pref("wtb-sound", ""));
  const soundOn = sound ? sound === "on" : isHost; // music plays on the host's device unless someone changes it
  const leftRef = useRef(left);
  leftRef.current = left;

  // Out of time: ask the server to close answers, retrying every 2s until the phase moves on.
  useEffect(() => { if (left !== null && left <= 0 && left % 2 === 0) g.tick() }, [left]); // eslint-disable-line react-hooks/exhaustive-deps
  // Tense music while people are answering.
  useEffect(() => { if (screen !== "loading" && r?.phase === "answer" && soundOn) music.play(() => leftRef.current ?? 30); else music.stop(); return music.stop }, [r?.phase, r?.id, soundOn, screen]);
  // Phones only allow audio after a tap.
  useEffect(() => { addEventListener("pointerdown", music.unlock); return () => removeEventListener("pointerdown", music.unlock) }, []);

  useEffect(() => { setHold(true); const t = setTimeout(() => setHold(false), 2400); return () => clearTimeout(t) }, [g.session?.code]);
  useEffect(() => { if (r?.phase !== "reveal") setAskOpen(false); if (r?.phase === "reveal") haptic() }, [r?.phase, r?.id]);

  const code = s?.room ?? g.session?.code;
  const v = {
    s, r, screen, code, left, isHost, soundOn,
    toggleSound: () => { const next = soundOn ? "off" : "on"; setSound(next); setPref("wtb-sound", next) },
    online: g.online,
    myTurn: s && s.next_asker === s.me.id,
    askerName: r ? nameOf(s, r.asker_id) : "",
    nextName: s ? nameOf(s, s.next_asker) : "",
    bot: s?.answers.find((a) => a.is_bot),
    gotIt: r?.my_vote && s?.answers.find((a) => a.id === r.my_vote)?.is_bot,
    ranked: s ? [...s.players].sort((a, b) => b.score - a.score) : [],
    form, setForm,
    openAsk: () => setAskOpen(true),
    showQr: () => setQr(true),
    submitJoin: async (e) => {
      e?.preventDefault();
      setPref("wtb-name", form.name.trim());
      let code = form.code.trim();
      if (!code) code = await g.newCode();
      g.join(code, form.name);
    },
  };

  return (
    <div className="app">
      <SkinAssistant g={g} v={v} />
      {qr && code && <QrSheet code={code} onClose={() => setQr(false)} />}
      {g.error && <div className="toast" role="alert" onClick={() => g.setError("")}>{g.error}</div>}
    </div>
  );
}
