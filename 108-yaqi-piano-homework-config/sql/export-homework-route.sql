SELECT
  id,
  day_num,
  comment_index,
  comment_match_type,
  match_key,
  match_value,
  sku_id,
  strategy_id,
  enabled,
  created_by,
  updated_by,
  DATE_FORMAT(created_at, '%Y-%m-%d %H:%i:%s.%f') AS created_at,
  DATE_FORMAT(updated_at, '%Y-%m-%d %H:%i:%s.%f') AS updated_at
FROM drh_ai_config_homework_route
ORDER BY id;
