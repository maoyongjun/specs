SET NAMES utf8mb4;
SET @operator = 'rollback_liuyuan_xiewenhao_config_20260603';

UPDATE drh_ai_config_homework_route r
JOIN drh_ai_config_homework_strategy s ON s.id = r.strategy_id
SET
  r.match_value = REGEXP_REPLACE(r.match_value, ',xiewenhao$', ''),
  r.updated_by = @operator,
  r.updated_at = NOW()
WHERE r.enabled = 1
  AND s.enabled = 1
  AND s.strategy_name LIKE 'liuyuan-vocal-%'
  AND r.sku_id = '5'
  AND r.match_key = 'currentDay&&homeworkDayRelation&&qwUserId_RLike'
  AND r.match_value REGEXP '^[1-6]&&(CURRENT|PAST|FUTURE)&&liuyuan,xiewenhao$';

SELECT ROW_COUNT() AS affected_rows;
