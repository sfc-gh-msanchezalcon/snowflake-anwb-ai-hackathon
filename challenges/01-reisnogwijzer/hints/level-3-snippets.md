# ReisNogWijzer — Level 3 hints (snippets)

*Copy-paste fragments. These are building blocks, not the finished agent — you still assemble them.*

## 1. Query the travel knowledge base (RAG) from SQL

```sql
SELECT PARSE_JSON(
  SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
    'HACKATHON_BOX.TRAVEL.TRAVEL_KB',
    '{"query": "driving a diesel camper into a German city", "columns": ["title","content","source_type","source_url"], "limit": 3}'
  )
)['results'] AS hits;
```

Tip: the KB is tagged by `source_type` (`anwb_website` / `wikivoyage` / `camping_navigator`) — the same
three sources ANWB uses. You can filter to one source with a Cortex Search `filter`, e.g.
`"filter": {"@eq": {"source_type": "anwb_website"}}`, and cite `source_url` in your answer.

## 2. Answer a question grounded in retrieved context

```sql
WITH ctx AS (
  SELECT PARSE_JSON(SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
      'HACKATHON_BOX.TRAVEL.TRAVEL_KB',
      '{"query": "emission zones caravan", "columns": ["content"], "limit": 3}'
  ))['results'] AS r
)
SELECT AI_COMPLETE('mistral-large2',
  'You are ReisNogWijzer, an ANWB travel expert. Answer using ONLY this context:\n'
  || ctx.r::STRING
  || '\n\nQuestion: Do I need a sticker to drive into Munich?')
FROM ctx;
```

## 3. Chain a tool + a table for the "Munich" question

```sql
WITH vehicle AS (
  SELECT SHARED.mock_rdw_lookup('XD-429-P') AS v
),
zone AS (
  SELECT * FROM TRAVEL.EMISSION_ZONES WHERE city = 'Munich'
)
SELECT AI_COMPLETE('mistral-large2',
  'Vehicle: ' || (SELECT v FROM vehicle)::STRING ||
  '\nMunich rule: ' || (SELECT OBJECT_CONSTRUCT(*) FROM zone)::STRING ||
  '\n\nCan this vehicle enter Munich? Explain simply for an ANWB member.'
) AS answer;
```

## 4. Cortex Agent tool spec (skeleton — fill in the rest)

When you formalise it as an agent, you describe each tool so the model knows when to call it. Sketch:

```sql
-- Pseudocode of the agent's tool set (see the Cortex Agents docs for exact syntax):
--   tool 1: cortex_search  -> HACKATHON_BOX.TRAVEL.TRAVEL_KB     (travel knowledge)
--   tool 2: generic/function -> SHARED.mock_rdw_lookup(kenteken) (vehicle info)
--   tool 3: generic/function -> SHARED.travel_advisory_tool(country)
-- Instruction: "You are ReisNogWijzer, an ANWB travel expert. Use the knowledge base for
--   travel/camping/emission questions, call rdw_lookup for vehicle facts, and advisory for safety.
--   Always answer in a warm, helpful ANWB tone."
```

The finished use case (`run_all.sql` and `reisnogwijzer.ipynb` in this folder) wires the full flow — RAG + tools + `AI_COMPLETE`. Try assembling snippets 1-3 into a working answer before you open either.

## Swapping to real tools

Just change `mock_rdw_lookup` → `real_rdw_lookup` and `mock_weather` → `real_weather` (same signatures).
Use a real plate like `L781HR` (RDW only knows real plates).
