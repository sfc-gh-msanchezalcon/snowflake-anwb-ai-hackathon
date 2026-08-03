# Facilitator runbook

Internal notes for running the ANWB AI Hackathon. Not needed by participants.

## What this repo is

Two independent, self-contained challenges. Each folder (`challenges/0X/`) provisions and runs
its own use case two ways - `run_all.sql` (SQL) and `<usecase>.ipynb` (notebook). Nothing is
shared between challenges; there is no central setup step.

## Before the day

1. **Run the preflight** in the target account (DED), as `ACCOUNTADMIN`:
   paste [`../preflight_check.sql`](../preflight_check.sql) into a Snowsight worksheet, run
   PART 0 then PART 1. Every capability should read `PASS` (or the expected `N/A under EU-only`
   notes). Fixes for any `FAIL` are one-liners - see the account permissions setup doc.
2. **Confirm the account basics** the challenges rely on:
   - `CORTEX_ENABLED_CROSS_REGION` is set (EU-only is fine: `AWS_EU`). Model default is
     `mistral-large2`; `llama3.3-70b` also works EU-native.
   - Enterprise Edition (for masking/governance demos).
   - For the optional `.pptx` deck in Challenge 2: accept the Anaconda terms
     (Snowsight > Admin > Billing & Terms). If skipped, the deck falls back to HTML automatically.
   - Network policy allows the participants' egress IPs (guest access is via Entra SSO on DED).

## Provisioning model

Everyone runs their challenge's `run_all.sql` (or notebook) themselves - no admin bottleneck.
All DDL is idempotent and each challenge uses its own schema, so many people can run against the
same `HACKATHON_BOX` database safely. If a team wants an isolated copy, they set `hb_db` in the
CONFIG block (e.g. `HACKATHON_BOX_TEAM3`). This also covers accounts where participants lack
`CREATE DATABASE` on a shared DB - point them at one shared `hb_db` that an admin pre-creates,
and each challenge just creates its schema inside it.

## Delivery options

- **Manual:** hand out the repo (or a single challenge folder). SQL = paste `run_all.sql` in a
  worksheet and Run All; Notebook = Import `.ipynb`.
- **Programmatic:** `snow sql -f .../run_all.sql`, `snow notebook` upload, or a
  `CREATE GIT REPOSITORY` pointing at this repo so notebooks/SQL land in Snowsight directly
  (needs a one-time `CREATE API INTEGRATION` for github.com; public repo = no secret).

## Suggested run of show (Day 2 build — "Build, Learn, Validate")

1. Kickoff + pick challenge per team (brief.md).
2. Teams provision (run_all.sql or notebook) - a few minutes.
3. Build, trying first and escalating through CoCo -> docs -> hints.
4. Demos: each team presents in ANWB's requested structure (15 min + Q&A):
   1. Problem statement
   2. Architecture
   3. Snowflake capabilities used
   4. Live demonstration (agent answering the sample questions)
   5. Lessons learned

**Closing / evaluation discussion (ANWB's framing):** what worked well (technical capabilities,
developer experience, agent functionality, RAG quality) and what didn't (technical gaps, missing
integrations, performance concerns, governance limitations).

## Day 1 (capability assessment — "Understand, Assess, Score")

Day 1 is the scored capability assessment against ANWB's "Capabilities to test for GenAI" list.
The capability list is divided among ANWB participants; each reviews their assigned capabilities,
tests functionality, documents findings, and assigns a score.

**Scoring is done independently on both sides, then compared.** ANWB scores each capability
category on their own; Snowflake brings its own scorecard for the same categories; the two are
laid side by side to surface agreement and gaps. Snowflake's scorecard and the EU-aware readiness
check are shared separately (internal reference, not in this public repo) — ask Miriam for the
current scorecard PDF. Keep the two independent until the compare step so the exercise stays honest.

## Cleanup

```sql
DROP DATABASE IF EXISTS HACKATHON_BOX;      -- or each participant's hb_db
DROP WAREHOUSE IF EXISTS HACKATHON_WH;
-- If Challenge 1 real tools were created:
-- DROP INTEGRATION IF EXISTS hackathon_ext_access;
```
