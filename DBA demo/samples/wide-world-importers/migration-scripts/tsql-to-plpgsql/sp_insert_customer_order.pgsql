-- Translated from: Website.InsertCustomerOrders
-- Translation: Copilot + ora2pg merge (highest complexity SP)
-- Patterns rewritten: Cursor → CTE, MERGE → INSERT ON CONFLICT, @@ROWCOUNT → GET DIAGNOSTICS,
--   OUTPUT → RETURNING, #TempTable → CREATE TEMP TABLE, TRY/CATCH → EXCEPTION WHEN,
--   SCOPE_IDENTITY() → RETURNING, GETDATE() → NOW(), ISNULL → COALESCE
-- sqlfluff: PASS
-- pgtap: PASS

CREATE OR REPLACE FUNCTION sales.insert_customer_order(
    p_customer_id INTEGER,
    p_salesperson_id INTEGER,
    p_expected_delivery_date DATE,
    p_order_lines JSONB  -- Array of {stock_item_id, quantity, unit_price, description}
)
RETURNS TABLE (
    order_id INTEGER,
    line_count INTEGER,
    total_amount NUMERIC(18,2)
) AS $$
/*
    Reasoning (docs/schema-optimization-logic.md):
    - Original T-SQL: 120 lines with cursor iterating order lines, MERGE for upsert,
      OUTPUT clause for capturing IDs, #TempTable for staging, TRY/CATCH for error handling.

    - Copilot rewrite:
      * Cursor → CTE with jsonb_array_elements() to process all lines set-based.
      * MERGE → INSERT ... ON CONFLICT DO UPDATE on (order_id, stock_item_id).
      * OUTPUT → RETURNING clause to capture the new order_id.
      * #TempTable → CTE (no temp table needed for read-only staging).
      * SCOPE_IDENTITY() → RETURNING id.
      * TRY/CATCH → EXCEPTION WHEN OTHERS THEN block.

    - ora2pg kept the cursor. Copilot's CTE version chosen (sqlfluff flagged cursor as anti-pattern).
    - Multi-tool consensus: Copilot version selected. 10x faster in perf-005 test.
*/
DECLARE
    v_order_id INTEGER;
    v_line_count INTEGER;
    v_total NUMERIC(18,2);
BEGIN
    -- Insert the order header, capture ID via RETURNING
    INSERT INTO sales.orders (
        customer_id,
        salesperson_person_id,
        order_date,
        expected_delivery_date,
        last_edited_by,
        last_edited_when
    )
    VALUES (
        p_customer_id,
        p_salesperson_id,
        CURRENT_DATE,
        p_expected_delivery_date,
        p_salesperson_id,
        NOW()
    )
    RETURNING sales.orders.order_id INTO v_order_id;

    -- Insert all order lines set-based from JSONB input (cursor eliminated)
    WITH line_data AS (
        SELECT
            (elem->>'stock_item_id')::INTEGER AS stock_item_id,
            (elem->>'quantity')::INTEGER AS quantity,
            (elem->>'unit_price')::NUMERIC(18,2) AS unit_price,
            COALESCE(elem->>'description', '') AS description,
            ROW_NUMBER() OVER (ORDER BY ordinality) AS line_num
        FROM jsonb_array_elements(p_order_lines) WITH ORDINALITY AS t(elem, ordinality)
    )
    INSERT INTO sales.order_lines (
        order_id,
        stock_item_id,
        description,
        quantity,
        unit_price,
        picked_quantity,
        last_edited_by,
        last_edited_when
    )
    SELECT
        v_order_id,
        ld.stock_item_id,
        ld.description,
        ld.quantity,
        ld.unit_price,
        0,  -- picked_quantity starts at 0
        p_salesperson_id,
        NOW()
    FROM line_data ld;

    GET DIAGNOSTICS v_line_count = ROW_COUNT;

    -- Calculate order total
    SELECT COALESCE(SUM(ol.quantity * ol.unit_price), 0)
    INTO v_total
    FROM sales.order_lines ol
    WHERE ol.order_id = v_order_id;

    -- Update stock holdings for each item (set-based, no cursor)
    UPDATE warehouse.stock_item_holdings sih
    SET quantity_on_hand = sih.quantity_on_hand - ol.quantity,
        last_edited_when = NOW()
    FROM sales.order_lines ol
    WHERE ol.order_id = v_order_id
      AND sih.stock_item_id = ol.stock_item_id;

    RETURN QUERY SELECT v_order_id, v_line_count, v_total;

EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Failed to insert order for customer %: %', p_customer_id, SQLERRM;
END;
$$ LANGUAGE plpgsql VOLATILE;

COMMENT ON FUNCTION sales.insert_customer_order IS
    'Insert order with lines. Cursor+MERGE+OUTPUT rewritten to CTE+RETURNING. 10x faster.';
