SELECT
  @@hostname AS db_hostname,
  DATABASE() AS db_name;

SELECT
  'target_liuyuan_only' AS metric,
  COUNT(*) AS row_count
FROM drh_ai_config_homework_route r
JOIN drh_ai_config_homework_strategy s ON s.id = r.strategy_id
WHERE r.enabled = 1
  AND s.enabled = 1
  AND s.strategy_name LIKE 'liuyuan-vocal-%'
  AND r.sku_id = '5'
  AND r.match_key = 'currentDay&&homeworkDayRelation&&qwUserId_RLike'
  AND r.match_value REGEXP '^[1-6]&&(CURRENT|PAST|FUTURE)&&liuyuan$';

SELECT
  'target_liuyuan_xiewenhao' AS metric,
  COUNT(*) AS row_count
FROM drh_ai_config_homework_route r
JOIN drh_ai_config_homework_strategy s ON s.id = r.strategy_id
WHERE r.enabled = 1
  AND s.enabled = 1
  AND s.strategy_name LIKE 'liuyuan-vocal-%'
  AND r.sku_id = '5'
  AND r.match_key = 'currentDay&&homeworkDayRelation&&qwUserId_RLike'
  AND r.match_value REGEXP '^[1-6]&&(CURRENT|PAST|FUTURE)&&liuyuan,xiewenhao$';

SELECT
  'duplicate_xiewenhao' AS metric,
  COUNT(*) AS row_count
FROM drh_ai_config_homework_route r
JOIN drh_ai_config_homework_strategy s ON s.id = r.strategy_id
WHERE r.enabled = 1
  AND s.enabled = 1
  AND s.strategy_name LIKE 'liuyuan-vocal-%'
  AND r.sku_id = '5'
  AND r.match_key = 'currentDay&&homeworkDayRelation&&qwUserId_RLike'
  AND r.match_value LIKE '%xiewenhao,xiewenhao%';

SELECT
  r.id,
  r.day_num,
  r.comment_index,
  r.comment_match_type,
  r.match_value,
  r.strategy_id,
  s.strategy_name
FROM drh_ai_config_homework_route r
JOIN drh_ai_config_homework_strategy s ON s.id = r.strategy_id
WHERE r.enabled = 1
  AND s.enabled = 1
  AND s.strategy_name LIKE 'liuyuan-vocal-%'
  AND r.sku_id = '5'
  AND r.match_key = 'currentDay&&homeworkDayRelation&&qwUserId_RLike'
ORDER BY r.day_num, r.comment_index, r.comment_match_type, r.id;
