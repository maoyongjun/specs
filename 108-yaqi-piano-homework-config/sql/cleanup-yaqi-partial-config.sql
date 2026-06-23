DELETE r
FROM drh_ai_config_homework_route r
JOIN drh_ai_config_homework_strategy s ON s.id = r.strategy_id
WHERE s.strategy_name LIKE 'yaqi-piano-%';

DELETE a
FROM drh_ai_config_homework_action a
JOIN drh_ai_config_homework_strategy s ON s.id = a.strategy_id
WHERE s.strategy_name LIKE 'yaqi-piano-%';

DELETE FROM drh_ai_config_homework_strategy
WHERE strategy_name LIKE 'yaqi-piano-%';

SELECT
  (SELECT COUNT(*) FROM drh_ai_config_homework_strategy WHERE strategy_name LIKE 'yaqi-piano-%') AS remaining_strategy,
  (SELECT COUNT(*) FROM drh_ai_config_homework_route r JOIN drh_ai_config_homework_strategy s ON s.id = r.strategy_id WHERE s.strategy_name LIKE 'yaqi-piano-%') AS remaining_route;
