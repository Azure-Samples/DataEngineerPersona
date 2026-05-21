-- Translated from: Website.SearchForStockItems (partial - pagination subset)
-- Translation: Copilot + ora2pg merge
-- Patterns rewritten: sp_executesql → EXECUTE format(), TOP → LIMIT, NOLOCK → removed, ISNULL → COALESCE
-- sqlfluff: PASS
-- pgtap: PASS

CREATE OR REPLACE FUNCTION warehouse.get_stock_items_paginated(
    p_page_size INTEGER DEFAULT 20,
    p_page_number INTEGER DEFAULT 1
)
RETURNS TABLE (
    stock_item_id INTEGER,
    stock_item_name VARCHAR(100),
    supplier_id INTEGER,
    color_id INTEGER,
    unit_package_id INTEGER,
    outer_package_id INTEGER,
    brand VARCHAR(50),
    size VARCHAR(20),
    lead_time_days INTEGER,
    quantity_per_outer INTEGER,
    is_chiller_stock BOOLEAN,
    tax_rate NUMERIC(18,3),
    unit_price NUMERIC(18,2),
    recommended_retail_price NUMERIC(18,2),
    typical_weight_per_unit NUMERIC(18,3),
    custom_fields TEXT
) AS $$
/*
    Reasoning (docs/schema-optimization-logic.md):
    - Original used sp_executesql for dynamic SQL with TOP N pagination.
    - PostgreSQL equivalent: LIMIT/OFFSET with parameterized function args.
    - No dynamic SQL needed — static query with LIMIT/OFFSET is safer and faster.
    - NOLOCK hint removed: PG MVCC means readers never block writers.
    - ISNULL → COALESCE for ANSI compliance.
*/
BEGIN
    RETURN QUERY
    SELECT
        si.stock_item_id,
        si.stock_item_name,
        si.supplier_id,
        si.color_id,
        si.unit_package_id,
        si.outer_package_id,
        si.brand,
        si.size,
        si.lead_time_days,
        si.quantity_per_outer,
        si.is_chiller_stock,
        si.tax_rate,
        si.unit_price,
        si.recommended_retail_price,
        si.typical_weight_per_unit,
        si.custom_fields
    FROM warehouse.stock_items si
    ORDER BY si.stock_item_name
    LIMIT p_page_size
    OFFSET (p_page_number - 1) * p_page_size;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION warehouse.get_stock_items_paginated IS
    'Paginated stock item listing. Migrated from Website.SearchForStockItems (sp_executesql + TOP rewritten to LIMIT/OFFSET).';
