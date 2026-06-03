SET NAMES utf8mb4;

DELETE FROM `drh_ai_config_homework_route`
WHERE `id` BETWEEN 91 AND 124
  AND `match_key` = 'currentDay&&homeworkDayRelation&&qwUserId_RLike'
  AND `match_value` REGEXP '^[1-6]&&(CURRENT|PAST|FUTURE)&&liuyuan,xiewenhao$'
  AND `sku_id` = '5';

DELETE FROM `drh_ai_config_homework_action`
WHERE `id` IN (
  311,313,315,317,319,321,322,323,324,325,326,327,328,329,330,331,332,333,334,
  335,336,337,338,339,340,341,342,343,344,345,346,347,348,349
)
  AND `updated_by` = 'liuyuan_config_20260601';

DELETE FROM `drh_ai_config_homework_strategy`
WHERE `id` BETWEEN 50 AND 83
  AND `strategy_name` LIKE 'liuyuan-vocal-%'
  AND `sku_id` = '5'
  AND `updated_by` = 'liuyuan_config_20260601';
