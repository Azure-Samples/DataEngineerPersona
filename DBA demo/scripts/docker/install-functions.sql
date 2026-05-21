-- Adapted PL/pgSQL functions for WideWorldImporters PostgreSQL migration
-- Column names match actual table structure (lowercased, no underscores)

-- 1. Get Stock Item by ID
CREATE OR REPLACE FUNCTION warehouse.get_stock_item_by_id(p_stock_item_id INTEGER)
RETURNS TABLE (
    r_stockitemid INTEGER, r_stockitemname VARCHAR(100), r_supplierid INTEGER,
    r_colorid INTEGER, r_unitpackageid INTEGER, r_outerpackageid INTEGER,
    r_brand VARCHAR(50), r_size VARCHAR(20), r_leadtimedays INTEGER,
    r_quantityperouter INTEGER, r_ischillerstock BOOLEAN,
    r_taxrate NUMERIC(18,3), r_unitprice NUMERIC(18,2),
    r_recommendedretailprice NUMERIC(18,2), r_typicalweightperunit NUMERIC(18,3),
    r_customfields TEXT, r_quantityonhand INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT si.stockitemid, si.stockitemname, si.supplierid, si.colorid,
           si.unitpackageid, si.outerpackageid, si.brand, si.size,
           si.leadtimedays, si.quantityperouter, si.ischillerstock,
           si.taxrate, si.unitprice, si.recommendedretailprice,
           si.typicalweightperunit, si.customfields, sih.quantityonhand
    FROM warehouse.stockitems si
    LEFT JOIN warehouse.stockitemholdings sih ON si.stockitemid = sih.stockitemid
    WHERE si.stockitemid = p_stock_item_id;
END;
$$ LANGUAGE plpgsql STABLE;

-- 2. Get Stock Items Paginated
CREATE OR REPLACE FUNCTION warehouse.get_stock_items_paginated(
    p_page_number INTEGER DEFAULT 1,
    p_page_size INTEGER DEFAULT 20
)
RETURNS TABLE (
    r_stockitemid INTEGER, r_stockitemname VARCHAR(100),
    r_supplierid INTEGER, r_unitprice NUMERIC(18,2),
    r_quantityonhand INTEGER, r_total_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT si.stockitemid, si.stockitemname, si.supplierid, si.unitprice,
           sih.quantityonhand,
           COUNT(*) OVER() AS total_count
    FROM warehouse.stockitems si
    LEFT JOIN warehouse.stockitemholdings sih ON si.stockitemid = sih.stockitemid
    ORDER BY si.stockitemname
    LIMIT p_page_size OFFSET (p_page_number - 1) * p_page_size;
END;
$$ LANGUAGE plpgsql STABLE;

-- 3. Search Stock Items (dynamic search with safe parameterization)
CREATE OR REPLACE FUNCTION warehouse.search_stock_items(
    p_search_term TEXT DEFAULT NULL,
    p_max_results INTEGER DEFAULT 50
)
RETURNS TABLE (
    r_stockitemid INTEGER, r_stockitemname VARCHAR(100),
    r_supplierid INTEGER, r_unitprice NUMERIC(18,2)
) AS $$
BEGIN
    RETURN QUERY
    SELECT si.stockitemid, si.stockitemname, si.supplierid, si.unitprice
    FROM warehouse.stockitems si
    WHERE p_search_term IS NULL
       OR si.stockitemname ILIKE '%' || p_search_term || '%'
       OR si.searchdetails ILIKE '%' || p_search_term || '%'
    ORDER BY si.stockitemname
    LIMIT p_max_results;
END;
$$ LANGUAGE plpgsql STABLE;

-- 4. Insert Customer Order (cursor rewritten to CTE, MERGE to upsert)
CREATE OR REPLACE FUNCTION sales.insert_customer_order(
    p_customerid INTEGER,
    p_orderdate DATE,
    p_expecteddeliverydate DATE,
    p_salespersonid INTEGER,
    p_order_lines JSONB
)
RETURNS INTEGER AS $$
DECLARE
    v_orderid INTEGER;
BEGIN
    SELECT COALESCE(MAX(orderid), 0) + 1 INTO v_orderid FROM sales.orders;

    INSERT INTO sales.orders (
        orderid, customerid, salespersonpersonid, contactpersonid,
        orderdate, expecteddeliverydate, isundersupplybackordered,
        lasteditedby, lasteditedwhen
    ) VALUES (
        v_orderid, p_customerid, p_salespersonid, p_salespersonid,
        p_orderdate, p_expecteddeliverydate, false,
        p_salespersonid, NOW()
    );

    INSERT INTO sales.orderlines (
        orderlineid, orderid, stockitemid, description,
        packagetypeid, quantity, unitprice, taxrate,
        pickedquantity, lasteditedby, lasteditedwhen
    )
    SELECT
        (SELECT COALESCE(MAX(orderlineid), 0) FROM sales.orderlines) + row_number() OVER(),
        v_orderid,
        (line->>'stockitemid')::INTEGER,
        (line->>'description')::TEXT,
        (line->>'packagetypeid')::INTEGER,
        (line->>'quantity')::INTEGER,
        (line->>'unitprice')::NUMERIC,
        (line->>'taxrate')::NUMERIC,
        0, p_salespersonid, NOW()
    FROM jsonb_array_elements(p_order_lines) AS line;

    RETURN v_orderid;
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Failed to insert order: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- 5. Update Stock Item Holdings (cursor eliminated, single UPDATE)
CREATE OR REPLACE FUNCTION warehouse.update_stock_item_holdings(
    p_stockitemid INTEGER,
    p_quantity_change INTEGER,
    p_lasteditedby INTEGER
)
RETURNS VOID AS $$
DECLARE
    v_rows INTEGER;
BEGIN
    UPDATE warehouse.stockitemholdings
    SET quantityonhand = quantityonhand + p_quantity_change,
        lasteditedby = p_lasteditedby,
        lasteditedwhen = NOW()
    WHERE stockitemid = p_stockitemid;

    GET DIAGNOSTICS v_rows = ROW_COUNT;

    IF v_rows = 0 THEN
        RAISE EXCEPTION 'Stock item % not found in holdings', p_stockitemid;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Failed to update holdings: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- 6. Invoice Customer Orders (cursor to CTE, @@ROWCOUNT to GET DIAGNOSTICS)
CREATE OR REPLACE FUNCTION sales.invoice_customer_orders(
    p_customerid INTEGER,
    p_invoicedate DATE,
    p_lasteditedby INTEGER
)
RETURNS INTEGER AS $$
DECLARE
    v_invoiceid INTEGER;
    v_rows INTEGER;
BEGIN
    SELECT COALESCE(MAX(invoiceid), 0) + 1 INTO v_invoiceid FROM sales.invoices;

    WITH pending_orders AS (
        SELECT orderid FROM sales.orders
        WHERE customerid = p_customerid
          AND orderid NOT IN (SELECT orderid FROM sales.invoices WHERE orderid IS NOT NULL)
        LIMIT 1
    )
    INSERT INTO sales.invoices (
        invoiceid, customerid, billtocustomerid, orderid,
        deliverymethodid, contactpersonid, accountspersonid,
        salespersonpersonid, packedbypersonid, invoicedate,
        iscreditnote, totaldryitems, totalchilleritems,
        lasteditedby, lasteditedwhen
    )
    SELECT
        v_invoiceid, p_customerid, p_customerid, po.orderid,
        c.deliverymethodid, c.primarycontactpersonid, p_lasteditedby,
        (SELECT salespersonpersonid FROM sales.orders WHERE orderid = po.orderid),
        p_lasteditedby, p_invoicedate, false, 0, 0,
        p_lasteditedby, NOW()
    FROM pending_orders po
    CROSS JOIN sales.customers c
    WHERE c.customerid = p_customerid;

    GET DIAGNOSTICS v_rows = ROW_COUNT;
    IF v_rows = 0 THEN
        RETURN NULL;
    END IF;

    INSERT INTO sales.invoicelines (
        invoicelineid, invoiceid, stockitemid, description,
        packagetypeid, quantity, unitprice, taxrate,
        taxamount, lineprofit, extendedprice,
        lasteditedby, lasteditedwhen
    )
    SELECT
        (SELECT COALESCE(MAX(invoicelineid), 0) FROM sales.invoicelines) + row_number() OVER(),
        v_invoiceid, ol.stockitemid, ol.description,
        ol.packagetypeid, ol.quantity, ol.unitprice, ol.taxrate,
        ROUND(ol.quantity * ol.unitprice * ol.taxrate / 100, 2),
        ROUND(ol.quantity * ol.unitprice * 0.1, 2),
        ROUND(ol.quantity * ol.unitprice * (1 + ol.taxrate / 100), 2),
        p_lasteditedby, NOW()
    FROM sales.orderlines ol
    JOIN sales.invoices inv ON inv.invoiceid = v_invoiceid AND inv.orderid = ol.orderid;

    RETURN v_invoiceid;
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Failed to invoice: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;
