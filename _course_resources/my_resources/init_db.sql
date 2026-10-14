-- ============================================================
-- Step 1: Importing Raw Tables
-- ============================================================
-- Set up the defaults
CREATE WAREHOUSE IF NOT EXISTS COMPUTE_WH;
USE WAREHOUSE COMPUTE_WH;

DROP DATABASE IF EXISTS AIRBNB CASCADE;

CREATE DATABASE AIRBNB;

CREATE SCHEMA IF NOT EXISTS AIRBNB.RAW;
CREATE SCHEMA IF NOT EXISTS AIRBNB.DEV;

USE DATABASE AIRBNB;
USE SCHEMA RAW;

-- Create our three tables and import the data from S3
CREATE OR REPLACE TABLE raw_listings
                    (id integer,
                     listing_url string,
                     name string,
                     room_type string,
                     minimum_nights integer,
                     host_id integer,
                     price string,
                     created_at datetime,
                     updated_at datetime);

COPY INTO raw_listings (id,
                        listing_url,
                        name,
                        room_type,
                        minimum_nights,
                        host_id,
                        price,
                        created_at,
                        updated_at)
                   from 's3://dbt-datasets/listings.csv'
                    FILE_FORMAT = (type = 'CSV' skip_header = 1
                    FIELD_OPTIONALLY_ENCLOSED_BY = '"');


CREATE OR REPLACE TABLE raw_reviews
                    (listing_id integer,
                     date datetime,
                     reviewer_name string,
                     comments string,
                     sentiment string);

COPY INTO raw_reviews (listing_id, date, reviewer_name, comments, sentiment)
                   from 's3://dbt-datasets/reviews.csv'
                    FILE_FORMAT = (type = 'CSV' skip_header = 1
                    FIELD_OPTIONALLY_ENCLOSED_BY = '"');


CREATE OR REPLACE TABLE raw_hosts
                    (id integer,
                     name string,
                     is_superhost string,
                     created_at datetime,
                     updated_at datetime);

COPY INTO raw_hosts (id, name, is_superhost, created_at, updated_at)
                   from 's3://dbt-datasets/hosts.csv'
                    FILE_FORMAT = (type = 'CSV' skip_header = 1
                    FIELD_OPTIONALLY_ENCLOSED_BY = '"');

-- ============================================================
-- Step 2: Setting up the dbt User and Roles
-- ============================================================
-- Use an admin role
USE ROLE ACCOUNTADMIN;

-- Create the `transform` role
DROP ROLE IF EXISTS TRANSFORM;
CREATE ROLE TRANSFORM;
GRANT ROLE TRANSFORM TO ROLE ACCOUNTADMIN;

-- Create the default warehouse if necessary
GRANT OPERATE ON WAREHOUSE COMPUTE_WH TO ROLE TRANSFORM;

-- Create the `dbt` user and assign to role
DROP USER IF EXISTS dbt;
CREATE USER IF NOT EXISTS dbt
  LOGIN_NAME='dbt'
  TYPE=SERVICE
  RSA_PUBLIC_KEY="-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAi/Aw57T9lO8YjvjB6TA7
MjOF8cMjIIrYVklxbxkRfGyTyig9LZjjZw3dkWBdAiGzpSSqnYZ+yDR5ljZc6aeO
6+COan2XubRbk9uYEJwWBlMuRxbyY8BwGLDR0PG8eoY3efdn0RWfKrwQQ2R4A2Eg
LRA+JzrkeOQu1yB6jKJGK/wWOspBcieAnthWKcRpAphEcFo5nNeivOyWj5V3jYFE
xxzAu16tBHwwsV705bkaVKf20FOi49Cts/IkmSjY5SwgFVfDMQUpEFSVzKj8AwnN
i+Via/8mWm++mhqcpu0SdLhpl+PnaIwPSt15MjUQQOiVZlZvjZsJU01NHVj9FJ9a
gQIDAQAB
-----END PUBLIC KEY-----
"
  DEFAULT_ROLE=TRANSFORM
  DEFAULT_WAREHOUSE='COMPUTE_WH'
  DEFAULT_NAMESPACE='AIRBNB.RAW'
  COMMENT='DBT user used for data transformation';

GRANT ROLE TRANSFORM to USER dbt;

-- Set up permissions to role `transform`
GRANT ALL ON WAREHOUSE COMPUTE_WH TO ROLE TRANSFORM;
GRANT ALL ON DATABASE AIRBNB to ROLE TRANSFORM;
GRANT ALL ON ALL SCHEMAS IN DATABASE AIRBNB to ROLE TRANSFORM;
GRANT ALL ON FUTURE SCHEMAS IN DATABASE AIRBNB to ROLE TRANSFORM;
GRANT ALL ON ALL TABLES IN SCHEMA AIRBNB.RAW to ROLE TRANSFORM;
GRANT ALL ON FUTURE TABLES IN SCHEMA AIRBNB.RAW to ROLE TRANSFORM;

-- Create the user and permissions for Preset.io
USE ROLE ACCOUNTADMIN;

DROP ROLE IF EXISTS REPORTER;
CREATE ROLE REPORTER;

DROP USER IF EXISTS PRESET;
CREATE USER PRESET
  LOGIN_NAME='preset'
  TYPE=SERVICE
  RSA_PUBLIC_KEY="-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAi/Aw57T9lO8YjvjB6TA7
MjOF8cMjIIrYVklxbxkRfGyTyig9LZjjZw3dkWBdAiGzpSSqnYZ+yDR5ljZc6aeO
6+COan2XubRbk9uYEJwWBlMuRxbyY8BwGLDR0PG8eoY3efdn0RWfKrwQQ2R4A2Eg
LRA+JzrkeOQu1yB6jKJGK/wWOspBcieAnthWKcRpAphEcFo5nNeivOyWj5V3jYFE
xxzAu16tBHwwsV705bkaVKf20FOi49Cts/IkmSjY5SwgFVfDMQUpEFSVzKj8AwnN
i+Via/8mWm++mhqcpu0SdLhpl+PnaIwPSt15MjUQQOiVZlZvjZsJU01NHVj9FJ9a
gQIDAQAB
-----END PUBLIC KEY-----
"
  DEFAULT_WAREHOUSE='COMPUTE_WH'
  DEFAULT_ROLE=REPORTER
  DEFAULT_NAMESPACE='AIRBNB.DEV'
 COMMENT='Preset user for creating reports';

GRANT ROLE REPORTER TO USER PRESET;
GRANT ROLE REPORTER TO ROLE ACCOUNTADMIN;
GRANT ALL ON WAREHOUSE COMPUTE_WH TO ROLE REPORTER;
GRANT USAGE ON DATABASE AIRBNB TO ROLE REPORTER;
GRANT USAGE ON ALL SCHEMAS IN DATABASE AIRBNB to ROLE REPORTER;
GRANT USAGE ON FUTURE SCHEMAS IN DATABASE AIRBNB to ROLE REPORTER;
GRANT SELECT ON ALL TABLES IN SCHEMA AIRBNB.DEV to ROLE REPORTER;
GRANT SELECT ON FUTURE TABLES IN SCHEMA AIRBNB.DEV to ROLE REPORTER;

-- ============================================================
-- Step 3: Importing AIRSTATS Capstone Tables
-- ============================================================
-- AIRSTATS Database Setup for Snowflake
-- Source: OurAirports.com (Public Domain)
-- Data loaded directly from public S3 bucket: s3://dbt-datasets/airstats/csv/

-- Database and Schema Setup
CREATE DATABASE IF NOT EXISTS AIRSTATS;
USE DATABASE AIRSTATS;
CREATE SCHEMA IF NOT EXISTS RAW;
USE SCHEMA RAW;

-- AIRPORTS: Global airport data (~72K rows)
CREATE OR REPLACE TABLE airports (
    id                  INTEGER,
    ident               STRING,
    type                STRING,
    name                STRING,
    latitude_deg        FLOAT,
    longitude_deg       FLOAT,
    elevation_ft        INTEGER,
    continent           STRING,
    iso_country         STRING,
    iso_region          STRING,
    municipality        STRING,
    scheduled_service   STRING,
    gps_code            STRING,
    iata_code           STRING,
    local_code          STRING,
    home_link           STRING,
    wikipedia_link      STRING,
    keywords            STRING
);

COPY INTO airports (id, ident, type, name, latitude_deg, longitude_deg,
                    elevation_ft, continent, iso_country, iso_region,
                    municipality, scheduled_service, gps_code, iata_code,
                    local_code, home_link, wikipedia_link, keywords)
    FROM 's3://dbt-datasets/airstats/csv/airports.csv'
    FILE_FORMAT = (TYPE = 'CSV' SKIP_HEADER = 1 FIELD_OPTIONALLY_ENCLOSED_BY = '"');

-- AIRPORT_COMMENTS: User comments about airports (fact table with timestamps)
CREATE OR REPLACE TABLE airport_comments (
    id                  INTEGER,
    thread_ref          INTEGER,
    airport_ref         INTEGER,
    airport_ident       STRING,
    date                DATETIME,
    member_nickname     STRING,
    subject             STRING,
    body                STRING,
    loaded_at           TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP
);

COPY INTO airport_comments (id, thread_ref, airport_ref, airport_ident,
                            date, member_nickname, subject, body)
    FROM 's3://dbt-datasets/airstats/csv/airport_comments.csv'
    FILE_FORMAT = (TYPE = 'CSV' SKIP_HEADER = 1 FIELD_OPTIONALLY_ENCLOSED_BY = '"');

-- RUNWAYS: Runway information (~44K rows) - joins to airports via airport_ref/airport_ident
CREATE OR REPLACE TABLE runways (
    id                          INTEGER,
    airport_ref                 INTEGER,
    airport_ident               STRING,
    length_ft                   INTEGER,
    width_ft                    INTEGER,
    surface                     STRING,
    lighted                     INTEGER,
    closed                      INTEGER,
    le_ident                    STRING,
    le_latitude_deg             FLOAT,
    le_longitude_deg            FLOAT,
    le_elevation_ft             INTEGER,
    le_heading_degT             FLOAT,
    le_displaced_threshold_ft   INTEGER,
    he_ident                    STRING,
    he_latitude_deg             FLOAT,
    he_longitude_deg            FLOAT,
    he_elevation_ft             INTEGER,
    he_heading_degT             FLOAT,
    he_displaced_threshold_ft   INTEGER
);

COPY INTO runways (id, airport_ref, airport_ident, length_ft, width_ft, surface,
                   lighted, closed, le_ident, le_latitude_deg, le_longitude_deg,
                   le_elevation_ft, le_heading_degT, le_displaced_threshold_ft,
                   he_ident, he_latitude_deg, he_longitude_deg, he_elevation_ft,
                   he_heading_degT, he_displaced_threshold_ft)
    FROM 's3://dbt-datasets/airstats/csv/runways.csv'
    FILE_FORMAT = (TYPE = 'CSV' SKIP_HEADER = 1 FIELD_OPTIONALLY_ENCLOSED_BY = '"');

-- Permission Grants for AIRSTATS database
USE ROLE ACCOUNTADMIN;

-- TRANSFORM role permissions (for dbt user)
GRANT ALL ON DATABASE AIRSTATS TO ROLE TRANSFORM;
GRANT ALL ON ALL SCHEMAS IN DATABASE AIRSTATS TO ROLE TRANSFORM;
GRANT ALL ON FUTURE SCHEMAS IN DATABASE AIRSTATS TO ROLE TRANSFORM;
GRANT ALL ON ALL TABLES IN SCHEMA AIRSTATS.RAW TO ROLE TRANSFORM;
GRANT ALL ON FUTURE TABLES IN SCHEMA AIRSTATS.RAW TO ROLE TRANSFORM;

-- REPORTER role permissions (for preset user)
GRANT USAGE ON DATABASE AIRSTATS TO ROLE REPORTER;
GRANT USAGE ON ALL SCHEMAS IN DATABASE AIRSTATS TO ROLE REPORTER;
GRANT USAGE ON FUTURE SCHEMAS IN DATABASE AIRSTATS TO ROLE REPORTER;
GRANT SELECT ON ALL TABLES IN SCHEMA AIRSTATS.RAW TO ROLE REPORTER;
GRANT SELECT ON FUTURE TABLES IN SCHEMA AIRSTATS.RAW TO ROLE REPORTER;