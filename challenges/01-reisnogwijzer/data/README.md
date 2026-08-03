# Travel knowledge base (Challenge 1)

The RAG knowledge base for ReisNogWijzer is **embedded directly** in this folder's `run_all.sql`
(table `HACKATHON_BOX.TRAVEL.KB_DOCUMENTS`), so there are no files to upload. The synthetic data is
deliberately shaped to **mirror ANWB's three real datasets** so it reads authentically alongside them.

## How it mirrors the real sources

| Real ANWB source | Our synthetic equivalent |
|------------------|--------------------------|
| Camping Navigator (campsite JSONs) | `TRAVEL.CAMPSITES` — gps, seasonal Basistarief, area (ha), pitches, amenities, `source_url` |
| ANWB Website (markdown pages) | `KB_DOCUMENTS` where `source_type = 'anwb_website'` — Dutch pages with a `source:` anwb.nl URL |
| Wikivoyage NL (destination articles) | `KB_DOCUMENTS` where `source_type = 'wikivoyage'` — destination articles with section headings |

## Structured tables (query these from tools / the agent)

| Table | Rows | Purpose |
|-------|------|---------|
| `TRAVEL.CAMPSITES` | 40 | Campsites with GPS, seasonal pricing (`price_low_eur`/`price_high_eur`), `area_ha`, `num_pitches`, amenities, `ev_charging`, season, `source_url` |
| `TRAVEL.EMISSION_ZONES` | 19 | City low-emission zones: `sticker_name`/`sticker_color`, `min_euro_diesel`, `diesel_ban_min_euro` (extra ban layer), `ev_exempt`, `register_plate_required` |
| `TRAVEL.TRAVEL_ADVISORIES` | 12 | Per-country safety advisory level + summary |
| `TRAVEL.COUNTRY_INFO` | 12 | Currency, language, emergency number, tolls, `vignette_required`, `emission_sticker`, speed limits |

### Emission-zone accuracy note
The German rows model **two layers** correctly: the green Umweltplakette needs **diesel Euro 4**
(`min_euro_diesel = 4`), and Munich/Stuttgart add a **separate diesel ban** (`diesel_ban_min_euro = 5`),
so a Euro 4 diesel camper has a valid sticker but is still blocked from Munich. EVs are **not** exempt
in Germany (`ev_exempt = FALSE`) — a sticker is required there even for electric vehicles.

## Knowledge base documents (indexed by Cortex Search `TRAVEL.TRAVEL_KB`)

Search attributes: `title`, `category`, `source_type`, `source_url` — the agent can filter/cite by source.

| doc_id | Title | source_type |
|--------|-------|-------------|
| AW01 | Milieuzones in Duitsland | anwb_website |
| AW02 | Milieuzones in Europa: overzicht | anwb_website |
| AW03 | Met de caravan of aanhanger naar het buitenland | anwb_website |
| AW04 | Elektrisch op reis: laden onderweg | anwb_website |
| AW05 | Tol en vignetten per land | anwb_website |
| AW06 | Kampeerchecklist voor Europa | anwb_website |
| AW07 | Pech onderweg: de Wegenwacht | anwb_website |
| AW08 | Huisdieren mee op reis | anwb_website |
| WV01 | Innsbruck en Tirol | wikivoyage |
| WV02 | De Veneto-kust en Venetie | wikivoyage |
| WV03 | Rovinj en Istrie | wikivoyage |
| WV04 | Zell am See | wikivoyage |
| CN01 | Camping Auwirt (Salzburg) | camping_navigator |
| CN02 | Camping Union Lido (Venetie) | camping_navigator |
| CN03 | Recreatiepark De Schatberg (Limburg) | camping_navigator |

## Extend it

Add rows to `KB_DOCUMENTS` (or the structured tables) and the search service picks them up within its
`TARGET_LAG`. To refresh immediately, re-run the `CREATE OR REPLACE CORTEX SEARCH SERVICE` block in
this folder's `run_all.sql`. When ANWB's real data is available, the same schema accepts it directly —
the structured columns and `source_type` tags map straight onto Camping Navigator, ANWB Website, and
Wikivoyage.
