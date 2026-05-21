-- Translated from: Warehouse.StockItemHoldings update logic (extracted from Website.InsertCustomerOrders)
-- Translation: Copilot + ora2pg merge
-- Patterns rewritten: Cursor → single UPDATE, @@ROWCOUNT → GET DIAGNOSTICS, TRY/CATCH → EXCEPTION WHEN
-- sqlfluff: PASS
-- pgtap: PASS

CREATE OR REPLACE FUNCTION warehouse.update_stock_item_holdings(
    p_stock_item_id INTEGER,
    p_quantity_change INTEGER
)
RETURNS VOID AS $$
/*
    Reasoning (docs/schema-optimization-logic.md):
    - Original T-SQL used a cursor to iterate and update holdings row-by-row.
    - Rewritten as single UPDATE statement — set-based is 10-100x faster.
    - @@ROWCOUNT replaced with GET DIAGNOSTICS for row verification.
    - TRY/CATCH replaced with EXCEPTION WHEN for block-scoped error handling.
    - Business rule: quantity_on_hand must not go below zero (CHECK constraint).
*/
DECLARE
    v_row_count INTEGER;
    v_current_quantity INTEGER;
BEGIN
    -- Check current stock level before update
    SELECT quantity_on_hand INTO v_current_quantity
    FROM warehouse.stock_item_holdings
    WHERE stock_item_id = p_stock_item_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Stock item % not found in holdings', p_stock_item_id;
    END IF;

    IF v_current_quantity + p_quantity_change < 0 THEN
        RAISE EXCEPTION 'Insufficient stock for item %. Current: %, Requested change: %',
            p_stock_item_id, v_current_quantity, p_quantity_change;
    END IF;

    -- Perform the update
    UPDATE warehouse.stock_item_holdings
    SET quantity_on_hand = quantity_on_hand + p_quantity_change,
        last_edited_when = NOW(),
        last_stocktake_quantity = CASE
            WHEN p_quantity_change > 0 THEN last_stocktake_quantity + p_quantity_change
            ELSE last_stocktake_quantity
        END
    WHERE stock_item_id = p_stock_item_id;

    GET DIAGNOSTICS v_row_count = ROW_COUNT;

    IF v_row_count = 0 THEN
        RAISE EXCEPTION 'No holdings row updated for stock item %', p_stock_item_id;
    END IF;

EXCEPTION WHEN OTHERS THEN
    RAISE;
END;
$$ LANGUAGE plpgsql VOLATILE;

COMMENT ON FUNCTION warehouse.update_stock_item_holdings IS
    'Update stock quantity. Cursor rewritten to single UPDATE. Business rule: no negative stock.';
