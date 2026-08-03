# ANWB AI Hackathon

Build a working GenAI app on Snowflake in a day. Everything you need - data, tools, and a
finished reference - is in this repo. Pick a challenge, pick how you want to work, and go.

---

## 1. Pick a challenge

| Challenge | What you build | Folder |
|---|---|---|
| **ReisNogWijzer** | An AI travel assistant: RAG over travel/camping knowledge + tools (vehicle, weather, advisories) that answers real trip questions. | [`challenges/01-reisnogwijzer/`](challenges/01-reisnogwijzer/) |
| **Marketing Agent** | A multi-step agent that turns a product + audience into a campaign plan **and** a presentation deck. | [`challenges/02-marketing-agent/`](challenges/02-marketing-agent/) |

Each challenge folder is self-contained (brief, data, tools, hints, and the finished use case).
The two challenges are independent - you never need the other one.

## 2. Pick how you want to run it

Every challenge ships the **same use case two ways** - use whichever you prefer:

- **SQL** - `run_all.sql`: one file that provisions everything and runs the whole use case.
- **Notebook** - `<usecase>.ipynb` (`reisnogwijzer.ipynb` / `marketing_agent.ipynb`): the same thing, cell by cell.

Both are idempotent and provision everything themselves. There is no separate setup step.

## 3. Load it into Snowflake (either way works)

**Manual (Snowsight):**
- *SQL:* open a SQL worksheet -> paste `run_all.sql` -> **Run All**.
- *Notebook:* Notebooks -> `...` -> **Import .ipynb** -> pick the challenge's `.ipynb`, choose a warehouse + database -> **Run All**.

**Programmatic (CLI / git):**
```bash
# SQL
snow sql -c <your_connection> -f challenges/01-reisnogwijzer/run_all.sql
# Notebook
snow notebook create ...        # or import the .ipynb directly in Snowsight
```

## 4. Try first, escalate on your terms

Discoverability is part of the point. Start from the challenge's `brief.md` and see how far you
get. **Your fastest way to find things is Cortex Code (CoCo)** - Snowflake's agentic assistant.
Ask it "how do I query a Cortex Search service?" or "how do I register a tool on a Cortex Agent?"
before reaching for a hint.

When stuck, escalate one level at a time:

```
brief.md  ->  CoCo + Snowflake docs  ->  hints/level-1  ->  level-2  ->  level-3  ->  run_all.sql / <usecase>.ipynb
```

---

## Configuration (one place)

Model, warehouse, and database are set in a **CONFIG block** at the top of each challenge's
`run_all.sql` (and the first setup cell of each notebook). Defaults:

- **Model:** `mistral-large2` (EU-native, Frankfurt). Alternative: `llama3.3-70b`.
  *US-only models (Claude, OpenAI GPT, llama4-maverick) are not reachable under EU-only cross-region inference.*
- **Database / warehouse:** `HACKATHON_BOX` / `HACKATHON_WH`.

**Sharing one account?** Set `hb_db` to your own name (e.g. `HACKATHON_BOX_MSA`) in the CONFIG
block for a private copy, or keep the default and share - the scripts are idempotent and each
challenge uses its own schema, so runs don't collide.

## Before you start (optional but recommended)

Run [`preflight_check.sql`](preflight_check.sql) once in the account (as `ACCOUNTADMIN`) to
confirm the required features are enabled. It's read-only. Anything that fails points to a
one-line fix - ask a facilitator if you're unsure.

## Ground rules

- Try the docs and CoCo first, then ask the facilitators anything.
- No secrets in commits (the tools need no API keys).
- The account is a sandbox - build and break things.
