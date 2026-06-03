SELECT
  CAST(COALESCE(SUM(
    CASE
      WHEN r.match_value REGEXP '^[1-6]&&(CURRENT|PAST|FUTURE)&&liuyuan$' THEN 1
      ELSE 0
    END
  ), 0) AS UNSIGNED) AS target_liuyuan_only,
  CAST(COALESCE(SUM(
    CASE
      WHEN r.match_value REGEXP '^[1-6]&&(CURRENT|PAST|FUTURE)&&liuyuan,xiewenhao$' THEN 1
      ELSE 0
    END
  ), 0) AS UNSIGNED) AS target_liuyuan_xiewenhao,
  CAST(COALESCE(SUM(
    CASE
      WHEN r.match_value LIKE '%xiewenhao,xiewenhao%' THEN 1
      ELSE 0
    END
  ), 0) AS UNSIGNED) AS duplicate_xiewenhao,
  COUNT(*) AS total_liuyuan_vocal_routes
FROM drh_ai_config_homework_route r
JOIN drh_ai_config_homework_strategy s ON s.id = r.strategy_id
WHERE r.enabled = 1
  AND s.enabled = 1
  AND s.strategy_name LIKE 'liuyuan-vocal-%'
  AND r.sku_id = '5'
  AND r.match_key = 'currentDay&&homeworkDayRelation&&qwUserId_RLike';
