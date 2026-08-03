# ANWB AI Hackathon

> Build a working GenAI app on Snowflake in a day. Everything you need — data, tools, hints, and a
> finished reference — is in this repo. Pick a challenge, pick how you want to work, and go.

## Quickstart

### 1. Pick a challenge

| Challenge | What you build | Folder |
|---|---|---|
| **ReisNogWijzer** | An AI travel assistant: RAG over travel/camping knowledge + tools (vehicle, weather, advisories) that answers real trip questions. | [`challenges/01-reisnogwijzer/`](challenges/01-reisnogwijzer/) |
| **Marketing Agent** | A multi-step agent that turns a product + audience into a campaign plan **and** a presentation deck. | [`challenges/02-marketing-agent/`](challenges/02-marketing-agent/) |

The two challenges are independent — you only need one. Each folder is self-contained.

### 2. Run it

Open your challenge folder and pick one way — both provision everything and build the use case
(idempotent, no separate setup step):

- **SQL:** paste `run_all.sql` into a Snowsight worksheet → **Run All** &nbsp;(or `snow sql -c <conn> -f challenges/01-reisnogwijzer/run_all.sql`)
- **Notebook:** import `<usecase>.ipynb` (`reisnogwijzer.ipynb` / `marketing_agent.ipynb`) into Snowsight → pick a warehouse + database → **Run All**

### 3. Build & present

Start from the challenge's `brief.md` and build the use case. Stuck? Escalate one level at a time:

```
brief.md  →  ask CoCo + Snowflake docs  →  hints/level-1  →  level-2  →  level-3
```

**CoCo (Cortex Code)** is your fastest way to find things — ask it "how do I query a Cortex Search
service?" before reaching for a hint. `run_all.sql` / the notebook is the working reference if you
want to peek.

## Good to know

- **Config in one place:** model / warehouse / database are set in a single **CONFIG block** at the
  top of `run_all.sql` (and the first notebook cell). Default model `mistral-large2` (EU-native);
  alternative `llama3.3-70b`. *US-only models (Claude, OpenAI GPT, llama4-maverick) aren't reachable
  under EU-only cross-region inference.*
- **Sharing one account?** Set `hb_db` to your own name (e.g. `HACKATHON_BOX_MSA`) in the CONFIG
  block for a private copy — otherwise runs don't collide (idempotent, per-challenge schema).
- **Your account needs:** Cortex AI enabled (EU-only cross-region is fine), Enterprise edition, and
  a role that can create a database / warehouse / schema. The optional live tools / `.pptx` deck
  need `CREATE INTEGRATION` / Anaconda — both degrade gracefully if not available.
- **PowerPoint (`.pptx`) in Challenge 2:** the HTML deck is the default and works with no setup. A
  real `.pptx` needs the `python-pptx` package — an admin accepts the Anaconda terms once
  (Snowsight → Admin → Billing & Terms). Without it, the deck step falls back to HTML automatically.
- **Preflight (optional):** run [`preflight_check.sql`](preflight_check.sql) once as `ACCOUNTADMIN`.
  It's read-only; any `FAIL` prints a one-line fix (admin-level items go to your account admin).
- **Your demo:** problem statement → architecture → Snowflake capabilities used → live demo →
  lessons learned (15 min + Q&A).
- **When you're done:** `DROP DATABASE IF EXISTS HACKATHON_BOX;` and `DROP WAREHOUSE IF EXISTS HACKATHON_WH;` (or your own `hb_db`).
- **No API keys needed;** sample data is synthetic, shaped to mirror ANWB's real datasets. It's a
  sandbox — build and break things.

## Repository layout

```
preflight_check.sql        Optional read-only account readiness check (run as ACCOUNTADMIN).
challenges/
  01-reisnogwijzer/        brief.md · run_all.sql · reisnogwijzer.ipynb · hints/ · data/ · tools/ · app.py
  02-marketing-agent/      brief.md · run_all.sql · marketing_agent.ipynb · hints/ · data/ · tools/ · app.py
```
