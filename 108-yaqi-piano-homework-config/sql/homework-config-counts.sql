SELECT
  (SELECT COUNT(*) FROM drh_ai_config_homework_strategy WHERE enabled = 1) AS enabled_strategy_count,
  (SELECT COUNT(*) FROM drh_ai_config_homework_action WHERE enabled = 1) AS enabled_action_count,
  (SELECT COUNT(*) FROM drh_ai_config_homework_route WHERE enabled = 1) AS enabled_route_count,
  (SELECT COUNT(*) FROM drh_ai_config_homework_strategy) AS total_strategy_count,
  (SELECT COUNT(*) FROM drh_ai_config_homework_action) AS total_action_count,
  (SELECT COUNT(*) FROM drh_ai_config_homework_route) AS total_route_count;
