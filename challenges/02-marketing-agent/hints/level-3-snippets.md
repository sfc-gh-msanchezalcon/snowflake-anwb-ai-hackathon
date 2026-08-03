# Marketing Agent — Level 3 hints (snippets)

*Copy-paste building blocks. You still assemble the workflow and the deck.*

## 1. Retrieve brand voice (RAG) so messaging stays on-brand

```sql
SELECT PARSE_JSON(
  SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
    'HACKATHON_BOX.MARKETING.MARKETING_KB',
    '{"query": "tone of voice and brand positioning", "columns": ["title","content"], "limit": 3}'
  )
)['results'] AS brand_context;
```

## 2. Generate the campaign plan as JSON, grounded in the brand

```sql
WITH brand AS (
  SELECT PARSE_JSON(SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
     'HACKATHON_BOX.MARKETING.MARKETING_KB',
     '{"query":"tone of voice, campaign planning framework","columns":["content"],"limit":4}'
  ))['results']::STRING AS ctx
)
SELECT AI_COMPLETE('mistral-large2',
  'You are an ANWB marketing strategist. Brand context:\n' || brand.ctx ||
  '\n\nBuild a campaign for the product "ANWB Wegenwacht Europa Service" targeting active seniors. '
  'Return ONLY valid JSON with keys: objective, audience, key_message, tagline, '
  'channels (array), timeline (array of {phase, weeks}), kpis (array), slides '
  '(array of {title, bullets}). Write in a warm ANWB tone.'
) AS plan_json
FROM brand;
```

Tip: wrap the result with `TRY_PARSE_JSON()` and, if it fails, re-prompt "return valid JSON only".

## 3. Generate a real .pptx (Snowpark Python stored procedure → stage)

`python-pptx` (1.0.2) is available. Create a stage, then a procedure that turns the `slides` array into a deck:

```sql
CREATE STAGE IF NOT EXISTS MARKETING.DECKS;

CREATE OR REPLACE PROCEDURE MARKETING.build_deck(slides VARIANT, filename STRING)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python','python-pptx')
HANDLER = 'run'
AS
$$
from pptx import Presentation
from pptx.util import Inches, Pt
import io
def run(session, slides, filename):
    prs = Presentation()
    for s in slides:                     # slides = [{title, bullets:[...]}, ...]
        layout = prs.slide_layouts[1]
        slide = prs.slides.add_slide(layout)
        slide.shapes.title.text = s.get('title','')
        body = slide.placeholders[1].text_frame
        for i, b in enumerate(s.get('bullets', [])):
            (body.paragraphs[0] if i == 0 else body.add_paragraph()).text = b
    buf = io.BytesIO(); prs.save(buf); buf.seek(0)
    session.file.put_stream(buf, f'@MARKETING.DECKS/{filename}', auto_compress=False, overwrite=True)
    return f'@MARKETING.DECKS/{filename}'
$$;

-- CALL MARKETING.build_deck(<slides variant>, 'campaign.pptx');
-- then GET @MARKETING.DECKS/campaign.pptx to download.
```

## 4. Or an instant HTML deck (no download, renders in Streamlit)

```python
def slides_to_html(slides):
    css = "body{font-family:sans-serif} .s{page-break-after:always;border:2px solid #FFD100;margin:12px;padding:24px;border-radius:12px} h2{color:#0a2a66}"
    parts = [f"<style>{css}</style>"]
    for s in slides:
        bl = "".join(f"<li>{b}</li>" for b in s.get("bullets", []))
        parts.append(f"<div class='s'><h2>{s['title']}</h2><ul>{bl}</ul></div>")
    return "".join(parts)
# In Streamlit:  import streamlit.components.v1 as c; c.html(slides_to_html(slides), height=600, scrolling=True)
```

The finished use case (`run_all.sql` and `marketing_agent.ipynb` in this folder) wires the full chain: plan + deck. Try assembling snippets 1-3 first.
