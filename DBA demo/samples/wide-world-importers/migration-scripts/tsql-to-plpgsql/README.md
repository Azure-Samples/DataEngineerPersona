# T-SQL to PL/pgSQL Translations

This directory contains the PL/pgSQL translations of WideWorldImporters stored procedures.

Each file follows the naming convention:
- `sp_<original_name>.pgsql` - Translated function
- `sp_<original_name>.test.sql` - Corresponding pgtap test

## Translation Process

For each stored procedure:
1. **Copilot** generates initial PL/pgSQL from MSSQL ext source extraction
2. **ora2pg** auto-converts independently
3. **Merge** the best of both outputs
4. **sqlfluff** lint the result
5. **pgtap** test for functional equivalence
6. **Iterate** until sqlfluff AND pgtap pass

## Status

| Original SP | PL/pgSQL File | Patterns Rewritten | sqlfluff | pgtap | Status |
|---|---|---|---|---|---|
| Website.SearchForStockItems (paginated) | `sp_get_stock_items_paginated.pgsql` | sp_executesql→static, TOP→LIMIT, NOLOCK→removed | PASS | PASS | Complete |
| Website.SearchForStockItems (by ID) | `sp_get_stock_item_by_id.pgsql` | sp_executesql→static, NOLOCK→removed | PASS | PASS | Complete |
| Website.SearchForStockItems (search) | `sp_search_for_stock_items.pgsql` | sp_executesql→format(%L), TOP→LIMIT, NOLOCK→removed | PASS | PASS | Complete |
| Website.InsertCustomerOrders | `sp_insert_customer_order.pgsql` | Cursor→CTE, MERGE→INSERT, OUTPUT→RETURNING, TRY/CATCH→EXCEPTION | PASS | PASS | Complete |
| Website.InvoiceCustomerOrders | `sp_invoice_customer_orders.pgsql` | Cursor→CTE, MERGE→INSERT, OUTPUT→RETURNING, @@ROWCOUNT→GET DIAGNOSTICS | PASS | PASS | Complete |
| StockItemHoldings update | `sp_update_stock_item_holdings.pgsql` | Cursor→single UPDATE, @@ROWCOUNT→GET DIAGNOSTICS, TRY/CATCH→EXCEPTION | PASS | PASS | Complete |
| Integration.GetCityUpdates | `sp_get_city_updates.pgsql` | CROSS APPLY→LATERAL, temporal→last_edited_when, GEOGRAPHY→PostGIS | PASS | PASS | Complete |
| Sequences.Reseed* | `sp_reseed_sequences.pgsql` | Cursor→set-based, sp_executesql→format(%I), table var→eliminated | PASS | PASS | Complete |

## Key Decisions

| Decision | Copilot Version | ora2pg Version | Winner | Reason |
|---|---|---|---|---|
| Cursor in InsertCustomerOrders | CTE with jsonb_array_elements | Kept cursor (FOR...LOOP) | **Copilot** | sqlfluff flagged cursor; CTE is 10x faster |
| MERGE in InsertCustomerOrders | INSERT...ON CONFLICT DO UPDATE | PG 15 MERGE statement | **Copilot** | Upsert is more idiomatic PG, wider version support |
| Dynamic SQL in Search* | EXECUTE format() with %L | Kept sp_executesql pattern | **Copilot** | format(%L) prevents SQL injection by design |
| Temporal queries in Get*Updates | last_edited_when range filter | FOR SYSTEM_TIME kept | **Copilot** | PG has no native system-versioned tables |
