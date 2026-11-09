// Small pieces shared by both visual styles.
import { useEffect, useState } from "react";
import { COLORS } from "./game.js";

const P = { fill: "none", stroke: "currentColor", strokeLinecap: "round", strokeLinejoin: "round", "aria-hidden": true };
export const Icon = {
  up: (s = 18) => <svg width={s} height={s} viewBox="0 0 24 24" strokeWidth="2.5" {...P}><path d="M12 19V5M5 12l7-7 7 7" /></svg>,
  bot: (s = 18) => <svg width={s} height={s} viewBox="0 0 24 24" strokeWidth="2" {...P}><rect x="5" y="8" width="14" height="11" rx="3" /><path d="M12 4v4M9 13h.01M15 13h.01" /></svg>,
  person: (s = 18) => <svg width={s} height={s} viewBox="0 0 24 24" strokeWidth="2" {...P}><circle cx="12" cy="8" r="4" /><path d="M4 21c1-4 4.5-6 8-6s7 2 8 6" /></svg>,
  people: (s = 24) => <svg width={s} height={s} viewBox="0 0 24 24" strokeWidth="1.8" {...P}><circle cx="9" cy="9" r="3" /><circle cx="17" cy="11" r="2.5" /><path d="M3 20c.8-3 3.2-5 6-5s5.2 2 6 5M14.5 16.5c.7-.9 1.6-1.5 2.5-1.5 2 0 3.5 1.7 4 4" /></svg>,
  left: (s = 20) => <svg width={s} height={s} viewBox="0 0 24 24" strokeWidth="2.5" {...P}><path d="M15 6l-6 6 6 6" /></svg>,
  right: (s = 20) => <svg width={s} height={s} viewBox="0 0 24 24" strokeWidth="2.5" {...P}><path d="M9 6l6 6-6 6" /></svg>,
  check: (s = 16) => <svg width={s} height={s} viewBox="0 0 24 24" strokeWidth="3" {...P}><path d="M5 12l5 5 9-10" /></svg>,
  clock: (s = 14) => <svg width={s} height={s} viewBox="0 0 24 24" strokeWidth="2" {...P}><circle cx="12" cy="12" r="9" /><path d="M12 7v5l3 2" /></svg>,
  out: (s = 18) => <svg width={s} height={s} viewBox="0 0 24 24" strokeWidth="2" {...P}><path d="M15 4h4v16h-4M10 8l-4 4 4 4M6 12h10" /></svg>,
  link: (s = 16) => <svg width={s} height={s} viewBox="0 0 24 24" strokeWidth="2" {...P}><path d="M10 14a4 4 0 006 0l3-3a4 4 0 00-6-6l-1 1M14 10a4 4 0 00-6 0l-3 3a4 4 0 006 6l1-1" /></svg>,
};

export const Avatar = ({ p, size = 30, online, ring }) => (
  <span
    className={"av" + (online ? " on" : "") + (ring ? " ring" : "")}
    style={{ width: size, height: size, background: COLORS[p.color % 8], fontSize: size * 0.42 }}
    title={p.name}
  >
    {p.name[0]?.toUpperCase()}
  </span>
);

// Seconds since an ISO time, ticking every second.
export function useElapsed(iso) {
  const [now, setNow] = useState(Date.now());
  useEffect(() => { const t = setInterval(() => setNow(Date.now()), 1000); return () => clearInterval(t) }, []);
  return iso ? Math.max(0, Math.floor((now - new Date(iso).getTime()) / 1000)) : 0;
}
export const clock = (s) => `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;

export const SUGGESTIONS = [
  "What's a smell that instantly takes you back to being a kid?",
  "What's the worst thing in your fridge right now?",
  "Describe your last dream in 5 words",
  "What's a hill you'll die on?",
  "What did you have for breakfast, honestly?",
  "What's the most useless thing you own?",
];

export const inviteLink = (code) => `${location.origin}${location.pathname}?room=${code}`;

export function haptic() { try { navigator.vibrate?.(30) } catch { /* not supported */ } }
