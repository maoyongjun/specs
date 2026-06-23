SELECT
  id,
  strategy_name,
  sku_id,
  enabled,
  remark,
  created_by,
  updated_by,
  DATE_FORMAT(created_at, '%Y-%m-%d %H:%i:%s.%f') AS created_at,
  DATE_FORMAT(updated_at, '%Y-%m-%d %H:%i:%s.%f') AS updated_at
FROM drh_ai_config_homework_strategy
ORDER BY id;
