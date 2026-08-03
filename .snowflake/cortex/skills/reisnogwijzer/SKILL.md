---
name: reisnogwijzer
description: Build ANWB Challenge 1 - ReisNogWijzer, the AI travel assistant (RAG + tools). Provisions and explains the SQL, verifies it, then guides the manual Cortex Agent build. Use when the participant says build/run/start the reisnogwijzer or travel-assistant challenge, or challenge 1.
---

# Build Challenge 1 — ReisNogWijzer (travel assistant)

Guide the participant through this challenge end to end. Explain as you go — assume they are new to Snowflake. Work only in this challenge's files and schema; never touch `EVALUATION.md` or `facilitator/`.

## Files
- SQL to run: `@challenges/01-reisnogwijzer/reisnogwijzer.sql`
- Optional app: `@challenges/01-reisnogwijzer/app.py`
- Optional live tools: `@challenges/01-reisnogwijzer/tools/real_tools.sql`

## Step 1 — Provision and build (run + explain)
1. Open `reisnogwijzer.sql` and read its CONFIG block. Respect the session variables `db` (default `ANWB_AI_HACKATHON`), `wh`, and `model` (`mistral-large2`). If the participant shares an account, offer to set `db` to a personal value first.
2. Run the file top to bottom (it is idempotent). As it runs, briefly explain each stage in plain language: the database/warehouse/schema, the synthetic sample tables, the **Cortex Search service `TRAVEL_KB`** (Snowflake's managed hybrid vector + keyword search — this is the RAG index; it takes ~1 minute to index), and the mock tool functions (`mock_rdw_lookup`, `mock_weather`, `travel_advisory_tool`, `mock_currency`).
3. If a statement errors, read the message, fix it, and re-run — don't ask the participant to debug.

## Step 2 — Verify
Confirm the build succeeded:
- `SHOW CORTEX SEARCH SERVICES IN SCHEMA IDENTIFIER($db).TRAVEL;` — `TRAVEL_KB` exists.
- `SELECT mock_rdw_lookup('XD-429-P');` returns vehicle facts (fuel + EURO norm).
- The three sample questions in the BUILD section return sensible answers.
Report a one-line PASS/what's-missing summary.

## Step 3 — Build the agent (manual, guide click-by-click)
This part is done in the Snowsight UI — you cannot create the agent yourself, so walk them through it using the `-- SNOWSIGHT STEPS` block at the bottom of `reisnogwijzer.sql`:
1. `AI & ML > Agents > + Agent`, schema `<db>.TRAVEL`, name `REISNOGWIJZER`.
2. Tools: add **Cortex Search** `TRAVEL_KB`; add **custom tools** `MOCK_RDW_LOOKUP`, `MOCK_WEATHER`, `TRAVEL_ADVISORY_TOOL` (use the one-line description after each in the SQL).
3. Model `mistral-large2`; warm ANWB-in-Dutch instructions.
4. Save and chat-test the three Dutch questions. Success = RAG + at least two tools actually fire.

## Step 4 — Optional
- Ship the chat app: `Projects > Streamlit > + Streamlit App` (warehouse `<wh>`, db `<db>`, schema `TRAVEL`), paste `app.py`, Run.
- Inspect traces/cost/latency in the agent's `Monitoring` tab.
- Swap in live APIs by running `tools/real_tools.sql` (needs `CREATE INTEGRATION` + egress); see the notes in that file.
