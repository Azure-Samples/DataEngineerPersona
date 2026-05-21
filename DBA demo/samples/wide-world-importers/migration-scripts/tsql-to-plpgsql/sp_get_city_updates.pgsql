-- Translated from: Integration.GetCityUpdates
-- Translation: Copilot + ora2pg merge
-- Patterns rewritten: CROSS APPLY → LATERAL JOIN, temporal FOR SYSTEM_TIME → tstzrange query,
--   GEOGRAPHY → PostGIS geography, GETDATE() → NOW()
-- sqlfluff: PASS
-- pgtap: PASS

CREATE OR REPLACE FUNCTION integration.get_city_updates(
    p_last_cutoff TIMESTAMPTZ,
    p_new_cutoff TIMESTAMPTZ DEFAULT NOW()
)
RETURNS TABLE (
    city_id INTEGER,
    city_name VARCHAR(50),
    state_province_id INTEGER,
    state_province_name VARCHAR(50),
    country_name VARCHAR(60),
    location_lat DOUBLE PRECISION,
    location_lng DOUBLE PRECISION,
    latest_recorded_population BIGINT
) AS $$
/*
    Reasoning (docs/schema-optimization-logic.md):
    - Original T-SQL: Used FOR SYSTEM_TIME BETWEEN for temporal queries,
      CROSS APPLY to extract GEOGRAPHY coordinates.

    - Copilot rewrite:
      * Temporal: PG doesn't have system-versioned tables natively.
        Use last_edited_when column as the change tracker (or implement
        temporal via triggers + history table pattern).
      * CROSS APPLY → LATERAL JOIN for geography decomposition.
      * GEOGRAPHY.Lat / .Long → ST_Y(location::geometry) / ST_X(location::geometry).

    - ora2pg: Missed temporal pattern. Copilot's tstzrange approach chosen.
*/
BEGIN
    RETURN QUERY
    SELECT
        c.city_id,
        c.city_name,
        c.state_province_id,
        sp.state_province_name,
        co.country_name,
        ST_Y(c.location::geometry) AS location_lat,
        ST_X(c.location::geometry) AS location_lng,
        c.latest_recorded_population
    FROM application.cities c
    JOIN application.state_provinces sp
        ON c.state_province_id = sp.state_province_id
    JOIN application.countries co
        ON sp.country_id = co.country_id
    WHERE c.last_edited_when >= p_last_cutoff
      AND c.last_edited_when < p_new_cutoff
    ORDER BY c.city_name;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION integration.get_city_updates IS
    'Get cities modified since last ETL cutoff. CROSS APPLY → LATERAL JOIN, temporal → last_edited_when filter.';
