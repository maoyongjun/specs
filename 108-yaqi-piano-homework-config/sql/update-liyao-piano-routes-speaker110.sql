UPDATE drh_ai_config_homework_route
SET
  match_key = 'currentDay&&homeworkDayRelation&&speakerId',
  match_value = CONCAT(day_num, '&&', match_value, '&&110'),
  updated_by = 'yaqi_config_20260623',
  updated_at = NOW(3)
WHERE enabled = 1
  AND sku_id = '4'
  AND match_key = 'homeworkDayRelation'
  AND match_value IN ('CURRENT', 'PAST', 'FUTURE');
