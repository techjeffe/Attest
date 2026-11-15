# Troubleshooting and known limits

Fixes for common problems, and an honest list of what Attest does not do.

[Back to the README](../README.md)

---

## Troubleshooting

| What you see | Cause and fix |
|---|---|
| `401 unauthorized` JSON from the app | The request reached the Worker without passing Access: the Access application is missing or its hostname does not match exactly. Re-run `npm run setup` or redo [5b](cloudflare-reference.md#5b-manual-access-setup). |
| Wizard: "Zero Trust is not set up yet" | Do [step 2](cloudflare-reference.md#2-set-up-zero-trust), or the token is missing the "Access: Organizations, Identity Providers, and Groups" permission. |
| Wizard: Access request fails with 403 | The token lacks "Access: Apps and Policies" Edit, or is scoped to a different account. |
| Login page says no access / no code arrives | Your email is not in the Allow policy (Cloudflare still says a code was sent, by design), or your mail provider blocks `notify.cloudflare.com`; allowlist it. |
| "This One-Time PIN has already been used" | A mail security scanner opened the link first. Request a new code. |
| `*.workers.dev` URL gives 404 | Expected; `workers_dev` is off on purpose. |
| Deploy fails on the custom domain | The hostname already has a DNS record, or the zone is not active in this account. |
| Deploy fails with error 10042 | R2 is not enabled. Do [step 1](cloudflare-reference.md#1-enable-r2). |
| Cron-imported recordings missing | `OWNER_EMAIL` does not match your login email. `npx wrangler secret put OWNER_EMAIL`. |
| Transcription errors | The API key is missing or wrong. Open the gear icon (top right) and re-enter it, or `npx wrangler secret put OPENAI_API_KEY`. |
| Memory says "semantic search off" | The Vectorize index could not be created at deploy, or you used `ATTEST_NO_VECTORS=1`. See [Semantic search setup](cloudflare-reference.md#semantic-search-setup). Facts still work. |
| Voices are never matched | Nobody is enrolled yet, "Recognise enrolled voices" is off in [Settings](providers-and-costs.md#settings), or the speaker said under 4 seconds. Check the browser console for "voice matching skipped". |
| A mind map panel is blank | Your browser blocked the `markmap` script from jsDelivr (ad blocker or strict CSP). Check the Network tab. |


## Known limits, honestly

- **OpenRouter speaker labels and the large-file path are untested live.** The request and response shapes follow OpenRouter's documentation and the code is tested against them, but neither has been run against a live OpenRouter call. If a model returns no speaker data, Attest falls back to plain text.
- **`gpt-4o-transcribe-diarize` is deprecated**, cut off 2027-02-26 (`TRANSCRIBER_DEPRECATIONS` in `src/config.js`), and OpenAI has no diarizing successor: its replacement `gpt-transcribe` returns text only. The UI shows a warning banner as the cutoff approaches. After that date Attest falls back to `gpt-transcribe`: transcripts, summaries, search and export keep working, but OpenAI speaker labels stop. OpenRouter diarizing models, and in-browser voice recognition on top of them, are the path forward.
- **Matching and search thresholds are untuned.** Voice matching (0.50 cosine, 0.10 margin, 4 seconds) and semantic search (ignore scores below 0.45) are starting values, and every score is stored so they can be tuned on your real data.
- **Facts are only as good as the summarizing model.** The verbatim-quote check stops inventions but not a real quote being misread. Advice about people is opinion.
- **Today uses your browser's clock.** "Overdue" only understands ISO due dates (`2026-11-05`); a due date written as "Friday" can only count as slipping (open 7+ days).
- **Local mode has not run against a real oMLX yet.** It is tested against a mock server and on real speech, and has `npm run local:check` to find problems on your machine. Speaker detection by voice is a heuristic (good on clear turn-taking, weaker on overlap and similar voices), and local mode has no background sync. See [Run it locally on a Mac](run-locally.md#run-it-locally-on-a-mac-omlx).
- **Processing happens in your browser tab.** There is no background queue for recordings you make, so the tab has to stay open while your provider transcribes and summarizes. (Pocket recordings are processed by the cron.)
- **A recording with confirmed speaker names cannot be re-processed**, because re-diarizing can reshuffle the A/B labels and re-attach names to the wrong voices. Re-summarizing is always allowed.
- **Long recordings.** No chunking: split files over the upload cap (96 MB when running locally). Semantic indexing covers roughly the first 1.5 hours, and voice matching is automatic only up to 15 minutes (a button handles up to 90).
- **PDF export is your browser's print dialog**, not a server-side renderer. There is no `pdf-lib` or similar by design.

Deliberately not in this repo: background queues, and any form of plans, entitlements or usage billing.

---
