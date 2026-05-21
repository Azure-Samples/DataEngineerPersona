-- Translated from: Website.SearchForStockItems
-- Translation: Copilot + ora2pg merge
-- Patterns rewritten: sp_executesql → EXECUTE format() with %I/%L, TOP → LIMIT,
--   NOLOCK → removed, ISNULL → COALESCE, GETDATE() → NOW()
-- sqlfluff: PASS
-- pgtap: PASS

CREATE OR REPLACE FUNCTION warehouse.search_stock_items(
    p_search_text TEXT DEFAULT NULL,
    p_max_results INTEGER DEFAULT 20
)
RETURNS TABLE (
    stock_item_id INTEGER,
    stock_item_name VARCHAR(100),
    supplier_name VARCHAR(100),
    brand VARCHAR(50),
    unit_price NUMERIC(18,2),
    tax_rate NUMERIC(18,3),
    is_chiller_stock BOOLEAN,
    quantity_on_hand INTEGER
) AS $$
/*
    Reasoning (docs/schema-optimization-logic.md):
    - Original T-SQL: Built dynamic SQL via sp_executesql with NVARCHAR concatenation.
    - Copilot rewrite: Uses EXECUTE format() with %L for literal interpolation (SQL injection safe).
    - ora2pg: Kept sp_executesql pattern. Copilot version safer — %L escapes all user input.
    - NOLOCK removed (PG MVCC). TOP N → LIMIT N.
    - When search_text is NULL, returns all items (paginated).
*/
DECLARE
    v_sql TEXT;
BEGIN
    v_sql := '
        SELECT
            si.stock_item_id,
            si.stock_item_name,
            s.supplier_name,
            si.brand,
            si.unit_price,
            si.tax_rate,
            si.is_chiller_stock,
            COALESCE(sih.quantity_on_hand, 0)
        FROM warehouse.stock_items si
        LEFT JOIN purchasing.suppliers s ON si.supplier_id = s.supplier_id
        LEFT JOIN warehouse.stock_item_holdings sih ON si.stock_item_id = sih.stock_item_id
    ';

    IF p_search_text IS NOT NULL THEN
        v_sql := v_sql || format(
            ' WHERE si.stock_item_name ILIKE %L OR si.brand ILIKE %L',
            '%' || p_search_text || '%',
            '%' || p_search_text || '%'
        );
    END IF;

    v_sql := v_sql || ' ORDER BY si.stock_item_name';
    v_sql := v_sql || format(' LIMIT %s', p_max_results);

    RETURN QUERY EXECUTE v_sql;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION warehouse.search_stock_items IS
    'Search stock items by name/brand. sp_executesql rewritten to EXECUTE format() with %L (injection safe).';
