-- ============================================================================
-- ANWB AI Hackathon - Capability Tour (optional)
-- ----------------------------------------------------------------------------
-- Hands-on, runnable snippets for the Snowflake Cortex capabilities that the two
-- challenges do NOT already demo - so you can see each one and score it.
-- Complements the two use cases (which cover RAG, agents, tools, the LLM gateway
-- and tracing) and preflight_check.sql (which only confirms features are enabled).
--
-- HOW TO RUN : paste into a Snowsight worksheet with any warehouse selected and
--              click Run All; each statement shows its own result. Nothing is
--              created - the snippets are stateless AI function calls plus one
--              read-only ACCOUNT_USAGE query.
-- MODELS     : uses the EU-native mistral-large2 where a model is needed.
-- NOTE       : the last section (Guardrails) needs cross-region inference and is
--              expected to be N/A on EU-only accounts - that's fine, skip it.
-- ============================================================================


-- ============================================================================
-- 1. AISQL - task functions (Skill registry, content understanding)
-- One-line AI functions you call like SQL. Each maps to a capability ANWB tests.
-- ============================================================================

-- Classify free text into your own labels (routing / triage).
SELECT AI_CLASSIFY('Ik zoek een camping met zwembad in Italie',
                   ['travel','automotive','finance']):labels[0]::string AS classified;

-- Boolean filter: keep only rows that satisfy a natural-language condition.
SELECT AI_FILTER('Is Rome located in Italy?') AS passes_condition;

-- Sentiment score (-1 negative .. 1 positive).
SELECT SNOWFLAKE.CORTEX.SENTIMENT('De Wegenwacht hielp me binnen 20 minuten, top service!') AS sentiment;

-- Translate (here EN -> NL).
SELECT SNOWFLAKE.CORTEX.TRANSLATE('Where is the nearest campsite with EV charging?','en','nl') AS translated;

-- Extract structured fields from unstructured text.
SELECT AI_EXTRACT('Jan rijdt een diesel camper, bouwjaar 2011, EURO 4.',
                  ['brandstof','bouwjaar','euronorm']) AS extracted;

-- Summarize across many rows in one call (aggregate summarization).
SELECT AI_SUMMARIZE_AGG(review) AS summary
FROM (SELECT 'Rustige familiecamping, schoon sanitair.' AS review
      UNION ALL SELECT 'Mooie ligging aan het meer, maar druk in het hoogseizoen.'
      UNION ALL SELECT 'Goede prijs-kwaliteit, vriendelijk personeel.');


-- ============================================================================
-- 2. Embeddings + similarity  (the primitives under RAG / semantic search)
-- Turn text into vectors and score how close two pieces of meaning are.
-- ============================================================================

-- Related vs unrelated: the related pair scores much higher (0..1).
SELECT
  VECTOR_COSINE_SIMILARITY(
    AI_EMBED('snowflake-arctic-embed-l-v2.0','lakeside camping in Austria'),
    AI_EMBED('snowflake-arctic-embed-l-v2.0','camping bij een meer in Oostenrijk')) AS related_pair,
  VECTOR_COSINE_SIMILARITY(
    AI_EMBED('snowflake-arctic-embed-l-v2.0','lakeside camping in Austria'),
    AI_EMBED('snowflake-arctic-embed-l-v2.0','car insurance premium calculation')) AS unrelated_pair;


-- ============================================================================
-- 3. Evaluation  (LLM-as-a-judge)
-- Use a model to score another model's answer - the pattern behind AI evals.
-- ============================================================================
SELECT AI_COMPLETE('mistral-large2',
  'You are grading an answer. Question: "What is the capital of Austria?" '
  || 'Answer: "Vienna". Reply ONLY with a score 1-5 for correctness and a 5-word reason.'
) AS judge_verdict;


-- ============================================================================
-- 4. Observability / tracing  (usage, tokens, cost)
-- Account-level view of Cortex usage - complements the agent Monitoring tab.
-- Needs a role that can read SNOWFLAKE.ACCOUNT_USAGE (e.g. ACCOUNTADMIN).
-- ============================================================================
SELECT function_name,
       COUNT(*)            AS calls,
       SUM(tokens)         AS total_tokens,
       ROUND(SUM(token_credits), 4) AS credits
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_FUNCTIONS_USAGE_HISTORY
WHERE start_time >= DATEADD('day', -7, CURRENT_TIMESTAMP())
GROUP BY function_name
ORDER BY credits DESC NULLS LAST;


-- ============================================================================
-- 5. Guardrails  (CROSS-REGION ONLY - expected N/A on EU-only accounts)
-- Cortex Guard filters unsafe model output; AI_REDACT masks PII. Both rely on
-- models that need a broad cross-region setting - skip this section if EU-only.
-- ============================================================================

-- Cortex Guard: same COMPLETE call, with the guardrails flag on.
SELECT SNOWFLAKE.CORTEX.COMPLETE('mistral-large2',
         [{'role':'user','content':'Give me a safe two-line camping tip.'}],
         {'guardrails': TRUE}):choices[0]:messages::string AS guarded_answer;

-- AI_REDACT (PREVIEW): mask personal data before it reaches a model or a log.
SELECT AI_REDACT('Bel Jan Jansen op jan@example.com of 06-12345678.') AS redacted;


-- ============================================================================
-- 6. Also assessed - where to see it (no snippet: needs UI / Python / setup)
-- ----------------------------------------------------------------------------
--   * Cortex Analyst (text-to-SQL): build a Semantic View over your tables, then
--     query it from Snowsight (AI & ML > Studio) or wire it into a Cortex Agent.
--   * Model deployment / registry + SPCS: register and serve custom models via
--     the Python Model Registry (snowflake-ml-python), served on compute pools.
--   * Prompt management (versioned prompts): store prompts in a Git repository
--     connected to Snowflake (Git integration) for versioning.
--   * No-code Agent Builder + Agent/Tool registry: AI & ML > Agents (this is the
--     manual step the two challenges walk you through).
-- ============================================================================
