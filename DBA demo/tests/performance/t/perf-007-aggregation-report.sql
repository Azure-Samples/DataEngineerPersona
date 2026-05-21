-- perf-007: Aggregation report (multi-join)
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
SELECT
  s.supplier_name,
  COUNT(si.stock_item_id) AS item_count,
  AVG(si.unit_price) AS avg_price,
  SUM(sih.quantity_on_hand) AS total_stock,
  COUNT(*) FILTER (WHERE sih.quantity_on_hand <= sih.reorder_level) AS items_below_reorder
FROM purchasing.suppliers s
JOIN warehouse.stock_items si ON s.supplier_id = si.supplier_id
LEFT JOIN warehouse.stock_item_holdings sih ON si.stock_item_id = sih.stock_item_id
GROUP BY s.supplier_name
ORDER BY total_stock DESC;
