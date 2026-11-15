# Cloudflare setup reference

The technical reference for deploying Attest to your own Cloudflare account: R2, Zero Trust, the API token, the setup wizard, choosing devices and background sync. If you want a gentler, click-by-click walkthrough, use [the step-by-step setup guide](setup.md).

[Back to the README](../README.md)

---

## Full setup guide

Attest ships locked down: it has no public URL until you give it your own hostname, and it refuses every request that has not passed Cloudflare Access. That is deliberate (without it, anyone with the URL would share one set of recordings), so there are a few Cloudflare dashboard steps. The setup wizard (`npm run deploy`) automates everything after them. Until Access is in place the app answers `401` to everyone; that is it failing closed.

**On this page:** [Before you start](#before-you-start) · [1. Enable R2](#1-enable-r2) · [2. Set up Zero Trust](#2-set-up-zero-trust) · [3. API token (optional)](#3-optional-api-token) · [4. Run the wizard](#4-run-the-wizard) · [5a. Test it](#5a-test-it) · [5b. Manual Access setup](#5b-manual-access-setup) · [Semantic search setup](#semantic-search-setup) · [Pocket and Omi sync](#background-sync-pocket-and-omi) · [Local dev](#local-dev)

### Before you start

- A Cloudflare account (free) with **two-factor authentication on**.
- A domain whose DNS is on Cloudflare (an **active zone** in your account), for example `example.com`. You will use a subdomain such as `attest.example.com`. That subdomain must not already have a DNS record; the deploy creates it.
- [Node.js](https://nodejs.org/) 22.12 or newer, this repo cloned (see [Quick start](../README.md#quick-start)), and an API key for OpenAI or OpenRouter (see [Providers and keys](providers-and-costs.md#providers-and-keys)).

### 1. Enable R2

Cloudflare dashboard, then **R2 Object Storage**, then enable it. It has a free tier but asks for a payment method. Skip this and the deploy fails with "Please enable R2 through the Cloudflare Dashboard" (error 10042) and no Worker is created.

### 2. Set up Zero Trust

Zero Trust is the Cloudflare product that provides Access, the login in front of the app.

1. Cloudflare dashboard, then **Zero Trust**.
2. Choose a **team name** (any unique name; it becomes `<team>.cloudflareaccess.com`, your login page). You can see it later under Zero Trust, then **Settings**.
3. Choose the **Free** plan and enter payment details. Cloudflare requires a card even for Free; you are not charged on the Free plan.

This step cannot be automated: plan selection and payment are dashboard-only.

### 3. (Optional) API token

Create a token so the wizard can set up the login for you. Skip this to do the login by hand in [step 5b](#5b-manual-access-setup) instead.

1. Go to [dash.cloudflare.com/profile/api-tokens](https://dash.cloudflare.com/profile/api-tokens), then **Create Token**, then **Create Custom Token**.
2. Add two permissions, both under **Account**:
   - **Access: Apps and Policies** with **Edit**
   - **Access: Organizations, Identity Providers, and Groups** with **Edit**
   - Only if you will use the Bluetooth pendant app, a third: **Access: Service Tokens** with **Edit** (it creates the sign-in the app uses; see [Choosing your devices](#choosing-your-devices))
3. Account Resources: **Include**, then your account. Create the token and copy it.
4. You also need your **account id**: dashboard, any zone's Overview page, right column. The wizard tries to detect it.

The token is typed into the wizard, used once in memory, and never saved. Delete it when setup finishes.

### 4. Run the wizard

```bash
npm install
npx wrangler login
npm run deploy
```

With no `wrangler.local.toml` yet, `npm run deploy` asks:

| Question | Used for |
|---|---|
| Hostname (`attest.example.com`) | Written to `wrangler.local.toml` (gitignored) as the Worker's custom domain |
| Your email | `OWNER_EMAIL` secret, and the address allowed through Access |
| AI provider (`openrouter`, the default, or `openai`) | OpenRouter: asks for one OpenRouter key plus the chat and transcription model ids, and sets `LLM_*`, `STT_*` and `DEFAULT_MODEL` as secrets. OpenAI: asks for `OPENAI_API_KEY`. Re-run `npm run setup` to switch. |
| Which devices you use | Asks yes or no for the app itself, Pocket, Omi, and the Bluetooth pendant; stores `SOURCES`. Only the ones you pick ask for a key. Change it later in **Settings** |
| Pocket API key | `POCKET_API_KEY` secret, optional. You can also add or change it later in **Settings** (the gear icon) |
| Omi Developer API key | `OMI_API_KEY` secret, optional (`omi_dev_...`, `conversations:read` scope). Also settable later in **Settings** |
| Create the Access login automatically? | If yes: asks for account id and the [step 3](#3-optional-api-token) token |

Then it deploys (creating the Worker, D1 database, R2 bucket, DNS record, certificate and the 15-minute cron; there is no SQL to run, the Worker creates its own tables on the first request), sets the secrets, and, if you said yes, creates a One-time PIN login method, an "Allow your email" policy, and the Access application on your hostname. It is safe to re-run (`npm run setup` re-asks the questions; existing pieces are reused or updated). Later `npm run deploy` runs just deploy. Your hostname never reaches git.

`OWNER_EMAIL` matters: the background cron has no login, so it files recordings under that address. It must equal the email you log in with (lowercase), or cron-imported recordings will not appear in your view.

If the wizard declined or you skipped the token, finish with [step 5b](#5b-manual-access-setup).

### 5a. Test it

1. Open `https://<your hostname>` in a private window. You should land on a Cloudflare Access login page, not on Attest.
2. Enter your email and choose **Send login code**. Check inbox and spam for a 6-digit code from `noreply@notify.cloudflare.com`; it expires after 10 minutes and works once.
3. You should now see Attest. Record something short, or use **Import from Pocket**.

### 5b. Manual Access setup

Only if you skipped the automatic login.

1. Zero Trust, then **Integrations**, then **Identity providers**. If **One-time PIN** is not listed, **Add new identity provider**, then **One-time PIN**. (This lets you log in by emailed code with no Google or GitHub setup.)
2. Zero Trust, then **Access controls**, then **Applications**, then **Create new application**, then **Self-hosted and private**.
3. Name it (for example `Attest`), choose **Add public hostname**, pick your zone in the **Domain** dropdown, and enter your subdomain so the hostname matches `wrangler.local.toml` exactly. No wildcards.
4. Under **Access policies** create a policy: **Action = Allow**, **Include, then Emails**, your email (exactly `OWNER_EMAIL`). Everyone you allow sees the same recordings (the app is [single-user](privacy.md#privacy-and-security)). Access is deny-by-default, so anyone not matching an Allow policy is blocked.
5. Enable **One-time PIN** as the login method. Leave "Apply instant authentication" off unless exactly one provider is enabled.
6. Set a **Session Duration** (for example 1 month) and choose **Create**.
7. If you skipped the wizard's secrets: the provider secrets (see [Providers and keys](providers-and-costs.md#providers-and-keys); for OpenAI, `npx wrangler secret put OPENAI_API_KEY`), `npx wrangler secret put OWNER_EMAIL`, and optionally `POCKET_API_KEY`.

Dashboard labels move around; if one differs, look for the same idea nearby. Docs: [developers.cloudflare.com/cloudflare-one](https://developers.cloudflare.com/cloudflare-one/). Something not working? See [Troubleshooting](troubleshooting.md#troubleshooting).

### Semantic search setup

This is automatic. Each deploy tries to create a Cloudflare Vectorize index named `attest-memory` (768 dimensions, cosine) and, if that works, adds the `AI` (Workers AI) and `VECTORS` (Vectorize) bindings to the merged config. Both have free allowances on Cloudflare. If the index can't be created (for example an account without Vectorize), the deploy continues without them and Ask uses keyword search. The bindings are not in `wrangler.toml` on purpose: a binding to a missing index would make a plain `wrangler deploy` fail.

- Skip it on purpose: `ATTEST_NO_VECTORS=1 npm run deploy`.
- By hand: `npx wrangler vectorize create attest-memory --dimensions=768 --metric=cosine`, then add `[ai] binding = "AI"` and `[[vectorize]] binding = "VECTORS" index_name = "attest-memory"` to your config.
- Older recordings catch up on their own via the cron, two per 15 minutes. To do it now, open Today, then Memory, and press **Build memory from N past recordings**. How it all works: [Memory and semantic search](using-attest.md#memory-and-semantic-search).

### Choosing your devices

Tick the ones you use in **Settings** (the gear icon, "Where your recordings come from"), or answer the questions in `npm run setup`. The main screen, the setup questions and the background sync all follow that choice, and you can use as many as you like at once. With nothing chosen yet, Attest shows the app's own recorder plus any device that already has a key, so an older deploy keeps its Pocket button.

| Source | What you get | Needs |
|---|---|---|
| **Record or upload in the app** | Browser recorder and file upload | nothing |
| **Pocket** | Full audio, run through Attest's own transcription and speaker pipeline | a Pocket API key |
| **Omi**, or a **Limitless pendant paired with the Omi app** | Omi's transcript and speaker turns, summarized by Attest. **No audio**, because Omi's Developer API does not share it (so no playback or voice matching on these rows) | an Omi Developer API key (`omi_dev_...`) with only the `conversations:read` scope, from the Omi app under Settings, Developer Settings |
| **Limitless pendant over Bluetooth** | Full audio straight from the pendant, through the Attest app for Mac or iPhone in [`apple/`](../apple/README.md) | the Attest app, and a Cloudflare Access service token (below) |

With two or more import sources ready, the sidebar also shows **Import from all**. A chosen source that has no key yet still shows its button, marked "(add key)", and opens Settings.

A pendant talks to one phone at a time. If you use it with Omi *and* the Attest app, only one of them can be connected at once, and whichever drains the pendant first takes the audio. Omi's copy of a conversation (transcript) and the Attest app's copy (audio) arrive as separate recordings.

**Omi imports** keep Omi's own speaker turns. Names Omi already knows are kept (as unconfirmed, with "Named in Omi" as the evidence), and placeholders such as "Speaker 0" are ignored. Re-importing is safe: one row per Omi conversation.

#### Sign-in for the Attest app (Bluetooth pendant)

The app cannot do an interactive login, so it uses a **Cloudflare Access service token**. Setup creates it when you tick the pendant. On a deployment that already exists:

```sh
npm run deploy         # the Worker needs the code that accepts the token
npm run device-token   # creates the token and prints the Client ID, secret and an attest://connect link
```

`device-token` needs an API token with the extra **Access: Service Tokens: Edit** permission ([step 3](#3-optional-api-token)). It sets three Worker secrets: `ACCESS_TEAM_DOMAIN` (your `team.cloudflareaccess.com`), `ACCESS_AUD` (the Access application's audience tag), and `OWNER_EMAIL`. The Worker verifies the token's signed JWT against Cloudflare's published keys (audience, issuer and expiry), treats it as you, and **only for two routes**: uploading a recording (`POST /api/recordings`) and `GET /api/meta`. A leaked token cannot read recordings or change settings. Without `ACCESS_TEAM_DOMAIN` and `ACCESS_AUD`, service tokens are off.

Uploads from a device app may carry `created_at` (when it was actually captured; ignored unless after 2020 and not in the future) and `ingest_id` (the app's own id for the recording: a repeat returns the existing row instead of creating a copy).

On a phone-width screen the web app shows a small bottom bar: **Home, Ask, Record, Library, Settings**. The Record button is hidden if you never record in the app. See [The interface](using-attest.md#the-interface) for what each one shows.

### Background sync, Pocket and Omi

`wrangler.toml` has a Cron Trigger (`*/15 * * * *`, free on Workers). Each tick does three things:

1. **Memory catch-up.** Builds facts and the semantic index for up to 2 older recordings, with or without Pocket or Omi.
2. **Imports.** For each of **Pocket** and **Omi** that you ticked and gave a key, imports up to 2 new recordings from the last 3 days. Does nothing for a source until its key is saved: paste it in **Settings** (the gear icon), or set the `POCKET_API_KEY` / `OMI_API_KEY` secret.
3. **Processing.** Processes up to 2 waiting Pocket or Omi recordings, so meetings show up transcribed without opening the app. (Omi rows already have a transcript, so this step only summarizes them.)

Because cron has no Access header, set the `OWNER_EMAIL` secret to the email you sign in with (default `local`). Failed rows are not retried automatically; open one and press Retry. The "Import from Pocket" and "Import from Omi" buttons still work for pulling something right now (it looks back 7 days). Free-plan CPU limits apply to a tick; if long recordings time out there, a paid plan or the button is the fallback.

### Local dev

```bash
npm run dev
```

`wrangler dev` runs the Worker against the local D1 and R2 emulation. There is no `cf-access-authenticated-user-email` header locally, so every row is owned by the string `local` (see [Privacy and security](privacy.md#privacy-and-security)). Workers AI and Vectorize are not emulated locally, so in `npm run dev` semantic search is off (Ask falls back to keywords) and facts still work. Copy `.dev.vars.example` to `.dev.vars` for local secrets. To run Attest on your machine as a product rather than to develop it, use `npm run local` instead: see [Run it locally on a Mac](run-locally.md#run-it-locally-on-a-mac-omlx), which supplies local stand-ins for both.

---
