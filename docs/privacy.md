# Privacy and security

What stays where, and how Attest is locked down.

[Back to the README](../README.md)

---

## Privacy and security

**Single-user by design.** There are no accounts, logins, or signup flow. The owner of every row is whatever is in the `cf-access-authenticated-user-email` request header (`ownerOf()` in `src/http.js`), or the literal string `local` if it is absent. If you expose the Worker to anyone but yourself, put **Cloudflare Access** in front of it (free for small teams); without it, every visitor shares the same `local` owner and sees the same recordings. Everyone you allow through Access sees the same data.

Do these two things when deploying behind Access (the wizard does both):

- Turn off the `*.workers.dev` URL (`workers_dev = false` in `wrangler.toml`), because Access only protects your custom hostname and the header is trivially spoofable on the open `workers.dev` URL.
- Set the var `REQUIRE_ACCESS = "true"` so a request without the Access header is refused with 401 instead of silently becoming the shared `local` owner.

State-changing requests the browser marks `Sec-Fetch-Site: cross-site` are refused, so another website cannot drive your session.

**Device sign-in.** The one exception to "the owner is whatever Access puts in the email header" is a verified Access *service token* (the Bluetooth pendant app). It acts as `OWNER_EMAIL`, is checked against Cloudflare's signing keys, and is limited to uploading a recording and reading `/api/meta`; every other route refuses it with 403.

**Where your data goes:**

| Data | Goes to | Notes |
|---|---|---|
| Audio, transcripts, summaries, facts, people | Your D1 database and R2 bucket | In your Cloudflare account. Owner-scoped on every query. |
| Audio | Your transcription provider | OpenAI or OpenRouter, via the key you gave. |
| Transcript text | Your chat provider | For summaries, speaker naming, Ask, Today and the facts. |
| Passage text for semantic search | Workers AI and Vectorize | Inside your Cloudflare account. |
| Voice matching | **Your browser only** | Audio is decoded and embedded locally. Only 192 numbers per speaker reach your Worker. |
| Your browser's page loads | jsDelivr, Hugging Face (fonts are your system's; Inter is used if installed, and nothing is fetched for icons) | Scripts for `markmap` and `onnxruntime-web`, and the voice model (pinned and sha256-checked), loaded by your browser. |

Nothing else leaves your Worker, and no telemetry is collected.
