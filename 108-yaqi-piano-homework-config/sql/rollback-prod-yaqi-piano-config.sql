-- Rollback for production Yaqi piano homework config sync.

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

UPDATE drh_ai_config_homework_route
SET match_key = 'homeworkDayRelation',
    match_value = 'CURRENT',
    updated_by = 'yaqi_prod_sync_20260623_rollback',
    updated_at = NOW(6)
WHERE id = 14;

UPDATE drh_ai_config_homework_route
SET match_key = 'homeworkDayRelation',
    match_value = 'CURRENT',
    updated_by = 'yaqi_prod_sync_20260623_rollback',
    updated_at = NOW(6)
WHERE id = 15;

UPDATE drh_ai_config_homework_route
SET match_key = 'homeworkDayRelation',
    match_value = 'CURRENT',
    updated_by = 'yaqi_prod_sync_20260623_rollback',
    updated_at = NOW(6)
WHERE id = 16;

UPDATE drh_ai_config_homework_route
SET match_key = 'homeworkDayRelation',
    match_value = 'CURRENT',
    updated_by = 'yaqi_prod_sync_20260623_rollback',
    updated_at = NOW(6)
WHERE id = 17;

UPDATE drh_ai_config_homework_route
SET match_key = 'homeworkDayRelation',
    match_value = 'CURRENT',
    updated_by = 'yaqi_prod_sync_20260623_rollback',
    updated_at = NOW(6)
WHERE id = 18;

UPDATE drh_ai_config_homework_route
SET match_key = 'homeworkDayRelation',
    match_value = 'CURRENT',
    updated_by = 'yaqi_prod_sync_20260623_rollback',
    updated_at = NOW(6)
WHERE id = 19;

UPDATE drh_ai_config_homework_route
SET match_key = 'homeworkDayRelation',
    match_value = 'CURRENT',
    updated_by = 'yaqi_prod_sync_20260623_rollback',
    updated_at = NOW(6)
WHERE id = 20;

UPDATE drh_ai_config_homework_route
SET match_key = 'homeworkDayRelation',
    match_value = 'CURRENT',
    updated_by = 'yaqi_prod_sync_20260623_rollback',
    updated_at = NOW(6)
WHERE id = 21;

UPDATE drh_ai_config_homework_route
SET match_key = 'homeworkDayRelation',
    match_value = 'CURRENT',
    updated_by = 'yaqi_prod_sync_20260623_rollback',
    updated_at = NOW(6)
WHERE id = 22;

UPDATE drh_ai_config_homework_route
SET match_key = 'homeworkDayRelation',
    match_value = 'CURRENT',
    updated_by = 'yaqi_prod_sync_20260623_rollback',
    updated_at = NOW(6)
WHERE id = 23;

UPDATE drh_ai_config_homework_route
SET match_key = 'homeworkDayRelation',
    match_value = 'CURRENT',
    updated_by = 'yaqi_prod_sync_20260623_rollback',
    updated_at = NOW(6)
WHERE id = 24;

UPDATE drh_ai_config_homework_route
SET match_key = 'homeworkDayRelation',
    match_value = 'CURRENT',
    updated_by = 'yaqi_prod_sync_20260623_rollback',
    updated_at = NOW(6)
WHERE id = 25;

UPDATE drh_ai_config_homework_route
SET match_key = 'homeworkDayRelation',
    match_value = 'CURRENT',
    updated_by = 'yaqi_prod_sync_20260623_rollback',
    updated_at = NOW(6)
WHERE id = 26;

UPDATE drh_ai_config_homework_route
SET match_key = 'homeworkDayRelation',
    match_value = 'FUTURE',
    updated_by = 'yaqi_prod_sync_20260623_rollback',
    updated_at = NOW(6)
WHERE id = 27;

SELECT
  (SELECT COUNT(*) FROM drh_ai_config_homework_strategy WHERE strategy_name LIKE 'yaqi-piano-%') AS remaining_yaqi_strategy,
  (SELECT COUNT(*) FROM drh_ai_config_homework_route r JOIN drh_ai_config_homework_strategy s ON s.id = r.strategy_id WHERE s.strategy_name LIKE 'yaqi-piano-%') AS remaining_yaqi_route;
