-- perf-005: Business-rule-heavy update (inventory adjustment)
-- This is the critical SP5 equivalent - tests complex business logic
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
WITH stock_check AS (
  SELECT stock_item_id, quantity_on_hand, reorder_level, target_stock_level
  FROM warehouse.stock_item_holdings
  WHERE stock_item_id = 1
)
UPDATE warehouse.stock_item_holdings h
SET quantity_on_hand = sc.quantity_on_hand - 5,
    last_edited_when = NOW()
FROM stock_check sc
WHERE h.stock_item_id = sc.stock_item_id
  AND sc.quantity_on_hand >= 5;
