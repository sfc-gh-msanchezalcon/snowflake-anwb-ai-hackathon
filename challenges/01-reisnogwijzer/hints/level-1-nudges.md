# ReisNogWijzer — Level 1 hints (nudges)

*Where to look. No code yet — try to find the shape of the solution yourself.*

> **First stop: ask Cortex Code (CoCo).** Before these nudges, ask CoCo — it searches the Snowflake docs,
> explains features, and can write + run SQL in your account. e.g. "How do I query a Cortex Search service
> in SQL?" or "show me AI_COMPLETE examples." Finding it yourself (with CoCo) is being scored.

## Stuck on the knowledge base search?
- The travel documents are already indexed. Look for **Cortex Search** — it's Snowflake's managed
  hybrid (semantic + keyword) retrieval. There's a service called `TRAVEL_KB` in the `TRAVEL` schema.
- Docs: [Cortex Search overview](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-search/cortex-search-overview),
  [Query a search service](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-search/query-cortex-search-service).

## Stuck on "how does the agent call tools"?
- Look at **Cortex Agents** — they orchestrate an LLM with tools (a Cortex Search service + your own
  SQL/Python functions). The tools already exist in the `SHARED` schema.
- Docs: [Cortex Agents](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents).
- Don't want a full agent yet? You can get far with a **notebook loop**: call `AI_COMPLETE`, let it decide
  which tool to call, run the tool, feed the result back. Prove the value first, formalise as an agent later.

## Stuck on the vehicle / weather / advisory facts?
- These are **functions** you call like any SQL function: `SELECT SHARED.mock_rdw_lookup('XD-429-P');`
  Explore them in a worksheet to see what they return.
- The emission-zone rules are in a **table** (`TRAVEL.EMISSION_ZONES`) — plain SQL.

## Stuck on the "diesel camper into Munich" logic?
- Break it down: (1) what vehicle is it? (tool) (2) what does Munich require? (table) (3) does the
  vehicle's EURO norm meet the minimum? (reasoning). The agent should chain these — you don't hard-code it.

## Stuck on "how do I even call an LLM"?
- The one function to know is `AI_COMPLETE(model, prompt)`. Try
  `SELECT AI_COMPLETE('mistral-large2', 'Say hi in Dutch');` in a worksheet.
- Docs: [AISQL / AI_COMPLETE](https://docs.snowflake.com/en/user-guide/snowflake-cortex/aisql).

Still stuck after trying these? Open `level-2-approach.md`.
