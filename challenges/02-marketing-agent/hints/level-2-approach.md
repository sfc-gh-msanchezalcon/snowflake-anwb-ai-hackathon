# Marketing Agent — Level 2 hints (approach)

*Recommended architecture and feature mapping. No full solution.*

## Recommended architecture

```
Product + target (user input)
   │
   ▼
Step 1  Analyse product        → SQL lookup in PRODUCTS + AI_COMPLETE
Step 2  Define audience        → pick from AUDIENCE_SEGMENTS (or refine)
Step 3  Retrieve brand voice   → Cortex Search MARKETING_KB (tone, positioning, framework)
Step 4  Generate strategy+msg  → AI_COMPLETE grounded in brand context (JSON output)
Step 5  Assemble plan          → structured JSON: objective, audience, message, channels, timeline, KPIs
Step 6  Generate deck          → python-pptx (.pptx)  OR  HTML slides from the plan JSON
```

This *is* the multi-step reasoning the judges want to see — keep the intermediate outputs visible.

## Feature mapping

| Need | Snowflake feature |
|------|-------------------|
| Brand / market grounding | Cortex Search `MARKETING.MARKETING_KB` |
| Reasoning + generation | `AI_COMPLETE('mistral-large2', …)`, ideally with JSON output |
| Structured facts | SQL over `PRODUCTS`, `AUDIENCE_SEGMENTS`, `PAST_CAMPAIGNS` |
| Deck: `.pptx` | Snowpark Python **stored procedure** using `python-pptx`, writes to a stage |
| Deck: HTML | Build an HTML string from the plan JSON, render in Streamlit |
| UI (stretch) | Streamlit in Snowflake (product dropdown + download button) |

## Two build routes

1. **Prompt-chain (recommended, fastest):** call `AI_COMPLETE` once per step, passing prior outputs
   forward. Retrieve brand docs before the messaging step so tone is right. End by turning the final plan
   JSON into a deck. Every step is a visible artefact for the demo.
2. **Cortex Agent:** register `MARKETING_KB` + SQL tools and let the agent orchestrate. More "agentic",
   but the prompt-chain is easier to control and demo the reasoning.

## Getting the deck right

- Ask the model for a **slide list**: an array of `{title, bullets[]}` objects following the
  `MARKETING_KB` deck-structure doc (title → opportunity → audience → strategy → messaging → channels →
  timeline → KPIs → CTA).
- Feed that array to either a `python-pptx` procedure (real download) or an HTML template (instant preview).
- Apply ANWB colours (yellow + dark blue) for polish — see the visual-identity doc.

## Order of attack (suggested)

1. `AI_COMPLETE` returns a plausible campaign paragraph for a chosen product.
2. Add brand grounding via `MARKETING_KB` — compare off-brand vs on-brand output (great demo moment).
3. Force **JSON** output for the plan.
4. Turn the JSON into slides (start with HTML, upgrade to `.pptx`).

Need code? Open `level-3-snippets.md`.
