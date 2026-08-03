-- ============================================================================
-- OPTIONAL: REAL external tools - live API calls via an External Access Integration.
-- No API keys needed (RDW open data + open-meteo are public).
-- Requires a role with CREATE INTEGRATION (typically ACCOUNTADMIN) AND outbound
-- egress. If your network policy blocks egress, skip this - reisnogwijzer.sql already
-- created zero-setup MOCK tools that work offline.
-- Run this AFTER reisnogwijzer.sql (it reuses the same database + schema).
-- ============================================================================
SET db = 'ANWB_AI_HACKATHON';   -- match the value you used in reisnogwijzer.sql
SET wh = 'ANWB_AI_HACKATHON_WH';
USE ROLE ACCOUNTADMIN;
USE DATABASE IDENTIFIER($db);
USE SCHEMA TRAVEL;
USE WAREHOUSE IDENTIFIER($wh);

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
import requests
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
        try:
            fr = requests.get(base + '8ys7-d773.json', params={'kenteken': plate}, timeout=10)
            fj = fr.json()
            if fj:
                fuel = fj[0].get('brandstof_omschrijving')
        except Exception:
            pass
        return {
            'kenteken': kenteken,
            'found': True,
            'merk': v.get('merk'),
            'model': v.get('handelsbenaming'),
            'brandstof': fuel,
            'bouwjaar': (v.get('datum_eerste_toelating') or '')[:4],
            'voertuigsoort': v.get('voertuigsoort'),
            'massa_ledig_kg': v.get('massa_ledig_voertuig'),
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

-- Smoke test (needs live network access)
SELECT real_rdw_lookup('XD-429-P') AS rdw, real_weather('Munich') AS weather;
