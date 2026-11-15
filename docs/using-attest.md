# Using Attest

Everyday use: recording, speakers and voices, areas, the interface, Today, memory, Ask and export.

[Back to the README](../README.md)

---

## Using Attest

### Recording, uploading, importing

- **Record** in the browser. While you talk, 5-second chunks are transcribed with `gpt-transcribe` for a **live preview**. The preview is only a preview; the final transcript comes from transcribing the whole file. The real audio is also stored in 5-second parts as it is recorded, so if the tab dies the recording shows **Recover audio**, which rebuilds the file. Recording stops itself at 22 MB. The recorder encodes at 32 kbps, about 14 MB an hour.
- **Upload** an audio file. The cap is 24 MB on OpenAI (just under its 25 MB transcription limit) and **48 MB on OpenRouter**, where larger audio is streamed to the model as base64 JSON straight from R2, never loaded into Worker memory. Longer recordings need splitting; Attest does not chunk.
- **Import from Pocket** pulls new recordings from a Pocket device or app (needs a Pocket API key, which you add in **Settings**). The cron does this for you in the background; see [Background sync, Pocket and Omi](cloudflare-reference.md#background-sync-pocket-and-omi).
- **Import from Omi** pulls your Omi conversations (also what a Limitless pendant paired with the Omi app produces) as transcripts, with no audio, and Attest summarizes them. See [Choosing your devices](cloudflare-reference.md#choosing-your-devices).
- **Bluetooth pendant**: the Attest app for Mac or iPhone copies audio straight off a Limitless pendant and uploads it as a normal recording. See [apple/README.md](../apple/README.md).

Processing happens in your browser tab: transcribe, match voices, then summarize. Leave the tab open until it finishes. If anything fails, press **Retry** (on the recording, or on its card in the list): a failed summary resumes from the saved transcript instead of paying for transcription twice.

### Speakers and voices

Attest names speakers in three layers, and none of them is allowed to guess.

1. **Diarization.** The transcriber labels who spoke when: OpenAI's `gpt-4o-transcribe-diarize`, or on OpenRouter models marked **LABELS SPEAKERS** (see [Providers and keys](providers-and-costs.md#providers-and-keys)). Turns are merged into readable text.
2. **Evidence-only names.** An LLM pass (`src/speakers.js`) reads the transcript plus your `people` list. A name is accepted only when a verbatim quote supports it, the quote contains the name, and it sits in or next to that speaker's own turn. The same name on two speakers is dropped. Anything unproven stays `Unknown 1..N`. The summarizer is also told never to name an Unknown speaker.
3. **Voice recognition.** Click **Enroll voice** on a speaker *you* confirmed, and Attest saves a short clip of them. In later recordings, enrolled people are matched by voice. Once someone has a saved voice the button becomes **Add voice sample** (more samples from other recordings make matching sturdier) next to a "voice saved" badge, and **Clear voices** appears only when there is something to clear.

Every chip above a transcript is clickable, and opens a dropdown: choose someone Attest already knows (people already on another speaker in this recording are flagged), or type a new name and press Enter to add them. `Sam ✓` was confirmed by you. `Sam ?` is a suggestion (inferred or voice-matched), with the evidence or score on hover. Only your click confirms, and only confirmed speakers can be enrolled.

**Fixing a wrong turn.** Click the speaker's name (the small ▾) on any transcript turn to move that turn to another speaker, or to **+ New speaker**, or to move **all** of that speaker's turns to someone else (which merges a person who was split in two). Confirmed names are never touched, a speaker left with no turns disappears, and a ready recording offers **Re-summarize with names**. This works however the speakers were found. To start over, **Clear speaker names** sets every speaker on that recording back to `Unknown 1..N`, confirmed names included, and keeps who-spoke-when as it was.

**Naming the same person two ways.** If you call someone "Jeff" in one recording and "Jeff Eberhard" in another, Attest treats them as two people. On Today, the **People** panel lists everyone with how many recordings and voice samples they have, and flags likely duplicates (one name's words all appear in another's, whole words only, so "Al" is never matched with "Alex"). Press **Merge** and the old name becomes the new one everywhere: every recording's speakers and transcript (and the search index), their saved voice samples, and their remembered facts. The old name is kept as an alias. A merge cannot be undone, so Attest asks first.

<details>
<summary><b>How voice recognition works (works on any provider)</b></summary>

OpenRouter and Cloudflare offer no speaker-embedding model, and a Worker cannot host one, so the model runs **in your browser**: ReDimNet2-B6 (MIT license, Hugging Face `soniqo/ReDimNet2-B6-ONNX-FP32`, pinned commit, sha256-checked) on `onnxruntime-web`. It downloads once (49 MB) into the browser's Cache Storage. **Your audio never leaves the browser**; only 192 numbers per speaker are sent to your Worker.

- Enrolling also stores an embedding for the clip. Older clips are embedded on first use.
- A recording processed in an open tab is transcribed, **matched, then summarized**, so names reach the summary and action items. Pocket and cron imports are summarized straight away and matched when you first open them; if that changes a name, a **Re-summarize with names** button appears (never automatic).
- A label matches an enrolled person when cosine similarity is at least 0.50 and beats the next person by 0.10, one person per label, with at least 4 seconds of that speaker. A name from the transcript that the voice contradicts is dropped (anonymous beats wrong).
- **Measured on real recordings:** the same person scored 0.59 to 0.81 against an enrolled clip from a different recording, and a different person at most 0.28. A short clip (under about 3 seconds of speech) scores much lower, which is why a speaker needs at least 4 seconds. Enrolling from a second recording makes matching more tolerant of a different mic or room.
- Every score is stored in `recordings.voice_match`, so the thresholds (`VOICE_MATCH` in `src/config.js`) can be tuned on real data. Matching runs in a background Web Worker, so the page stays responsive, and it is budgeted: the up to 8 speakers who talk the most, at most 24 six-second windows in total (about 35 seconds). It runs by itself on recordings up to 15 minutes; a longer one gets a **Recognise voices** button (with Cancel) instead, up to 90 minutes, because decoding a long file needs memory. A run that fails or is cancelled is remembered and not retried on every open. Turn it off in [Settings](providers-and-costs.md#settings).
- On OpenAI's diarize model, enrolled clips are also sent as `known_speaker_references` (up to 4 people), so OpenAI can match them itself. If OpenAI rejects them, the transcription retries without.

</details>

### Transcription hallucination guard

Speech models invent text over silence and room noise: "Thank you." repeated dozens of times, or words in a script nobody spoke (Russian on an English call). Recordings started and stopped by hand, such as from a Pocket pendant, always have that dead air. Attest removes runs of a repeated phrase and text in an unexpected script before the transcript is saved, and keeps the real speech. It is on by default. Turn it off with `HALLUCINATION_GUARD=off` (or in **Settings**), and set `STT_LANGUAGE` (for example `en`) so text in other scripts is recognised as noise. (Separately, speaker detection ignores phantom text; see [Speakers and voices](#speakers-and-voices).)

### The interface

- **Command palette.** Press **Cmd/Ctrl+K** (or click the search button in the header) from anywhere: type a question and press Enter to ask Attest, or jump to Today, Ask & chats, Settings, any recording, or one of the ten prompts. The **Deep reasoning** chip changes how the question is asked; hover it for what it means.
- **On a phone** (under 768 px wide, or inside the Attest app) the sidebar becomes a small bottom bar: **Home** (Today), **Ask**, a raised **Record** button, **Library** (the recordings list), and **Settings**. The header shrinks to the logo, a search button and your avatar, and the [area filter](#areas-work-personal-health-learning) gets its own row under it. **Record** opens its own screen: one big button, a large timer, the live transcript, and Upload and Import underneath. When a recording or upload finishes it opens full screen, with a short "Saved" note. The screen is kept awake while you record, where the browser allows it. People rows wrap so names and the Rename and Merge controls fit.
- **In the iPhone app** you can also pull down on Home to refresh it, and you get small haptic taps (checking off a to-do, starting and stopping a recording, switching tabs). If the server cannot be reached, the app says so and offers **Try again** or **Change server**, instead of showing a blank screen. Text follows the iPhone's text size (Settings > Display & Brightness > Text Size).
- **Asking before anything is lost.** Deleting a recording or chat, joining, splitting, undoing, clearing speaker names, merging people and forgetting a voice or fact each ask first, with a sheet that names the action (red when it destroys something). On a phone it is a bottom sheet; on desktop a centred dialog.
- **Speaking as.** The chip at the top right is you. Pick yourself from the people Attest knows, or type a name.
- **Area filter.** The dropdown beside it (on a phone, the row under the header) limits everything to one [area](#areas-work-personal-health-learning), or shows **All areas**.
- **Sidebar.** Recordings are grouped Today, Yesterday, Last 7 days and Earlier, each with its duration, who spoke, and a Ready / Processing / Failed status. A failed recording shows why and has its own **Retry** button. **Right-click** a recording (or **long-press** it on a touch screen) for Open, Retry, Move to area, Export and Delete; on a touch screen, **swipe left** to delete. **Record** pulses (and follows your mic level) while recording. The transcription and summary models sit in a collapsible "Recording options" row, shown as friendly names ("GPT-OSS 20B", "MAI Transcribe 2") with the exact model id in the tooltip.
- **Audio player.** Play and pause, back and forward 15 seconds, 1x / 1.25x / 1.5x / 2x speed, and a seek bar that shows what has loaded and previews the time as you hover. The server answers HTTP range requests, so jumping anywhere does not download the whole file first.
- **Transcript.** A conversation: avatar, name and a timestamp chip on the left, what they said on the right. Click a timestamp to play from there; the line being spoken highlights as audio plays (turn **Follow audio** off to stop it scrolling). Search highlights matches live, and **Only matches** hides the rest. Recordings without speaker timing show plain text.
- **Notes.** Briefs and summaries with headings split into collapsible, icon-tagged sections (commitments, dependencies, decisions and so on). Action items show an owner tag and a due-date tag (red once overdue), and a finished item stays readable. See [What counts as an action item](#what-counts-as-an-action-item).
- **Talk balance.** One split bar for the whole conversation, then each speaker's share, turns, questions, longest turn and cut-ins.

### Areas: work, personal, health, learning

Every recording belongs to one of four areas, so your work life and your home life do not blur together.

- **Attest picks one for you.** It starts from the kind of summary (a Meeting is Work, a Journal entry is Personal, a Medical visit is Health, a Lecture is Learning), then reads what was actually said and corrects itself. A doctor's appointment recorded as a plain "Meeting" ends up in Health. Recordings that arrive from Pocket, Omi or the pendant are sorted the same way once they are processed.
- **Change it any time.** Use the area dropdown on the recording's page. Once you choose, Attest never changes it again, even if you re-summarize. Pick **Auto-pick again** to hand the choice back.
- **Look at one area at a time.** The **All areas / Work / Personal / Health / Learning** dropdown at the top (next to Speaking as) limits everything you see: the recording list, search, Today and its brief, Ask, memory, people counts and exports. While a filter is on, anything you record is filed in that area. The choice is remembered in your browser.
- **Older recordings** from before areas existed all start in Work. Change the ones that belong elsewhere from their page.

<details><summary>For tinkerers</summary>

`GET /api/recordings`, `/api/today`, `/api/memory`, `/api/people` and `/api/export` take `?area=work|personal|health|learning`; `POST /api/ask`, `/api/chats/:id/messages`, `/api/today/brief` and `/api/insight` take `area` in the body. A missing or unknown value means all areas. Uploads and `POST /api/recordings/live` accept an `area` field. They also take the speaker's timezone as minutes east of UTC (`tz_offset`: a form field on uploads, a body field on live start, or an `x-tz-offset` header on any call), used to resolve "tomorrow" and "by Friday" in action items. The web app and the iOS and Android apps send it for you. `PATCH /api/recordings/:id/area {"area": "health"}` sets one (`"auto"` hands it back). `POST /api/recordings/areas/backfill` re-derives every automatic area of older recordings from their summary style once, leaving your own choices alone.
</details>

### Conversation shaping: one recording, one conversation

Recorders cut calls wherever they like. Pocket and the pendant chop one long call into several recordings; Omi sometimes glues unrelated conversations into one. Attest fixes this by listening to where people actually talk, not where the app drew its lines:

- **Dead air is trimmed.** If nothing is said for more than 30 seconds at the start or end of a recording, that stretch is cut off (a few seconds are kept so nothing is clipped).
- **Different conversations are split.** A silence of 5 minutes or more between two stretches of talking means two different conversations. Each becomes its own recording with its own audio, summary, speakers and area, titled like "Lunch chat (2/3)". A few stray words on their own are folded into the nearest conversation instead of becoming a recording, and a very long unbroken one (over 100 minutes) is cut at its longest pause.
- **Pieces of one call are joined.** Recordings from the same device or Pocket that are only a few minutes apart are put back together **before** they are transcribed, so the whole call is transcribed once and the speakers stay consistent. This happens automatically when they arrive.

The sound is cut and joined **without re-encoding**, so there is no loss in quality. This works for the common formats (MP3, WAV and the browser's and pendant's recordings). For other formats, or very large files, Attest still splits the *text* into separate conversations, but the pieces will not have their own audio (the sound stays on the original, and Undo brings it back).

**Nothing is ever lost.** The original is kept out of sight, not deleted. A recording made this way says so at the top, with an **Undo** button that removes the new pieces and brings the original back. A joined call unwinds all the way back to its original pieces, and they will not be joined again. If you delete every piece of a split, the hidden original is deleted too, so nothing lingers where you cannot see it.

**Do it by hand.** For a recording that was summarized before this existed, open it and press **Split by silence**. If two recordings were really one call, open the later one and press **Join with previous**. That one transcribes the joined audio again, because the speaker names from two separate transcripts do not line up.

**Limits.** It needs word-by-word timing from the transcriber, so a recording transcribed as plain text with no timing is left alone.

<details><summary>For tinkerers</summary>

Optional settings (Worker variables): `SPLIT_GAP_MIN` (default 5 minutes), `TRIM_MIN_SEC` (default 30 seconds), `MERGE_GAP_MIN` (default 3 minutes); `RESHAPE=off` turns all of it off. API: `POST /api/recordings/:id/reshape`, `POST /api/recordings/:id/undo-reshape`, `POST /api/recordings/merge {"ids": [...]}`. `POST /api/recordings/:id/process` answers with the first new recording and a `split_into` list when it split one. Audio is handled by pure-JavaScript container code (`src/audio/`), since a Worker cannot run ffmpeg; files over 48 MB are never cut.
</details>

### Summaries and mind maps

- **88 built-in presets**, grouped by category (work, sales, research, people, health, personal, media, education), plus per-owner **custom templates** you write yourself from the UI.
- **Three mind maps** from the same summarize call, shown as tabs: **Topic** (subject matter), **Driver** (decisions and actions), **People** (who said what). Rendered in your browser with `markmap` on a dark canvas with zoom, fit-to-view and **SVG / PNG** download (PNG depends on your browser allowing it; SVG always works). Outline text is escaped before it is drawn.
- Every recording also gets **unanswered questions** (asked but never clearly answered) and a **talk balance** table: each speaker's share of talk time, turns, questions, longest turn and cut-ins, measured from the stored turns.
- Action items have **checkboxes that are saved**, and a re-summarize keeps your ticks.
- **Dismiss a to-do that is not real.** On Home, swipe a to-do left (touch) or open its **⋯** menu and choose Dismiss (desktop). It leaves the reminders, the badge, the briefs and the recording's action list, a toast offers **Undo**, and a re-summarize keeps it dismissed. It is flagged `dismissed` in the stored item, not deleted: `PATCH /api/recordings/:id/actions {task, i, dismissed: true|false}`.

### What counts as an action item

Summaries list only **pending commitments and explicit reminders**, never a recap of what was discussed, a hypothetical ("we could maybe look at..."), or something already done. Each item is:

- **A task that starts with a verb**: "Send the deck to Ben", not "Deck".
- **Owned.** The speaker who promised it, or the person who was asked and agreed. Someone who is not named is left blank (the item is kept, not dropped). With **Speaking as** set, your items are yours and everyone else's go under **Waiting on others**.
- **Dated only when a date was said.** "By Tuesday", "tomorrow" and "next week" are turned into real dates using the day the recording was made, on the clock where you were (the web and phone apps send your timezone; imports with no timezone count as UTC). If no date was said the item has none, and Attest never guesses one. The words you actually said ("before the client call") still show on the item.
- **Soft or firm.** "I'll try", "maybe I'll", "if there's time" are marked **tentative**. They are not hidden: they sit, dimmed, under **Maybe / soft commitments** after your firm to-dos, and they never nag as *slipping*.
- **Backed by a quote.** Hover an item on Today to see the words from the transcript it came from.

Recordings made before this change keep their old items; **Re-summarize** one to get the new fields.

### The Today screen

Today is the home screen, and it is built around one question: **what do I need to do today?**

- **Your brief comes first.** It fills the main part of the screen, ready when you open Attest. It is written like a chief of staff would hand it to you: the **three things to do first** and why they are urgent now, what is **due or overdue**, what **other people owe you** (with a one-line nudge you could send), **decisions that are stuck**, **people to follow up with**, and **what changed since yesterday**. It leans on the last two days, leaves out any section with nothing real in it, and says where each point came from.
- **Numbers at a glance.** Above the brief, small chips show how many things are overdue, due today, due this week, slipping, or waiting on others.
- **Needs you.** Beside the brief (right under it on a phone) your open to-dos are sorted by *when* they matter: **Overdue**, **Due today**, **This week**, **Slipping** (open a week or more with no date), **Open**, **Later**, **Maybe / soft commitments**, and **Waiting on others**. If you have set **Speaking as**, other people's to-dos move to "Waiting on others" instead of cluttering yours, and **Mine / Everyone** switches the view. Tick a to-do when it is done.
- **The brief and the list agree.** The brief is written from the same sorted list you see on screen, so it never calls something overdue that the list does not, or the other way round.
- **Weekly review.** Themes, decisions, open questions and one thing to focus on, once a week. On a phone it stays folded except on Friday.
- **Hide what you have handled.** Each bullet in the brief has a **✓**. Click it and the item disappears, along with reworded repeats, and the next brief is told not to bring it up again. After 7 days it can come back if it is still true. **Show all** brings everything back at once.
- **Check things off.** Ticking a to-do shows **Marked done · Undo** for a few seconds.
- **Turn it off.** Open **What runs on its own** at the bottom of Today and untick *Write briefs automatically* if you would rather write them yourself with **Refresh**. Each brief is one small request to your AI provider, and it is only rewritten after a newer recording arrives.

**Prefilled prompts** (click a chip, edit the text, press Run). Pick a person and a time window (1 to 60 days) first where it applies:

| Run your day | Run your business | Work with others |
|---|---|---|
| What did I promise? | Decisions log | Communication advice for [person] |
| Prep me for [person] | Recurring problems (wide sweep) | Follow-up draft to [person] (text only; nothing is sent) |
| End-of-day wrap | Customer or client pulse | Coach me |
| | What changed? | |

Each Run is one request over a window of your recordings plus what Attest remembers from them. Choose **Speaking as** (the button at the top right) so "I", "me" and "my" in prompts and briefs mean you. It also lets Today separate your to-dos from other people's, and marks you in talk balance; it is remembered only in your browser. Advice about people is the model's opinion from the transcripts, with quotes, and it says when evidence is thin.

### Memory and semantic search

Two layers make Ask and Today smarter and cheaper as your history grows.

**Structured facts.** Every summarize call also returns durable facts, each one a `commitment` (someone promised something), `decision`, `preference` (how a person works or communicates), `relationship`, or `fact` (a date, number or plan), with the person it concerns and a **verbatim quote**. A fact whose quote is not found in the transcript is thrown away, the same evidence rule speaker naming uses, so the model cannot invent memories. Facts are replaced when a recording is re-summarized (a ticked promise stays ticked) and deleted with the recording. Today, then Memory, lists them, filterable by kind and person. Tick a promise when done, or **forget** a wrong fact (the recording itself is unchanged).

**Semantic index.** Each recording's summary, facts and overlapping transcript passages (about 900 characters each, up to 120 per recording, so roughly the first 1.5 hours of a very long one) are embedded with Workers AI and stored in Vectorize, namespaced by a hash of the owner so one person's questions never search another's data. Ask then retrieves by meaning, topped up with keyword hits, and sends only the matching passages to the model. If Vectorize errors, the question is answered with keyword search instead. Set it up with [Semantic search setup](cloudflare-reference.md#semantic-search-setup).

**Unnamed speakers fade out of the list.** When Attest could not tell who said something (the speaker is just "Unknown"), that item shows on the Memory list for **7 days** after the recording, long enough for you to tag the speaker and have it named properly. After that, if it is still unnamed, it quietly leaves the Memory list and the daily brief. It is **not deleted**: it stays searchable, so Ask can still find it, it just is not pushed in front of you. Anything about a named person always stays on the list.

**Staying current.** New recordings are memorized as soon as they finish summarizing. Older recordings catch up on their own, two per 15 minutes, or press **Build memory from N past recordings** to do it now.

### Ask Attest

There are three ways in, and they all search every recording: the **Ask bar at the top of Today**, the **Ask & chats** button at the top of the sidebar (one question box, plus your past chat threads), and the **Ask Attest** box at the bottom of any recording. Each answer is one grounded completion that cites the recordings it used. Every question starts or continues a chat thread, so you can follow up.

**What "Deep" means.** Tick **Deep** (hover the `?` for the same explanation) and the question is split into up to 4 sub-questions, each is searched separately, the results are merged (up to 12 recordings), and one answer also says what your recordings could not answer. It uses 2 model calls instead of 1 and is slower, so save it for broad questions like "what has changed since March?" and leave it off for quick lookups.

Everywhere in the app, the **ATTEST** title and the **Today** button take you back to Today, and recording and chat pages have a "← Today" or "← Ask & chats" link at the top.

### Export

`.md` (one recording, or everything), `.docx` (one recording, using a hand-written writer with no dependencies), a `.zip` of every recording as `.docx`, and **Print / PDF** through your browser's own print dialog. One endpoint: `/api/export?id=<id>&format=<md|html|docx|zip>`; leave out `id` to export every ready recording.

---
