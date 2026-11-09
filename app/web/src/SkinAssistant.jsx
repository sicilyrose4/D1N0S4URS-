// Style B: "Assistant". Monochrome, ChatGPT-like. The room "thinks" like a model.
import { useState } from "react";
import { Icon, Avatar, SUGGESTIONS, clock, inviteLink } from "./ui.jsx";

export default function SkinAssistant({ g, v }) {
  const { r, screen } = v;
  if (screen === "join") return <Join g={g} v={v} />;
  if (screen === "loading") return <div className="b-screen b-center"><span className="b-shim">Loading room…</span></div>;

  return (
    <div className="b-screen">
      <Top g={g} v={v} />
      {screen === "lobby" && <Lobby v={v} />}
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
      <div className="b-faces" aria-label={`${s.players.length} players`}>
        {s.players.slice(0, 3).map((p) => <Avatar key={p.id} p={p} size={24} online={!!v.online[p.id]} />)}
        {s.players.length > 3 && <span className="av more">+{s.players.length - 3}</span>}
      </div>
    </header>
  );
}

function Join({ g, v }) {
  const { form, setForm } = v;
  return (
    <form className="b-screen b-join" onSubmit={v.submitJoin}>
      <div className="b-hero">
        <div className="b-orb">{Icon.people()}</div>
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

function Players({ v }) {
  return (
    <ul className="b-players">
      {v.s.players.map((p) => (
        <li key={p.id}>
          <Avatar p={p} size={28} online={!!v.online[p.id]} />
          <span>{p.name}{p.id === v.s.me.id && <em> (you)</em>}</span>
          {p.score > 0 && <b>{p.score}</b>}
        </li>
      ))}
    </ul>
  );
}

function Invite({ code }) {
  const [copied, setCopied] = useState(false);
  const copy = async () => { try { await navigator.clipboard.writeText(inviteLink(code)); setCopied(true); setTimeout(() => setCopied(false), 1500) } catch { /* ignore */ } };
  return (
    <button className="b-invite" onClick={copy}>
      {Icon.link()} <span>{copied ? "Link copied" : <>Invite friends · <b>{code}</b></>}</span>
    </button>
  );
}

function Lobby({ v }) {
  return (
    <main className="b-body b-mid">
      <span className="b-shim">Waiting for {v.nextName} to ask…</span>
      <Players v={v} />
      <Invite code={v.s.room} />
    </main>
  );
}

function Ask({ g, v }) {
  const [q, setQ] = useState("");
  const alone = v.s.players.length < 2;
  const send = (e) => { e.preventDefault(); if (q.trim()) g.ask(q) };
  return (
    <>
      <main className="b-body b-mid">
        <div className="b-orb glow">{Icon.people()}</div>
        <h2>What should the room answer?</h2>
        <p className="b-sub">
          {alone ? "Invite at least one more person to start." : `${v.s.players.length - 1} people and 1 bot will answer. Ask something only a human would get right.`}
        </p>
        {alone && <Invite code={v.s.room} />}
        <div className="b-chips">
          {SUGGESTIONS.slice(0, 4).map((t) => (
            <button key={t} className="b-chip" onClick={() => setQ(t)}>{t}</button>
          ))}
        </div>
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
      <main className="b-body">
        <div className="b-asked">{v.askerName} asks</div>
        <div className="b-q">{v.r.question}</div>
        <p className="b-hint">Answer like yourself. The bot is trying to sound like everyone.</p>
        {v.typing > 0 && <span className="b-shim">{v.typing} {v.typing === 1 ? "person is" : "people are"} writing…</span>}
      </main>
      <Composer value={a} onChange={setA} onSubmit={(e) => { e.preventDefault(); if (a.trim()) g.answer(a) }}
        placeholder="Your answer, anonymous" max={160} disabled={g.busy}
        onFocus={() => g.setTyping(true)} onBlur={() => g.setTyping(false)} />
    </>
  );
}

function Waiting({ g, v }) {
  const { r } = v;
  const total = r.expected_answers;
  return (
    <>
      <main className="b-body">
        <div className="b-q">{r.question}</div>
        <span className="b-shim">
          {r.answered >= total ? "Shuffling answers…" : `${total - r.answered} still writing…`}
        </span>
        <div className="b-skel">
          {Array.from({ length: total }, (_, i) => (
            <div key={i} className={"b-skel-row" + (i < r.answered ? " done" : "")}>
              <span className="b-dot">{i < r.answered ? Icon.check(12) : ""}</span>
              <span className="b-bar" style={{ width: `${40 + ((i * 37) % 50)}%` }} />
            </div>
          ))}
        </div>
      </main>
      <footer className="b-foot">
        <span className="b-pill">{Icon.clock()} {clock(v.elapsed)} · answers reveal together</span>
        {v.isAsker && v.elapsed > 45 && <button className="b-ghost" onClick={g.force}>Skip ahead</button>}
      </footer>
    </>
  );
}

function Judge({ g, v }) {
  const { s, r } = v;
  const reveal = r.phase === "reveal";
  return (
    <>
      <main className="b-body">
        {reveal ? (
          <div className="b-reveal">
            <div className="b-botbadge">{Icon.bot(28)}</div>
            <h2>{v.bot ? `${v.bot.label} was the bot` : "Round over"}</h2>
            <p className="b-sub">{v.gotIt ? "You caught it. +2" : r.my_vote ? "It fooled you." : `${v.askerName} asked: ${r.question}`}</p>
          </div>
        ) : (
          <>
            <div className="b-asked">Which one is the bot?</div>
            <div className="b-q small">{r.question}</div>
          </>
        )}
        <div className="b-opts">
          {s.answers.map((a, i) => {
            const picked = r.my_vote === a.id;
            return (
              <button key={a.id} className={"b-opt" + (picked ? " picked" : "") + (reveal && a.is_bot ? " bot" : "") + (reveal && !a.is_bot ? " dim" : "")}
                style={{ animationDelay: `${i * 70}ms` }} disabled={reveal || a.mine || g.busy} onClick={() => g.vote(a.id)}>
                <span className="b-radio" />
                <span className="b-opt-body">
                  <span><b>{a.label}</b> · {a.body}</span>
                  {a.mine && !reveal && <em>Your answer</em>}
                  {reveal && (
                    <em className="b-who">
                      {a.is_bot ? <>{Icon.bot(12)} Bot</> : a.author} · {a.votes} {a.votes === 1 ? "vote" : "votes"}
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
            {v.isAsker && <button className="b-ghost" onClick={g.force}>Reveal now</button>}
          </>
        )}
      </footer>
    </>
  );
}
