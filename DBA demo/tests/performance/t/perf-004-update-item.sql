-- perf-004: Update single item
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
UPDATE warehouse.stock_items
SET unit_price = unit_price * 1.05,
    typical_weight_per_unit = typical_weight_per_unit + 0.1
WHERE stock_item_id = 1;
