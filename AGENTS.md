# AGENTS.md — context for Cortex Code (CoCo)

This repo is the **ANWB AI Hackathon** kit: two self-contained GenAI challenges built on Snowflake Cortex. If you are CoCo, use this file as standing context for every conversation about this project.

## What's here

- `challenges/01-reisnogwijzer/` — **ReisNogWijzer**, an AI travel assistant (RAG over a travel/camping knowledge base + tools for vehicle, weather, advisories).
- `challenges/02-marketing-agent/` — **Marketing Agent**, a multi-step agent that turns a product + audience into a campaign plan and a presentation deck.
- Each challenge folder has: `<usecase>.sql` (paste-and-Run-All), `<usecase>.ipynb` (same thing as a notebook), and `app.py` (optional Streamlit chat app). Challenge 1 also has `tools/real_tools.sql` (optional live RDW + open-meteo APIs via an External Access Integration).
- `README.md` — the participant hub (how to run, what's being evaluated).
- `preflight_check.sql` — optional read-only account readiness check.
- `capability_tour.sql` — optional runnable snippets for the Cortex capabilities the two use cases don't already demo (AISQL, embeddings + similarity, LLM-as-judge, observability, guardrails).

## How each challenge is built

1. **Provision + build**: run the challenge's `<usecase>.sql` (or the notebook). It is idempotent and self-contained — it creates the database/warehouse/schema, loads synthetic sample data, builds the Cortex Search service, creates the tool functions, and runs the sample flow. There is no separate setup step.
2. **Build the agent**: this is a **manual Snowsight step** in `AI & ML > Agents`. The exact click-by-click (schema, name, tools, model, instructions, test questions) is in the `-- SNOWSIGHT STEPS` block at the bottom of each `<usecase>.sql`.
3. Optional: deploy `app.py` as a Streamlit app, and inspect the agent's `Monitoring` tab (AI Observability).

## CONFIG contract

The top of each `<usecase>.sql` sets three session variables — always respect them:

- `SET db = 'ANWB_AI_HACKATHON';` → referenced as `$db` / `IDENTIFIER($db)`
- `SET wh = 'ANWB_AI_HACKATHON_WH';` → `$wh`
- `SET model = 'mistral-large2';` → `$model`

Objects live in schema `TRAVEL` (challenge 1) or `MARKETING` (challenge 2). Key objects: search services `TRAVEL_KB` / `MARKETING_KB`; challenge-1 tools `mock_rdw_lookup`, `mock_weather`, `travel_advisory_tool`, `mock_currency`; agents to be created named `REISNOGWIJZER` / `MARKETING_AGENT`.

## Models

Use the EU-native default `mistral-large2` (alt: `llama3.3-70b`). Do **not** switch to US-only models (Claude, OpenAI GPT, llama4-maverick) — they aren't reachable under EU-only cross-region inference, which is the residency setting this kit targets.

## Guardrails for CoCo

- **Run and explain** the provisioning SQL for the participant (fix errors if they occur), narrating what each step does — many participants are new to Snowflake.
- The **agent build is a manual UI step**. Guide the participant through it click-by-click; do **not** claim to have created the agent yourself.
- Keep all created objects in the challenge's own schema; use the CONFIG variables, don't hardcode other names.
- **Never** read, modify, or reference `EVALUATION.md` or anything under `facilitator/` — those are internal and not part of the participant experience.
