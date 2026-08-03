-- ============================================================================
-- ANWB AI Hackathon - Account Readiness Check
-- ----------------------------------------------------------------------------
-- WHERE TO RUN : In your hackathon account, in a single Snowsight worksheet,
--                as ACCOUNTADMIN.
-- WHAT IT DOES : Checks that the Snowflake AI features the challenges use (plus
--                a few extras) are enabled and reachable in this account/region.
-- SAFETY       : 100% READ-ONLY. Creates nothing, changes nothing. Probes run
--                in-memory inference / SHOW / ACCOUNT_USAGE reads only.
-- HOW TO READ  : Run PART 0, then PART 1. PART 1 returns ONE JSON object with a
--                PASS/FAIL per feature, grouped by feature area. PART 2 is an
--                optional UI checklist for items SQL cannot prove.
-- ============================================================================

-- ============================================================================
-- PART 0 - Where am I?  (confirm account + region BEFORE trusting anything)
-- ============================================================================
SELECT CURRENT_ACCOUNT()          AS account,
       CURRENT_REGION()           AS region,
       CURRENT_ROLE()             AS role,
       CURRENT_AVAILABLE_ROLES()  AS available_roles;

-- ============================================================================
-- PART 1 - Capability report  (THE MAIN RESULT)
-- ----------------------------------------------------------------------------
-- One JSON object. Keys are prefixed with a feature area so they group when
-- sorted. Every value should read "PASS". A "FAIL" means that feature is not
-- enabled/reachable in this account/region.
-- ============================================================================
EXECUTE IMMEDIATE $$
DECLARE
  r OBJECT;
  n INT;
BEGIN
  r := OBJECT_CONSTRUCT();

  ---------------------------------------------------------------------------
  -- 00  Critical account setting
  ---------------------------------------------------------------------------
  BEGIN
    EXECUTE IMMEDIATE 'SHOW PARAMETERS LIKE ''CORTEX_ENABLED_CROSS_REGION'' IN ACCOUNT';
    LET xr STRING := (SELECT "value" FROM TABLE(RESULT_SCAN(LAST_QUERY_ID())));
    r := OBJECT_INSERT(r,'00 Setting / CORTEX_ENABLED_CROSS_REGION',
         IFF(:xr ILIKE '%DISABLED%','FAIL (DISABLED - blocks Claude/GPT + Cortex Guard)','PASS ('||:xr||')'),TRUE);
  EXCEPTION WHEN OTHER THEN r := OBJECT_INSERT(r,'00 Setting / CORTEX_ENABLED_CROSS_REGION','FAIL: '||LEFT(:SQLERRM,60),TRUE); END;

  ---------------------------------------------------------------------------
  -- 01  LLM Gateway  -> multi-model providers, model comparison
  ---------------------------------------------------------------------------
  -- EU-native models (Frankfurt / AWS_EU). These are the models the kit uses.
  BEGIN LET v STRING := SNOWFLAKE.CORTEX.COMPLETE('mistral-large2','say ok');
    r := OBJECT_INSERT(r,'01 LLM Gateway / model mistral-large2 (default)','PASS',TRUE);
  EXCEPTION WHEN OTHER THEN r := OBJECT_INSERT(r,'01 LLM Gateway / model mistral-large2 (default)','FAIL: '||LEFT(:SQLERRM,60),TRUE); END;
  BEGIN LET v STRING := SNOWFLAKE.CORTEX.COMPLETE('llama3.3-70b','say ok');
    r := OBJECT_INSERT(r,'01 LLM Gateway / model llama3.3-70b (alt provider)','PASS',TRUE);
  EXCEPTION WHEN OTHER THEN r := OBJECT_INSERT(r,'01 LLM Gateway / model llama3.3-70b (alt provider)','FAIL: '||LEFT(:SQLERRM,60),TRUE); END;
  -- US-only models (Claude, OpenAI GPT, llama4-maverick) require cross-region
  -- inference (ANY_REGION/AWS_US) and are NOT reachable under EU-only residency.
  r := OBJECT_INSERT(r,'01 LLM Gateway / US-only models (Claude, GPT, llama4-maverick)',
       'N/A under EU-only cross-region (expected) - not needed by the kit',TRUE);

  ---------------------------------------------------------------------------
  -- 02  Core AISQL functions (used across Gateway, Guardrails, RAG)
  ---------------------------------------------------------------------------
  BEGIN LET v STRING := AI_COMPLETE('mistral-large2','hi');
    r := OBJECT_INSERT(r,'02 AISQL / AI_COMPLETE','PASS',TRUE);
  EXCEPTION WHEN OTHER THEN r := OBJECT_INSERT(r,'02 AISQL / AI_COMPLETE','FAIL: '||LEFT(:SQLERRM,60),TRUE); END;
  BEGIN LET v STRING := AI_CLASSIFY('camping trip', ARRAY_CONSTRUCT('travel','automotive')):labels[0]::string;
    r := OBJECT_INSERT(r,'02 AISQL / AI_CLASSIFY','PASS ('||:v||')',TRUE);
  EXCEPTION WHEN OTHER THEN r := OBJECT_INSERT(r,'02 AISQL / AI_CLASSIFY','FAIL: '||LEFT(:SQLERRM,60),TRUE); END;
  BEGIN LET b BOOLEAN := AI_FILTER('is 2 greater than 1?');
    r := OBJECT_INSERT(r,'02 AISQL / AI_FILTER','PASS',TRUE);
  EXCEPTION WHEN OTHER THEN r := OBJECT_INSERT(r,'02 AISQL / AI_FILTER','FAIL: '||LEFT(:SQLERRM,60),TRUE); END;
  BEGIN LET v STRING := TO_JSON(AI_EXTRACT('John lives in Paris', ['who','where']));
    r := OBJECT_INSERT(r,'02 AISQL / AI_EXTRACT','PASS',TRUE);
  EXCEPTION WHEN OTHER THEN r := OBJECT_INSERT(r,'02 AISQL / AI_EXTRACT','FAIL: '||LEFT(:SQLERRM,60),TRUE); END;
  BEGIN LET ok BOOLEAN := (AI_EMBED('snowflake-arctic-embed-l-v2.0','hello') IS NOT NULL);
    r := OBJECT_INSERT(r,'02 AISQL / AI_EMBED','PASS',TRUE);
  EXCEPTION WHEN OTHER THEN r := OBJECT_INSERT(r,'02 AISQL / AI_EMBED','FAIL: '||LEFT(:SQLERRM,60),TRUE); END;
  BEGIN LET v STRING := SNOWFLAKE.CORTEX.TRANSLATE('hello','en','nl');
    r := OBJECT_INSERT(r,'02 AISQL / TRANSLATE','PASS ('||:v||')',TRUE);
  EXCEPTION WHEN OTHER THEN r := OBJECT_INSERT(r,'02 AISQL / TRANSLATE','FAIL: '||LEFT(:SQLERRM,60),TRUE); END;
  BEGIN LET v STRING := SNOWFLAKE.CORTEX.SENTIMENT('I love this')::STRING;
    r := OBJECT_INSERT(r,'02 AISQL / SENTIMENT','PASS',TRUE);
  EXCEPTION WHEN OTHER THEN r := OBJECT_INSERT(r,'02 AISQL / SENTIMENT','FAIL: '||LEFT(:SQLERRM,60),TRUE); END;
  BEGIN LET v STRING := (SELECT AI_SUMMARIZE_AGG(c) FROM (SELECT 'the cat sat' c UNION ALL SELECT 'the dog ran'));
    r := OBJECT_INSERT(r,'02 AISQL / AI_SUMMARIZE_AGG','PASS',TRUE);
  EXCEPTION WHEN OTHER THEN r := OBJECT_INSERT(r,'02 AISQL / AI_SUMMARIZE_AGG','FAIL: '||LEFT(:SQLERRM,60),TRUE); END;

  ---------------------------------------------------------------------------
  -- 03  Guardrails  -> toxicity, prompt injection, PII, decisions
  ---------------------------------------------------------------------------
  -- Cortex Guard needs cross-region (ANY_REGION/AWS_US); expect N/A under EU-only.
  BEGIN LET g VARIANT := SNOWFLAKE.CORTEX.COMPLETE('mistral-large2',[{'role':'user','content':'hi'}],{'guardrails':TRUE});
    r := OBJECT_INSERT(r,'03 Guardrails / Cortex Guard (needs cross-region)', IFF(:g IS NOT NULL,'PASS','FAIL: null'),TRUE);
  EXCEPTION WHEN OTHER THEN r := OBJECT_INSERT(r,'03 Guardrails / Cortex Guard (needs cross-region)','N/A under EU-only (expected): '||LEFT(:SQLERRM,50),TRUE); END;
  BEGIN LET v STRING := AI_REDACT('call John Smith at john@example.com');
    r := OBJECT_INSERT(r,'03 Guardrails / AI_REDACT (PREVIEW)','PASS ('||:v||')',TRUE);
  EXCEPTION WHEN OTHER THEN r := OBJECT_INSERT(r,'03 Guardrails / AI_REDACT (PREVIEW)','FAIL: '||LEFT(:SQLERRM,60),TRUE); END;

  ---------------------------------------------------------------------------
  -- 04  Evaluation  -> LLM-as-a-judge (AI_JUDGE is NOT GA; use judge prompt)
  ---------------------------------------------------------------------------
  BEGIN LET v STRING := AI_COMPLETE('mistral-large2','Score 1-5 how correct. Q: 2+2? A: 4. Reply only a number.');
    r := OBJECT_INSERT(r,'04 Evaluation / LLM-as-judge (AI_COMPLETE prompt)','PASS',TRUE);
  EXCEPTION WHEN OTHER THEN r := OBJECT_INSERT(r,'04 Evaluation / LLM-as-judge (AI_COMPLETE prompt)','FAIL: '||LEFT(:SQLERRM,60),TRUE); END;

  ---------------------------------------------------------------------------
  -- 05  RAG  -> embeddings, hybrid search, freshness
  ---------------------------------------------------------------------------
  BEGIN LET ok BOOLEAN := (SNOWFLAKE.CORTEX.EMBED_TEXT_768('snowflake-arctic-embed-m-v1.5','hi') IS NOT NULL);
    r := OBJECT_INSERT(r,'05 RAG / EMBED_TEXT_768','PASS',TRUE);
  EXCEPTION WHEN OTHER THEN r := OBJECT_INSERT(r,'05 RAG / EMBED_TEXT_768','FAIL: '||LEFT(:SQLERRM,60),TRUE); END;
  BEGIN EXECUTE IMMEDIATE 'SHOW CORTEX SEARCH SERVICES IN ACCOUNT'; n := (SELECT COUNT(*) FROM TABLE(RESULT_SCAN(LAST_QUERY_ID())));
    r := OBJECT_INSERT(r,'05 RAG / Cortex Search (hybrid vector store)','PASS ('||:n||' services)',TRUE);
  EXCEPTION WHEN OTHER THEN r := OBJECT_INSERT(r,'05 RAG / Cortex Search (hybrid vector store)','FAIL: '||LEFT(:SQLERRM,60),TRUE); END;

  ---------------------------------------------------------------------------
  -- 06  Agent Runtime + Agent Registry  -> Cortex Agents, versioning, catalogue
  ---------------------------------------------------------------------------
  BEGIN EXECUTE IMMEDIATE 'SHOW AGENTS IN ACCOUNT'; n := (SELECT COUNT(*) FROM TABLE(RESULT_SCAN(LAST_QUERY_ID())));
    r := OBJECT_INSERT(r,'06 Agent Runtime+Registry / Cortex Agents','PASS ('||:n||' agents)',TRUE);
  EXCEPTION WHEN OTHER THEN r := OBJECT_INSERT(r,'06 Agent Runtime+Registry / Cortex Agents','FAIL: '||LEFT(:SQLERRM,60),TRUE); END;
  BEGIN EXECUTE IMMEDIATE 'SHOW MCP SERVERS IN ACCOUNT'; n := (SELECT COUNT(*) FROM TABLE(RESULT_SCAN(LAST_QUERY_ID())));
    r := OBJECT_INSERT(r,'06 Agent Runtime / MCP interface (SHOW MCP SERVERS)','PASS ('||:n||')',TRUE);
  EXCEPTION WHEN OTHER THEN r := OBJECT_INSERT(r,'06 Agent Runtime / MCP interface (SHOW MCP SERVERS)','FAIL: '||LEFT(:SQLERRM,60),TRUE); END;

  ---------------------------------------------------------------------------
  -- 07  Cortex Analyst (text-to-SQL, used by agents)
  ---------------------------------------------------------------------------
  BEGIN EXECUTE IMMEDIATE 'SHOW SEMANTIC VIEWS IN ACCOUNT'; n := (SELECT COUNT(*) FROM TABLE(RESULT_SCAN(LAST_QUERY_ID())));
    r := OBJECT_INSERT(r,'07 Cortex Analyst / Semantic Views','PASS ('||:n||')',TRUE);
  EXCEPTION WHEN OTHER THEN r := OBJECT_INSERT(r,'07 Cortex Analyst / Semantic Views','FAIL: '||LEFT(:SQLERRM,60),TRUE); END;

  ---------------------------------------------------------------------------
  -- 08  AI Model Deployment  -> Model Registry, SPCS (custom / BYOM serving)
  ---------------------------------------------------------------------------
  BEGIN EXECUTE IMMEDIATE 'SHOW MODELS IN ACCOUNT'; n := (SELECT COUNT(*) FROM TABLE(RESULT_SCAN(LAST_QUERY_ID())));
    r := OBJECT_INSERT(r,'08 Model Deployment / Model Registry','PASS ('||:n||' models)',TRUE);
  EXCEPTION WHEN OTHER THEN r := OBJECT_INSERT(r,'08 Model Deployment / Model Registry','FAIL: '||LEFT(:SQLERRM,60),TRUE); END;
  BEGIN EXECUTE IMMEDIATE 'SHOW COMPUTE POOLS'; n := (SELECT COUNT(*) FROM TABLE(RESULT_SCAN(LAST_QUERY_ID())));
    r := OBJECT_INSERT(r,'08 Model Deployment / SPCS compute pools (BYOM)','PASS ('||:n||')',TRUE);
  EXCEPTION WHEN OTHER THEN r := OBJECT_INSERT(r,'08 Model Deployment / SPCS compute pools (BYOM)','FAIL: '||LEFT(:SQLERRM,60),TRUE); END;

  ---------------------------------------------------------------------------
  -- 09  Prompt Management  -> Git integration for versioned prompts
  ---------------------------------------------------------------------------
  BEGIN EXECUTE IMMEDIATE 'SHOW GIT REPOSITORIES IN ACCOUNT'; n := (SELECT COUNT(*) FROM TABLE(RESULT_SCAN(LAST_QUERY_ID())));
    r := OBJECT_INSERT(r,'09 Prompt Mgmt / Git integration','PASS ('||:n||' repos)',TRUE);
  EXCEPTION WHEN OTHER THEN r := OBJECT_INSERT(r,'09 Prompt Mgmt / Git integration','FAIL: '||LEFT(:SQLERRM,60),TRUE); END;

  ---------------------------------------------------------------------------
  -- 10  System integrations + Alerts
  ---------------------------------------------------------------------------
  BEGIN EXECUTE IMMEDIATE 'SHOW EXTERNAL ACCESS INTEGRATIONS'; n := (SELECT COUNT(*) FROM TABLE(RESULT_SCAN(LAST_QUERY_ID())));
    r := OBJECT_INSERT(r,'10 Integrations / External Access (REST/HTTP)','PASS ('||:n||')',TRUE);
  EXCEPTION WHEN OTHER THEN r := OBJECT_INSERT(r,'10 Integrations / External Access (REST/HTTP)','FAIL: '||LEFT(:SQLERRM,60),TRUE); END;
  BEGIN EXECUTE IMMEDIATE 'SHOW NOTIFICATION INTEGRATIONS'; n := (SELECT COUNT(*) FROM TABLE(RESULT_SCAN(LAST_QUERY_ID())));
    r := OBJECT_INSERT(r,'10 Alerts / Notification Integrations','PASS ('||:n||')',TRUE);
  EXCEPTION WHEN OTHER THEN r := OBJECT_INSERT(r,'10 Alerts / Notification Integrations','FAIL: '||LEFT(:SQLERRM,60),TRUE); END;

  ---------------------------------------------------------------------------
  -- 11  Observability / Tracing  -> ACCOUNT_USAGE + AI observability
  ---------------------------------------------------------------------------
  BEGIN LET c INT := (SELECT COUNT(*) FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_FUNCTIONS_USAGE_HISTORY);
    r := OBJECT_INSERT(r,'11 Observability / CORTEX_FUNCTIONS_USAGE_HISTORY','PASS',TRUE);
  EXCEPTION WHEN OTHER THEN r := OBJECT_INSERT(r,'11 Observability / CORTEX_FUNCTIONS_USAGE_HISTORY','FAIL: '||LEFT(:SQLERRM,60),TRUE); END;
  BEGIN LET c INT := (SELECT COUNT(*) FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_HISTORY);
    r := OBJECT_INSERT(r,'11 Observability / METERING_HISTORY (cost)','PASS',TRUE);
  EXCEPTION WHEN OTHER THEN r := OBJECT_INSERT(r,'11 Observability / METERING_HISTORY (cost)','FAIL: '||LEFT(:SQLERRM,60),TRUE); END;
  BEGIN LET c INT := (SELECT COUNT(*) FROM SNOWFLAKE.ACCOUNT_USAGE.ACCESS_HISTORY);
    r := OBJECT_INSERT(r,'11 Observability / ACCESS_HISTORY (audit)','PASS',TRUE);
  EXCEPTION WHEN OTHER THEN r := OBJECT_INSERT(r,'11 Observability / ACCESS_HISTORY (audit)','FAIL: '||LEFT(:SQLERRM,60),TRUE); END;
  BEGIN LET c INT := (SELECT COUNT(*) FROM SNOWFLAKE.LOCAL.AI_OBSERVABILITY_EVENTS);
    r := OBJECT_INSERT(r,'11 Observability / AI_OBSERVABILITY_EVENTS (traces)','PASS',TRUE);
  EXCEPTION WHEN OTHER THEN r := OBJECT_INSERT(r,'11 Observability / AI_OBSERVABILITY_EVENTS (traces)','FAIL: '||LEFT(:SQLERRM,60),TRUE); END;

  RETURN TO_JSON(r);
END;
$$;

-- ============================================================================
-- PART 2 - MANUAL / UI VERIFICATION CHECKLIST
-- ----------------------------------------------------------------------------
-- A few features can't be proven by SQL. Tick them off in the Snowsight UI
-- (a few minutes, ACCOUNTADMIN):
--
--   [ ] Cortex AI Studio / Playground  (model comparison, evaluation
--       playground, low-code agent builder)
--       -> Snowsight > AI & ML > Studio.  Confirm Playground opens and lists
--          multiple models side by side.
--   [ ] Snowsight Agent Builder (low-code agent builder)
--       -> Snowsight > AI & ML > Agents.  Confirm "Create agent" is available.
--   [ ] Trust Center (Monitoring: system health / security scanners)
--       -> Snowsight > Monitoring > Trust Center.  Confirm scanners are enabled.
--   [ ] Account Edition & SLA
--       -> Snowsight > Admin > Accounts.  Confirm edition (Enterprise required
--          for Cortex Guardrails; Business Critical for 99.99% SLA / PHI).
--   [ ] Provisioned Throughput (priority throughput / latency)
--       -> Confirm with your Snowflake team whether PT is enabled if you need
--          reserved model capacity (optional for the hackathon).
--   [ ] Multimodal image input + AI_PARSE_DOCUMENT + AI_TRANSCRIBE
--       -> These need a file staged to test; validate during the RAG /
--          document challenge rather than here.
--   [ ] Streaming & async COMPLETE (behavioural, tested via REST API / SDK,
--       not a plain SQL probe).
--   [ ] Backup/DR: Time Travel is on by default; Replication is
--       account-config - confirm only if disaster recovery is in scope.
-- ============================================================================

-- ============================================================================
-- INTERPRETING RESULTS
-- ----------------------------------------------------------------------------
-- PART 1: every value should read "PASS" (or the expected "N/A" notes below).
--   * If your account runs EU-only cross-region (AWS_EU/AZURE_EU) for data
--     residency, the kit uses mistral-large2 / llama3.3-70b.
--   * 00 Setting FAIL only if DISABLED  -> run, as ACCOUNTADMIN:
--        ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'AWS_EU';
--     (AWS_EU keeps inference in-region. ANY_REGION would add Claude/GPT +
--      Cortex Guard but sends inference to the US - not the EU-only choice.)
--   * 01 US-only models + 03 Cortex Guard show "N/A under EU-only" by design -
--     these are NOT blockers and NOT used by the hackathon challenges.
--   * 03 AI_REDACT is PREVIEW - a FAIL is not a blocker; GA fallback is
--     Dynamic Data Masking + Sensitive Data Classification.
--   * SHOW-based checks showing 0 objects is FINE (nothing created yet); only
--     an actual error is a real FAIL.
--   * "Unknown function AI_JUDGE" is expected - LLM-as-judge uses AI_COMPLETE.
-- Any FAIL prints a short reason; account-level fixes may need your ACCOUNTADMIN.
-- ============================================================================
