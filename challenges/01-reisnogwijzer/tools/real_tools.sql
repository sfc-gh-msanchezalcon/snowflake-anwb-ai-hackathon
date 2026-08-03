-- ============================================================================
-- OPTIONAL: REAL external tools - live API calls via an External Access Integration.
-- No API keys needed (RDW open data + open-meteo are public).
-- Requires a role with CREATE INTEGRATION (typically ACCOUNTADMIN) AND outbound
-- egress. If your network policy blocks egress, skip this - reisnogwijzer.sql already
-- created zero-setup MOCK tools that work offline.
-- Run this AFTER reisnogwijzer.sql (it reuses the same database + schema).
-- ----------------------------------------------------------------------------
-- NOTE - the real tools are drop-in replacements for the mocks:
--   * Signatures match (same args, VARIANT out), so real_rdw_lookup / real_weather
--     swap straight in for the mock versions in the agent, app or SQL.
--   * real_rdw_lookup returns live RDW data AND a derived 'euronorm' (parsed from
--     RDW's emissiecode_omschrijving / uitlaatemissieniveau), so Q1's Munich
--     diesel-ban logic works end-to-end on real data - just like the mock.
--   * The VALUES differ from the mock's fictional demo vehicles, and the demo
--     plates in reisnogwijzer.sql (XD-429-P, ...) are fictional - real_rdw_lookup
--     needs a REAL Dutch plate (the smoke test at the bottom uses a working one).
--   * There is no real advisory or currency tool - keep those on mock.
-- ============================================================================
USE ROLE ACCOUNTADMIN;   -- creating an External Access Integration requires this

-- Auto-target the database + warehouse from your main run. Nothing to match or
-- edit - even if you renamed the DB in the CONFIG block: we just find the database
-- whose TRAVEL schema you created and use it, and reuse your challenge warehouse.
SHOW TERSE SCHEMAS LIKE 'TRAVEL' IN ACCOUNT;
SET challenge_db = (SELECT "database_name" FROM TABLE(RESULT_SCAN(LAST_QUERY_ID())) ORDER BY "created_on" DESC LIMIT 1);
USE DATABASE IDENTIFIER($challenge_db);
USE SCHEMA TRAVEL;
SHOW TERSE WAREHOUSES LIKE 'ANWB_AI_HACKATHON_WH';
SET challenge_wh = (SELECT COALESCE(MAX("name"), CURRENT_WAREHOUSE()) FROM TABLE(RESULT_SCAN(LAST_QUERY_ID())));
USE WAREHOUSE IDENTIFIER($challenge_wh);

-- 1. Allow outbound HTTPS to the two public APIs only
CREATE OR REPLACE NETWORK RULE hackathon_api_network_rule
    MODE = EGRESS
    TYPE = HOST_PORT
    VALUE_LIST = (
        'opendata.rdw.nl',
        'api.open-meteo.com',
        'geocoding-api.open-meteo.com'
    );

-- 2. External Access Integration wrapping that rule
CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION hackathon_ext_access
    ALLOWED_NETWORK_RULES = (hackathon_api_network_rule)
    ENABLED = TRUE
    COMMENT = 'Outbound access for the ANWB hackathon travel tools (RDW + open-meteo)';

-- 3. Real RDW vehicle lookup (Dutch open vehicle register)
CREATE OR REPLACE FUNCTION real_rdw_lookup(kenteken VARCHAR)
RETURNS VARIANT
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
HANDLER = 'lookup'
EXTERNAL_ACCESS_INTEGRATIONS = (hackathon_ext_access)
PACKAGES = ('requests')
AS
$$
import requests, re
def lookup(kenteken):
    plate = (kenteken or '').replace('-', '').replace(' ', '').upper()
    base = 'https://opendata.rdw.nl/resource/'
    try:
        r = requests.get(base + 'm9d7-ebf2.json', params={'kenteken': plate}, timeout=10)
        rows = r.json()
        if not rows:
            return {'kenteken': kenteken, 'found': False, 'note': 'plate not found in RDW'}
        v = rows[0]
        fuel = None
        euronorm = None
        emissieniveau = None
        try:
            fr = requests.get(base + '8ys7-d773.json', params={'kenteken': plate}, timeout=10)
            fj = fr.json()
            if fj:
                fuel = fj[0].get('brandstof_omschrijving')
                emissieniveau = fj[0].get('uitlaatemissieniveau')     # e.g. 'EURO 6'
                ec = fj[0].get('emissiecode_omschrijving')            # e.g. '6'
                if ec is not None and str(ec).strip().isdigit():
                    euronorm = int(str(ec).strip())
                elif emissieniveau:
                    m = re.search(r'(\d+)', emissieniveau)
                    if m:
                        euronorm = int(m.group(1))
        except Exception:
            pass
        return {
            'kenteken': kenteken,
            'found': True,
            'source': 'RDW open data (live via EAI)',
            'merk': v.get('merk'),
            'model': v.get('handelsbenaming'),
            'brandstof': fuel,
            'euronorm': euronorm,                 # derived - drives Q1 diesel-ban logic
            'uitlaatemissieniveau': emissieniveau,
            'bouwjaar': (v.get('datum_eerste_toelating') or '')[:4],
            'voertuigsoort': v.get('voertuigsoort'),
            'gewicht_kg': v.get('massa_ledig_voertuig'),
        }
    except Exception as e:
        return {'kenteken': kenteken, 'error': str(e)}
$$;

-- 4. Real weather via open-meteo (geocode the place, then fetch the forecast)
CREATE OR REPLACE FUNCTION real_weather(location VARCHAR)
RETURNS VARIANT
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
HANDLER = 'get_weather'
EXTERNAL_ACCESS_INTEGRATIONS = (hackathon_ext_access)
PACKAGES = ('requests')
AS
$$
import requests
def get_weather(location):
    try:
        g = requests.get('https://geocoding-api.open-meteo.com/v1/search',
                         params={'name': location, 'count': 1}, timeout=10).json()
        if not g.get('results'):
            return {'location': location, 'found': False}
        loc = g['results'][0]
        lat, lon = loc['latitude'], loc['longitude']
        w = requests.get('https://api.open-meteo.com/v1/forecast',
                         params={'latitude': lat, 'longitude': lon,
                                 'current': 'temperature_2m,weather_code',
                                 'daily': 'temperature_2m_max,weather_code',
                                 'forecast_days': 3, 'timezone': 'auto'}, timeout=10).json()
        return {
            'location': loc.get('name'),
            'country': loc.get('country'),
            'current_temp_c': w.get('current', {}).get('temperature_2m'),
            'daily_max_c': w.get('daily', {}).get('temperature_2m_max'),
            'source': 'open-meteo',
        }
    except Exception as e:
        return {'location': location, 'error': str(e)}
$$;

-- Smoke test - proves the External Access Integration reached the LIVE APIs.
-- open-meteo needs no plate. RDW needs a REAL Dutch plate (the demo plates in
-- reisnogwijzer.sql are fictional); 0047ZZ is a real diesel, EURO 6, so you can
-- see the derived 'euronorm' come back from live data.
SELECT real_weather('Munich')    AS live_weather,     -- live forecast (open-meteo)
       real_rdw_lookup('0047ZZ') AS live_vehicle;     -- live RDW record incl. euronorm
