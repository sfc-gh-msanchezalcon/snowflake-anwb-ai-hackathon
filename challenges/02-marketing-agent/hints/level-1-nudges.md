# Marketing Agent — Level 1 hints (nudges)

*Where to look. No code yet — try to find the shape yourself.*

> **First stop: ask Cortex Code (CoCo).** Before these nudges, ask CoCo — it searches the Snowflake docs,
> explains features, and can write + run SQL in your account. e.g. "How do I get JSON output from
> AI_COMPLETE?" or "how do I call a stored procedure that uses python-pptx?" Finding it yourself (with
> CoCo) is being scored.

## Stuck on "how do I make the agent think in steps"?
- A marketing plan is a **sequence** of reasoning steps (analyse → audience → strategy → messaging →
  plan → deck). You can drive this with one LLM function called repeatedly, or with a Cortex Agent.
- The core LLM function is `AI_COMPLETE(model, prompt)`. Start there:
  `SELECT AI_COMPLETE('mistral-large2', 'Draft a one-line campaign idea for ANWB roadside cover');`

## Stuck on keeping it on-brand?
- The brand voice, positioning, and planning framework are **already indexed** — look for the Cortex
  Search service `MARKETING_KB` in the `MARKETING` schema. Retrieve the tone-of-voice doc and put it in
  your prompt so the model writes like ANWB, not like a generic ad.
- Docs: [Cortex Search](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-search/cortex-search-overview).

## Stuck on the structured plan?
- Ask the model to return **JSON** with fixed fields (objective, audience, message, channels, timeline,
  KPIs). Look at structured/JSON output in the AISQL docs — it makes the plan machine-usable for the deck.
- Docs: [AISQL](https://docs.snowflake.com/en/user-guide/snowflake-cortex/aisql).

## Stuck on the presentation?
- Two routes, both work here: generate a real **`.pptx`** (the `python-pptx` package is available) from a
  Snowpark Python procedure, or render an **HTML slide deck** you can show in Streamlit. Pick one.
- The `MARKETING_KB` has a "Presentation structure for a campaign deck" doc — use it as the slide order.

## Stuck on what to build a campaign *for*?
- `MARKETING.PRODUCTS`, `AUDIENCE_SEGMENTS`, and `PAST_CAMPAIGNS` are tables — browse them in a worksheet
  to pick a product and audience.

Still stuck? Open `level-2-approach.md`.
