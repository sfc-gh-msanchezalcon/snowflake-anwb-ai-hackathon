-- ============================================================================
-- Challenge 2 - Marketing Agent
-- ----------------------------------------------------------------------------
-- WHAT YOU'RE BUILDING: a multi-step marketing agent that turns a product +
-- audience segment into a structured campaign PLAN and a presentation DECK.
--
-- SUCCESS CRITERIA (ANWB): a structured marketing plan; a presentation output;
-- a demonstrable agent workflow; visible multi-step reasoning and execution.
--
-- HOW TO RUN - two ways, same result:
--   SQL      : paste this file into a Snowsight worksheet and click Run All
--              (or run: snow sql -c <connection> -f marketing_agent.sql).
--   Notebook : import marketing_agent.ipynb into Snowsight and Run All.
-- After Run All, follow the SNOWSIGHT STEPS at the bottom to build the agent
-- (and, optionally, the app).
--
-- Self-contained and idempotent; independent of Challenge 1. The deck defaults
-- to HTML (no extra packages); a real .pptx is an optional stretch that needs
-- python-pptx (accept Anaconda terms in Snowsight > Admin > Billing & Terms).
-- ============================================================================

-- ============================================================================
-- CONFIG  --  the only knobs. Edit here to change model, warehouse, or DB.
-- ============================================================================
SET hb_db    = 'HACKATHON_BOX';      -- your DB. For a private copy on a shared
                                     -- account, set e.g. 'HACKATHON_BOX_MSA'.
SET hb_wh    = 'HACKATHON_WH';       -- warehouse (created if missing)
SET hb_model = 'mistral-large2';     -- EU-native (Frankfurt). Alt: 'llama3.3-70b'.
                                     -- US-only models (Claude/GPT/llama4-maverick)
                                     -- are NOT reachable under EU-only cross-region.

-- ----------------------------------------------------------------------------
-- Base (idempotent): database, warehouse, schema
-- ----------------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS IDENTIFIER($hb_db)
    COMMENT = 'ANWB AI hackathon - Marketing Agent';
CREATE WAREHOUSE IF NOT EXISTS IDENTIFIER($hb_wh)
    WAREHOUSE_SIZE = 'SMALL' AUTO_SUSPEND = 60 AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE COMMENT = 'Compute for the ANWB AI hackathon';

USE DATABASE IDENTIFIER($hb_db);
CREATE SCHEMA IF NOT EXISTS MARKETING COMMENT = 'Challenge 2 - Marketing Agent';
USE SCHEMA MARKETING;
USE WAREHOUSE IDENTIFIER($hb_wh);


-- ----------------------------------------------------------------------------
-- PRODUCTS — ANWB product/service catalog the agent can build campaigns for
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TABLE PRODUCTS (
    product_id     VARCHAR(10) PRIMARY KEY,
    name           VARCHAR(100),
    category       VARCHAR(50),   -- membership | insurance | travel | roadside | shop | energy
    price_from_eur NUMBER(8,2),
    price_model    VARCHAR(30),   -- per year | per month | one-off | per trip
    target_hint    VARCHAR(120),
    description    VARCHAR(400)
);

INSERT INTO PRODUCTS VALUES
('P01','ANWB Lidmaatschap Basis','membership',0.00,'per year','value-seeking members','Entry membership with discounts, the ANWB magazine, and access to member services.'),
('P02','ANWB Lidmaatschap Plus','membership',33.75,'per year','active families and drivers','Adds Wegenwacht roadside assistance in the Netherlands plus extra member benefits.'),
('P03','ANWB Wegenwacht Europa Service','roadside',66.00,'per year','frequent European road-trippers','Roadside assistance and recovery across Europe, including towing and replacement transport.'),
('P04','ANWB Doorlopende Reisverzekering','insurance',5.50,'per month','people who travel more than once a year','Annual travel insurance covering luggage, medical costs, and cancellations for all trips.'),
('P05','ANWB Kortlopende Reisverzekering','insurance',3.00,'per trip','occasional holidaymakers','Single-trip travel insurance for a specific holiday.'),
('P06','ANWB Autoverzekering','insurance',9.00,'per month','car owners','Car insurance with member discount and optional roadside cover.'),
('P07','ANWB Kampeerverzekering','insurance',4.00,'per trip','campers and caravanners','Insurance for tents, caravans, and camping equipment on trips.'),
('P08','ANWB Camping App & Gids','travel',0.00,'one-off','campers planning European trips','Digital and print camping guide with 9000+ inspected European campsites.'),
('P09','ANWB Energie','energy',0.00,'per month','cost-conscious households','Green energy for the home with member benefits and transparent tariffs.'),
('P10','ANWB Rijopleiding','travel',49.00,'one-off','learner drivers 16-24','Driving-lesson packages and theory training via ANWB partners.'),
('P11','ANWB Webshop Kampeerartikelen','shop',12.50,'one-off','campers and outdoor fans','Camping and travel gear: tents, cool boxes, navigation, safety kits.'),
('P12','ANWB Fietsverzekering','insurance',3.50,'per month','cyclists and e-bike owners','Bicycle and e-bike insurance against theft and damage, with member discount.');

-- ----------------------------------------------------------------------------
-- AUDIENCE_SEGMENTS — reusable target personas
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TABLE AUDIENCE_SEGMENTS (
    segment_id    VARCHAR(10) PRIMARY KEY,
    name          VARCHAR(80),
    age_range     VARCHAR(20),
    description   VARCHAR(300),
    top_channels  VARCHAR(120),
    key_motivator VARCHAR(160)
);

INSERT INTO AUDIENCE_SEGMENTS VALUES
('S01','Young families','30-45','Parents with school-age children planning affordable, safe family holidays by car.','Facebook, Instagram, email, YouTube','Safety, convenience, value for the whole family.'),
('S02','Active seniors','60-75','Retired members with time and budget for longer European road trips and camping.','Email, print magazine, Facebook','Peace of mind, reliability, being looked after abroad.'),
('S03','Young adventurers','18-29','Students and young professionals doing budget road trips, festivals, and city breaks.','Instagram, TikTok, YouTube','Freedom, spontaneity, low cost, shareable experiences.'),
('S04','EV early adopters','35-55','Tech-forward members driving electric vehicles who worry about charging on trips.','Email, YouTube, LinkedIn, Instagram','Range confidence, sustainability, smart planning.'),
('S05','Caravan enthusiasts','45-65','Experienced caravanners who take multiple camping trips across Europe each year.','Email, print magazine, Facebook groups','Expertise, community, protecting their investment.'),
('S06','Urban cyclists','25-45','City dwellers relying on bikes and e-bikes for daily transport.','Instagram, email, local out-of-home','Theft protection, convenience, sustainability.');

-- ----------------------------------------------------------------------------
-- PAST_CAMPAIGNS — prior campaigns for context / few-shot inspiration
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TABLE PAST_CAMPAIGNS (
    campaign_id   VARCHAR(10) PRIMARY KEY,
    name          VARCHAR(120),
    product_id    VARCHAR(10),
    segment_id    VARCHAR(10),
    year          INT,
    channel_mix   VARCHAR(120),
    tagline       VARCHAR(160),
    result_note   VARCHAR(200)
);

INSERT INTO PAST_CAMPAIGNS VALUES
('CM01','Zorgeloos op reis','P04','S01',2024,'Email + Meta + YouTube pre-roll','Zorgeloos op reis, waar je ook heen gaat','+18% policy sign-ups vs. prior year; strong email CTR.'),
('CM02','Nooit meer stil langs de weg','P03','S02',2024,'Print magazine + email + Facebook','Onderweg pech? Wij staan voor je klaar.','High renewal among seniors; low CAC on email.'),
('CM03','Laad op, rij door','P03','S04',2025,'YouTube + Instagram + email','Laad op, rij door — heel Europa binnen bereik','Best-performing EV creative; strong under-45 reach.'),
('CM04','Zomer op de camping','P08','S05',2025,'Email + Facebook groups + print','Jouw perfecte plek staat in de gids','Drove app downloads and guide sales in Q2.'),
('CM05','Veilig op de fiets','P12','S06',2025,'Instagram + out-of-home + email','Jouw fiets verzekerd, jouw vrijheid gedekt','Grew bike-insurance base among urban cyclists.');

-- ----------------------------------------------------------------------------
-- KB_DOCUMENTS — brand guidelines, tone of voice, and market context (RAG)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TABLE KB_DOCUMENTS (
    doc_id     VARCHAR(20) PRIMARY KEY,
    title      VARCHAR(160),
    category   VARCHAR(60),
    source     VARCHAR(60),
    content    VARCHAR(16000)
);

INSERT INTO KB_DOCUMENTS (doc_id, title, category, source, content) VALUES
('MB01','ANWB brand positioning','brand','Brand Guidelines',
'ANWB is the Royal Dutch Touring Club: a member organisation that has helped people travel safely and enjoyably for over 140 years. The brand promise is "onderweg thuis" — feeling looked after wherever you are. Core brand values: reliable, helpful, expert, approachable, and rooted in the Netherlands. ANWB is not a pushy commercial brand; it is a trusted companion. Campaigns should reinforce trust, safety, and genuine care for members rather than hard-selling. The iconic ANWB yellow signals recognition and reassurance on every road.'),
('MB02','Tone of voice','brand','Brand Guidelines',
'ANWB speaks in a warm, clear, and helpful voice — like a knowledgeable friend, never corporate or salesy. Guidelines: use plain Dutch (or plain English for international), address the member directly with "je", keep sentences short, and lead with the benefit to the member. Be optimistic and reassuring, especially around travel worries. Avoid jargon, fear-mongering, and superlatives that sound like advertising. Humour is welcome when light and human. Always be inclusive and accessible. Example do: "Onderweg pech? Wij staan voor je klaar." Example don''t: "Profiteer NU van de beste deal ooit!"'),
('MB03','Visual identity basics','brand','Brand Guidelines',
'The primary colour is ANWB yellow (a warm golden yellow) paired with dark blue and plenty of white space. Photography is real and human: members, families, and landscapes, natural light, no overly staged stock imagery. Use the ANWB logo with clear space around it and never recolour it. Typography is clean and legible. Presentations and campaign material should feel open, friendly, and uncluttered, with one clear message per slide or asset.'),
('MB04','Campaign planning framework','strategy','Marketing Playbook',
'Every ANWB campaign plan should cover: (1) Objective — what business result (awareness, sign-ups, renewals, app downloads); (2) Target audience — a specific segment with its motivator; (3) Key message — one benefit-led idea in the brand voice; (4) Channel mix — chosen for where the audience is; (5) Content and assets — hero message, supporting proof points, and a call to action; (6) Timeline and phasing; (7) KPIs and how success is measured. Keep the strategy focused: one primary audience and one core message per campaign outperform scattergun approaches.'),
('MB05','Channel guide','strategy','Marketing Playbook',
'Channel strengths at ANWB: Email — highest ROI, best for existing members, renewals, and personalised offers. Facebook/Meta — broad reach for families and seniors, good for awareness and retargeting. Instagram — younger members, visual travel inspiration, Stories and Reels. TikTok/YouTube — reach and storytelling for under-30s and EV/tech audiences. Print magazine (the ANWB ledenmagazine) — trusted, high-engagement with seniors and caravanners. Out-of-home — local, tactical awareness (e.g. urban cyclists). Match the channel mix to the segment''s top channels rather than defaulting to everything.'),
('MB06','Market context: Dutch travel and mobility 2026','market','Market Research',
'Trends shaping ANWB campaigns in 2026: camping and "staycation-plus" trips remain popular as households stay cost-conscious; electric-vehicle adoption keeps rising, and range anxiety on holidays is a top concern; sustainability influences choices, especially among under-45s; members increasingly research and book on mobile. Competitive context: online insurers and price-comparison sites pressure margins, so ANWB leans on trust, service, and roadside expertise as differentiators rather than price. Safety and "peace of mind" messaging consistently resonates across segments.'),
('MB07','Presentation structure for a campaign deck','strategy','Marketing Playbook',
'A strong campaign presentation follows this slide order: (1) Title — campaign name and one-line vision; (2) The opportunity — the audience insight and business context; (3) Target audience — the segment and its motivator; (4) Strategy — the core idea and why it works; (5) Key messaging — the tagline and supporting messages; (6) Channel plan — the mix and role of each channel; (7) Timeline — phases and key moments; (8) KPIs — how success is measured; (9) Call to action — the ask. Keep one clear idea per slide, use the brand voice, and end with a confident, member-centric close.');

-- ----------------------------------------------------------------------------
-- Data loaded checkpoint
-- ----------------------------------------------------------------------------
SELECT 'Marketing data loaded: '
    || (SELECT COUNT(*) FROM PRODUCTS) || ' products, '
    || (SELECT COUNT(*) FROM AUDIENCE_SEGMENTS) || ' segments, '
    || (SELECT COUNT(*) FROM PAST_CAMPAIGNS) || ' past campaigns, '
    || (SELECT COUNT(*) FROM KB_DOCUMENTS) || ' KB docs.' AS status;


-- ============================================================================
-- SEARCH  --  hybrid Cortex Search over the brand/marketing knowledge base.
-- (EXECUTE IMMEDIATE so the WAREHOUSE clause can use the CONFIG variable.)
-- ============================================================================
EXECUTE IMMEDIATE $$
BEGIN
  EXECUTE IMMEDIATE 'CREATE OR REPLACE CORTEX SEARCH SERVICE MARKETING_KB '
    || 'ON content ATTRIBUTES title, category, source '
    || 'WAREHOUSE = ' || $hb_wh || ' TARGET_LAG = ''1 hour'' '
    || 'AS (SELECT doc_id, title, category, source, content FROM KB_DOCUMENTS)';
  RETURN 'MARKETING_KB search service created';
END;
$$;


-- ============================================================================
-- BUILD  --  the multi-step Marketing Agent in SQL. Run these blocks top to
-- bottom. Scenario: a campaign for one product + audience segment.
-- ============================================================================

-- --- Step 1: pick a product + segment (the agent's inputs) -------------------
SELECT p.name AS product, p.description, s.name AS segment, s.key_motivator
FROM PRODUCTS p, AUDIENCE_SEGMENTS s
WHERE p.product_id = 'P01' AND s.segment_id = 'S01';

-- --- Step 2: campaign PLAN (RAG brand voice + playbook -> structured JSON) ----
-- Grounds on the marketing KB so tone + slide structure match ANWB guidelines.
SELECT AI_COMPLETE($hb_model,
    'Je bent de Marketing Agent van de ANWB. Maak een campagneplan als JSON met velden: '
 || 'campaign_name, big_idea, audience, key_messages (array), channels (array), kpis (array), '
 || 'slides (array van {title, bullets[]}). Gebruik de merkstem en de deckstructuur uit de kennisbank. '
 || 'Geen uitleg, alleen JSON, geen markdown-fences. '
 || 'Product: ' || (SELECT name||' - '||description FROM PRODUCTS WHERE product_id='P01')
 || '  Doelgroep: ' || (SELECT name||' ('||key_motivator||')' FROM AUDIENCE_SEGMENTS WHERE segment_id='S01')
 || '  Kennisbank (merkstem + deckstructuur): ' || (
        SELECT SUBSTR(TO_JSON(PARSE_JSON(
            SNOWFLAKE.CORTEX.SEARCH_PREVIEW('MARKETING_KB',
              '{"query":"merkstem tone of voice campagne deck structuur presentatie","columns":["title","content"],"limit":4}')
        ):results), 1, 3500)
    )
) AS campaign_plan_json;

-- --- Step 3: DECK (default = HTML; no extra packages, always works) ----------
-- Turn the campaign into a self-contained HTML slide deck you can open or embed.
SELECT AI_COMPLETE($hb_model,
    'Maak een nette, op zichzelf staande HTML-presentatie voor een ANWB-campagne: een <section> per slide, '
 || 'inline CSS, ANWB-geel #FFCC00 als accent. Volg de deckstructuur (titel, opportunity, doelgroep, strategie, '
 || 'messaging, kanalen, timeline, KPIs, call-to-action). Alleen HTML, geen uitleg, geen markdown-fences. '
 || 'Product: ' || (SELECT name||' - '||description FROM PRODUCTS WHERE product_id='P01')
 || '  Doelgroep: ' || (SELECT name||' ('||key_motivator||')' FROM AUDIENCE_SEGMENTS WHERE segment_id='S01')
) AS campaign_deck_html;


-- ============================================================================
-- OPTIONAL STRETCH  --  real .pptx via python-pptx.
-- Requires the Anaconda packages to be enabled (Snowsight > Admin >
-- Billing & Terms > accept Anaconda). Guarded so run-all does NOT fail if
-- python-pptx is unavailable - you simply keep the HTML deck above.
-- ============================================================================
CREATE STAGE IF NOT EXISTS DECKS;

EXECUTE IMMEDIATE $$
BEGIN
  CREATE OR REPLACE PROCEDURE build_deck(slides VARIANT, filename STRING)
  RETURNS STRING
  LANGUAGE PYTHON
  RUNTIME_VERSION = '3.11'
  PACKAGES = ('snowflake-snowpark-python', 'python-pptx')
  HANDLER = 'run'
  AS
  '
from pptx import Presentation
import io
def run(session, slides, filename):
    prs = Presentation()
    for s in slides:
        slide = prs.slides.add_slide(prs.slide_layouts[1])
        slide.shapes.title.text = s.get(''title'', '''')
        tf = slide.placeholders[1].text_frame
        for i, b in enumerate(s.get(''bullets'', [])):
            (tf.paragraphs[0] if i == 0 else tf.add_paragraph()).text = b
    buf = io.BytesIO(); prs.save(buf); buf.seek(0)
    session.file.put_stream(buf, f''@DECKS/{filename}'', auto_compress=False, overwrite=True)
    return f''@DECKS/{filename}''
  ';
  RETURN 'build_deck procedure created (.pptx available)';
EXCEPTION WHEN OTHER THEN
  RETURN 'build_deck skipped - enable Anaconda (python-pptx) for .pptx; the HTML deck already works';
END;
$$;


-- Final readiness line
SELECT 'Marketing Agent ready in ' || $hb_db || '.MARKETING  |  model=' || $hb_model
    || '  |  search=MARKETING_KB  |  deck: HTML (default) + optional .pptx via build_deck'
    AS status;

-- ============================================================================
-- SNOWSIGHT STEPS  --  the parts you do in the Snowsight UI (clicks, not SQL).
-- Do these after Run All above succeeds.
-- ----------------------------------------------------------------------------
-- STEP A - Build the Marketing Agent
--   1. Left nav > AI & ML > Agents > "+ Agent" (Create agent).
--   2. Schema HACKATHON_BOX.MARKETING; name it MARKETING_AGENT; Create.
--   3. Open the agent > Tools > Add > Cortex Search:
--        HACKATHON_BOX.MARKETING.MARKETING_KB   (brand voice + deck structure)
--   4. Model = mistral-large2. Instructions: "You are the ANWB Marketing Agent.
--      Given a product + audience, produce a structured campaign plan and a
--      presentation outline, grounded in the brand knowledge base."
--   5. Save, open the chat, and ask e.g.:
--        - "Maak een campagne voor ANWB Wegenwacht Europa voor actieve senioren."
--      Success = a structured plan + presentation output with visible steps.
--
-- STEP B (optional) - Ship the app
--   Projects > Streamlit > "+ Streamlit App"; warehouse HACKATHON_WH, database
--   HACKATHON_BOX, schema MARKETING. Paste app.py from this folder and Run.
--
-- STEP C (optional) - Real .pptx deck
--   Enable Anaconda (Admin > Billing & Terms), then
--     CALL MARKETING.build_deck(<slides JSON>, 'deck.pptx');
--   and download it from the DECKS stage (Data > Databases > ... > DECKS).
--
-- STEP D (optional) - Inspect what the agent did (AI Observability)
--   AI & ML > Agents > MARKETING_AGENT > Monitoring: traces, tool calls, latency, tokens.
-- ============================================================================
