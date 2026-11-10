# Who's the Bot?

A live party game for 3 to 12 people on their phones. One person asks a question, everyone answers anonymously, and an AI secretly answers too. Then the room votes on which answer came from the bot.

**Play:** https://whos-the-bot.vercel.app (share a room with `?room=CODE`)

## How it works

- **`web/`**: the phone web app (Vite + React). It uses one ChatGPT-like visual style. A robot mascot (looping GIFs in `web/public/robot`) reacts to each moment: its antenna turns green when you catch the bot and red when the bot fools you.
- **Game flow**: whoever makes the room is the host. Everyone waits in a lobby until the host taps Go. Each question has a 30 second countdown (with tense music on the host's device), everyone can see who is typing and who has answered, and the host can skip ahead at any time. Answers get shuffled before voting so nobody can tell the order they came in.
- **Supabase**: stores rooms, players, rounds, answers and votes. Every phone gets a realtime ping when something changes, and presence shows who is online and typing.
- **`supabase/functions/bot-answer/`**: when a question is asked, this function waits for a couple of human answers, then asks Claude to write an answer in the same casual style and slips it in.
- **`supabase/migrations/`**: the database tables and game rules.

## Safety guardrails

- Tables are locked. Phones can only call the game functions, which check turn order, phase, and lengths (names up to 20 characters, questions up to 200, answers up to 160).
- Who wrote what, and which answer is the bot, stays hidden on the server until the reveal.
- Rooms cap at 12 players. The countdown is enforced on the server, so a round can't get stuck, and only the host can skip ahead.

## Run locally

```bash
cd app/web
npm install
npm run dev
```
