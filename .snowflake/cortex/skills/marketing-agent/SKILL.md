---
name: marketing-agent
description: Build ANWB Challenge 2 - the Marketing Agent (product + audience -> campaign plan + deck). Provisions and explains the SQL, verifies it, then guides the manual Cortex Agent build. Use when the participant says build/run/start the marketing agent or campaign challenge, or challenge 2.
---

# Build Challenge 2 — Marketing Agent (campaign builder)

Guide the participant through this challenge end to end. Explain as you go — assume they are new to Snowflake. Work only in this challenge's files and schema; never touch `EVALUATION.md` or `facilitator/`.

## Files
- SQL to run: `@challenges/02-marketing-agent/marketing_agent.sql`
- Optional app: `@challenges/02-marketing-agent/app.py`

## Step 1 — Provision and build (run + explain)
1. Open `marketing_agent.sql` and read its CONFIG block. Respect the session variables `db` (default `ANWB_AI_HACKATHON`), `wh`, and `model` (`mistral-large2`). If the participant shares an account, offer to set `db` to a personal value first.
2. Run the file top to bottom (it is idempotent). As it runs, briefly explain each stage: the database/warehouse/schema, the sample tables (`PRODUCTS`, `AUDIENCE_SEGMENTS`, `PAST_CAMPAIGNS`, `KB_DOCUMENTS`), the **Cortex Search service `MARKETING_KB`** (managed hybrid search over the brand voice + deck-structure docs — the RAG index), and the multi-step build: pick inputs -> RAG-grounded campaign **plan** (JSON via `AI_COMPLETE`) -> HTML **deck**.
3. If a statement errors, read the message, fix it, and re-run — don't ask the participant to debug.

## Step 2 — Verify
Confirm the build succeeded:
- `SHOW CORTEX SEARCH SERVICES IN SCHEMA IDENTIFIER($db).MARKETING;` — `MARKETING_KB` exists.
- The Step 2 (`campaign_plan_json`) and Step 3 (deck HTML) queries return output.
- The optional `.pptx` stretch (`build_deck`) only exists if Anaconda/`python-pptx` is enabled; if not, the HTML deck is the expected result — say so rather than treating it as a failure.
Report a one-line PASS/what's-missing summary.

## Step 3 — Build the agent (manual, guide click-by-click)
Done in the Snowsight UI — you cannot create the agent yourself, so walk them through the `-- SNOWSIGHT STEPS` block at the bottom of `marketing_agent.sql`:
1. `AI & ML > Agents > + Agent`, schema `<db>.MARKETING`, name `MARKETING_AGENT`.
2. Tools: add **Cortex Search** `MARKETING_KB`.
3. Model `mistral-large2`; instructions to produce a structured campaign plan + presentation outline grounded in the brand knowledge base.
4. Save and chat-test (e.g. "Maak een campagne voor ANWB Wegenwacht Europa voor actieve senioren."). Success = a structured plan + presentation output with visible multi-step reasoning.

## Step 4 — Optional
- Ship the app: `Projects > Streamlit > + Streamlit App` (warehouse `<wh>`, db `<db>`, schema `MARKETING`), paste `app.py`, Run.
- Real `.pptx`: enable Anaconda (`Admin > Billing & Terms`), then `CALL MARKETING.build_deck(<slides JSON>, 'deck.pptx');` and download from the `DECKS` stage.
- Inspect traces/cost/latency in the agent's `Monitoring` tab.
