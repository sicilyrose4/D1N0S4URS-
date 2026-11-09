# Who's the Bot?

A live party game for 3 to 12 people on their phones. One person asks a question, everyone answers anonymously, and an AI secretly answers too. Then the room votes on which answer came from the bot.

**Play:** https://whos-the-bot.vercel.app (share a room with `?room=CODE`)

## How it works

- **`web/`**: the phone web app (Vite + React). It has two visual styles you can switch between at the top of the screen: **Assistant** (ChatGPT-like) and **Stack** (one big card at a time).
- **Supabase**: stores rooms, players, rounds, answers and votes. Every phone gets a realtime ping when something changes, and presence shows who is online and typing.
- **`supabase/functions/bot-answer/`**: when a question is asked, this function waits for a couple of human answers, then asks Claude to write an answer in the same casual style and slips it in.
- **`supabase/migrations/`**: the database tables and game rules.

## Safety guardrails

- Tables are locked. Phones can only call the game functions, which check turn order, phase, and lengths (names up to 20 characters, questions up to 200, answers up to 160).
- Who wrote what, and which answer is the bot, stays hidden on the server until the reveal.
- Rooms cap at 12 players. The asker can skip ahead if someone goes quiet.

## Run locally

```bash
cd app/web
npm install
npm run dev
```
