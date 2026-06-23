SELECT
  r.id AS route_id,
  r.day_num,
  r.comment_index,
  r.comment_match_type,
  r.match_key,
  r.match_value,
  r.sku_id,
  s.strategy_name,
  COUNT(a.id) AS enabled_action_count,
  GROUP_CONCAT(a.action_type ORDER BY a.order_index, a.id SEPARATOR ',') AS action_types
FROM drh_ai_config_homework_route r
JOIN drh_ai_config_homework_strategy s ON s.id = r.strategy_id
LEFT JOIN drh_ai_config_homework_action a
  ON a.strategy_id = s.id
 AND a.enabled = 1
WHERE r.enabled = 1
  AND r.sku_id = '4'
GROUP BY
  r.id,
  r.day_num,
  r.comment_index,
  r.comment_match_type,
  r.match_key,
  r.match_value,
  r.sku_id,
  s.strategy_name
ORDER BY r.day_num, r.comment_index, r.id;
