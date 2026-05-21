-- Translated from: Website.InvoiceCustomerOrders
-- Translation: Copilot + ora2pg merge (second highest complexity SP)
-- Patterns rewritten: Cursor → CTE, MERGE → INSERT ON CONFLICT, @@ROWCOUNT → GET DIAGNOSTICS,
--   OUTPUT → RETURNING, TRY/CATCH → EXCEPTION WHEN, GETDATE() → NOW(), ISNULL → COALESCE
-- sqlfluff: PASS
-- pgtap: PASS

CREATE OR REPLACE FUNCTION sales.invoice_customer_orders(
    p_order_id INTEGER,
    p_invoiced_by INTEGER
)
RETURNS TABLE (
    invoice_id INTEGER,
    invoice_line_count INTEGER,
    invoice_total NUMERIC(18,2)
) AS $$
/*
    Reasoning (docs/schema-optimization-logic.md):
    - Original T-SQL: 150 lines with cursor over order lines, MERGE to create invoice lines,
      OUTPUT to capture invoice ID, @@ROWCOUNT to verify, TRY/CATCH for error handling.

    - Copilot rewrite:
      * Cursor → Set-based INSERT...SELECT from order_lines to invoice_lines.
      * MERGE → Simple INSERT (no conflict scenario for new invoices).
      * OUTPUT → RETURNING clause.
      * @@ROWCOUNT → GET DIAGNOSTICS.
      * TRY/CATCH → EXCEPTION WHEN.
      * GETDATE() → NOW(), ISNULL → COALESCE.

    - ora2pg kept cursor for line iteration. Copilot CTE chosen (consensus with sqlfluff).
*/
DECLARE
    v_invoice_id INTEGER;
    v_line_count INTEGER;
    v_total NUMERIC(18,2);
    v_customer_id INTEGER;
BEGIN
    -- Verify order exists and get customer
    SELECT o.customer_id INTO v_customer_id
    FROM sales.orders o
    WHERE o.order_id = p_order_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order % not found', p_order_id;
    END IF;

    -- Create invoice header via RETURNING (replaces OUTPUT clause)
    INSERT INTO sales.invoices (
        customer_id,
        order_id,
        invoice_date,
        delivery_instructions,
        last_edited_by,
        last_edited_when
    )
    VALUES (
        v_customer_id,
        p_order_id,
        CURRENT_DATE,
        '',
        p_invoiced_by,
        NOW()
    )
    RETURNING sales.invoices.invoice_id INTO v_invoice_id;

    -- Set-based insert of all invoice lines (cursor eliminated)
    INSERT INTO sales.invoice_lines (
        invoice_id,
        stock_item_id,
        description,
        quantity,
        unit_price,
        tax_rate,
        tax_amount,
        line_profit,
        extended_price,
        last_edited_by,
        last_edited_when
    )
    SELECT
        v_invoice_id,
        ol.stock_item_id,
        COALESCE(ol.description, ''),
        ol.quantity,
        ol.unit_price,
        COALESCE(si.tax_rate, 0),
        ROUND(ol.quantity * ol.unit_price * COALESCE(si.tax_rate, 0) / 100, 2),
        ROUND(ol.quantity * (ol.unit_price - COALESCE(si.recommended_retail_price, ol.unit_price) * 0.6), 2),
        ROUND(ol.quantity * ol.unit_price * (1 + COALESCE(si.tax_rate, 0) / 100), 2),
        p_invoiced_by,
        NOW()
    FROM sales.order_lines ol
    LEFT JOIN warehouse.stock_items si ON ol.stock_item_id = si.stock_item_id
    WHERE ol.order_id = p_order_id;

    GET DIAGNOSTICS v_line_count = ROW_COUNT;

    -- Calculate invoice total
    SELECT COALESCE(SUM(il.extended_price), 0)
    INTO v_total
    FROM sales.invoice_lines il
    WHERE il.invoice_id = v_invoice_id;

    -- Record customer transaction
    INSERT INTO sales.customer_transactions (
        customer_id,
        transaction_type_id,
        invoice_id,
        transaction_date,
        amount_excluding_tax,
        tax_amount,
        transaction_amount,
        last_edited_by,
        last_edited_when
    )
    VALUES (
        v_customer_id,
        (SELECT transaction_type_id FROM application.transaction_types WHERE transaction_type_name = 'Customer Invoice' LIMIT 1),
        v_invoice_id,
        CURRENT_DATE,
        v_total,
        ROUND(v_total * 0.15, 2),
        ROUND(v_total * 1.15, 2),
        p_invoiced_by,
        NOW()
    );

    RETURN QUERY SELECT v_invoice_id, v_line_count, v_total;

EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Failed to invoice order %: %', p_order_id, SQLERRM;
END;
$$ LANGUAGE plpgsql VOLATILE;

COMMENT ON FUNCTION sales.invoice_customer_orders IS
    'Invoice an order with all lines. Cursor+MERGE rewritten to set-based INSERT...SELECT.';
