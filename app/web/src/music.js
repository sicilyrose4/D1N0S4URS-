// Original tense countdown loop, made live with Web Audio (no audio files).
// A minor bass ostinato plus a ticking clock. It speeds up and climbs in pitch as time runs out.
let ctx, out, timer, nextAt, step;
const BASS = [45, 45, 48, 45, 52, 45, 51, 48]; // A minor-ish, with a tense flat fifth
const hz = (m) => 440 * 2 ** ((m - 69) / 12);

// Phones only allow sound after a tap, so call this from a tap (Go, Send, anything).
export function unlock() {
  try {
    // iPhone: without this, browser sound is muted whenever the silent switch is on.
    if (navigator.audioSession) navigator.audioSession.type = "playback";
    ctx ??= new (window.AudioContext || window.webkitAudioContext)();
    if (!out) { out = ctx.createGain(); out.gain.value = 1; out.connect(ctx.destination) }
    if (ctx.state !== "running") ctx.resume();
    // iPhone: playing a tiny silent sound inside the tap fully unlocks audio output.
    const src = ctx.createBufferSource();
    src.buffer = ctx.createBuffer(1, 1, 22050);
    src.connect(ctx.destination);
    src.start(0);
  } catch { /* no audio on this device */ }
}

export function play(secondsLeft) {
  if (timer) return;
  unlock();
  if (!ctx) return;
  step = 0;
  nextAt = ctx.currentTime + 0.05;
  timer = setInterval(() => {
    if (nextAt < ctx.currentTime) nextAt = ctx.currentTime + 0.05; // audio was paused; don't burst to catch up
    while (nextAt < ctx.currentTime + 0.12) {
      const left = secondsLeft();
      const bpm = left <= 5 ? 184 : left <= 10 ? 160 : left <= 20 ? 140 : 124;
      const lift = left <= 10 ? 3 : 0; // key change for the last 10 seconds
      blip(nextAt, step, left, lift);
      nextAt += 60 / bpm / 2;
      step++;
    }
  }, 25);
}

export function stop() { clearInterval(timer); timer = null }

function tone(t, freq, type, vol, len, cutoff) {
  const o = ctx.createOscillator(), g = ctx.createGain(), f = ctx.createBiquadFilter();
  o.type = type; o.frequency.value = freq;
  f.type = "lowpass"; f.frequency.value = cutoff;
  g.gain.setValueAtTime(0.0001, t);
  g.gain.exponentialRampToValueAtTime(vol, t + 0.008);
  g.gain.exponentialRampToValueAtTime(0.0001, t + len);
  o.connect(f).connect(g).connect(out);
  o.start(t); o.stop(t + len + 0.02);
}

function blip(t, i, left, lift) {
  tone(t, hz(BASS[i % 8] + 12 + lift), "square", 0.16, 0.16, 1500); // bass, high enough for phone speakers
  if (i % 2 === 0) tone(t, left <= 5 ? 2200 : 1700, "triangle", left <= 5 ? 0.14 : 0.07, 0.03, 8000); // clock tick
  if (left <= 20 && i % 2 === 1) tone(t, hz(BASS[(i + 3) % 8] + 24 + lift), "sawtooth", 0.045, 0.09, 2400); // upper pulse joins at 20s
}
