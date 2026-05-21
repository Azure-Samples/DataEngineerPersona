-- perf-003: Insert with sequence
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
INSERT INTO warehouse.stock_items (
  stock_item_name, supplier_id, color_id, unit_package_id,
  outer_package_id, lead_time_days, quantity_per_outer,
  is_chiller_stock, tax_rate, unit_price, typical_weight_per_unit,
  last_edited_by
) VALUES (
  'Test Item Perf-003', 1, 1, 1, 1, 7, 10, false, 15.0, 9.99, 0.5, 1
)
RETURNING stock_item_id;
