-- Translated from: Website.SearchForStockItems (single-item lookup subset)
-- Translation: Copilot + ora2pg merge
-- Patterns rewritten: sp_executesql → static query, NOLOCK → removed
-- sqlfluff: PASS
-- pgtap: PASS

CREATE OR REPLACE FUNCTION warehouse.get_stock_item_by_id(
    p_stock_item_id INTEGER
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
    custom_fields TEXT,
    quantity_on_hand INTEGER
) AS $$
/*
    Reasoning:
    - Original used sp_executesql with parameter sniffing.
    - Static query is faster and safer — no injection risk.
    - JOIN to StockItemHoldings for inventory level in single call.
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
        si.custom_fields,
        sih.quantity_on_hand
    FROM warehouse.stock_items si
    LEFT JOIN warehouse.stock_item_holdings sih
        ON si.stock_item_id = sih.stock_item_id
    WHERE si.stock_item_id = p_stock_item_id;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION warehouse.get_stock_item_by_id IS
    'Single stock item lookup with inventory level. Migrated from Website.SearchForStockItems.';
