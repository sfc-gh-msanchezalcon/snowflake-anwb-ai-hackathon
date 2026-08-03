# ReisNogWijzer — Level 2 hints (approach)

*Recommended architecture and which features to use. Still no full solution.*

## Recommended architecture

```
User question
   │
   ▼
Cortex Agent  (LLM orchestrator: mistral-large2)
   ├── Tool: Cortex Search TRAVEL_KB        → travel knowledge (RAG)
   ├── Tool: rdw_lookup(kenteken)           → vehicle facts
   ├── Tool: weather(location)              → forecast
   ├── Tool: travel_advisory_tool(country)  → safety
   └── (SQL over CAMPSITES / EMISSION_ZONES for structured facts)
   │
   ▼
Grounded, on-brand answer
```

Two valid ways to build it:

1. **Cortex Agent (recommended for the demo):** register the search service and the functions as tools,
   give the agent an instruction prompt ("You are ReisNogWijzer, an ANWB travel expert…"), and let it
   decide what to call. Cleanest story for judges.
2. **Notebook orchestration (fastest to first value):** in Python/SQL, call `AI_COMPLETE` with the
   question + a description of available tools; parse which tool it wants; execute; loop the result back
   in. Good if you want full control or the agent API is new to you.

## Feature mapping

| Need | Snowflake feature |
|------|-------------------|
| Retrieve travel docs | Cortex Search `TRAVEL.TRAVEL_KB` |
| Vehicle / weather / advisory facts | `SHARED.*` functions (mock or real) |
| Structured lookups (campsites, zones) | plain SQL over `TRAVEL` tables |
| LLM reasoning / final answer | `AI_COMPLETE('mistral-large2', …)` |
| Chat UI (stretch) | Streamlit in Snowflake |

## Tackling each sample question

- **Diesel camper into Munich:** tool → `rdw_lookup` gives fuel + EURO norm; SQL → `EMISSION_ZONES`
  row for Munich gives `min_euro_diesel`; the LLM compares and explains (and note: the *towing vehicle*
  determines access, which is in `KB01`).
- **2-week Austria+Italy trip:** RAG `TRAVEL_KB` for the itinerary + tolls docs; SQL `CAMPSITES` filtered
  by country/rating/season; LLM assembles a day-by-day plan and flags cities to avoid driving into.
- **Croatia advisories:** `travel_advisory_tool('Croatia')` → LLM summarises in the ANWB voice.

## Order of attack (suggested)

1. Get `AI_COMPLETE` answering a plain travel question.
2. Add RAG: retrieve from `TRAVEL_KB` and stuff results into the prompt. See the value jump.
3. Add one tool (`rdw_lookup`). Then a second (`weather` or `advisory`) — that satisfies the "≥2 tools".
4. Wrap it as a Cortex Agent or a Streamlit chat.

Need actual code? Open `level-3-snippets.md` — but try the above first.
