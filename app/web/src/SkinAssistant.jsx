// Style B: "Assistant". Monochrome, ChatGPT-like. The room "thinks" like a model.
import { useEffect, useState } from "react";
import { Icon, Avatar, Robot, useQuestions, useLoadingLine, inviteLink } from "./ui.jsx";

export default function SkinAssistant({ g, v }) {
  const { r, screen } = v;
  if (screen === "join") return <Join g={g} v={v} />;
  if (screen === "loading") return <div className="b-screen"><Scan v={v} loading /><LobbyFoot g={g} v={v} /></div>;

  return (
    <div className="b-screen">
      <Top g={g} v={v} />
      {screen === "lobby" && <><Scan v={v} /><LobbyFoot g={g} v={v} /></>}
      {screen === "ask" && <Ask g={g} v={v} />}
      {screen === "answer" && <Answer g={g} v={v} />}
      {screen === "waiting" && <Waiting g={g} v={v} />}
      {(screen === "judge" || screen === "reveal") && <Judge g={g} v={v} key={r.id} />}
    </div>
  );
}

function Top({ g, v }) {
  const { s, r } = v;
  return (
    <header className="b-top">
      <button className="b-ib" aria-label="Leave room" onClick={g.leave}>{Icon.out()}</button>
      <div className="b-title">
        {r && r.phase !== "reveal" ? <>Round {r.number}</> : <>Room {s.room}</>}
      </div>
      <div className="b-row">
      <button className="b-ib" aria-label={v.soundOn ? "Turn music off" : "Turn music on"} onClick={v.toggleSound}>{v.soundOn ? Icon.sound() : Icon.mute()}</button>
      <button className="b-faces" aria-label={`${s.players.length} players. Show invite QR code`} onClick={v.showQr}>
        {s.players.slice(0, 3).map((p) => <Avatar key={p.id} p={p} size={24} online={!!v.online[p.id]} />)}
        {s.players.length > 3 && <span className="av more">+{s.players.length - 3}</span>}
      </button>
      </div>
    </header>
  );
}

function Join({ g, v }) {
  const { form, setForm } = v;
  return (
    <form className="b-screen b-join" onSubmit={v.submitJoin}>
      <div className="b-hero">
        <Robot mood="idle" size={80} />
        <h1>Who's the Bot?</h1>
        <p>Everyone answers. One answer is secretly AI. Find it.</p>
      </div>
      <div className="b-fields">
        <label className="b-field">
          <span>Room code</span>
          <input value={form.code} maxLength={4} autoCapitalize="characters" placeholder="Leave empty for a new room"
            onChange={(e) => setForm({ ...form, code: e.target.value.toUpperCase().replace(/[^A-Z0-9]/g, "") })} />
        </label>
        <label className="b-field">
          <span>Your name</span>
          <input value={form.name} maxLength={20} placeholder="First name" autoComplete="given-name"
            onChange={(e) => setForm({ ...form, name: e.target.value })} />
        </label>
        <button className="b-cta" disabled={g.busy || !form.name.trim()}>
          {form.code ? "Join room" : "Start a new room"}
        </button>
      </div>
    </form>
  );
}

function Invite({ code, onQr }) {
  const [copied, setCopied] = useState(false);
  const copy = async () => { try { await navigator.clipboard.writeText(inviteLink(code)); setCopied(true); setTimeout(() => setCopied(false), 1500) } catch { /* ignore */ } };
  return (
    <div className="b-invite-row">
      <button className="b-invite" onClick={copy}>
        {Icon.link()} <span>{copied ? "Link copied" : <>Invite · <b>{code}</b></>}</span>
      </button>
      <button className="b-invite" onClick={onQr}>{Icon.qr()} <span>QR code</span></button>
    </div>
  );
}

// Loading and lobby: the robot hops along the players and checks each one off as human.
function Scan({ v, loading }) {
  const line = useLoadingLine();
  const people = v.s?.players ?? [];
  const faces = people.slice(0, 6);
  while (faces.length < 4) faces.push(null); // empty seats, so the scan has room to move
  const pass = faces.length * 0.7;
  const hostName = people.find((p) => p.id === v.s?.host_id)?.name ?? "the host";
  return (
    <main className="b-body b-mid">
      <div className="b-scan" style={{ "--pass": `${pass}s` }}>
        <Robot mood="deciding" size={48} className="b-scanner" />
        {faces.map((p, i) => (
          <span key={p?.id ?? i} className={"b-face" + (p ? "" : " empty")} style={{ "--d": `${i * 0.12}s` }}>
            {p ? <Avatar p={p} size={40} /> : <span className="av ghost" />}
            {p && <small>{p.id === v.s.me.id ? "You" : p.name}</small>}
          </span>
        ))}
        {people.length > 6 && <span className="b-face more"><span className="av more">+{people.length - 6}</span></span>}
      </div>
      {loading ? (
        <>
          <h2>Checking who's human…</h2>
          <p className="b-sub b-line" key={line}>{line}</p>
        </>
      ) : (
        <>
          <h2>{!v.s.started ? (v.isHost ? "Everyone in?" : `Waiting for ${hostName} to start…`) : `Waiting for ${v.nextName} to ask…`}</h2>
          <p className="b-sub">{people.length} {people.length === 1 ? "human" : "humans"} found. 1 imposter incoming.</p>
        </>
      )}
    </main>
  );
}

// Waiting room footer: the host's Go button, and the invite code + QR for everyone.
function LobbyFoot({ g, v }) {
  const n = v.s?.players.length ?? 0;
  return (
    <footer className="b-foot">
      {v.s && !v.s.started && v.isHost && v.screen === "lobby" && (
        <button className="b-cta b-go-big" disabled={g.busy || n < 2} onClick={g.start}>{n < 2 ? "Waiting for one more person" : "Go"}</button>
      )}
      {v.code && <Invite code={v.code} onQr={v.showQr} />}
    </footer>
  );
}

// Shrinking 30 second bar. Turns red for the last 10.
function Timer({ v }) {
  const left = Math.max(0, v.left ?? 0);
  return (
    <div className={"b-timer" + (left <= 10 ? " hot" : "") + (left <= 5 ? " panic" : "")} role="timer" aria-label={`${left} seconds left`}>
      <span className="b-track"><span className="b-fill" style={{ transform: `scaleX(${Math.min(1, left / 30)})` }} /></span>
      <b>{left}</b>
    </div>
  );
}

// Everyone's face while answering: typing bubble, or a check once they've sent. The bot plays along.
function Crowd({ v }) {
  const { r, s } = v;
  const done = new Set(r.answered_ids);
  const status = (p) => (done.has(p.id) ? "done" : v.online[p.id]?.typing ? "typing" : v.online[p.id] ? "idle" : "away");
  return (
    <ul className="b-crowd" aria-label="Who has answered">
      {s.players.filter((p) => p.id !== r.asker_id).map((p) => (
        <Seat key={p.id} st={status(p)} name={p.id === s.me.id ? "You" : p.name}><Avatar p={p} size={44} /></Seat>
      ))}
      <Seat st={r.bot_answered ? "done" : "typing"} name="Bot"><Robot mood="idle" size={44} /></Seat>
    </ul>
  );
}
const Seat = ({ st, name, children }) => (
  <li className={"b-seat " + st}>
    {st === "typing" && <span className="b-bubble" aria-label="typing"><i /><i /><i /></span>}
    {children}
    {st === "done" && <span className="b-tick" aria-label="answered">{Icon.check(10)}</span>}
    <small>{name}</small>
  </li>
);

// Answer text that flickers through random letters while the answers are being mixed.
const GLYPHS = "abcdefghijklmnopqrstuvwxyz#%&?!";
function Scramble({ text, on }) {
  const [t, setT] = useState(text);
  useEffect(() => {
    if (!on) return;
    const id = setInterval(() => setT(text.replace(/\S/g, () => GLYPHS[(Math.random() * GLYPHS.length) | 0])), 70);
    return () => clearInterval(id);
  }, [text, on]);
  return on ? t : text;
}

function Ask({ g, v }) {
  const [q, setQ] = useState("");
  const deck = useQuestions(v.s.asked);
  const alone = v.s.players.length < 2;
  const send = (e) => { e.preventDefault(); if (q.trim()) g.ask(q) };
  return (
    <>
      <main className="b-body b-mid">
        <Robot mood="idle" size={64} />
        <h2>What should the room answer?</h2>
        <p className="b-sub">
          {alone ? "Invite at least one more person to start." : `${v.s.players.length - 1} ${v.s.players.length === 2 ? "person" : "people"} and 1 bot will answer. Ask something only a human would get right.`}
        </p>
        <Invite code={v.s.room} onQr={v.showQr} />
        <div className="b-chips">
          {deck.qs.map((t, i) => (
            <button key={t + deck.spin} className="b-chip" style={{ animationDelay: `${i * 50}ms` }} onClick={() => setQ(t)}>{t}</button>
          ))}
        </div>
        <button className="b-shuffle" onClick={deck.shuffle}>
          <span key={deck.spin} className="spin">{Icon.shuffle()}</span> New questions
        </button>
      </main>
      <Composer value={q} onChange={setQ} onSubmit={send} placeholder="Ask the room anything" max={200} disabled={g.busy || alone} />
    </>
  );
}

function Composer({ value, onChange, onSubmit, placeholder, max, disabled, onFocus, onBlur }) {
  return (
    <form className="b-compose" onSubmit={onSubmit}>
      <label className="sr">{placeholder}</label>
      <textarea rows={1} value={value} maxLength={max} placeholder={placeholder} onFocus={onFocus} onBlur={onBlur}
        onChange={(e) => onChange(e.target.value)}
        onKeyDown={(e) => { if (e.key === "Enter" && !e.shiftKey) { e.preventDefault(); onSubmit(e) } }} />
      <button className="b-go" aria-label="Send" disabled={disabled || !value.trim()}>{Icon.up()}</button>
    </form>
  );
}

function Answer({ g, v }) {
  const [a, setA] = useState("");
  return (
    <>
      <Timer v={v} />
      <main className="b-body">
        <div className="b-asked">{v.askerName} asks</div>
        <div className="b-q">{v.r.question}</div>
        <p className="b-hint">Answer like yourself. The bot is trying to sound like everyone.</p>
        <Crowd v={v} />
        {v.isHost && <button className="b-ghost b-skip" onClick={g.force} disabled={g.busy}>Skip to voting</button>}
      </main>
      <Composer value={a} onChange={setA} onSubmit={(e) => { e.preventDefault(); if (a.trim()) g.answer(a) }}
        placeholder="Your answer, anonymous" max={160} disabled={g.busy}
        onFocus={() => g.setTyping(true)} onBlur={() => g.setTyping(false)} />
    </>
  );
}

function Waiting({ g, v }) {
  const { r } = v;
  const waiting = r.expected_answers - r.answered;
  return (
    <>
      <Timer v={v} />
      <main className="b-body">
        <div className="b-q">{r.question}</div>
        <span className="b-shim">{waiting <= 0 ? "Mixing up the answers…" : `${waiting} still writing…`}</span>
        <Crowd v={v} />
      </main>
      <footer className="b-foot">
        <span className="b-pill">Answers reveal together, in random order</span>
        {v.isHost && <button className="b-cta" onClick={g.force} disabled={g.busy}>Skip to voting</button>}
      </footer>
    </>
  );
}

function Judge({ g, v }) {
  const { s, r } = v;
  const reveal = r.phase === "reveal";
  const [mixing, setMixing] = useState(!reveal);
  useEffect(() => { if (!mixing) return; const t = setTimeout(() => setMixing(false), 1800); return () => clearTimeout(t) }, [mixing]);
  return (
    <>
      <main className="b-body">
        {reveal ? (
          <div className="b-reveal">
            <Robot mood={v.gotIt ? "caught" : r.my_vote ? "fooled" : "busted"} size={88} />
            <h2>{v.bot ? `${v.bot.label} was the bot` : "Round over"}</h2>
            <p className={"b-sub" + (v.gotIt ? " win" : r.my_vote ? " lose" : "")}>{v.gotIt ? "You caught it. +2" : r.my_vote ? "It fooled you." : `${v.askerName} asked: ${r.question}`}</p>
          </div>
        ) : (
          <>
            <div className="b-row"><Robot mood={mixing ? "deciding" : "suspicious"} size={40} /><div className="b-asked">{mixing ? "Mixing up the answers…" : "Which one is the bot?"}</div></div>
            <div className="b-q small">{r.question}</div>
          </>
        )}
        <div className="b-opts">
          {s.answers.map((a, i) => {
            const picked = r.my_vote === a.id;
            return (
              <button key={a.id} className={"b-opt" + (picked ? " picked" : "") + (reveal && a.is_bot ? " bot" : "") + (reveal && !a.is_bot ? " dim" : "") + (reveal && picked ? (a.is_bot ? " right" : " wrong") : "") + (mixing ? " mix" : "")}
                style={{ animationDelay: `${i * 70}ms`, "--y": `${(((i * 3) % 5) - 2) * 34 || 30}px`, "--r": `${i % 2 ? 2 : -2}deg` }}
                disabled={reveal || a.mine || g.busy || mixing} onClick={() => g.vote(a.id)}>
                <span className="b-radio" />
                <span className="b-opt-body">
                  <span><b>{mixing ? "?" : a.label}</b> · <Scramble text={a.body} on={mixing} /></span>
                  {a.mine && !reveal && !mixing && <em>Your answer</em>}
                  {reveal && (
                    <em className="b-who">
                      {a.is_bot ? <><Robot mood="busted" size={18} /> Bot</> : a.author} · {a.votes} {a.votes === 1 ? "vote" : "votes"}
                    </em>
                  )}
                </span>
              </button>
            );
          })}
        </div>
      </main>
      <footer className="b-foot">
        {reveal ? (
          <>
            <span className="b-pill">{v.ranked.slice(0, 3).map((p, i) => `${i + 1}. ${p.name} ${p.score}`).join("   ")}</span>
            {v.myTurn ? <button className="b-cta" onClick={v.openAsk}>Your turn to ask</button>
              : <span className="b-shim">Waiting for {v.nextName} to ask…</span>}
          </>
        ) : (
          <>
            <span className="b-pill">{r.voted} of {r.expected_votes} voted{r.my_vote ? " · tap another to change" : ""}</span>
            {v.isHost && !mixing && <button className="b-ghost" onClick={g.force}>Reveal now</button>}
          </>
        )}
      </footer>
    </>
  );
}
