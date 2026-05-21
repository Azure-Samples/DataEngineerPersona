-- perf-006: Delete
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
DELETE FROM warehouse.stock_items
WHERE stock_item_name = 'Test Item Perf-003';
