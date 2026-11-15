# Providers, settings and cost

Which AI provider to use, how to switch without redeploying, and what it costs.

[Back to the README](../README.md)

---

## Providers and keys

Everything is bring-your-own: there is no Attest-run service. Set secrets with `npx wrangler secret put NAME`, or change provider and models later from [Settings](#settings).

| Feature | You need | Status |
|---|---|---|
| Everything (transcribe, summaries, mind maps, ask, speaker naming) | `OPENAI_API_KEY`, **or** one OpenRouter key (`LLM_API_KEY` / `STT_API_KEY`) | **built, required** |
| Sign-in and keeping others out | [Cloudflare Access](privacy.md#privacy-and-security) in front of the Worker, plus `REQUIRE_ACCESS="true"` | built, strongly advised |
| Live preview, voice recognition, memory, Today, export, chats, custom templates | nothing extra | built |
| Semantic search | Workers AI and Vectorize bindings (see [Semantic search setup](cloudflare-reference.md#semantic-search-setup)) | built, optional, free allowances |
| Import from Pocket | a Pocket API key (a `pk_...` key created in the Pocket app), entered in **Settings** or set as the `POCKET_API_KEY` secret | built, optional |
| Import from Omi | an Omi Developer API key (`omi_dev_...`, `conversations:read`), entered in **Settings** or set as the `OMI_API_KEY` secret | built, optional (transcripts only) |
| Bluetooth pendant app | a Cloudflare Access service token (`npm run device-token`): secrets `ACCESS_TEAM_DOMAIN`, `ACCESS_AUD`, `OWNER_EMAIL` | built, optional |
| Daily digest email | `RESEND_API_KEY`, `DIGEST_FROM` | planned (#9), placeholder only |
| Push action items to Linear, Todoist, Notion | `LINEAR_API_KEY`, `TODOIST_API_TOKEN`, `NOTION_TOKEN` | planned (#10), placeholder only |
| Google Drive / OneDrive export | `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `MS_CLIENT_ID`, `MS_CLIENT_SECRET` | planned (#11), placeholder only |

"Planned" rows are listed so you know what a future feature will ask for. No code in `src/` reads those variables yet.

### The recommended route

**OpenRouter + `openai/gpt-oss-20b` (chat) + `microsoft/mai-transcribe-2` (transcription).** One OpenRouter key covers everything, and it is the best value that still labels speakers:

- **About $0.10 per recorded hour** all in: MAI-Transcribe 2 is $0.10 per audio hour, and `gpt-oss-20b` ($0.03 / $0.13 per million tokens in/out) adds about a tenth of a cent for the summary, mind maps, speaker naming and memory facts. See the [route comparison](#compare-routes).
- **Speaker labels included**, so naming, [voice recognition](using-attest.md#speakers-and-voices), talk balance and the Today prompts all work.
- **Big files**: MAI takes up to 300 MB / 2 hours per file, and Attest streams large uploads (up to 48 MB) straight from R2.
- **It is the wizard's default** (`npm run setup`, press Enter at the provider and model questions), and the first choice in [Settings](#settings).
- **Live preview stays cheap**: on OpenRouter the preview always uses plain Whisper (about $0.012 per audio hour), not MAI.

Upgrade the chat model whenever you want better writing: `anthropic/claude-haiku-5.5` costs about a third of a cent more per hour, and `openai/gpt-5-mini` about a cent more.

### OpenAI

**OpenAI** gives you summaries, mind maps, ask, speaker naming and `gpt-4o-transcribe-diarize` for speaker labels, all on one key. Choose it by answering `openai` in the wizard. It costs about **$0.36 per recorded hour** on `gpt-6-luna`. That diarize model is deprecated and cut off on 2027-02-26; see [Known limits](troubleshooting.md#known-limits-honestly).

### OpenRouter

Run `npm run setup` and answer `openrouter`: one OpenRouter key covers summaries, mind maps, ask, speaker naming *and* transcription (OpenRouter's `/audio/transcriptions`). Transcription models that label speakers: Microsoft `mai-transcribe-2` ($0.10 per audio hour, the cheapest and the recommended pick), Mistral `voxtral-mini-transcribe-3-0` and `voxtral-small-transcribe-3-0`, and ElevenLabs `scribe-v2`. Pick one and Attest requests diarization and turns the per-word speaker ids into the same speaker turns the OpenAI path produces, so naming, summaries, [voice recognition](using-attest.md#speakers-and-voices) and export work as usual. If a model rejects the request or returns no speaker data, that recording falls back to plain text instead of failing. Whisper models (`openai/whisper-large-v3-turbo`, about $0.012 per audio hour) are the cheapest of all but give plain text with no speaker labels.

Chat step-ups from `gpt-oss-20b` (prices as of 2026-11-10; they move, so check [openrouter.ai/models](https://openrouter.ai/models)): `deepseek/deepseek-v4-flash`, `anthropic/claude-haiku-5.5`, `openai/gpt-5-mini`. Any OpenRouter model id works. By hand, set `LLM_BASE_URL`, `LLM_API_KEY`, `LLM_MODELS`, `DEFAULT_MODEL`, `STT_BASE_URL`, `STT_API_KEY` and `STT_MODELS` (examples in `wrangler.toml`). Anthropic keys are not supported directly; use their OpenRouter ids.


## Settings

Click the **gear icon in the top right** (the **Settings** tab on a phone) to change things without redeploying. The dialog is grouped into folding sections (Models, Voice recognition, Transcription, Devices, API key), and closing it with unsaved edits asks first. Inside the iPhone or Mac app it starts with a **Server** row (the address you are connected to, with **Pendant sync** and **Change server**) and a **Lock Attest** switch, which asks for Face ID, Touch ID or your passcode when the app opens. You can switch between **OpenAI** and **OpenRouter**, tick which chat and transcription models to offer (with prices shown), pick the default model, add any other model id, replace the API key, add or remove your **Pocket** and **Omi** API key (write-only, like the others), and turn **voice recognition** on or off. (Who "I" and "me" mean is the **Speaking as** chip in the header, not in Settings.) **Save** applies the provider and model changes immediately.

- Saved settings live in the D1 `settings` table and override the same names set at deploy time. Switching to OpenAI clears the OpenRouter values.
- API keys are write-only: stored in your database, never sent back to the browser (the dialog only says whether one is set). Anyone who can read your D1 database can read them, the same trust level as your Worker secrets.
- If `OWNER_EMAIL` is set, only that account can save settings.
- API: `GET /api/settings` and `PUT /api/settings` with `{provider, chat_models[], default_model, stt_models[], api_key?, voice_match?, sources[]?, pocket_api_key?, omi_api_key?}`. `sources` is a list of `mic`, `pocket`, `omi`, `pendant`.


## Cost

You pay your AI provider directly, per call; there is no markup and no Attest-side billing. Every recording stores `tokens_in` / `tokens_out` and the recording view shows the total. No usage caps exist in the code. **The recommended route costs about $0.10 per recorded hour (about $4 for 40 hours a month).**

**How these are estimated.** A 1-hour meeting is about 9,000 spoken words. Per recorded hour Attest makes a summary call (about 12k tokens in, 1.8k out: summary, action items, three mind maps, unanswered questions, facts) and a speaker-naming call (about 12k in), so roughly **25k tokens in and 2k out** per hour. Prices are from OpenAI's published prices (2026-11-06) and OpenRouter's models page (2026-11-10) and **will drift**: check them, and measure one of your own recordings, because the token counts are right there. Reasoning models such as `gpt-oss-20b` bill their thinking as output tokens; even 10,000 extra thinking tokens add only about $0.0013 on `gpt-oss-20b`.

### Compare routes

Sorted roughly by cost. "Needs" is the API key you must hold. Speaker labels are what make [voice recognition](using-attest.md#speakers-and-voices) and talk balance possible.

| Route (transcription + chat) | Needs | Speaker labels | About per hour | About 40 h/month |
|---|---|:---:|---:|---:|
| OpenRouter: `whisper-large-v3-turbo` + `gpt-oss-20b` | OpenRouter key | no | **$0.013** | $0.52 |
| OpenRouter: `whisper-large-v3` + `deepseek-v4-flash` | OpenRouter key | no | $0.03 | $1.18 |
| **OpenRouter: `mai-transcribe-2` + `gpt-oss-20b`** (recommended) | OpenRouter key | **yes** | **$0.10** | **$4.04** |
| OpenRouter: `mai-transcribe-2` + `claude-haiku-5.5` | OpenRouter key | yes | $0.10 | $4.14 |
| OpenRouter: `mai-transcribe-2` + `gpt-5-mini` | OpenRouter key | yes | $0.11 | $4.41 |
| OpenRouter: `voxtral-mini` + `gpt-oss-20b` | OpenRouter key | yes | $0.21 | $8.44 |
| OpenRouter: `scribe-v2` + `claude-haiku-5.5` | OpenRouter key | yes | $0.22 | $8.94 |
| OpenAI: `gpt-transcribe` + `gpt-6-luna` | OpenAI API key | no | $0.27 | $10.94 |
| OpenAI: `gpt-4o-transcribe-diarize` + `gpt-6-luna` (OpenAI route default) | OpenAI API key | yes (until 2027-02-26) | $0.36 | $14.54 |
| OpenAI: `gpt-4o-transcribe-diarize` + `gpt-6.1-terra` | OpenAI API key | yes (until 2027-02-26) | $0.40 | $15.80 |
| OpenAI: `gpt-4o-transcribe-diarize` + `gpt-6-astra` | OpenAI API key | yes (until 2027-02-26) | $0.71 | $28.40 |
| [Local Mac with oMLX](run-locally.md#run-it-locally-on-a-mac-omlx) | none | yes, detected by voice in your browser | $0 in API fees | $0 |

Cloudflare itself (Worker, D1, R2, Workers AI, Vectorize) fits the free allowances for one person on every row, including a few gigabytes of audio (about 14 MB per recorded hour).

### Choosing by what you already pay for

- **You have an OpenRouter account or credits.** Use the [recommended route](#the-recommended-route). One key, lowest cost with speaker labels, and you can swap in Claude, GPT or DeepSeek chat models by id.
- **You have an OpenAI API account.** Use the OpenAI route. Note that a ChatGPT Plus or Pro *subscription* does not include API access; Attest needs an API key from [platform.openai.com](https://platform.openai.com/), billed per use. The same goes for Claude: a Claude Pro or Max subscription gives no API key, and Attest does not call Anthropic directly, so use Claude through OpenRouter (for example `anthropic/claude-haiku-5.5`). Check your plan's terms, as these offers change.
- **You want no per-use bill at all.** Run [locally on a Mac](run-locally.md#run-it-locally-on-a-mac-omlx), accepting the trade-offs there.
- **You only want transcripts and summaries, no speakers.** Whisper on OpenRouter is about $0.013 an hour, the cheapest row above.
- **Cloudflare.** The free plan is enough. R2 asks for a card on file; Workers AI and Vectorize have free allowances.

### Prices by component

Transcription:

| Transcriber | Via | Labels speakers | Price | 1 hour |
|---|---|:---:|---|---:|
| `microsoft/mai-transcribe-2` | OpenRouter | yes | $0.10 per audio hour | $0.10 |
| `openai/whisper-large-v3-turbo` | OpenRouter | no | ~$0.012 per audio hour | $0.01 |
| `openai/whisper-large-v3` | OpenRouter | no | ~$0.027 per audio hour | $0.03 |
| `mistralai/voxtral-mini-transcribe-3-0` | OpenRouter | yes | ~$0.21 per audio hour | $0.21 |
| `elevenlabs/scribe-v2` | OpenRouter | yes | ~$0.22 per audio hour | $0.22 |
| `gpt-4o-transcribe-diarize` | OpenAI | yes (deprecated 2027-02-26) | $0.006 per minute | $0.36 |
| `gpt-transcribe` | OpenAI | no | $0.0045 per minute | $0.27 |

Chat (summaries, mind maps, naming, memory, Ask, Today), at the 25k in / 2k out per hour estimate:

| Model | Via | Per 1M tokens in / out | Per recorded hour |
|---|---|---|---:|
| `openai/gpt-oss-20b` | OpenRouter | $0.03 / $0.13 | $0.001 |
| `deepseek/deepseek-v4-flash` | OpenRouter | $0.09 / $0.18 | $0.003 |
| `anthropic/claude-haiku-5.5` | OpenRouter | $0.10 / $0.50 | $0.004 |
| `openai/gpt-5-mini` | OpenRouter | $0.25 / $2.00 | $0.010 |
| `gpt-6-luna` (OpenAI route default) | OpenAI | $0.10 / $0.50 | $0.004 |
| `gpt-6.1-terra` | OpenAI | $1.00 / $5.00 | $0.035 |
| `gpt-6.1-sol` | OpenAI | $2.00 / $10.00 | $0.07 |
| `gpt-6-astra` | OpenAI | $10.00 / $50.00 | $0.35 |

### Other things that cost money

- **Live preview** transcribes every 5-second chunk a second time. On OpenAI that is `gpt-transcribe`: about **+$0.27 per hour recorded**. On OpenRouter it is always plain Whisper, about **+$0.012 per hour**, so the recommended route stays near $0.11. Uploading a file instead has no preview cost.
- **OpenAI voice references** add up to four 10-second clips to each diarize call: about +$0.004 per recording. In-browser voice recognition costs nothing on any provider.
- **Ask** is one chat call over up to 8 recordings (about 7k tokens): a fraction of a cent on `gpt-oss-20b`, about $0.001 on Luna, $0.07 on Astra. **Deep** mode is two calls over up to 12 recordings: about $0.002 on Luna, $0.20 on Astra.
- **Memory** adds a facts list to the summarize call you already pay for (about +300 output tokens). Catching up an old recording is one extra call, once. Semantic search embeds each recording once with Workers AI (`bge-base-en-v1.5`, inside the free allowance for one person) and each question once, and it makes Ask *cheaper*, because only the matching passages (about 2,800 characters per recording) are sent.
- **Today**: the brief and the weekly review each cost one chat call per day or week, and again only after a new recording. The prompt box costs one call per Run.

**Bottom line:** the recommended route is about **$0.10 per recorded hour** ($4 for a heavy 40-hour month). The OpenAI defaults are about **$0.36** ($15 for 40 hours), and after 2027-02-26, with no speaker labels, about $0.27.

---
