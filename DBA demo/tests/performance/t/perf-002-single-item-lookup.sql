-- perf-002: Point lookup by primary key
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
SELECT * FROM warehouse.stock_items WHERE stock_item_id = 42;
