// Style D: "Stack". One thing at a time, big type, cards you flip through.
import { useState } from "react";
import { Icon, Avatar, SUGGESTIONS, clock, inviteLink } from "./ui.jsx";
import { COLORS } from "./game.js";

export default function SkinStack({ g, v }) {
  const { screen, r } = v;
  if (screen === "join") return <Join g={g} v={v} />;
  if (screen === "loading") return <div className="d-screen d-center"><span className="d-eyebrow">Loading room…</span></div>;
  return (
    <div className="d-screen">
      {screen === "lobby" && <Lobby g={g} v={v} />}
      {screen === "ask" && <Ask g={g} v={v} />}
      {screen === "answer" && <Answer g={g} v={v} />}
      {screen === "waiting" && <Waiting g={g} v={v} />}
      {screen === "judge" && <Judge g={g} v={v} key={r.id} />}
      {screen === "reveal" && <Reveal v={v} />}
    </div>
  );
}

const Head = ({ eyebrow, title, color, right }) => (
  <header className="d-head">
    <div>
      <span className="d-eyebrow" style={color ? { color } : undefined}>{eyebrow}</span>
      {title && <h1>{title}</h1>}
    </div>
    {right}
  </header>
);

function Join({ g, v }) {
  const { form, setForm } = v;
  const today = new Date().toLocaleDateString(undefined, { weekday: "long", month: "short", day: "numeric" });
  return (
    <form className="d-screen" onSubmit={v.submitJoin}>
      <Head eyebrow={today} title="Tonight" />
      <div className="d-card d-dark d-rise">
        <div className="d-card-top">
          <span className="d-eyebrow" style={{ color: "#ff9f0a" }}>Live party game</span>
          <h2>Who's the Bot?</h2>
          <p>Your friends answer. One answer is AI. Can you tell?</p>
        </div>
        <div className="d-mini-stack" aria-hidden="true">
          <span /><span /><span className="d-tilt">"half a gas station burrito"</span>
        </div>
        <div className="d-card-form">
          <label className="d-in">
            <span>Room code</span>
            <input value={form.code} maxLength={4} autoCapitalize="characters" placeholder="New room"
              onChange={(e) => setForm({ ...form, code: e.target.value.toUpperCase().replace(/[^A-Z0-9]/g, "") })} />
          </label>
          <label className="d-in">
            <span>Name</span>
            <input value={form.name} maxLength={20} placeholder="First name" autoComplete="given-name"
              onChange={(e) => setForm({ ...form, name: e.target.value })} />
          </label>
          <button className="d-join" disabled={g.busy || !form.name.trim()}>{form.code ? "JOIN" : "START"}</button>
        </div>
      </div>
    </form>
  );
}

function PlayerChips({ v, done }) {
  return (
    <div className="d-chips">
      {v.s.players.map((p) => (
        <span key={p.id} className="d-chip">
          <Avatar p={p} size={20} online={!!v.online[p.id]} />
          {p.id === v.s.me.id ? "You" : p.name}
          {done?.(p) && <span className="d-ok">{Icon.check(11)}</span>}
          {v.online[p.id]?.typing && <span className="d-typing"><i /><i /><i /></span>}
        </span>
      ))}
    </div>
  );
}

function Invite({ code, onQr }) {
  const [copied, setCopied] = useState(false);
  const copy = async () => { try { await navigator.clipboard.writeText(inviteLink(code)); setCopied(true); setTimeout(() => setCopied(false), 1500) } catch { /* ignore */ } };
  return (
    <div className="d-invite-row">
      <button type="button" className="d-ghost" onClick={copy}>{Icon.link()} {copied ? "Link copied" : `Invite · ${code}`}</button>
      <button type="button" className="d-ghost" onClick={onQr}>{Icon.qr()} QR code</button>
    </div>
  );
}

const Leave = ({ g }) => <button className="d-icon" aria-label="Leave room" onClick={g.leave}>{Icon.out()}</button>;

function Lobby({ g, v }) {
  return (
    <>
      <Head eyebrow={`Room ${v.s.room}`} title="Waiting room" right={<Leave g={g} />} />
      <div className="d-card d-pad d-rise">
        <span className="d-eyebrow">Up next</span>
        <p className="d-big">{v.nextName} is picking a question</p>
        <PlayerChips v={v} />
      </div>
      <div className="d-fill" />
      <div className="d-foot"><Invite code={v.s.room} onQr={v.showQr} /></div>
    </>
  );
}

function Ask({ g, v }) {
  const [q, setQ] = useState("");
  const alone = v.s.players.length < 2;
  return (
    <>
      <Head eyebrow={`Room ${v.s.room}`} title="Your turn to ask" right={<Leave g={g} />} />
      <label className="d-write">
        <span className="sr">Your question</span>
        <textarea value={q} maxLength={200} placeholder="Ask something only a human would get right…" onChange={(e) => setQ(e.target.value)} />
      </label>
      <div className="d-sugg">
        {SUGGESTIONS.map((t) => <button key={t} className="d-pill" onClick={() => setQ(t)}>{t}</button>)}
      </div>
      <div className="d-fill" />
      <div className="d-foot">
        <Invite code={v.s.room} onQr={v.showQr} />
        <button className="d-cta" disabled={g.busy || alone || !q.trim()} onClick={() => g.ask(q)}>
          {alone ? "Waiting for one more person" : "Ask the room"}
        </button>
      </div>
    </>
  );
}

function Answer({ g, v }) {
  const [a, setA] = useState("");
  return (
    <>
      <Head eyebrow={`${v.askerName} asks`} right={<span className="d-time">{clock(v.elapsed)}</span>} />
      <h2 className="d-question">{v.r.question}</h2>
      <label className="d-write small">
        <span className="d-eyebrow">Your answer · anonymous</span>
        <textarea value={a} maxLength={160} placeholder="Type like you text…" onChange={(e) => setA(e.target.value)}
          onFocus={() => g.setTyping(true)} onBlur={() => g.setTyping(false)} />
      </label>
      <p className="d-tip">Tip: sound like yourself. The bot sounds like everyone.</p>
      <div className="d-fill" />
      <PlayerChips v={v} />
      <div className="d-foot">
        <button className="d-cta" disabled={g.busy || !a.trim()} onClick={() => g.answer(a)}>Send anonymously</button>
      </div>
    </>
  );
}

function Ring({ value, total }) {
  const pct = total ? value / total : 0;
  return (
    <div className="d-ring" style={{ "--p": pct }}>
      <span><b>{value}</b>/{total}</span>
    </div>
  );
}

function Waiting({ g, v }) {
  const { r } = v;
  return (
    <>
      <Head eyebrow={v.isAsker ? "You asked" : "Answer sent"} right={<span className="d-time">{clock(v.elapsed)}</span>} />
      <h2 className="d-question">{r.question}</h2>
      <div className="d-card d-pad d-center-col d-rise">
        <Ring value={r.answered} total={r.expected_answers} />
        <p className="d-big small">{r.answered >= r.expected_answers ? "Shuffling the deck…" : "Answers are coming in"}</p>
        <span className="d-tip">Everyone sees them at the same time</span>
      </div>
      <div className="d-fill" />
      <div className="d-foot">
        {v.isAsker && v.elapsed > 45 && <button className="d-ghost" onClick={g.force}>Skip ahead</button>}
      </div>
    </>
  );
}

function Judge({ g, v }) {
  const { s, r } = v;
  const cards = s.answers;
  const [i, setI] = useState(0);
  const a = cards[Math.min(i, cards.length - 1)];
  const go = (d) => setI((x) => (x + d + cards.length) % cards.length);
  const picked = r.my_vote === a.id;
  return (
    <>
      <Head eyebrow="Find the bot" right={<span className="d-time">{i + 1} / {cards.length}</span>} />
      <div className="d-progress">{cards.map((c, k) => <span key={c.id} className={(k <= i ? "on" : "") + (r.my_vote === c.id ? " vote" : "")} />)}</div>
      <p className="d-q-small">{r.question}</p>
      <div className="d-deck">
        <div className="d-card d-back2" />
        <div className="d-card d-back1" />
        <div className={"d-card d-front" + (picked ? " picked" : "")} key={a.id}>
          <span className="d-eyebrow">Answer {a.label}{a.mine ? " · yours" : ""}{picked ? " · your bot pick" : ""}</span>
          <p className="d-answer">{a.body}</p>
          <div className="d-nav">
            <button className="d-icon" aria-label="Previous answer" onClick={() => go(-1)}>{Icon.left()}</button>
            <button className="d-icon" aria-label="Next answer" onClick={() => go(1)}>{Icon.right()}</button>
          </div>
        </div>
      </div>
      <div className="d-actions">
        <button className="d-round bot" aria-label="This one is the bot" disabled={a.mine || g.busy}
          onClick={async () => { if (await g.vote(a.id)) go(1) }}>{Icon.bot(28)}</button>
        <button className="d-round human" aria-label="Human, next answer" onClick={() => go(1)}>{Icon.person(28)}</button>
      </div>
      <p className="d-tip center">{r.voted} of {r.expected_votes} voted</p>
      {v.isAsker && <div className="d-foot"><button className="d-ghost" onClick={g.force}>Reveal now</button></div>}
    </>
  );
}

function Reveal({ v }) {
  const { s, r } = v;
  const humans = s.answers.filter((a) => !a.is_bot);
  return (
    <>
      <Head eyebrow={v.gotIt ? "Caught it · +2" : r.my_vote ? "It fooled you" : "Round over"} color={v.gotIt ? "#34c759" : "#ff3b30"} title={`Round ${r.number} results`} />
      <div className="d-passes">
        {v.bot && (
          <div className="d-pass bot">
            <div className="d-pass-row"><span className="d-eyebrow">Answer {v.bot.label} · the bot</span>{Icon.bot(22)}</div>
            <p>{v.bot.body}</p>
            <span className="d-pass-sub">{v.bot.votes} of {r.expected_votes} called it</span>
          </div>
        )}
        {humans.map((a, k) => (
          <div key={a.id} className="d-pass" style={{ background: COLORS[(a.author_color ?? k) % 8], animationDelay: `${300 + k * 90}ms` }}>
            <b>{a.author}</b><span>{a.label} · {a.body}</span>
          </div>
        ))}
      </div>
      <div className="d-fill" />
      <div className="d-foot">
        <span className="d-tip center">{v.ranked.slice(0, 3).map((p, k) => `${k + 1}. ${p.name} ${p.score}`).join("    ")}</span>
        {v.myTurn ? <button className="d-cta dark" onClick={v.openAsk}>Your turn to ask</button>
          : <span className="d-tip center">Waiting for {v.nextName} to ask…</span>}
      </div>
    </>
  );
}
