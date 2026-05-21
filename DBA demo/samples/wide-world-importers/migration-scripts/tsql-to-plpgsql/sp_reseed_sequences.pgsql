-- Translated from: Sequences.ReseedSequenceBeyondTableValues + Sequences.ReseedAllSequences
-- Translation: Copilot + ora2pg merge
-- Patterns rewritten: Cursor → set-based with EXECUTE format(), sp_executesql → EXECUTE format(%I/%L),
--   Table variable → CTE, TRY/CATCH → EXCEPTION WHEN, @@ROWCOUNT → GET DIAGNOSTICS
-- sqlfluff: PASS
-- pgtap: PASS

CREATE OR REPLACE FUNCTION sequences.reseed_sequence_beyond_table(
    p_schema_name TEXT,
    p_table_name TEXT,
    p_column_name TEXT,
    p_sequence_name TEXT
)
RETURNS BIGINT AS $$
/*
    Reasoning (docs/schema-optimization-logic.md):
    - Original T-SQL: Used cursor + sp_executesql + table variable to iterate sequences
      and reseed each one beyond the max table value.

    - Copilot rewrite:
      * Cursor → single dynamic query with EXECUTE format().
      * sp_executesql → EXECUTE format() with %I (identifier quoting, injection safe).
      * Table variable → eliminated (single-row result).
      * TRY/CATCH → EXCEPTION WHEN.

    - ora2pg: Converted cursor to FOR...LOOP. Copilot's single-statement approach preferred.
*/
DECLARE
    v_max_val BIGINT;
    v_new_val BIGINT;
BEGIN
    -- Get max value from the table column
    EXECUTE format(
        'SELECT COALESCE(MAX(%I), 0) FROM %I.%I',
        p_column_name, p_schema_name, p_table_name
    ) INTO v_max_val;

    -- Set the sequence to max + 1
    v_new_val := v_max_val + 1;
    EXECUTE format(
        'ALTER SEQUENCE %I.%I RESTART WITH %s',
        p_schema_name, p_sequence_name, v_new_val
    );

    RETURN v_new_val;

EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Failed to reseed %.%: %', p_schema_name, p_sequence_name, SQLERRM;
    RETURN -1;
END;
$$ LANGUAGE plpgsql VOLATILE;


CREATE OR REPLACE FUNCTION sequences.reseed_all_sequences()
RETURNS TABLE (
    schema_name TEXT,
    sequence_name TEXT,
    new_value BIGINT
) AS $$
/*
    Reasoning: Original used cursor over all sequences. Rewritten using
    pg_sequences catalog + set-based processing.
*/
BEGIN
    RETURN QUERY
    WITH seq_info AS (
        SELECT
            s.schemaname::TEXT AS schema_name,
            s.sequencename::TEXT AS sequence_name,
            -- Map sequence name to table/column (convention: schema.TableNameID → schema.table_name.table_name_id)
            s.schemaname::TEXT AS tbl_schema,
            REPLACE(LOWER(s.sequencename), 'id', '')::TEXT AS tbl_base
        FROM pg_sequences s
        WHERE s.schemaname NOT IN ('pg_catalog', 'information_schema')
    )
    SELECT
        si.schema_name,
        si.sequence_name,
        sequences.reseed_sequence_beyond_table(
            si.tbl_schema,
            si.tbl_base || 's',  -- pluralized table name convention
            si.tbl_base || '_id',
            si.sequence_name
        ) AS new_value
    FROM seq_info si;
END;
$$ LANGUAGE plpgsql VOLATILE;

COMMENT ON FUNCTION sequences.reseed_sequence_beyond_table IS
    'Reseed a single sequence beyond its table max value. Cursor+sp_executesql → EXECUTE format(%I).';
COMMENT ON FUNCTION sequences.reseed_all_sequences IS
    'Reseed all sequences in the database. Cursor loop → set-based pg_sequences catalog query.';
