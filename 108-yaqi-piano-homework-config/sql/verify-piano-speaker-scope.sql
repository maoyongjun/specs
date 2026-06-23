SELECT
  SUM(CASE WHEN s.strategy_name NOT LIKE 'yaqi-piano-%' THEN 1 ELSE 0 END) AS old_sku4_route_count,
  SUM(CASE WHEN s.strategy_name LIKE 'yaqi-piano-%' THEN 1 ELSE 0 END) AS yaqi_route_count,
  SUM(CASE
        WHEN s.strategy_name NOT LIKE 'yaqi-piano-%'
         AND (r.match_key <> 'currentDay&&homeworkDayRelation&&speakerId'
              OR r.match_value NOT LIKE '%&&110')
        THEN 1 ELSE 0
      END) AS old_speaker_violation_count,
  SUM(CASE
        WHEN s.strategy_name LIKE 'yaqi-piano-%'
         AND (r.match_key <> 'currentDay&&homeworkDayRelation&&speakerId'
              OR r.match_value NOT LIKE '%&&113')
        THEN 1 ELSE 0
      END) AS yaqi_speaker_violation_count
FROM drh_ai_config_homework_route r
JOIN drh_ai_config_homework_strategy s ON s.id = r.strategy_id
WHERE r.enabled = 1
  AND r.sku_id = '4';

SELECT
  r.id AS route_id,
  r.day_num,
  r.comment_index,
  r.comment_match_type,
  r.match_key,
  r.match_value,
  s.strategy_name
FROM drh_ai_config_homework_route r
JOIN drh_ai_config_homework_strategy s ON s.id = r.strategy_id
WHERE r.enabled = 1
  AND r.sku_id = '4'
  AND (
    (s.strategy_name NOT LIKE 'yaqi-piano-%'
      AND (r.match_key <> 'currentDay&&homeworkDayRelation&&speakerId'
           OR r.match_value NOT LIKE '%&&110'))
    OR
    (s.strategy_name LIKE 'yaqi-piano-%'
      AND (r.match_key <> 'currentDay&&homeworkDayRelation&&speakerId'
           OR r.match_value NOT LIKE '%&&113'))
  )
ORDER BY r.id;
