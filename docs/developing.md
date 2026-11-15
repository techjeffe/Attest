# Developing Attest

Architecture, tests and contributing notes.

[Back to the README](../README.md)

---

## For developers

### Architecture

```
src/config.js       model + transcriber catalogs (OpenAI and OpenRouter menus), upload cap,
                    deprecation dates, voice and match thresholds
src/llm.js          chat-completion and speech-to-text endpoints (base URL + key)
src/stt.js          OpenRouter diarization: per-word speaker ids -> speaker turns
src/settings.js     in-app settings: D1 overlay on env, GET/PUT /api/settings
src/templates.js    88 builtin summary presets (pure data)
src/text.js         pure text helpers: diarization merge, FTS query, export bodies
src/prompts.js      the one summarize-call prompt (summary, items, mind maps, facts, ...)
src/insights.js     Today helpers: open/overdue items, talk balance, prompt context (pure)
src/memory.js       fact validation (verbatim-quote rule), extraction prompt, chunking (pure)
src/vectors.js      Workers AI embeddings + Vectorize index and search; no-op without bindings
src/speakers.js     speaker naming: evidence-only inference, name application
src/local.js        local mode: embeddings from a local server + a vector index in D1, in place of
                    Workers AI and Vectorize
src/voiceprints.js  WAV helpers, OpenAI reference selection, local-embedding matcher
src/http.js         json()/fail() helpers, uid(), ownerOf()
src/db.js           owner-scoped row reads, template resolution
src/cron.js         scheduled run: memory catch-up, Pocket import, processing
src/routes/         one module per feature: recordings, ask, chats, people, templates,
                    export, today (briefs + prompts), memory (facts + backfill), pocket
src/testing.js      test-only re-exports (kept out of the Worker entry module)
src/index.js        router + Worker entry point; no logic of its own
public/             the frontend: index.html, app.css (the design system: CSS custom properties
                    for colors, surfaces, text and spacing), and app/*.js ES modules, no build step.
                    Screens: main, today, recordings, chats. Components: player, transcript,
                    mindmap, palette (Cmd+K), persona (Speaking as). Helpers: format, icons
                    (inline Lucide-style SVG, nothing loaded for them), me, ask, lists.
scripts/deploy.mjs  the setup and deploy wizard (asks Cloudflare or local first)
scripts/local-setup.mjs, local-check.mjs, lib/omlx.mjs   local setup and the capability doctor
```

**Data.** D1 tables: `recordings` (owner-scoped, with transcript, segments, speakers, summary, action items, mind maps, unanswered, voice match, memory bookkeeping), `people`, `voiceprints` (clips plus 192-float embeddings), `facts`, `briefs`, `brief_acks` (acknowledged brief items, 7-day expiry), `custom_templates`, `chats`, `chat_messages`, `settings`, and an FTS5 table for keyword search. R2 holds raw audio (`rec/<id>`) and voiceprint clips (`vp/<personId>/<uuid>`). Optional bindings are `AI` (Workers AI) and `VECTORS` (Vectorize index `attest-memory`).

**Migrations.** Tables are versioned migrations in `src/schema.js`, applied automatically and atomically on the first request after a deploy and recorded in `schema_migrations`. To change a table, append a new `{ id, sql: [...] }` entry; never edit a shipped one.

**Where the AI provider is called**, always through `src/llm.js`: `routes/recordings.js` (transcription and the summarize call, plus the live-preview chunks), `speakers.js` (naming), `routes/ask.js` (single-pass and Deep), `routes/today.js` (briefs and prompts), and `routes/memory.js` (fact backfill). Embeddings go through Workers AI in `vectors.js`.

### Tests

`npm test` runs `node --test "test/*.test.mjs"` (345 tests, no network; the quoted glob is expanded by Node itself, so it works the same in cmd, PowerShell and sh, and needs Node 21 or newer):

- `unit.test.mjs`: pure helpers: diarization merge, FTS query, export shaping, prompts, the speaker evidence filter, the voice matcher, fact validation, chunking, open-items and talk-balance logic.
- `routes.test.mjs`: the router against a fake D1 and R2 that derives owner scoping from the bound SQL: dispatch order, owner isolation, the live and recover lifecycle, Today and brief caching, facts, the scheduled run, and the semantic path with a fake Workers AI and Vectorize.
- `schema.test.mjs`: every migration against real SQLite.
- `frontend.test.mjs`: imports every `public/app/*.js` module with a stubbed DOM, boots the app, and checks escaping and the markdown renderer.
- `haptic.test.mjs`: the haptic helper is a no-op in a plain browser and posts the right message to the native app.
- `local.test.mjs` and `local-scripts.test.mjs`: tolerant JSON, the local embedding and vector backends on real SQLite, and the setup and doctor scripts against a mock oMLX server.
- `platform.test.mjs`: the Windows/Linux differences in the setup scripts (entry-point detection, launching `npx` on Windows, ports and model recommendations per platform), checked for every platform on any OS.
- `zip.test.mjs` and `docx.test.mjs`: archive structure, verified with `unzip -t` and Python's `zipfile` when available.

Not covered: real OpenAI, OpenRouter, D1, R2, Workers AI or Vectorize calls, and the browser-only paths (MediaRecorder, `decodeAudioData`, the ONNX voice model, markmap rendering). Those are exercised by hand against a deploy.

### Contributing notes

Keep logic out of `src/index.js`, keep pure helpers pure (they are the tested surface), scope every query by `owner`, and append migrations rather than editing them. A model's output is data, never markup: everything rendered goes through `esc()` first.
