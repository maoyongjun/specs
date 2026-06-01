SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

TRUNCATE TABLE drh_ai_config_homework_route;
TRUNCATE TABLE drh_ai_config_homework_action;
TRUNCATE TABLE drh_ai_config_homework_strategy;

SOURCE C:/workspace/ju-chat/specs/043-homework-config-zhangkai-vocal/sql/prod-homework-config-data.sql;

SET FOREIGN_KEY_CHECKS = 1;

SELECT 'strategy' AS table_name, COUNT(*) AS row_count FROM drh_ai_config_homework_strategy
UNION ALL
SELECT 'action' AS table_name, COUNT(*) AS row_count FROM drh_ai_config_homework_action
UNION ALL
SELECT 'route' AS table_name, COUNT(*) AS row_count FROM drh_ai_config_homework_route;
