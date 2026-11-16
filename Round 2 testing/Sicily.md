# Test notes for 11-16 — Sicily

## Notes from prototype test

We had one person be the coach and everyone else be the players.

- The coach flow in general was pretty straightforward.
- "Flash them" is a funny way to say the flashlight thing lol
- Why is the person who's last red? Yes, they're last, but the green/grey indicator means green = awake, and they're still awake even if they were last.
  - What if every single person wakes up within about 3 seconds of each other? The person who was last shouldn't get punished just because they were last.
- "So this is the people waking up?"
- Overall it was pretty clear what was happening.
- At first she was confused about why the alarm wasn't turning off when she turned it off.
  - We could have a bit of a change on the screen once they turn it off. Nothing changing is a bit confusing.
- "I would hate this but it would work lol"
- They could clearly see each other turning it off and going on the clock.
- She was scrolled down on the leaderboard, so she didn't immediately see the people waking up in that part. She was confused about why the clock was changing because she wasn't looking at the changes in the leaderboard.
  - Maybe auto-scroll when someone wakes up, if the person isn't scrolled to the top.
- Realistically they aren't interacting with a whole lot. The main thing is making sure the key image is clear, because it shouldn't be interaction-heavy right when they wake up.

## Multiplayer issue

The live prototype with multiple people did not work on the Apple developer version, so testers couldn't see each other. They could see themselves and the mock teammates, so they understood what was happening and weren't confused about what the clock and the avatars turning green meant.

- There aren't interactions that show where people are on the screen. It's just awake/not awake indicators and who is in the group, and that was clear to everyone.

<br>

---

## Takeaways

- **People understood what was going on.** The coach flow was easy to follow. Testers could see each other turn off their alarms and get added to the clock, and they knew what the avatars turning green meant.
- **Red for last place sends the wrong message.** Green means awake, but the last person to wake up is shown in red even though they're awake too. If everyone wakes up within about 3 seconds of each other, the last person shouldn't look like they failed.
- **Turning off the alarm needs to show a result.** One tester was confused because nothing changed on her screen after she turned the alarm off, so she thought it hadn't worked.
- **Teammates waking up is easy to miss if you're scrolled down.** One tester was partway down the leaderboard, didn't see people waking up, and couldn't tell why the clock was changing.
- **People expect to tap very little right after waking up.** The main screen needs to be clear at a glance, not something they have to interact with.
- **The concept works, even if people don't love being woken up.** One tester said: "I would hate this but it would work lol." People also found the "Flash them" wording funny.
- **We couldn't test live multiplayer.** It didn't work in the Apple developer build, so testers only saw themselves and the mock teammates. They still understood the screen, since it only shows who's in the group and who's awake.

### What to change next
1. Stop showing the last person in red. Keep the color to awake/not awake, and show placement another way, or only call out real latecomers.
2. Show a clear confirmation when someone turns their alarm off, for example "You're up — waiting on 3 teammates."
3. Scroll the leaderboard to the top automatically when someone wakes up, if the person isn't already there.
4. Get live multiplayer working outside the Apple developer build so the next test shows real teammates.
