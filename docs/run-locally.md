# Run Attest locally

Everything on your own computer, with no cloud account: a Mac with oMLX, or Windows and Linux.

[Back to the README](../README.md)

---

## Run it locally on a Mac (oMLX)

Attest can run entirely on your own Mac, with no Cloudflare account, no API fees, and nothing leaving the machine. Local mode keeps **semantic search** and **speaker labels** (the speakers are worked out in your browser, by voice). What you give up is reaching it from other devices and the background cron. If you want to open it from your phone, or have Pocket recordings processed while you sleep, use [Cloudflare + OpenRouter](providers-and-costs.md#the-recommended-route) instead.

**What it runs on.** [oMLX](https://github.com/jundot/omlx) ([site](https://omlx.ai)) is an inference server for Apple Silicon (macOS 15+, an M-series Mac) that speaks the OpenAI API: chat (`/v1/chat/completions`), embeddings (`/v1/embeddings`) and transcription (`/v1/audio/transcriptions`, in versions that have it). Attest runs on your machine with `npm run local` (the same Worker, in Cloudflare's local runtime) and talks to it.

### Quick start

```bash
npm install
npm run setup:local      # or: npm run setup, then choose "2. This Mac only"
npm run local            # http://localhost:8787
```

`setup:local` starts by listing the three recommended models (with sizes and what each is for) and lets you quit to download them first. Then it finds your oMLX server (it tries ports 8000, 11434 and 11436), asks for its API key, lists the models it has with the recommended one marked and preselected, **tests each one**, and writes `.dev.vars` (gitignored). `npm run local:check` repeats the tests any time, and `npm run local:check -- --audio speech.wav` also confirms your Whisper model returns timestamps.

### Models to download

Download these in oMLX's admin page (Models, then search Hugging Face). I confirmed each exists on Hugging Face, and the Whisper file list is based on a real oMLX load failure; `npm run local:check` tells you whether your oMLX loads each one.

| Role | Model | Roughly | Why |
|---|---|---|---|
| Chat (summaries, mind maps, Ask, Today, memory) | `mlx-community/gpt-oss-20b-MXFP4-Q8` | 12 GB | The same open-weight model as the recommended cloud route, so results are comparable. Needs about 16 GB of RAM or more, plus room for a long context. Lighter alternative: `mlx-community/Qwen3.5-9B-MLX-4bit` (about 5-6 GB), which reads an hour-long transcript much faster than a 27B model; use it on a 16 GB Mac or if summaries feel slow. |
| Transcription | `mlx-community/whisper-large-v3-turbo-asr-fp16` | 1.6 GB | Fast, accurate Whisper that returns the **timestamps** Attest needs to split speakers. Use an **`-asr`** build (`-asr-4bit` is the smaller one): plain `mlx-community/whisper-*` repos, and their `-4bit` builds, omit the Hugging Face tokenizer files oMLX needs and fail to load ("missing the HuggingFace processor / feature-extractor configuration"). |
| Embeddings (semantic search) | `mlx-community/Qwen3-Embedding-0.6B-4bit-DWQ` | under 1 GB | Small, good quality. If your oMLX will not load it, try `mlx-community/embeddinggemma-300m-4bit`. |

On a smaller Mac, a smaller chat model works, but summaries and structured output get noticeably weaker. Attest asks the chat model for strict JSON and reads it tolerantly (it copes with code fences and chatter around the JSON), but a small model that cannot produce JSON at all will fail with "summarize returned invalid JSON".

**If transcription fails with "missing the HuggingFace processor / feature-extractor configuration"**, your Whisper model is an MLX-only conversion. Either download an `-asr` build in oMLX (above), or add the tokenizer files to the model you have: `npm run local:check` prints the exact commands, filled in with your model's folder. After adding files, reload the model in oMLX and re-run the check.

### How it compares

| | **Cloudflare + OpenRouter** (recommended) | **Local Mac + oMLX** |
|---|---|---|
| Where it runs | Cloudflare Worker, D1 and R2 in your account | `npm run local` on your Mac; data in `.wrangler/state` on disk, only while it runs |
| Cost per recorded hour | about $0.10 | $0 in API fees (your hardware and power) |
| Where your audio and text go | OpenRouter and the transcription provider | nowhere. (The page still loads two scripts from jsDelivr, and the voice model comes from Hugging Face once.) |
| Reach it from your phone or another computer | yes, behind Cloudflare Access | no, `localhost` only |
| Background work (Pocket and Omi sync, memory catch-up) | yes, a free 15-minute cron | not by itself: use **Build memory from past recordings** and **Import from Pocket**, or [run the job by hand](#other-things-to-know) |
| Transcription | `mai-transcribe-2`, nothing to run | your local Whisper model |
| Speaker labels | from the transcriber | **detected in your browser by clustering voices** (see below) |
| [Voice recognition](using-attest.md#speakers-and-voices) | yes | yes |
| Semantic search | Workers AI + Vectorize | your embedding model + a vector index in the local database |
| Summary quality | a hosted model, consistent | depends on the model and your Mac |
| Setup | about 20 minutes, mostly the Cloudflare dashboard | about 10 minutes |

### How speakers are detected locally

A plain Whisper model transcribes but does not say who spoke. So Attest asks for timestamped segments, cuts a window from each segment, turns it into a voice embedding with the same in-browser model that recognises enrolled people, and **clusters** the embeddings into speakers (average-linkage, threshold 0.35, up to 8 speakers). It then asks the chat model to name them from evidence, as usual, and recognises any people you enrolled using the embeddings it already made, so that costs no extra work.

- **It is measured, not assumed.** On a real two-person call the clustering recovered the diarizing model's labels exactly (14 of 14 windows). That is one call, though: expect it to be good with speakers who take turns of a few seconds or more, and weaker on rapid back-and-forth, overlapping speech, or two very similar voices. Every label is a suggestion until you name the speaker.
- **When it runs.** Automatically when a recording is transcribed in your browser and when you open one that has not been split, up to 10 minutes. A longer recording (up to 90 minutes) gets a **Detect speakers** button with progress and Cancel. It is budgeted to at most 100 six-second windows, in a background worker, so the page does not freeze.
- **Keep the tab in front.** Browsers slow background tabs: a window that took 1.5 seconds in the foreground took about 4 when the tab was not focused, so a long run can take several minutes.
- **Whisper's phantom text is ignored.** In silence and noise Whisper invents text, usually "Thank you." (on a real 5-minute call it did so five times in the quiet first two minutes, with a no-speech score of ~1e-11, so that score cannot be used). Those segments stay in the transcript but are left out of the clustering, along with very short stock phrases ("Yeah.", "Okay.") and any tiny text repeated three or more times. A "speaker" has to be built from at least two windows and 6 seconds of speech, or it is folded into the nearest one. Before this, that call came out as 3 speakers (one was the noise); now it is 2, matching the diarizing model.
- **After it runs on a ready recording,** a **Re-summarize with names** button appears, because the summary was written before the speakers existed.
- **Re-detect.** Any recording with timed turns shows **Re-detect speakers**. Names you have confirmed are kept: each new cluster is lined up with the confirmed speaker whose old turns it covers (at least half of the smaller side), so a person keeps their letter, and anyone left with no turns is reported rather than silently lost.
- **Your enrolled voices live in the Attest you enrolled them in.** A local Attest has its own database, so voices enrolled on your Cloudflare deployment are not here. Confirm a speaker, click **Enroll voice**, and it recognises that person in later recordings; enrolling from two recordings is better than one.

### Other things to know

- **Search.** Embeddings go through your server's `/v1/embeddings` and are stored in the local database (`local_vectors`), searched by cosine similarity. Fine for a personal corpus (thousands of passages). Changing the embedding model starts a fresh index: the old vectors are simply not searched, so re-index from Today, then Memory.
- **Context length.** Attest trims what it sends the chat model to `LLM_CONTEXT_CHARS` (setup sets it from the context window you tell it, at about 3 characters per token). If a long recording gets a shallow summary, raise your model's context and this value.
- **Always-on.** Your Mac must be awake and `npm run local` running. Back up `.wrangler/state`: it is your only copy.
- **Settings dialog.** In local mode the provider and model form is replaced by a note that models live in `.dev.vars` (saving that form would overwrite them). The **Pocket key** and the **voice recognition** switch are still there, and save normally.
- **"Scheduled Workers are not automatically triggered during local development."** You will see this warning when you start `npm run local`. It is harmless. On Cloudflare, a Cron Trigger runs a small job every 15 minutes: it builds memory for older recordings and, if you have a Pocket key, imports and processes new Pocket recordings. Your Mac has no such timer, so nothing runs it by itself, and the warning is just wrangler saying so. To run the job once by hand: `curl "http://localhost:8787/cdn-cgi/local/scheduled"`. It does the same memory catch-up (including the local embeddings) and the Pocket import if a key is saved. You rarely need it: **Build memory from past recordings** on Today does the catch-up, and **Import from Pocket** pulls Pocket recordings.
- **Honest status.** The local path is tested with unit tests, and end to end against a mock oMLX server under the real local runtime (upload, timestamped transcription, speaker turns, summary from fenced JSON, memory, vector indexing, semantic Ask), and the clustering on real speech. It has **not** been run against a real oMLX with real models, which is what `npm run local:check` is for. If your server's transcription does not return timestamps, speaker detection cannot work and the check says so.

**Hybrid.** Because the chat endpoint is just a URL, you could keep the Cloudflare deployment and point `LLM_BASE_URL` at your Mac through a tunnel (Cloudflare Tunnel or Tailscale). That works in principle; your Mac must be reachable and the endpoint authenticated. Untried.


## Run it locally on Windows or Linux

oMLX is Apple Silicon only, but nothing else in local mode is Mac-specific: Attest talks to any OpenAI-compatible server, keeps its search index in the local database, and detects speakers in your browser. On Windows or Linux you run **two** small servers instead of one, because the popular chat servers do not transcribe:

| Role | Server | Notes |
|---|---|---|
| Chat and embeddings | [LM Studio](https://lmstudio.ai) (Developer tab, start the server; port 1234) or [Ollama](https://ollama.com) (port 11434) | `setup:local` looks for both. Load the chat model with a **long context** (32k tokens or more). In Ollama the OpenAI-style API cannot raise the context per request, so set `OLLAMA_CONTEXT_LENGTH=32768` (System environment variables on Windows) and restart Ollama. |
| Transcription | [Speaches](https://speaches.ai) (faster-whisper; port 8000) or whisper.cpp's `whisper-server` | Must serve `/v1/audio/transcriptions` and return timestamped segments (`verbose_json`). For whisper.cpp use `--inference-path /v1/audio/transcriptions --convert` (the browser records WebM, so it needs ffmpeg on `PATH` to convert). |

### Quick start (Windows, PowerShell)

Use PowerShell or Windows Terminal rather than Git Bash's default terminal, which cannot hide the API-key prompts. Node 22 or newer.

```powershell
# 1. Chat + embeddings: in LM Studio download openai/gpt-oss-20b and an embedding model, then start the server.
#    Or with Ollama:
ollama pull gpt-oss:20b
ollama pull qwen3-embedding:0.6b

# 2. Transcription: Speaches in Docker Desktop with an NVIDIA GPU, then download a Whisper model into it.
#    (Do not turn on Speaches' batched mode: it needs a VAD filter Attest does not send, and answers HTTP 500.)
docker run -d --gpus all --restart unless-stopped -p 8000:8000 --name speaches `
  -v speaches-hf:/home/ubuntu/.cache/huggingface/hub -e WHISPER__COMPUTE_TYPE=float16 `
  ghcr.io/speaches-ai/speaches:latest-cuda
Invoke-RestMethod -Method Post http://localhost:8000/v1/models/deepdml/faster-whisper-large-v3-turbo-ct2

# 3. Attest
npm install
npm run setup:local      # finds LM Studio/Ollama, then asks for the transcription server (default http://localhost:8000/v1)
npm run local:check -- --audio speech.wav
npm run local            # http://localhost:8787
```

`setup:local` recommends the GGUF equivalents of the Mac models (`openai/gpt-oss-20b` / `gpt-oss:20b` for chat, `qwen3-embedding` for embeddings, `faster-whisper-large-v3-turbo` for transcription) and finds them under either LM Studio's or Ollama's names. Everything in [How speakers are detected locally](#how-speakers-are-detected-locally) and [Other things to know](#other-things-to-know) applies unchanged; read "your Mac" as "your PC". Data lives in `.wrangler\state` in this folder.

**Hardware.** A GPU with 16 GB or more runs the recommended chat model comfortably; with less, pick a smaller model (the Qwen 8-9B class) and expect weaker summaries. Running chat and Whisper on one GPU works if both fit in its memory: on an RTX 5090 (32 GB), `gpt-oss:20b` plus `qwen3-embedding:0.6b` in Ollama (32k context) and Whisper turbo in Speaches all fit at once.

**Keep the folder path short.** Local data lives in `.wrangler\state`, and wrangler's local runtime cannot open its database when the full path passes Windows' 260-character limit (the error is `SQLITE_CANTOPEN`), even with long paths enabled in Windows. A clone in `C:\Users\you\code\Attest` is far below it. In a deeply nested folder, keep the data somewhere short instead: `npm run local -- --persist-to C:\attest-state`.

**Honest status.** Run end to end on Windows 11 with an RTX 5090: Ollama (`gpt-oss:20b`, `qwen3-embedding:0.6b`) plus Speaches (`deepdml/faster-whisper-large-v3-turbo-ct2`, float16). `npm run local:check -- --audio` passed every check, and a 48-second, two-voice recording uploaded through the UI came back ready in about 80 seconds: transcribed with timestamps in about 2.5 seconds, split into the right two speakers in the browser, then summarized with action items, indexed (9 chunks), and answerable from Ask. One limit showed up: when a Whisper segment spans a change of speaker, the whole segment goes to one person, so an action item can be credited to the wrong speaker; check names before trusting owners. (That test used Windows' synthetic voices with no pauses between speakers; real conversations usually split more cleanly.) Not yet tried: LM Studio, whisper.cpp, Linux, and `npm run deploy` (the Cloudflare route) from Windows. `test/platform.test.mjs` covers the command line built for `npx` there, but not a real deploy.
