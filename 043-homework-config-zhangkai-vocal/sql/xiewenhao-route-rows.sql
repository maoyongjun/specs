SELECT
  r.id AS route_id,
  r.day_num,
  r.comment_index,
  r.comment_match_type,
  r.match_key,
  r.match_value,
  r.sku_id,
  r.strategy_id,
  s.strategy_name,
  COALESCE(GROUP_CONCAT(a.action_type ORDER BY a.order_index, a.id SEPARATOR ','), '') AS action_types
FROM drh_ai_config_homework_route r
JOIN drh_ai_config_homework_strategy s ON s.id = r.strategy_id
LEFT JOIN drh_ai_config_homework_action a
  ON a.strategy_id = s.id
 AND a.enabled = 1
WHERE r.enabled = 1
  AND s.enabled = 1
  AND s.strategy_name LIKE 'liuyuan-vocal-%'
  AND r.sku_id = '5'
  AND r.match_key = 'currentDay&&homeworkDayRelation&&qwUserId_RLike'
GROUP BY
  r.id,
  r.day_num,
  r.comment_index,
  r.comment_match_type,
  r.match_key,
  r.match_value,
  r.sku_id,
  r.strategy_id,
  s.strategy_name
ORDER BY r.day_num, r.comment_index, r.comment_match_type, r.id;
