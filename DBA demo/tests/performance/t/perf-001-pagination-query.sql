-- perf-001: Paginated query
-- Equivalent to typical catalog/list page query
-- Measure with: EXPLAIN (ANALYZE, BUFFERS, TIMING)
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
SELECT si.stock_item_id, si.stock_item_name, si.unit_price,
       si.quantity_per_outer, si.is_chiller_stock
FROM warehouse.stock_items si
ORDER BY si.stock_item_name
LIMIT 20 OFFSET 0;
