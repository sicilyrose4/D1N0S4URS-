import { useEffect, useState } from "react";
import { useGame, screenFor, nameOf } from "./game.js";
import { useElapsed, haptic } from "./ui.jsx";
import SkinAssistant from "./SkinAssistant.jsx";
import SkinStack from "./SkinStack.jsx";

const SKINS = { b: { name: "Assistant", C: SkinAssistant }, d: { name: "Stack", C: SkinStack } };
const pref = (k, d) => { try { return localStorage.getItem(k) ?? d } catch { return d } };
const setPref = (k, v) => { try { localStorage.setItem(k, v) } catch { /* private mode */ } };

export default function App() {
  const g = useGame();
  const params = new URLSearchParams(location.search);
  const [skin, setSkin] = useState(() => (SKINS[params.get("skin")] ? params.get("skin") : pref("wtb-skin", "b")));
  const [askOpen, setAskOpen] = useState(false);
  const [form, setForm] = useState({ code: (params.get("room") || "").toUpperCase(), name: pref("wtb-name", "") });

  const s = g.state, r = s?.round;
  const screen = screenFor(g, askOpen);
  const elapsed = useElapsed(r?.created_at);

  useEffect(() => { setPref("wtb-skin", skin); document.documentElement.dataset.skin = skin }, [skin]);
  useEffect(() => { if (r?.phase !== "reveal") setAskOpen(false); if (r?.phase === "reveal") haptic() }, [r?.phase, r?.id]);

  const typing = s ? Object.entries(g.online).filter(([id, v]) => v.typing && id !== s.me.id).length : 0;
  const v = {
    s, r, screen, elapsed, typing,
    online: g.online,
    isAsker: r && s && r.asker_id === s.me.id,
    myTurn: s && s.next_asker === s.me.id,
    askerName: r ? nameOf(s, r.asker_id) : "",
    nextName: s ? nameOf(s, s.next_asker) : "",
    bot: s?.answers.find((a) => a.is_bot),
    gotIt: r?.my_vote && s?.answers.find((a) => a.id === r.my_vote)?.is_bot,
    ranked: s ? [...s.players].sort((a, b) => b.score - a.score) : [],
    form, setForm,
    openAsk: () => setAskOpen(true),
    submitJoin: async (e) => {
      e?.preventDefault();
      setPref("wtb-name", form.name.trim());
      let code = form.code.trim();
      if (!code) code = await g.newCode();
      g.join(code, form.name);
    },
  };

  const { C } = SKINS[skin];
  return (
    <div className={`app skin-${skin}`}>
      <div className="skin-switch" role="group" aria-label="Visual style">
        {Object.entries(SKINS).map(([k, { name }]) => (
          <button key={k} aria-pressed={k === skin} onClick={() => setSkin(k)}>{name}</button>
        ))}
      </div>
      <C g={g} v={v} />
      {g.error && <div className="toast" role="alert" onClick={() => g.setError("")}>{g.error}</div>}
    </div>
  );
}
