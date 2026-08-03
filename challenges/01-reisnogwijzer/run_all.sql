-- ============================================================================
-- Challenge 1 - ReisNogWijzer
-- ----------------------------------------------------------------------------
-- WHAT YOU'RE BUILDING: an AI travel assistant that answers member trip
-- questions by combining a travel/camping knowledge base (Cortex Search / RAG)
-- with tools for vehicle, weather and country-advisory facts.
--
-- SUCCESS CRITERIA (ANWB): functional RAG search; at least two external tools
-- connected; the agent answers travel questions; demonstrable value over a
-- plain chatbot.
--
-- HOW TO RUN - two ways, same result:
--   SQL      : paste this file into a Snowsight worksheet and click Run All
--              (or run: snow sql -c <connection> -f run_all.sql).
--   Notebook : import reisnogwijzer.ipynb into Snowsight and Run All.
-- After Run All, follow the SNOWSIGHT STEPS at the bottom to build the agent
-- (and, optionally, the chat app).
--
-- Self-contained and idempotent (safe to re-run); independent of Challenge 2.
-- Data is synthetic, shaped to mirror ANWB's three real sources (Camping
-- Navigator, ANWB Website, Wikivoyage NL); no uploads needed. The mock tools
-- are created below with zero setup; tools/real_tools.sql is an optional
-- stretch that swaps in live RDW + open-meteo APIs.
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
    COMMENT = 'ANWB AI hackathon - ReisNogWijzer';
CREATE WAREHOUSE IF NOT EXISTS IDENTIFIER($hb_wh)
    WAREHOUSE_SIZE = 'SMALL' AUTO_SUSPEND = 60 AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE COMMENT = 'Compute for the ANWB AI hackathon';

USE DATABASE IDENTIFIER($hb_db);
CREATE SCHEMA IF NOT EXISTS TRAVEL COMMENT = 'Challenge 1 - ReisNogWijzer';
USE SCHEMA TRAVEL;
USE WAREHOUSE IDENTIFIER($hb_wh);

-- ----------------------------------------------------------------------------
-- CAMPSITES - mirrors campingnavigator.com fields (gps, seasonal Basistarief,
-- Oppervlakte/ha, Aantal plaatsen, voorzieningen, url).
-- Prices are per-night Basistarief (pitch, excl. persons), realistic ranges.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TABLE CAMPSITES (
    campsite_id      VARCHAR(10) PRIMARY KEY,
    name             VARCHAR(120),
    country          VARCHAR(40),
    region           VARCHAR(80),
    nearest_city     VARCHAR(80),
    latitude         NUMBER(8,5),
    longitude        NUMBER(8,5),
    type             VARCHAR(30),      -- camping | glamping | naturist | farm | mountain | beach
    area_ha          NUMBER(6,1),      -- Oppervlakte (ha)
    num_pitches      INT,              -- Aantal plaatsen totaal
    price_low_eur    NUMBER(6,2),      -- Basistarief laagseizoen
    price_high_eur   NUMBER(6,2),      -- Basistarief hoogseizoen
    rating           NUMBER(2,1),
    has_pool         BOOLEAN,
    has_wifi         BOOLEAN,
    pet_friendly     BOOLEAN,
    ev_charging      BOOLEAN,
    supermarket      BOOLEAN,
    restaurant       BOOLEAN,
    open_from_month  INT,
    open_to_month    INT,
    source_url       VARCHAR(200),
    description      VARCHAR(400)
);

INSERT INTO CAMPSITES VALUES
('C001','Camping Zeeburg','Netherlands','Noord-Holland','Amsterdam',52.36270,4.94800,'camping',5.0,300,24.50,34.50,4.1,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,3,10,'campingnavigator.com/nl/campings-nederland/noord-holland/zeeburg','Stadscamping op een eiland, 10 min van het centrum van Amsterdam per pont. Geschikt voor stedelijk kamperen met caravan.'),
('C002','Recreatiepark De Achterste Hoef','Netherlands','Noord-Brabant','Eindhoven',51.29200,5.23800,'camping',30.0,650,29.00,41.00,4.4,TRUE,TRUE,TRUE,TRUE,TRUE,TRUE,4,10,'campingnavigator.com/nl/campings-nederland/noord-brabant/de-achterste-hoef','Familiepark in de Brabantse bossen met groot zwembadcomplex, ideale uitvalsbasis voor het zuiden.'),
('C003','Camping Bakkum','Netherlands','Noord-Holland','Castricum',52.55600,4.65200,'beach',18.0,900,26.00,38.00,4.2,FALSE,TRUE,TRUE,FALSE,TRUE,FALSE,4,9,'campingnavigator.com/nl/campings-nederland/noord-holland/bakkum','Duincamping vlak bij het Noordzeestrand, rustig en groen.'),
('C004','Vakantiepark Delftse Hout','Netherlands','Zuid-Holland','Delft',52.02400,4.38900,'camping',12.0,350,30.00,44.00,4.3,TRUE,TRUE,TRUE,TRUE,TRUE,TRUE,1,12,'campingnavigator.com/nl/campings-nederland/zuid-holland/delftse-hout','Het hele jaar open, dicht bij Delft en Den Haag, prima voor stedentrips per fiets.'),
('C005','Camping Ganspoort','Netherlands','Utrecht','Utrecht',52.06700,5.13100,'camping',2.5,120,24.00,36.00,4.0,FALSE,TRUE,TRUE,TRUE,FALSE,FALSE,3,10,'campingnavigator.com/nl/campings-nederland/utrecht/ganspoort','Kleine groene camping op 15 min fietsen van het centrum van Utrecht.'),
('C006','Recreatiepark De Schatberg','Netherlands','Limburg','Sevenum',51.36900,6.02900,'camping',96.0,1100,35.00,68.00,4.5,TRUE,TRUE,TRUE,TRUE,TRUE,TRUE,1,12,'campingnavigator.com/nl/campings-nederland/limburg/de-schatberg','Groot recreatiepark met overdekt zwembad, meren en wellness; het hele jaar open.'),
('C007','Camping De Roos','Netherlands','Overijssel','Ommen',52.52200,6.41500,'farm',12.0,275,25.00,33.00,4.6,FALSE,TRUE,TRUE,FALSE,TRUE,FALSE,4,10,'campingnavigator.com/nl/campings-nederland/overijssel/de-roos','Rustige natuurcamping langs de Vecht, geen animatie - alleen rust.'),
('C008','Kur- und Feriencamping Dreiländereck','Germany','Bayern','Passau',48.57600,13.46100,'camping',6.0,220,22.00,32.00,4.2,TRUE,TRUE,TRUE,FALSE,TRUE,TRUE,4,10,'campingnavigator.com/nl/campings-duitsland/bayern/dreilaendereck','Aan de Oostenrijkse grens, plaatsen aan de rivier, poort naar de Alpen.'),
('C009','Camping Tennsee','Germany','Bayern','Garmisch-Partenkirchen',47.53400,11.22300,'mountain',5.5,250,32.00,46.00,4.7,TRUE,TRUE,TRUE,TRUE,TRUE,TRUE,1,12,'campingnavigator.com/nl/campings-duitsland/bayern/tennsee','Bekroonde alpencamping bij de Zugspitze, het hele jaar open, laadpunten aanwezig.'),
('C010','Campingplatz Hopfensee','Germany','Bayern','Füssen',47.60000,10.68000,'beach',8.0,400,34.00,49.00,4.6,TRUE,TRUE,FALSE,TRUE,TRUE,TRUE,3,11,'campingnavigator.com/nl/campings-duitsland/bayern/hopfensee','Luxe camping aan het meer bij Neuschwanstein, met wellness.'),
('C011','Camping Wagenburg','Germany','Baden-Württemberg','Stuttgart',48.80200,9.20300,'camping',2.0,120,21.00,30.00,3.9,FALSE,TRUE,TRUE,FALSE,FALSE,TRUE,3,10,'campingnavigator.com/nl/campings-duitsland/baden-wuerttemberg/wagenburg','Eenvoudige camping aan de Neckar, tram naar Stuttgart - let op de milieuzone.'),
('C012','Camping Baltic Freizeit','Germany','Schleswig-Holstein','Grömitz',54.15000,10.95000,'beach',20.0,800,33.00,47.00,4.4,TRUE,TRUE,TRUE,TRUE,TRUE,TRUE,3,10,'campingnavigator.com/nl/campings-duitsland/schleswig-holstein/baltic-freizeit','Groot resort aan de Oostzee met binnenbad en laadpunten.'),
('C013','Aktiv-Camp Purgstall','Austria','Tirol','Innsbruck',47.32700,11.66600,'mountain',4.0,180,30.00,44.00,4.6,TRUE,TRUE,TRUE,TRUE,TRUE,TRUE,1,12,'campingnavigator.com/nl/campings-oostenrijk/tirol/purgstall','Tiroolse camping met bergzicht en laadpunten, het hele jaar open.'),
('C014','Nature Resort Natterer See','Austria','Tirol','Innsbruck',47.23800,11.34700,'glamping',9.0,350,40.00,62.00,4.8,TRUE,TRUE,TRUE,TRUE,TRUE,TRUE,4,10,'campingnavigator.com/nl/campings-oostenrijk/tirol/natterer-see','Premium glampingpods aan een alpenmeer, hoogst gewaardeerd in Oostenrijk.'),
('C015','Camping Auwirt','Austria','Salzburg','Hallein',47.70430,13.06889,'camping',1.0,50,20.20,22.00,4.2,FALSE,TRUE,TRUE,FALSE,FALSE,TRUE,4,10,'campingnavigator.com/nl/campings-oostenrijk/salzburg/auwirt','Kleine familiecamping bij Salzburg, rustig en persoonlijk.'),
('C016','Camping Zell am See','Austria','Salzburg','Zell am See',47.32300,12.79800,'mountain',4.5,200,28.00,44.00,4.5,TRUE,TRUE,TRUE,FALSE,TRUE,TRUE,5,9,'campingnavigator.com/nl/campings-oostenrijk/salzburg/zell-am-see','Camping aan het meer onder het Kitzsteinhorn-gletsjergebied, prima wandelbasis.'),
('C017','Camping Seewiese','Austria','Kärnten','Klagenfurt',46.61500,14.26200,'beach',3.0,150,24.00,40.00,4.4,TRUE,TRUE,TRUE,FALSE,FALSE,TRUE,5,9,'campingnavigator.com/nl/campings-oostenrijk/kaernten/seewiese','Aan de Wörthersee, warm zwemwater, gezinsvriendelijk.'),
('C018','Camping Union Lido','Italy','Veneto','Cavallino',45.46600,12.53200,'beach',60.0,1500,38.00,68.00,4.7,TRUE,TRUE,TRUE,TRUE,TRUE,TRUE,4,9,'campingnavigator.com/nl/campings-italie/veneto/union-lido','Groot Adriatisch strandresort bij Venetië met aquapark; een van Europa''s beste.'),
('C019','Camping Residence Punta Spin','Italy','Friuli-Venezia Giulia','Grado',45.69237,13.45467,'beach',12.0,500,29.20,44.00,4.3,TRUE,TRUE,TRUE,FALSE,TRUE,TRUE,4,10,'campingnavigator.com/nl/campings-italie/friuli-venezia-giulia/punta-spin','Strandcamping bij Grado met zwembad en directe zeetoegang.'),
('C020','Camping Village Cavallino','Italy','Veneto','Cavallino',45.45800,12.56900,'beach',20.0,700,32.00,55.00,4.4,TRUE,TRUE,TRUE,TRUE,TRUE,TRUE,4,9,'campingnavigator.com/nl/campings-italie/veneto/cavallino','Lang zandstrand, animatie voor gezinnen, laadpunten.'),
('C021','Camping Fabulous','Italy','Lazio','Rome',41.78900,12.42600,'camping',8.0,300,28.00,45.00,4.1,TRUE,TRUE,TRUE,FALSE,TRUE,TRUE,3,10,'campingnavigator.com/nl/campings-italie/lazio/fabulous','Uitvalsbasis voor Rome met shuttle naar de metro - let op de ZTL in het centrum.'),
('C022','Camping Jesolo International','Italy','Veneto','Jesolo',45.50200,12.62800,'beach',15.0,600,34.00,58.00,4.5,TRUE,TRUE,TRUE,FALSE,TRUE,TRUE,4,9,'campingnavigator.com/nl/campings-italie/veneto/jesolo-international','Levendige strandcamping aan de Lido di Jesolo.'),
('C023','Camping Municipal de Boyse','France','Bourgogne-Franche-Comté','Champagnole',46.74640,5.89889,'camping',3.0,180,14.40,18.20,4.0,TRUE,TRUE,TRUE,FALSE,FALSE,FALSE,5,9,'campingnavigator.com/nl/campings-frankrijk/franche-comte/municipal-de-boyse','Betaalbare gemeentecamping in de Jura, aan de rivier, rustig.'),
('C024','Camping Lac de Sainte-Croix','France','Provence','Aups',43.76000,6.22000,'beach',6.0,300,26.00,43.00,4.5,TRUE,TRUE,TRUE,FALSE,TRUE,TRUE,4,9,'campingnavigator.com/nl/campings-frankrijk/provence/lac-de-sainte-croix','Bij het turquoise Verdonmeer, kajakken en kloven in de buurt.'),
('C025','Camping Indigo Paris','France','Île-de-France','Paris',48.86800,2.23400,'camping',7.0,350,32.00,54.00,4.0,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,1,12,'campingnavigator.com/nl/campings-frankrijk/ile-de-france/indigo-paris','De enige camping in Parijs, Bois de Boulogne - let op de Crit''Air-zone.'),
('C026','Camping Les Méditerranées','France','Occitanie','Béziers',43.29000,3.27000,'beach',30.0,900,34.00,60.00,4.6,TRUE,TRUE,TRUE,TRUE,TRUE,TRUE,4,9,'campingnavigator.com/nl/campings-frankrijk/occitanie/les-mediterranees','Drie strandcampings gecombineerd, groot waterpark.'),
('C027','Camping du Lac de Carcans','France','Nouvelle-Aquitaine','Bordeaux',45.08000,-1.10000,'beach',10.0,400,22.00,39.00,4.1,TRUE,TRUE,TRUE,FALSE,TRUE,TRUE,5,9,'campingnavigator.com/nl/campings-frankrijk/nouvelle-aquitaine/lac-de-carcans','Camping aan een meer aan de Atlantische kust bij de wijngaarden van Bordeaux.'),
('C028','Camping Zaton Holiday Resort','Croatia','Zadar','Zadar',44.22600,15.16500,'beach',40.0,1200,33.00,57.00,4.7,TRUE,TRUE,TRUE,TRUE,TRUE,TRUE,4,10,'campingnavigator.com/nl/campings-kroatie/zadar/zaton','Bekroond Adriatisch resort met dennenbos en kiezelstranden.'),
('C029','Camping Polari','Croatia','Istria','Rovinj',45.06900,13.66700,'beach',60.0,1400,30.00,53.00,4.6,TRUE,TRUE,TRUE,TRUE,TRUE,TRUE,4,10,'campingnavigator.com/nl/campings-kroatie/istrie/polari','Aan de Istrische kust bij het mooie stadje Rovinj.'),
('C030','Camping Bijela Uvala','Croatia','Istria','Poreč',45.19800,13.59400,'beach',60.0,1600,28.00,46.00,4.2,TRUE,TRUE,TRUE,FALSE,TRUE,TRUE,4,10,'campingnavigator.com/nl/campings-kroatie/istrie/bijela-uvala','Grote terrascamping bij Poreč.'),
('C031','Camping Krk','Croatia','Kvarner','Krk',45.02400,14.57500,'beach',10.0,450,26.00,44.00,4.3,TRUE,TRUE,TRUE,FALSE,TRUE,TRUE,4,10,'campingnavigator.com/nl/campings-kroatie/kvarner/krk','Familiecamping op het eiland Krk, makkelijk bereikbaar via de brug.'),
('C032','Camping Cikat','Croatia','Kvarner','Mali Lošinj',44.53000,14.44900,'beach',20.0,700,29.00,49.00,4.5,TRUE,TRUE,TRUE,FALSE,TRUE,TRUE,4,10,'campingnavigator.com/nl/campings-kroatie/kvarner/cikat','Eilandcamping in een geurige dennenbaai.'),
('C033','Camping Resort Sanguli','Spain','Catalonia','Salou',41.07600,1.13000,'beach',25.0,1000,36.00,63.00,4.7,TRUE,TRUE,TRUE,TRUE,TRUE,TRUE,3,11,'campingnavigator.com/nl/campings-spanje/catalonie/sanguli','Costa Dorada-resort bij PortAventura, uitstekende voorzieningen.'),
('C034','Camping La Paz','Spain','Asturias','Llanes',43.40400,-4.68200,'beach',6.0,300,31.85,31.85,4.3,FALSE,TRUE,TRUE,FALSE,TRUE,TRUE,4,10,'campingnavigator.com/nl/campings-spanje/asturie/la-paz','Spectaculair gelegen kliftcamping aan de Asturische kust.'),
('C035','Camping Las Dunas','Spain','Catalonia','Girona',42.15600,3.11700,'beach',30.0,1100,32.00,56.00,4.4,TRUE,TRUE,TRUE,FALSE,TRUE,TRUE,4,10,'campingnavigator.com/nl/campings-spanje/catalonie/las-dunas','Grote strandcamping aan de Costa Brava.'),
('C036','Camping Playa Montroig','Spain','Catalonia','Tarragona',41.03700,0.95900,'beach',35.0,1200,34.00,61.00,4.6,TRUE,TRUE,TRUE,TRUE,TRUE,TRUE,3,11,'campingnavigator.com/nl/campings-spanje/catalonie/playa-montroig','Luxe strandcamping met palmen, een gezinsklassieker.'),
('C037','Camping TCS Sion','Switzerland','Wallis','Sion',46.22700,7.35900,'camping',3.0,150,30.00,42.00,4.2,TRUE,TRUE,TRUE,TRUE,FALSE,TRUE,4,10,'campingnavigator.com/nl/campings-zwitserland/wallis/tcs-sion','TCS-camping in het Wallis, prima uitvalsbasis voor de Zwitserse Alpen.'),
('C038','Camping Manor Farm','Switzerland','Bern','Interlaken',46.68300,7.81700,'mountain',5.0,500,33.00,52.00,4.5,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,3,10,'campingnavigator.com/nl/campings-zwitserland/bern/manor-farm','Aan de Thunersee bij Interlaken, met bergpanorama.'),
('C039','Camping Nordstrand','Denmark','Nordjylland','Skagen',57.72000,10.58000,'beach',8.0,400,30.00,45.00,4.3,FALSE,TRUE,TRUE,TRUE,TRUE,FALSE,4,9,'campingnavigator.com/nl/campings-denemarken/nordjylland/nordstrand','Aan het strand bij Skagen, waar twee zeeën samenkomen.'),
('C040','Camping Mossø','Denmark','Midtjylland','Skanderborg',56.02000,9.83000,'camping',6.0,250,28.00,40.00,4.2,TRUE,TRUE,TRUE,FALSE,TRUE,TRUE,4,9,'campingnavigator.com/nl/campings-denemarken/midtjylland/mosso','Rustige meercamping in het Deense merengebied.');

-- ----------------------------------------------------------------------------
-- EMISSION_ZONES - city low-emission zones. Accuracy verified against ANWB's
-- real "milieuzones" pages. Two separate layers modelled correctly:
--   min_euro_diesel      = minimum EURO norm for the sticker / basic zone access
--   diesel_ban_min_euro  = extra city diesel ban (NULL if none) - stricter layer
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TABLE EMISSION_ZONES (
    city                    VARCHAR(60),
    country                 VARCHAR(40),
    zone_name               VARCHAR(80),
    zone_type               VARCHAR(40),   -- Umweltzone | LEZ | ZTL | ZFE (Crit'Air) | ULEZ
    sticker_name            VARCHAR(40),   -- Umweltplakette | Crit'Air | none
    sticker_color           VARCHAR(30),
    sticker_required        BOOLEAN,
    min_euro_diesel         INT,           -- min EURO diesel for sticker/basic access
    min_euro_petrol         INT,
    diesel_ban_min_euro     INT,           -- extra diesel ban layer (NULL = none)
    ev_exempt               BOOLEAN,       -- EV exempt from the zone entirely?
    register_plate_required BOOLEAN,       -- foreign plate must register online?
    caravan_note            VARCHAR(200),
    notes                   VARCHAR(320)
);

INSERT INTO EMISSION_ZONES VALUES
('Munich','Germany','Umweltzone München','Umweltzone','Umweltplakette','groen',TRUE,4,1,5,FALSE,FALSE,'De trekkende auto bepaalt de toegang; de caravan zelf heeft geen sticker nodig.','Groene Umweltplakette verplicht (diesel Euro 4+). Munchen heeft daarbovenop een dieselverbod: Euro 4 en ouder mag de milieuzone niet in. Sticker is ook voor EV verplicht. Boete ca. 100 euro; op de snelweg en bij doorreis geen sticker nodig.'),
('Berlin','Germany','Umweltzone Berlin','Umweltzone','Umweltplakette','groen',TRUE,4,1,NULL,FALSE,FALSE,'Caravan volgt de trekkende auto.','Groene sticker verplicht (diesel Euro 4+ / benzine met katalysator). Ook EV heeft de sticker nodig.'),
('Stuttgart','Germany','Umweltzone Stuttgart','Umweltzone','Umweltplakette','groen',TRUE,4,1,5,FALSE,FALSE,'Campers worden op hun emissieklasse beoordeeld.','Groene sticker verplicht; daarnaast een dieselverbod voor Euro 4 en ouder wegens luchtkwaliteit. Sticker ook voor EV verplicht.'),
('Frankfurt','Germany','Umweltzone Frankfurt','Umweltzone','Umweltplakette','groen',TRUE,4,1,NULL,FALSE,FALSE,'Caravan volgt de trekkende auto.','Groene sticker verplicht in het hele centrum; ook voor EV.'),
('Cologne','Germany','Umweltzone Köln','Umweltzone','Umweltplakette','groen',TRUE,4,1,NULL,FALSE,FALSE,'Caravan volgt de trekkende auto.','Groene sticker verplicht; ook voor EV.'),
('Amsterdam','Netherlands','Milieuzone Amsterdam','LEZ','none','n.v.t.',FALSE,4,0,NULL,TRUE,FALSE,'Geldt voor bestel-/vrachtauto''s; personenauto''s grotendeels vrij.','Geen sticker; op kenteken/brandstof/leeftijd. Oude diesels van voor 2005 geweerd; vanaf 2025 strengere regels voor oudere diesels en bestelauto''s.'),
('Rotterdam','Netherlands','Milieuzone Rotterdam','LEZ','none','n.v.t.',FALSE,4,0,NULL,TRUE,FALSE,'Personenauto''s en campers op brandstof/leeftijd.','Geen sticker; oudere dieselpersonenauto''s en bestelauto''s geweerd in het centrum.'),
('Utrecht','Netherlands','Milieuzone Utrecht','LEZ','none','n.v.t.',FALSE,4,0,NULL,TRUE,FALSE,'Camper volgt de regels voor personenauto''s.','Geen sticker; dieselpersonenauto''s van voor 2009 geweerd.'),
('Antwerp','Belgium','LEZ Antwerpen','LEZ','none','n.v.t.',FALSE,5,1,NULL,TRUE,TRUE,'Campers moeten zich registreren; controleer de emissieklasse.','Buitenlandse voertuigen moeten hun kenteken vooraf online registreren voor de LEZ.'),
('Brussels','Belgium','LEZ Brussel','LEZ','none','n.v.t.',FALSE,5,2,NULL,TRUE,TRUE,'Campers op emissieklasse; buitenlands kenteken registreren.','Diesel Euro 5+ vereist; registreer je kenteken vooraf.'),
('Ghent','Belgium','LEZ Gent','LEZ','none','n.v.t.',FALSE,5,2,NULL,TRUE,TRUE,'Buitenlands kenteken online registreren.','Vergelijkbaar met Antwerpen; dagpas beschikbaar.'),
('Paris','France','ZFE Paris','ZFE (Crit''Air)','Crit''Air','sticker 0-5',TRUE,0,0,NULL,TRUE,FALSE,'Crit''Air-sticker geldt voor auto en camper.','Crit''Air-vignet verplicht; Crit''Air 3 en oudere diesels op werkdagen geweerd. EV krijgt Crit''Air E (vrijgesteld).'),
('Lyon','France','ZFE Lyon','ZFE (Crit''Air)','Crit''Air','sticker 0-5',TRUE,0,0,NULL,TRUE,FALSE,'Crit''Air-sticker verplicht.','Crit''Air-vignet verplicht in de ZFE. EV krijgt Crit''Air E.'),
('Milan','Italy','Area B / Area C Milano','ZTL / LEZ','none','n.v.t.',FALSE,4,0,NULL,TRUE,FALSE,'Campers boven 3,5 t hebben aparte regels.','Area C is een betaalde centrale ZTL; Area B weert oudere diesels (Euro 4 en ouder uitgefaseerd).'),
('Rome','Italy','ZTL Roma Centro','ZTL','none','n.v.t.',FALSE,0,0,NULL,FALSE,FALSE,'Campers/caravans mogen de historische ZTL doorgaans niet in.','Historische ZTL is overdag alleen met ontheffing, ongeacht brandstof; parkeer buiten en gebruik OV.'),
('Bologna','Italy','ZTL Bologna','ZTL','none','n.v.t.',FALSE,0,0,NULL,FALSE,FALSE,'Geen caravantoegang tot de ZTL.','Camerabewaakte historische zone; alleen bewoners/ontheffing.'),
('Vienna','Austria','Umweltzone Wien (IG-L)','LEZ','none','n.v.t.',FALSE,4,1,NULL,TRUE,FALSE,'Geldt vooral voor zware voertuigen.','Emissieregels richten zich op vrachtverkeer; personenauto''s in het centrum grotendeels onaangetast.'),
('Barcelona','Spain','ZBE Barcelona','LEZ','none','n.v.t.',FALSE,4,3,NULL,TRUE,TRUE,'Buitenlandse voertuigen moeten zich voor de ZBE registreren.','Registreer je kenteken; diesel Euro 4+ en benzine Euro 3+ toegestaan.'),
('London','United Kingdom','ULEZ London','ULEZ','none','n.v.t.',FALSE,6,4,NULL,TRUE,FALSE,'Campers betalen op emissieklasse of een dagtarief.','Diesel Euro 6 / benzine Euro 4 vermijden de dagheffing; anders betaal je per dag.');

-- ----------------------------------------------------------------------------
-- TRAVEL_ADVISORIES - per-country safety advisory (synthetic; no real source sent)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TABLE TRAVEL_ADVISORIES (
    country        VARCHAR(40),
    iso2           VARCHAR(2),
    advisory_level INT,
    advisory_color VARCHAR(10),
    summary        VARCHAR(300),
    updated_date   DATE
);

INSERT INTO TRAVEL_ADVISORIES VALUES
('Netherlands','NL',1,'green','Geen bijzondere veiligheidsrisico''s. Normale voorzichtigheid.','2026-07-01'),
('Germany','DE',1,'green','Veilig om te reizen. Let op incidentele stakingen in het openbaar vervoer.','2026-07-01'),
('Austria','AT',1,'green','Veilig om te reizen. Alpenweer kan in de bergen snel omslaan.','2026-07-01'),
('Italy','IT',2,'yellow','Over het algemeen veilig. Zakkenrollerij op toeristische plekken; hittewaarschuwingen in de zomer.','2026-07-10'),
('France','FR',2,'yellow','Over het algemeen veilig. Af en toe demonstraties in steden; kleine criminaliteit in Parijs/Marseille.','2026-07-05'),
('Croatia','HR',1,'green','Veilig om te reizen. Drukke kustwegen in het hoogseizoen; kwallen op sommige stranden.','2026-07-08'),
('Spain','ES',2,'yellow','Over het algemeen veilig. Zakkenrollerij in Barcelona; extreme hitte in het binnenland in de zomer.','2026-07-09'),
('Belgium','BE',1,'green','Veilig om te reizen. Normale voorzichtigheid in stadscentra.','2026-07-01'),
('Switzerland','CH',1,'green','Veilig om te reizen. Duur; zorg voor het juiste snelwegvignet.','2026-07-01'),
('Slovenia','SI',1,'green','Veilig om te reizen. Vignet verplicht op snelwegen.','2026-07-01'),
('United Kingdom','GB',2,'yellow','Over het algemeen veilig. Links rijden; controleer je documenten na de Brexit.','2026-07-01'),
('Denmark','DK',1,'green','Veilig om te reizen. Veel fietsers in de steden; let op fietspaden.','2026-07-01');

-- ----------------------------------------------------------------------------
-- COUNTRY_INFO - practical driving/travel facts per country
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TABLE COUNTRY_INFO (
    country              VARCHAR(40),
    iso2                 VARCHAR(2),
    currency             VARCHAR(20),
    language             VARCHAR(60),
    emergency_number     VARCHAR(10),
    toll_system          VARCHAR(120),
    vignette_required    BOOLEAN,
    emission_sticker     VARCHAR(40),      -- what sticker/scheme applies
    motorway_speed_kmh   INT,
    notes                VARCHAR(300)
);

INSERT INTO COUNTRY_INFO VALUES
('Netherlands','NL','EUR','Nederlands','112','Geen algemene snelwegtol; enkele tunnels heffen.',FALSE,'Milieuzone (op kenteken)',130,'Overdag (06-19u) op veel snelwegen 100 km/u.'),
('Germany','DE','EUR','Duits','112','Geen autotol op de Autobahn (alleen vracht).',FALSE,'Umweltplakette (groen)',0,'Autobahn heeft stukken zonder limiet; advies 130 km/u.'),
('Austria','AT','EUR','Duits','112','Vignet verplicht (digitaal of sticker); extra tol op sommige passen/tunnels.',TRUE,'IG-L (beperkt)',130,'Koop het vignet voordat je de snelweg oprijdt.'),
('Italy','IT','EUR','Italiaans','112','Snelwegtol op ticketbasis, betalen bij afrit.',FALSE,'ZTL / Area B-C',130,'Houd pas/contant klaar voor tolpoorten; Telepass-stroken zijn voor abonnees.'),
('France','FR','EUR','Frans','112','Snelwegtol (péage) op ticketbasis.',FALSE,'Crit''Air',130,'Crit''Air-vignet nodig voor veel ZFE-zones.'),
('Croatia','HR','EUR','Kroatisch','112','Snelwegtol op ticketbasis; sinds kort de euro.',FALSE,'geen',130,'Kustwegen traag in de zomer; veerboten naar eilanden snel vol.'),
('Spain','ES','EUR','Spaans','112','Mix van gratis (autovía) en tol (autopista/AP).',FALSE,'ZBE (registreren)',120,'Sommige steden vragen ZBE-registratie voor buitenlandse kentekens.'),
('Belgium','BE','EUR','Nederlands, Frans, Duits','112','Geen autotol (vracht betaalt per km).',FALSE,'LEZ (registreren)',120,'LEZ-steden vereisen online registratie van buitenlandse kentekens.'),
('Switzerland','CH','CHF','Duits, Frans, Italiaans','112','Jaarvignet verplicht (geen korte optie).',TRUE,'geen',120,'Vignet ook nodig voor een enkele doorreis.'),
('Slovenia','SI','EUR','Sloveens','112','Vignet verplicht voor snelwegen.',TRUE,'geen',130,'Populair doorreisland naar Kroatië - koop het e-vignet.'),
('United Kingdom','GB','GBP','Engels','999 / 112','Weinig tol; Londen heeft ULEZ + congestieheffing.',FALSE,'ULEZ',112,'Links rijden; 70 mph (112 km/u) op de motorway.'),
('Denmark','DK','DKK','Deens','112','Tol op de Storebælt- en Øresundbrug.',FALSE,'geen',130,'Bruggen Grote Belt en Øresund zijn tolplichtig.');

-- ----------------------------------------------------------------------------
-- KB_DOCUMENTS - RAG knowledge base (indexed by Cortex Search in step 03).
-- Regenerated to mirror ANWB's three real sources. source_type marks which:
--   anwb_website      -> markdown pages with a source: anwb.nl URL (Dutch)
--   wikivoyage        -> destination articles with section headings (Dutch)
--   camping_navigator -> individual campsite write-ups (Dutch)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TABLE KB_DOCUMENTS (
    doc_id      VARCHAR(20) PRIMARY KEY,
    title       VARCHAR(160),
    category    VARCHAR(60),
    source_type VARCHAR(30),   -- anwb_website | wikivoyage | camping_navigator
    source_url  VARCHAR(200),
    content     VARCHAR(16000)
);

INSERT INTO KB_DOCUMENTS (doc_id, title, category, source_type, source_url, content) VALUES
('AW01','Milieuzones in Duitsland','milieuzones','anwb_website','https://www.anwb.nl/vakantie/duitsland/reisvoorbereiding/milieuzones',
'# Milieuzones in Duitsland

## Heb ik een milieusticker nodig?
Ja. In veel Duitse steden is een milieusticker (Umweltplakette) verplicht voor alle auto''s, campers, bussen en vrachtwagens - ook voor elektrische auto''s. De milieuzones (Umweltzonen) zijn met borden aangeduid. Sommige steden hebben daarnaast een dieselverbod (Durchfahrtbeschraenkung) voor oudere dieselauto''s.

## Welke sticker?
De groene sticker is de enige nog geldige milieusticker; gele en rode zijn nergens meer toegestaan. Voor de groene sticker moet een diesel minimaal Euro 4 zijn (benzine met katalysator voldoet meestal). De sticker is aan het voertuig gekoppeld en onbeperkt geldig. Voor elektrische auto''s bestaat optioneel een blauwe sticker, maar de groene blijft nodig.

## Steden met een milieuzone
In ongeveer 35 Duitse plaatsen is een sticker verplicht, waaronder Muenchen, Berlijn, Stuttgart, Frankfurt en Keulen. Op autosnelwegen binnen een milieuzone en bij doorreis naar buurlanden heb je geen sticker nodig.

## Let op: dieselverbod
Enkele steden, waaronder Muenchen en Stuttgart, hebben bovenop de groene sticker een dieselverbod. Daar mogen diesels van Euro 4 en ouder de zone niet in, ook al hebben ze een groene sticker. Een Euro 4-dieselcamper heeft dus wel een groene sticker, maar mag door het dieselverbod Muenchen niet in.

## Boete
Rijden zonder geldige sticker in een Umweltzone kost ongeveer 100 euro.'),
('AW02','Milieuzones in Europa: overzicht','milieuzones','anwb_website','https://www.anwb.nl/vakantie/reisvoorbereiding/milieuzones-europa',
'# Milieuzones in Europa

Lage-emissiezones (LEZ) weren oudere, vervuilende voertuigen uit stadscentra. De regels verschillen per land:
- Duitsland: Umweltzone met een gekleurde Umweltplakette (groen is de enige geldige). Diesel minimaal Euro 4.
- Frankrijk: Crit''Air-vignet met nummers 0-5 op basis van leeftijd en brandstof; ZFE-zones weren de vuilste categorieen op werkdagen. Elektrisch krijgt Crit''Air E.
- Italie: ZTL (beperkte-verkeerszones), vaak camerabewaakt en in historische centra alleen met ontheffing, plus Area B/Area C in Milaan.
- Belgie (Antwerpen, Brussel, Gent) en Spanje (Barcelona ZBE): buitenlandse voertuigen moeten hun kenteken vooraf online registreren.
- Nederland: milieuzones op basis van kenteken/brandstof/leeftijd, geen sticker.

Elektrische auto''s zijn bijna overal vrijgesteld, behalve dat je in Duitsland toch een sticker nodig hebt. Koop stickers vooraf via officiele kanalen.'),
('AW03','Met de caravan of aanhanger naar het buitenland','kamperen','anwb_website','https://www.anwb.nl/vakantie/reisvoorbereiding/caravan-buitenland',
'# Met de caravan of aanhanger naar het buitenland

Bij een milieuzone bepaalt de trekkende auto de toegang, niet de caravan. Let op de lengte en het gewicht in verband met je rijbewijs: met rijbewijs B trek je tot 3500 kg combinatie; zwaarder heeft BE nodig. Monteer verlengde spiegels, houd je aan lagere aanhangersnelheden (vaak 80-90 km/u) en neem in sommige landen twee gevarendriehoeken mee. Controleer of je bestemming een vignet (Oostenrijk, Zwitserland, Slovenie) of milieusticker (Duitsland, Frankrijk) vereist en regel dat voor vertrek.'),
('AW04','Elektrisch op reis: laden onderweg','ev','anwb_website','https://www.anwb.nl/vakantie/reisvoorbereiding/elektrisch-op-reis',
'# Elektrisch op reis door Europa

Snelladen langs de snelweg is dicht bezaaid in Nederland, Duitsland, Oostenrijk en langs de Franse autoroutes, maar schaarser op Kroatische eilanden en op het Spaanse platteland. Neem een Type 2-kabel en een laadpas of app die door heel Europa roamt. Vuistregel: plan elke 200-250 km een laadstop en laad tot 80 procent in plaats van 100 procent om tijd te sparen. Een caravan halveert het bereik ongeveer, dus plan voorzichtiger. Elektrische auto''s zijn vrijgesteld van bijna alle milieuzones - in Duitsland heb je wel een sticker nodig.'),
('AW05','Tol en vignetten per land','tol','anwb_website','https://www.anwb.nl/vakantie/reisvoorbereiding/tol-en-vignetten',
'# Tol en vignetten per land

Oostenrijk, Zwitserland en Slovenie vereisen een snelwegvignet (digitaal of sticker) dat je voor vertrek moet kopen - Zwitserland verkoopt alleen een jaarvignet. Frankrijk, Italie, Spanje en Kroatie werken met tol op ticketbasis: je neemt een ticket bij oprit en betaalt bij afrit (houd een pas of contant klaar). Duitsland, Nederland en Belgie hebben geen algemene autotol, al heffen sommige tunnels en bruggen wel. Reken voor een rondreis van twee weken door Oostenrijk en Italie al snel meer dan 150 euro aan vignetten en tol.'),
('AW06','Kampeerchecklist voor Europa','kamperen','anwb_website','https://www.anwb.nl/vakantie/reisvoorbereiding/kampeerchecklist',
'# Kampeerchecklist voor een Europese reis

Essentieel: geldig paspoort/ID per reiziger, rijbewijs, kentekenbewijs en verzekeringsbewijs (groene kaart), gevarendriehoek(en) en veiligheidshesjes (in veel landen verplicht), EHBO-kit, reservelampjes en koplampstickers voor rechts rijden. Voor de plek: stelblokken, grondzeil, verlengsnoer met Europese adapters, gasfles met drukregelaar en een waterslang. Controleer of je bestemming een vignet (Oostenrijk, Zwitserland, Slovenie) of milieusticker (Duitsland, Frankrijk) nodig heeft en koop die vooraf. Boek eiland- en kustcampings vroeg in juli-augustus.'),
('AW07','Pech onderweg: de Wegenwacht','pech','anwb_website','https://www.anwb.nl/wegenwacht/pech-in-het-buitenland',
'# Pech onderweg in het buitenland

Leden met Wegenwacht Europa Service kunnen de ANWB Alarmcentrale bellen voor hulp langs de weg in heel Europa. Doe je veiligheidshesje aan, zet de gevarendriehoek neer en ga op de snelweg achter de vangrail staan. Houd je lidmaatschapsnummer, je locatie (let op de kilometerpaaltjes) en de voertuiggegevens bij de hand. Vermeld bij een elektrische auto het merk en de batterij zodat de juiste hulp komt. Als reparatie ter plaatse niet lukt, kan de dekking slepen, vervangend vervoer of overnachting omvatten, afhankelijk van je pakket.'),
('AW08','Huisdieren mee op reis','huisdieren','anwb_website','https://www.anwb.nl/vakantie/reisvoorbereiding/huisdieren',
'# Met je huisdier op reis

Voor een hond, kat of fret over de EU-grens heb je een dierenpaspoort, een chip en een geldige rabiesvaccinatie nodig (minimaal 21 dagen oud bij de eerste enting). Sommige landen eisen een wormkuur voor honden voor binnenkomst. Veel campings zijn huisdiervriendelijk, maar vragen je de hond aangelijnd te houden en weg te houden bij zwembad en speeltuin; filter bij het boeken op huisdiervriendelijk. Laat huisdieren nooit achter in een warme auto of caravan - de zomer in Italie, Spanje en Kroatie is gevaarlijk heet.'),
('WV01','Innsbruck en Tirol','bestemming','wikivoyage','https://nl.wikivoyage.org/wiki/Innsbruck',
'# Innsbruck

Innsbruck is de hoofdstad van Tirol en een uitstekende uitvalsbasis voor de Alpen.

## Aankomst
Goed bereikbaar via de A12 en de Brennerpas (A13, tolplichtig) vanuit Italie. Een Oostenrijks vignet is verplicht op de snelweg.

## Bezienswaardigheden
Het Gouden Dakje, de Nordkette-kabelbaan en de Ambras-kastelen. Rondom liggen talrijke campings zoals Natterer See en Aktiv-Camp Purgstall.

## Praktisch
Bergweer slaat snel om; neem ook in de zomer lagen mee. Veel Tiroolse campings zijn het hele jaar open, ook voor de wintersport.'),
('WV02','De Veneto-kust en Venetie','bestemming','wikivoyage','https://nl.wikivoyage.org/wiki/Veneto',
'# Veneto-kust

De Adriatische kust van de Veneto is een kampeerfavoriet, met badplaatsen als Cavallino, Jesolo en Grado.

## Aankomst
Vanuit het noorden via de A22/A4 (tol op ticketbasis). Rijd niet het historische centrum van Venetie in - dat is per boot en te voet.

## Bezienswaardigheden
Venetie zelf (per vaporetto of campingshuttle), de stranden van de Lido di Jesolo en het aquapark bij Cavallino.

## Praktisch
Boek strandresorts als Union Lido vroeg; ze zitten in juli-augustus vol. Let op de ZTL-zones in de steden.'),
('WV03','Rovinj en Istrie','bestemming','wikivoyage','https://nl.wikivoyage.org/wiki/Rovinj',
'# Rovinj

Rovinj is een van de mooiste stadjes van Istrie, met een schilderachtige oude haven.

## Aankomst
Istrie is de dichtstbijzijnde Kroatische regio vanuit Nederland, via Slovenie (vignet verplicht). Kroatie gebruikt sinds kort de euro en heeft tol op de snelweg.

## Bezienswaardigheden
De oude stad met de Eufemiakerk, de eilandjes voor de kust en campings als Polari en Bijela Uvala.

## Praktisch
Kustwegen zijn druk in het hoogseizoen. Waterschoenen helpen op kiezelstranden.'),
('WV04','Zell am See','bestemming','wikivoyage','https://nl.wikivoyage.org/wiki/Zell_am_See',
'# Zell am See

Zell am See ligt aan een helder bergmeer onder het Kitzsteinhorn-gletsjergebied in de deelstaat Salzburg.

## Aankomst
Via de A10 Tauern Autobahn (Oostenrijks vignet plus extra tol op het Tauern-traject). 

## Bezienswaardigheden
Het meer met zwem- en watersportmogelijkheden, de gletsjer voor zomerski en talrijke wandelroutes.

## Praktisch
Combineer met de Grossglockner Hochalpenstrasse (aparte tol). Campings aan het meer zijn in de zomer snel vol.'),
('CN01','Camping Auwirt (Salzburg)','camping','camping_navigator','https://campingnavigator.com/nl/campings-oostenrijk/salzburg/auwirt',
'# Camping Auwirt

Kleine, persoonlijke familiecamping bij Hallein, ten zuiden van Salzburg. Oppervlakte circa 1 ha met ongeveer 50 plaatsen. Basistarief 20,20 euro laagseizoen tot 22,00 euro hoogseizoen (exclusief personen en stroom). Voorzieningen: wifi, camping-gaz en propaangas, kleine maaltijden/snacks. Rustige uitvalsbasis voor Salzburg en het Salzkammergut. Open april tot en met oktober.'),
('CN02','Camping Union Lido (Venetie)','camping','camping_navigator','https://campingnavigator.com/nl/campings-italie/veneto/union-lido',
'# Camping Union Lido

Groot Adriatisch strandresort bij Cavallino, vlak bij Venetie. Circa 60 ha met een aquapark, meerdere zwembaden, supermarkt en restaurants. Basistarief van 38 euro laagseizoen tot 68 euro hoogseizoen. Laadpunten voor elektrische auto''s aanwezig. Bootshuttle naar Venetie. Een van de best beoordeelde campings van Europa. Open april tot en met september.'),
('CN03','Recreatiepark De Schatberg (Limburg)','camping','camping_navigator','https://campingnavigator.com/nl/campings-nederland/limburg/de-schatberg',
'# Recreatiepark De Schatberg

Groot recreatiepark bij Sevenum in Limburg, circa 96 ha met ongeveer 1100 plaatsen. Basistarief 35 euro laagseizoen tot 68 euro hoogseizoen, stroom inbegrepen. Voorzieningen: wifi, broodservice, supermarkt, restaurant, overdekt zwembad, sauna en wellness, sanitair met familiebadkamers. Het hele jaar open. Geschikt voor gezinnen en als uitvalsbasis voor het zuiden.');

SELECT 'Travel data loaded: '
    || (SELECT COUNT(*) FROM CAMPSITES) || ' campsites, '
    || (SELECT COUNT(*) FROM EMISSION_ZONES) || ' emission zones, '
    || (SELECT COUNT(*) FROM TRAVEL_ADVISORIES) || ' advisories, '
    || (SELECT COUNT(*) FROM COUNTRY_INFO) || ' countries, '
    || (SELECT COUNT(*) FROM KB_DOCUMENTS) || ' KB docs ('
    || (SELECT COUNT(DISTINCT source_type) FROM KB_DOCUMENTS) || ' source types).' AS status;


-- ============================================================================
-- SEARCH  --  hybrid (vector + keyword) Cortex Search over the knowledge base
-- Indexing takes ~1 minute. Verify with SHOW CORTEX SEARCH SERVICES.
-- ============================================================================
-- (Built via EXECUTE IMMEDIATE because the WAREHOUSE clause here does not accept
--  IDENTIFIER($hb_wh); this keeps the warehouse driven by the CONFIG variable.)
EXECUTE IMMEDIATE $$
DECLARE stmt STRING;
BEGIN
  stmt := 'CREATE OR REPLACE CORTEX SEARCH SERVICE TRAVEL_KB '
       || 'ON content ATTRIBUTES title, category, source_type, source_url '
       || 'WAREHOUSE = ' || $hb_wh || ' TARGET_LAG = ''1 hour'' '
       || 'AS (SELECT doc_id, title, category, source_type, source_url, content FROM KB_DOCUMENTS)';
  EXECUTE IMMEDIATE :stmt;
  RETURN 'TRAVEL_KB search service created';
END;
$$;


-- ============================================================================
-- TOOLS  --  mock external tools (zero setup, always work, no network needed).
-- For live APIs (RDW open data + open-meteo) see tools/real_tools.sql (optional).
-- Defined in the TRAVEL schema so they resolve regardless of the DB name above.
-- ============================================================================

-- Vehicle registration lookup (like the RDW open-data API): make, model, fuel,
-- EURO emission norm, year, weight. Fictional demo plates for the scenarios.
CREATE OR REPLACE FUNCTION mock_rdw_lookup(kenteken VARCHAR)
RETURNS VARIANT
LANGUAGE SQL
AS
$$
    SELECT TO_VARIANT(CASE UPPER(REPLACE(kenteken, '-', ''))
        WHEN 'L345IJ' THEN OBJECT_CONSTRUCT('kenteken', kenteken, 'merk','BMW','model','320d','brandstof','Diesel','euronorm',6,'bouwjaar',2019,'gewicht_kg',1520,'voertuigsoort','Personenauto')
        WHEN 'K012GH' THEN OBJECT_CONSTRUCT('kenteken', kenteken, 'merk','Toyota','model','Yaris','brandstof','Benzine','euronorm',6,'bouwjaar',2018,'gewicht_kg',1045,'voertuigsoort','Personenauto')
        WHEN 'R123AB' THEN OBJECT_CONSTRUCT('kenteken', kenteken, 'merk','Volkswagen','model','ID.4','brandstof','Elektrisch','euronorm',NULL,'bouwjaar',2021,'gewicht_kg',2124,'voertuigsoort','Personenauto')
        WHEN 'XD429P' THEN OBJECT_CONSTRUCT('kenteken', kenteken, 'merk','Fiat','model','Ducato Camper','brandstof','Diesel','euronorm',4,'bouwjaar',2011,'gewicht_kg',3200,'voertuigsoort','Kampeerauto')
        WHEN 'BG881K' THEN OBJECT_CONSTRUCT('kenteken', kenteken, 'merk','Mercedes','model','Marco Polo','brandstof','Diesel','euronorm',6,'bouwjaar',2022,'gewicht_kg',2900,'voertuigsoort','Kampeerauto')
        ELSE OBJECT_CONSTRUCT('kenteken', kenteken, 'merk','Volkswagen','model','Transporter','brandstof','Diesel','euronorm',5,'bouwjaar',2016,'gewicht_kg',2600,'voertuigsoort','Kampeerauto','note','default demo vehicle for unknown plate')
    END)
$$;

-- Current weather + short forecast (like open-meteo).
CREATE OR REPLACE FUNCTION mock_weather(location VARCHAR)
RETURNS VARIANT
LANGUAGE SQL
AS
$$
    SELECT TO_VARIANT(OBJECT_CONSTRUCT(
        'location', location,
        'current_temp_c', 22 + (ABS(HASH(location)) % 10),
        'condition', ARRAY_CONSTRUCT('sunny','partly cloudy','light rain','clear')[ABS(HASH(location)) % 4],
        'forecast_3day', ARRAY_CONSTRUCT(
            OBJECT_CONSTRUCT('day','tomorrow','high_c', 24 + (ABS(HASH(location))%6), 'condition','sunny'),
            OBJECT_CONSTRUCT('day','day+2','high_c', 21 + (ABS(HASH(location))%6), 'condition','partly cloudy'),
            OBJECT_CONSTRUCT('day','day+3','high_c', 23 + (ABS(HASH(location))%6), 'condition','sunny')
        ),
        'note','mock data for demo'
    ))
$$;

-- Safety advisory (reads the internal table; unqualified name resolves in TRAVEL).
CREATE OR REPLACE FUNCTION travel_advisory_tool(country_name VARCHAR)
RETURNS VARIANT
LANGUAGE SQL
AS
$$
    SELECT TO_VARIANT(OBJECT_CONSTRUCT(
        'country', country,
        'advisory_level', advisory_level,
        'advisory_color', advisory_color,
        'summary', summary,
        'updated', updated_date::VARCHAR
    ))
    FROM TRAVEL_ADVISORIES
    WHERE LOWER(country) = LOWER(country_name)
    LIMIT 1
$$;

-- Indicative currency rate (optional tool).
CREATE OR REPLACE FUNCTION mock_currency(from_ccy VARCHAR, to_ccy VARCHAR)
RETURNS VARIANT
LANGUAGE SQL
AS
$$
    SELECT TO_VARIANT(OBJECT_CONSTRUCT(
        'from', UPPER(from_ccy), 'to', UPPER(to_ccy),
        'rate', CASE UPPER(from_ccy)||'>'||UPPER(to_ccy)
            WHEN 'EUR>GBP' THEN 0.85 WHEN 'GBP>EUR' THEN 1.18
            WHEN 'EUR>CHF' THEN 0.96 WHEN 'CHF>EUR' THEN 1.04
            WHEN 'EUR>DKK' THEN 7.46 WHEN 'DKK>EUR' THEN 0.134
            ELSE 1.0 END,
        'note','mock indicative rate'
    ))
$$;


-- ============================================================================
-- BUILD  --  the ReisNogWijzer flow in SQL. Run these blocks top to bottom;
-- each answers one sample question and shows the expected result.
-- ============================================================================

-- --- Q1: "Can I drive my diesel camper (plate XD-429-P) into Munich?" --------
-- Step 1: look up the vehicle (tool call).
SELECT mock_rdw_lookup('XD-429-P') AS vehicle;

-- Step 2: pull Munich's emission-zone facts (grounding data).
SELECT city, zone_name, sticker_required, min_euro_diesel, diesel_ban_min_euro, ev_exempt, caravan_note
FROM EMISSION_ZONES WHERE LOWER(city) = 'munich';

-- Step 3: let the model reason over vehicle + zone facts and answer in Dutch.
-- The field semantics are spelled out so the model applies the diesel DRIVING
-- BAN (diesel_ban_min_euro), not just the green-sticker threshold.
SELECT AI_COMPLETE($hb_model,
    'Je bent ReisNogWijzer, de reisassistent van de ANWB. Antwoord in het Nederlands, kort en concreet, begin met Ja of Nee. '
 || 'Voertuig: ' || mock_rdw_lookup('XD-429-P')::STRING
 || '  Regels milieuzone Munchen (let goed op het verschil): '
 || (SELECT 'groene sticker vereist minimaal Euro ' || min_euro_diesel || ' diesel; '
        || 'MAAR er geldt bovendien een dieselrijverbod: diesel moet minimaal Euro ' || diesel_ban_min_euro
        || ' zijn om de zone in te mogen. Diesels onder Euro ' || diesel_ban_min_euro
        || ' zijn verboden, OOK met een groene sticker. Elektrisch vrijgesteld: ' || ev_exempt
      FROM EMISSION_ZONES WHERE LOWER(city)='munich')
 || '  Vraag: Mag ik met deze dieselcamper (let op de euronorm) de milieuzone van Munchen in? Leg uit waarom wel of niet.'
) AS antwoord_munchen;

-- --- Q2: "Plan a 2-week camping trip through Austria and Italy." -------------
-- RAG: hybrid-search the knowledge base for grounding, then synthesize.
-- (SEARCH_PREVIEW returns JSON; we pass the top hits to the model.)
SELECT AI_COMPLETE($hb_model,
    'Je bent ReisNogWijzer. Gebruik onderstaande kennisbank-fragmenten om een beknopt 2-weken kampeerplan '
 || 'door Oostenrijk en Italie te maken (route, 3-4 campings, let op vignetten/tol). Antwoord in het Nederlands.'
 || '  Kennisbank: ' || (
        SELECT SUBSTR(TO_JSON(PARSE_JSON(
            SNOWFLAKE.CORTEX.SEARCH_PREVIEW('TRAVEL_KB',
              '{"query":"kamperen Oostenrijk Italie route vignet tol camping","columns":["title","content"],"limit":4}')
        ):results), 1, 3500)
    )
) AS reisplan;

-- --- Q3: "What are the current travel advisories for Croatia?" ---------------
SELECT travel_advisory_tool('Croatia') AS advisory_raw;
SELECT AI_COMPLETE($hb_model,
    'Vat dit reisadvies bondig samen voor een ANWB-lid, in het Nederlands, met de kleurcode: '
 || travel_advisory_tool('Croatia')::STRING) AS advisory_summary;


-- Final readiness line
SELECT 'ReisNogWijzer ready in ' || $hb_db || '.TRAVEL  |  model=' || $hb_model
    || '  |  search=TRAVEL_KB  |  tools: mock_rdw_lookup, mock_weather, travel_advisory_tool, mock_currency'
    AS status;

-- ============================================================================
-- SNOWSIGHT STEPS  --  the parts you do in the Snowsight UI (clicks, not SQL).
-- Do these after Run All above succeeds.
-- ----------------------------------------------------------------------------
-- STEP A - Build the ReisNogWijzer agent
--   1. Left nav > AI & ML > Agents > "+ Agent" (Create agent).
--   2. Schema HACKATHON_BOX.TRAVEL; name it REISNOGWIJZER; Create.
--   3. Open the agent > Tools:
--        - Add > Cortex Search  : HACKATHON_BOX.TRAVEL.TRAVEL_KB   (travel KB / RAG)
--        - Add > Custom tool (function), schema TRAVEL:
--            MOCK_RDW_LOOKUP(VARCHAR)       - vehicle info from a licence plate
--            MOCK_WEATHER(VARCHAR)          - travel weather
--            TRAVEL_ADVISORY_TOOL(VARCHAR)  - country safety advisory
--   4. Model = mistral-large2. Instructions: "You are ReisNogWijzer, a warm ANWB
--      travel expert. Answer in Dutch, grounded in the knowledge base and tools."
--   5. Save, open the chat, and ask the three questions:
--        - "Mag ik met mijn dieselcamper (XD-429-P) Munchen in?"   -> expect "Nee"
--        - "Plan een 2-weken kampeertrip door Oostenrijk en Italie."
--        - "Wat is het reisadvies voor Kroatie?"
--      You meet the criteria when RAG + at least two tools are actually called.
--
-- STEP B (optional) - Ship the chat app
--   Projects > Streamlit > "+ Streamlit App"; warehouse HACKATHON_WH, database
--   HACKATHON_BOX, schema TRAVEL. Paste app.py from this folder and Run.
--
-- STEP C (optional) - Inspect what the agent did (AI Observability)
--   AI & ML > Agents > REISNOGWIJZER > Monitoring: traces, tool calls, latency, tokens.
-- ============================================================================
