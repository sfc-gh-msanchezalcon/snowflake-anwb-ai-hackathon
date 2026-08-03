# ANWB AI Hackathon

> Build a working GenAI app on Snowflake in a day. Two self-contained use cases — everything you
> need to run each one is inside its challenge folder.

## Repository layout

```
README.md                  This guide: how to run + what's being evaluated.
preflight_check.sql        Optional read-only account readiness check (run as ACCOUNTADMIN).
challenges/
  01-reisnogwijzer/        reisnogwijzer.sql · reisnogwijzer.ipynb · app.py · tools/real_tools.sql
  02-marketing-agent/      marketing_agent.sql · marketing_agent.ipynb · app.py
```

Each challenge is independent and self-contained. General hackathon info lives here in the README;
the detailed, step-by-step build for each use case lives in its own folder — in two forms, SQL and
notebook.

## The two use cases

| Use case | What you build | Folder |
|---|---|---|
| **ReisNogWijzer** | An AI travel assistant: RAG over travel/camping knowledge + tools (vehicle, weather, advisories) that answers real trip questions. | [`challenges/01-reisnogwijzer/`](challenges/01-reisnogwijzer/) |
| **Marketing Agent** | A multi-step agent that turns a product + audience into a campaign plan **and** a presentation deck. | [`challenges/02-marketing-agent/`](challenges/02-marketing-agent/) |

## How to run

1. **Pick a use case** and open its folder.
2. **Run it one of two ways — same result, pick whichever you prefer:**
   - **SQL:** paste the challenge's `<usecase>.sql` (e.g. `reisnogwijzer.sql`) into a Snowsight worksheet → **Run All** (or `snow sql -c <conn> -f challenges/01-reisnogwijzer/reisnogwijzer.sql`).
   - **Notebook:** import the challenge's `<usecase>.ipynb` into Snowsight → pick a warehouse + database → **Run All**.
   Both provision everything (idempotent — no separate setup step) and build the use case.
3. **Then follow the "SNOWSIGHT STEPS"** at the bottom of the `.sql` file (or the last notebook cell)
   — a step-by-step, click-by-click guide to build the Cortex Agent and, optionally, ship the
   Streamlit app and inspect AI Observability. Each file is fully self-guiding; you don't need any
   other document.

## What ANWB is evaluating (and how each use case maps)

ANWB's "Capabilities to test for GenAI" list groups into **11 capability areas**: **Overall, LLM
Gateway, Evaluation, Guardrails, Tracing, Prompt management, Agent registry, Skill registry, Tool
registry, RAG, and Agent runtime** (Governance / IAM / RBAC sits inside *Overall*; the no-code
agent builder inside *Agent runtime*). Building either use case exercises the areas below — both run
entirely on Snowflake Cortex, the same platform being assessed.

| Capability area | ReisNogWijzer | Marketing Agent |
|---|:---:|:---:|
| Overall (platform, governance/RBAC, ops) | ● | ● |
| LLM Gateway (model calls, compare models) | ● | ● |
| RAG (Cortex Search over a knowledge base) | ● | ● |
| Agent runtime (multi-step orchestration) | ● | ● |
| Tool registry (custom tools / functions) | ● (vehicle, weather, advisory) | ● (deck generator) |
| Agent registry (build as a Cortex Agent) | ● | ● |
| Tracing (traces, cost, latency) | ● | ● |
| Prompt management (structured / versioned prompts) | ○ | ● (structured plan) |
| Evaluation (judge answer quality) | ○ | ○ |
| Guardrails (PII redaction, scope, safety) | ○ | ○ |
| Skill registry (reusable skills / functions) | ○ | ○ |

● = a natural part of the use case  ○ = available as a stretch

## Good to know

- **Config in one place:** model / warehouse / database are set in a single **CONFIG block** at the
  top of the `.sql` file (and the first notebook cell). Default model `mistral-large2` (EU-native);
  alternative `llama3.3-70b`. *US-only models (Claude, OpenAI GPT, llama4-maverick) aren't reachable
  under EU-only cross-region inference.*
- **Sharing one account?** Set `db` to your own name (e.g. `ANWB_AI_HACKATHON_MSA`) in the CONFIG
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
- **When you're done:** `DROP DATABASE IF EXISTS ANWB_AI_HACKATHON;` and `DROP WAREHOUSE IF EXISTS ANWB_AI_HACKATHON_WH;` (or your own `db`).
- **No API keys needed;** sample data is synthetic, shaped to mirror ANWB's real datasets. It's a
  sandbox — build and break things.
