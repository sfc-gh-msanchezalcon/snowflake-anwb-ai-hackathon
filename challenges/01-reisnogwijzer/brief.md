# Challenge 1 — ReisNogWijzer

> An AI-powered travel assistant that helps travellers prepare road trips and camping holidays across Europe.

## The vision

Build an agent that acts like a knowledgeable ANWB travel expert. A member describes their trip, and
ReisNogWijzer answers using ANWB travel knowledge **plus** live facts about their vehicle, the weather,
and country advisories — going well beyond what a plain chatbot could do.

## What it should do

- **Search the travel knowledge base** (RAG) — camping guides, emission-zone rules, tolls, EV charging, pets, breakdowns.
- **Generate travel itineraries** and **compare destinations / recommend campsites** from the structured data.
- **Call external tools** to ground answers in real facts.

## Data already in your account (`HACKATHON_BOX.TRAVEL`)

| Object | What it gives you |
|--------|-------------------|
| `CAMPSITES` (40) | Sites across NL/DE/AT/IT/FR/HR/ES/CH/DK with GPS, seasonal pricing, area/pitches, amenities, EV charging, season, source URL |
| `EMISSION_ZONES` (19) | City LEZ / Umweltzone / Crit'Air / ZTL rules: sticker type, min EURO norm, extra diesel-ban layer, EV/registration flags |
| `TRAVEL_ADVISORIES` (12) | Per-country safety level + summary |
| `COUNTRY_INFO` (12) | Currency, language, emergency number, tolls, speed limits |
| Cortex Search `TRAVEL_KB` | 15 Dutch travel docs tagged by `source_type` (anwb_website / wikivoyage / camping_navigator), mirroring ANWB's three real sources |

## Tools available (created in `TRAVEL` by `run_all.sql`)

| Tool | Purpose |
|------|---------|
| `mock_rdw_lookup` / `real_rdw_lookup` | Retrieve vehicle info from a licence plate (fuel, EURO norm, weight) |
| `mock_weather` / `real_weather` | Travel weather / short forecast |
| `travel_advisory_tool` | Country safety advisory |
| `mock_currency` | Exchange info (optional) |

See [`tools/`](tools/) — mocks are built into `run_all.sql` (zero setup); real ones make live calls.

## Sample questions your agent should handle

1. **"Can I drive my diesel camper (plate XD-429-P) into Munich?"**
   → look up the vehicle → find Munich's emission zone → reason about whether the EURO norm qualifies.
2. **"Plan a 2-week camping trip through Austria and Italy."**
   → RAG the itinerary guide → pick campsites → note vignettes/tolls and cities to avoid driving into.
3. **"What are the current travel advisories for Croatia?"**
   → call the advisory tool → summarise in a helpful, on-brand way.

## Success criteria (how you'll be judged)

- [ ] **Functional RAG search** over the travel knowledge base.
- [ ] **At least two external tools** connected and actually used by the agent.
- [ ] The agent **answers travel questions** correctly and helpfully.
- [ ] **Demonstrable value over a simple chat** — i.e. it grounds answers in data + live tools.

## Definition of done (demo)

A working agent (Cortex Agent, a notebook loop, or a Streamlit app) that answers all three sample
questions, visibly using both RAG and at least two tools, and explains its reasoning.

## Stretch goals

- Swap mock tools for the **real** RDW + open-meteo APIs.
- Add a Streamlit chat UI.
- Add a "build me a day-by-day itinerary" structured output.
- Add guardrails (PII redaction, Dutch-only answers, out-of-scope refusal).

## Where to get unstuck

Try the [Snowflake docs](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents) first.
Then escalate through the hints — one level at a time, and ask **CoCo** as you go:
`hints/level-1-nudges.md` → `hints/level-2-approach.md` → `hints/level-3-snippets.md`.

The finished use case lives in this folder two ways — `run_all.sql` (SQL) and
`reisnogwijzer.ipynb` (notebook). Open one of those only once you've had a real go yourself.
