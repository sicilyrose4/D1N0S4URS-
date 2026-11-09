// Who's the Bot? -- writes the hidden AI player's answer for a round.
// Called by the asker's app right after a question is posted.
import Anthropic from "npm:@anthropic-ai/sdk";
import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const FALLBACKS = ["honestly no clue lol", "probably pizza", "my moms car", "idk depends on the day", "the smell of rain on hot pavement"];

const SYSTEM = `You are secretly playing a party game called "Who's the Bot?" with a group of college students on their phones.
Someone asks a question, everyone answers anonymously, and the group votes on which answer came from the AI. Your goal is to not get caught.

Write ONE answer the way a real college student types into a group game on their phone:
- Short. Usually 2 to 12 words. Never more than 2 short sentences.
- Casual. Mostly lowercase, light punctuation, no em dashes, no semicolons, no polished or poetic phrasing.
- Specific and a little personal or funny, like a real memory or opinion. Not generic, not wholesome-sounding.
- If other players' answers are shown, match their length and vibe. Do not copy them or repeat their idea.
- Never mention being an AI, never refuse, never explain. Output only the answer text.`;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const { round_id } = await req.json();
    if (typeof round_id !== "string") return json({ error: "round_id required" }, 400);

    const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const round = await db.from("wtb_rounds").select("id, question, phase").eq("id", round_id).single();
    if (round.error || round.data.phase !== "answer") return json({ skipped: "round not open" });

    // Wait up to ~12s for a couple of human answers so the bot can match the room's style.
    let humans: string[] = [];
    for (let i = 0; i < 6; i++) {
      const res = await db.from("wtb_answers").select("body, is_bot").eq("round_id", round_id);
      if (res.data?.some((a) => a.is_bot)) return json({ skipped: "bot already answered" });
      humans = (res.data ?? []).map((a) => a.body);
      if (humans.length >= 2) break;
      await new Promise((r) => setTimeout(r, 2000));
    }

    const answer = await writeAnswer(round.data.question, humans);
    const done = await db.rpc("wtb_bot_answer", { p_round: round_id, p_body: answer });
    if (done.error) throw done.error;
    return json({ ok: true });
  } catch (e) {
    console.error(e);
    return json({ error: String(e) }, 500);
  }
});

async function writeAnswer(question: string, humans: string[]): Promise<string> {
  try {
    const client = new Anthropic(); // reads ANTHROPIC_API_KEY from the function's secrets
    const others = humans.length
      ? `\n\nOther players' answers so far (match their style, don't copy):\n${humans.map((h) => `- ${h}`).join("\n")}`
      : "";
    const response = await client.beta.messages.create({
      model: "claude-opus-5-5",
      max_tokens: 2000,
      output_config: { effort: "low" },
      betas: ["server-side-fallback-2026-07-01"],
      fallbacks: "default",
      system: SYSTEM,
      messages: [{ role: "user", content: `Question: ${question}${others}` }],
    } as any);
    if (response.stop_reason === "refusal") return pick();
    const text = response.content
      .filter((b: any) => b.type === "text")
      .map((b: any) => b.text)
      .join(" ");
    return clean(text) || pick();
  } catch (e) {
    console.error("claude call failed", e);
    return pick();
  }
}

function clean(s: string) {
  return s.split("\n").map((l) => l.trim()).filter(Boolean)[0]?.replace(/^["'“]|["'”]$/g, "").replace(/—/g, ", ").slice(0, 160) ?? "";
}
const pick = () => FALLBACKS[Math.floor(Math.random() * FALLBACKS.length)];
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });
