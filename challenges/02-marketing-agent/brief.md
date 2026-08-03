# Challenge 2 — Marketing Agent

> A marketing strategist agent that turns a product brief into a campaign plan **and** a presentation.

## The vision

Build a multi-step agent that works like an ANWB marketing strategist: give it a product (or a short
description) and it researches the brand, defines an audience, proposes a strategy, writes on-brand
messaging, assembles a full campaign plan, and **auto-generates a presentation deck**.

## What it should do (multi-step workflow)

1. **Analyse** the product/service.
2. **Define the target audience** (pick or refine a segment).
3. **Propose a campaign strategy** (core idea + why it works).
4. **Generate messaging** (tagline + supporting messages, in the ANWB voice).
5. **Assemble a marketing plan** (objective, audience, message, channels, timeline, KPIs).
6. **Generate a presentation** from the plan.

## Data already in your account (`HACKATHON_BOX.MARKETING`)

| Object | What it gives you |
|--------|-------------------|
| `PRODUCTS` (12) | ANWB products/services to build campaigns for |
| `AUDIENCE_SEGMENTS` (6) | Personas with age range, channels, and motivators |
| `PAST_CAMPAIGNS` (5) | Prior campaigns for inspiration / few-shot |
| Cortex Search `MARKETING_KB` | Brand positioning, tone of voice, visual identity, planning framework, channel guide, market context, deck structure |

## Tools / building blocks

| Building block | How |
|----------------|-----|
| Brand + market retrieval | Cortex Search `MARKETING_KB` (keeps messaging on-brand) |
| Reasoning + generation | `AI_COMPLETE` (mistral-large2) — use structured/JSON output for the plan |
| Presentation generator | Turn the plan into a slide deck — see hints (both `.pptx` via `python-pptx` and an HTML deck work) |
| Web search / market context | Provided as the `MARKETING_KB` market doc (mock); real web search is an optional stretch |

## Sample prompts your agent should handle

1. **"Create a campaign for ANWB Wegenwacht Europa Service aimed at active seniors."**
2. **"We want to grow EV-membership sign-ups — build me a campaign and a deck."**
3. **"Plan a summer camping-guide campaign for caravan enthusiasts."**

## Success criteria (how you'll be judged)

- [ ] Generates a **structured marketing plan** (objective, audience, message, channels, timeline, KPIs).
- [ ] Produces a **presentation output** (slide deck or structured slide outline).
- [ ] Demonstrates an **agent workflow** — not one prompt, but multiple reasoning steps.
- [ ] Shows **multi-step reasoning and execution** you can walk through.

## Maps to ANWB's evaluation areas

Building this use case demonstrates **LLM Gateway, RAG, Agent Runtime, Tool use, Prompt
Management, Model Deployment (structured output), and Tracing / Observability** (plus Evaluation
and Guardrails as stretches). See [`../../EVALUATION.md`](../../EVALUATION.md) for the full
use-case-to-criteria map.

## Definition of done (demo)

Given a product + audience, the agent returns an on-brand campaign plan and generates a deck
(downloadable `.pptx` or a rendered HTML/Streamlit deck), and you can show the intermediate steps.

## Stretch goals

- Ground the tone strictly in the brand docs and show a "before/off-brand vs after/on-brand" comparison.
- Let the user pick the product from a dropdown in a Streamlit app and download the `.pptx`.
- Add an image or brand-colour theme to the deck.
- Add an evaluation step: an LLM-as-judge scoring the plan against the brand voice.

## Where to get unstuck

Try the [Cortex AISQL docs](https://docs.snowflake.com/en/user-guide/snowflake-cortex/aisql) first.
Then escalate through the hints — one level at a time, and ask **CoCo** as you go:
`hints/level-1-nudges.md` → `hints/level-2-approach.md` → `hints/level-3-snippets.md`.

The finished use case lives in this folder two ways — `run_all.sql` (SQL) and
`marketing_agent.ipynb` (notebook). Open one of those only once you've had a real go yourself.
