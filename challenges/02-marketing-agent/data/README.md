# Marketing knowledge base (Challenge 2)

The data and RAG knowledge base for the Marketing Agent are **embedded** in this folder's
`run_all.sql` (schema `MARKETING`), so there are no files to upload. This folder documents what's available.

## Structured tables

| Table | Rows | Purpose |
|-------|------|---------|
| `MARKETING.PRODUCTS` | 12 | ANWB products/services to build campaigns for (membership, insurance, travel, roadside, energy, shop) |
| `MARKETING.AUDIENCE_SEGMENTS` | 6 | Reusable target personas with channels + motivators |
| `MARKETING.PAST_CAMPAIGNS` | 5 | Prior campaigns for context / few-shot inspiration |

## Knowledge base documents (indexed by Cortex Search `MARKETING.MARKETING_KB`)

| doc_id | Title | Category |
|--------|-------|----------|
| MB01 | ANWB brand positioning | brand |
| MB02 | Tone of voice | brand |
| MB03 | Visual identity basics | brand |
| MB04 | Campaign planning framework | strategy |
| MB05 | Channel guide | strategy |
| MB06 | Market context: Dutch travel and mobility 2026 | market |
| MB07 | Presentation structure for a campaign deck | strategy |

## How the agent uses this

- **Brand + tone docs** keep the generated messaging on-brand (retrieve via Cortex Search).
- **Campaign planning framework / presentation structure** guide the multi-step plan and the deck outline.
- **Products / segments / past campaigns** are structured facts the agent grounds its plan in.

Extend by adding rows; the search service refreshes within its `TARGET_LAG` (or re-run
the `CREATE OR REPLACE CORTEX SEARCH SERVICE` block in `run_all.sql` to refresh immediately).
