-- Production incremental sync for Yaqi piano homework config.

-- Scope: drh_ai_config_homework_strategy/action/route only.

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

UPDATE drh_ai_config_homework_route r
JOIN drh_ai_config_homework_strategy s ON s.id = r.strategy_id
SET r.match_key = 'currentDay&&homeworkDayRelation&&speakerId',
    r.match_value = CONCAT(
      r.day_num,
      '&&',
      CASE
        WHEN r.match_key = 'currentDay&&homeworkDayRelation&&speakerId' THEN SUBSTRING_INDEX(SUBSTRING_INDEX(r.match_value, '&&', 2), '&&', -1)
        WHEN r.match_key = 'homeworkDayRelation' THEN r.match_value
        WHEN r.match_value LIKE '%&&%' THEN SUBSTRING_INDEX(SUBSTRING_INDEX(r.match_value, '&&', 2), '&&', -1)
        ELSE r.match_value
      END,
      '&&110'
    ),
    r.updated_by = 'yaqi_prod_sync_20260623',
    r.updated_at = NOW(6)
WHERE r.enabled = 1
  AND r.sku_id = '4'
  AND s.strategy_name NOT LIKE 'yaqi-piano-%';

INSERT INTO drh_ai_config_homework_strategy (strategy_name, sku_id, enabled, remark, created_by, updated_by, created_at, updated_at)
VALUES ('yaqi-piano-day1-comment1', '4', 1, '', 'yaqi_prod_sync_20260623', 'yaqi_prod_sync_20260623', NOW(6), NOW(6));

INSERT INTO drh_ai_config_homework_strategy (strategy_name, sku_id, enabled, remark, created_by, updated_by, created_at, updated_at)
VALUES ('yaqi-piano-day2-comment1', '4', 1, '', 'yaqi_prod_sync_20260623', 'yaqi_prod_sync_20260623', NOW(6), NOW(6));

INSERT INTO drh_ai_config_homework_strategy (strategy_name, sku_id, enabled, remark, created_by, updated_by, created_at, updated_at)
VALUES ('yaqi-piano-day3-comment1', '4', 1, '', 'yaqi_prod_sync_20260623', 'yaqi_prod_sync_20260623', NOW(6), NOW(6));

INSERT INTO drh_ai_config_homework_strategy (strategy_name, sku_id, enabled, remark, created_by, updated_by, created_at, updated_at)
VALUES ('yaqi-piano-day4-comment1', '4', 1, '', 'yaqi_prod_sync_20260623', 'yaqi_prod_sync_20260623', NOW(6), NOW(6));

INSERT INTO drh_ai_config_homework_action (strategy_id, order_index, action_type, condition_key, condition_value, text_content, material_url, oss_url, voice_duration_millis, pdf_file_name, pdf_file_size_bytes, delay_millis, enabled, created_by, updated_by, created_at, updated_at)
SELECT s.id, 1, 'VOICE', 'question', '折指', NULL, 'https://kkhc.tos-cn-beijing.volces.com/eps-juzibot/permanent/material/%36%61%33%61%37%34%36%31%61%61%61%30%64%30%66%34%65%32%35%33%31%32%30%64.silk', 'https://drh.likeduoduiyi.cn/homework/voice/570603ce57cb42d7b7ec60429741e54a.mp3', 27000, NULL, NULL, 27000, 1, 'yaqi_prod_sync_20260623', 'yaqi_prod_sync_20260623', NOW(6), NOW(6)
FROM (SELECT id FROM drh_ai_config_homework_strategy WHERE strategy_name = 'yaqi-piano-day1-comment1' AND enabled = 1 ORDER BY id DESC LIMIT 1) s;

INSERT INTO drh_ai_config_homework_action (strategy_id, order_index, action_type, condition_key, condition_value, text_content, material_url, oss_url, voice_duration_millis, pdf_file_name, pdf_file_size_bytes, delay_millis, enabled, created_by, updated_by, created_at, updated_at)
SELECT s.id, 2, 'VIDEO_CHANNEL', 'question', '折指', 'V23', NULL, NULL, NULL, NULL, NULL, 2000, 1, 'yaqi_prod_sync_20260623', 'yaqi_prod_sync_20260623', NOW(6), NOW(6)
FROM (SELECT id FROM drh_ai_config_homework_strategy WHERE strategy_name = 'yaqi-piano-day1-comment1' AND enabled = 1 ORDER BY id DESC LIMIT 1) s;

INSERT INTO drh_ai_config_homework_action (strategy_id, order_index, action_type, condition_key, condition_value, text_content, material_url, oss_url, voice_duration_millis, pdf_file_name, pdf_file_size_bytes, delay_millis, enabled, created_by, updated_by, created_at, updated_at)
SELECT s.id, 3, 'VOICE', 'question', '折指', NULL, 'https://kkhc.tos-cn-beijing.volces.com/eps-juzibot/permanent/material/%36%61%33%61%37%34%36%32%61%30%36%37%63%30%66%64%37%39%62%66%61%31%66%38.silk', 'https://drh.likeduoduiyi.cn/homework/voice/8d1c58eeb6454c8d85b3bb4d339b44b0.mp3', 35000, NULL, NULL, 35000, 1, 'yaqi_prod_sync_20260623', 'yaqi_prod_sync_20260623', NOW(6), NOW(6)
FROM (SELECT id FROM drh_ai_config_homework_strategy WHERE strategy_name = 'yaqi-piano-day1-comment1' AND enabled = 1 ORDER BY id DESC LIMIT 1) s;

INSERT INTO drh_ai_config_homework_action (strategy_id, order_index, action_type, condition_key, condition_value, text_content, material_url, oss_url, voice_duration_millis, pdf_file_name, pdf_file_size_bytes, delay_millis, enabled, created_by, updated_by, created_at, updated_at)
SELECT s.id, 4, 'VOICE', 'question', '折指', NULL, 'https://kkhc.tos-cn-beijing.volces.com/eps-juzibot/permanent/material/%36%61%33%61%37%34%36%34%61%30%36%37%63%30%66%64%37%39%62%66%61%32%63%35.silk', 'https://drh.likeduoduiyi.cn/homework/voice/d566ea6559a5449e868c13d12a68d337.mp3', 35000, NULL, NULL, 35000, 1, 'yaqi_prod_sync_20260623', 'yaqi_prod_sync_20260623', NOW(6), NOW(6)
FROM (SELECT id FROM drh_ai_config_homework_strategy WHERE strategy_name = 'yaqi-piano-day1-comment1' AND enabled = 1 ORDER BY id DESC LIMIT 1) s;

INSERT INTO drh_ai_config_homework_action (strategy_id, order_index, action_type, condition_key, condition_value, text_content, material_url, oss_url, voice_duration_millis, pdf_file_name, pdf_file_size_bytes, delay_millis, enabled, created_by, updated_by, created_at, updated_at)
SELECT s.id, 5, 'VOICE', 'question', '折指', NULL, 'https://kkhc.tos-cn-beijing.volces.com/eps-juzibot/permanent/material/%36%61%33%61%37%34%36%36%61%61%61%30%64%30%66%34%65%32%35%33%31%34%34%37.silk', 'https://drh.likeduoduiyi.cn/homework/voice/0d4d861ae301459e8ca1480958d218ea.mp3', 20000, NULL, NULL, 20000, 1, 'yaqi_prod_sync_20260623', 'yaqi_prod_sync_20260623', NOW(6), NOW(6)
FROM (SELECT id FROM drh_ai_config_homework_strategy WHERE strategy_name = 'yaqi-piano-day1-comment1' AND enabled = 1 ORDER BY id DESC LIMIT 1) s;

INSERT INTO drh_ai_config_homework_action (strategy_id, order_index, action_type, condition_key, condition_value, text_content, material_url, oss_url, voice_duration_millis, pdf_file_name, pdf_file_size_bytes, delay_millis, enabled, created_by, updated_by, created_at, updated_at)
SELECT s.id, 1, 'VOICE', 'question', '翘指', NULL, 'https://kkhc.tos-cn-beijing.volces.com/eps-juzibot/permanent/material/%36%61%33%61%37%34%36%37%34%34%31%38%65%65%61%61%65%35%31%35%39%36%36%63.silk', 'https://drh.likeduoduiyi.cn/homework/voice/65f75b49bc5d4863b23dab54be70fe86.mp3', 27000, NULL, NULL, 27000, 1, 'yaqi_prod_sync_20260623', 'yaqi_prod_sync_20260623', NOW(6), NOW(6)
FROM (SELECT id FROM drh_ai_config_homework_strategy WHERE strategy_name = 'yaqi-piano-day1-comment1' AND enabled = 1 ORDER BY id DESC LIMIT 1) s;

INSERT INTO drh_ai_config_homework_action (strategy_id, order_index, action_type, condition_key, condition_value, text_content, material_url, oss_url, voice_duration_millis, pdf_file_name, pdf_file_size_bytes, delay_millis, enabled, created_by, updated_by, created_at, updated_at)
SELECT s.id, 2, 'VIDEO_CHANNEL', 'question', '翘指', 'V23', NULL, NULL, NULL, NULL, NULL, 2000, 1, 'yaqi_prod_sync_20260623', 'yaqi_prod_sync_20260623', NOW(6), NOW(6)
FROM (SELECT id FROM drh_ai_config_homework_strategy WHERE strategy_name = 'yaqi-piano-day1-comment1' AND enabled = 1 ORDER BY id DESC LIMIT 1) s;

INSERT INTO drh_ai_config_homework_action (strategy_id, order_index, action_type, condition_key, condition_value, text_content, material_url, oss_url, voice_duration_millis, pdf_file_name, pdf_file_size_bytes, delay_millis, enabled, created_by, updated_by, created_at, updated_at)
SELECT s.id, 3, 'VOICE', 'question', '翘指', NULL, 'https://kkhc.tos-cn-beijing.volces.com/eps-juzibot/permanent/material/%36%61%33%61%37%34%36%39%61%30%36%37%63%30%66%64%37%39%62%66%61%35%35%34.silk', 'https://drh.likeduoduiyi.cn/homework/voice/0105a163d2244123bd6bf67fb505e8d7.mp3', 20000, NULL, NULL, 20000, 1, 'yaqi_prod_sync_20260623', 'yaqi_prod_sync_20260623', NOW(6), NOW(6)
FROM (SELECT id FROM drh_ai_config_homework_strategy WHERE strategy_name = 'yaqi-piano-day1-comment1' AND enabled = 1 ORDER BY id DESC LIMIT 1) s;

INSERT INTO drh_ai_config_homework_action (strategy_id, order_index, action_type, condition_key, condition_value, text_content, material_url, oss_url, voice_duration_millis, pdf_file_name, pdf_file_size_bytes, delay_millis, enabled, created_by, updated_by, created_at, updated_at)
SELECT s.id, 4, 'VOICE', 'question', '翘指', NULL, 'https://kkhc.tos-cn-beijing.volces.com/eps-juzibot/permanent/material/%36%61%33%61%37%34%36%61%61%30%36%37%63%30%66%64%37%39%62%66%61%36%30%33.silk', 'https://drh.likeduoduiyi.cn/homework/voice/4ea58b699f5a4ebbb715950dc06a1610.mp3', 35000, NULL, NULL, 35000, 1, 'yaqi_prod_sync_20260623', 'yaqi_prod_sync_20260623', NOW(6), NOW(6)
FROM (SELECT id FROM drh_ai_config_homework_strategy WHERE strategy_name = 'yaqi-piano-day1-comment1' AND enabled = 1 ORDER BY id DESC LIMIT 1) s;

INSERT INTO drh_ai_config_homework_action (strategy_id, order_index, action_type, condition_key, condition_value, text_content, material_url, oss_url, voice_duration_millis, pdf_file_name, pdf_file_size_bytes, delay_millis, enabled, created_by, updated_by, created_at, updated_at)
SELECT s.id, 5, 'VOICE', 'question', '翘指', NULL, 'https://kkhc.tos-cn-beijing.volces.com/eps-juzibot/permanent/material/%36%61%33%61%37%34%36%63%34%34%31%38%65%65%61%61%65%35%31%35%39%38%30%37.silk', 'https://drh.likeduoduiyi.cn/homework/voice/d7ad402c4d2b48d28489d9ec6b3c6261.mp3', 20000, NULL, NULL, 20000, 1, 'yaqi_prod_sync_20260623', 'yaqi_prod_sync_20260623', NOW(6), NOW(6)
FROM (SELECT id FROM drh_ai_config_homework_strategy WHERE strategy_name = 'yaqi-piano-day1-comment1' AND enabled = 1 ORDER BY id DESC LIMIT 1) s;

INSERT INTO drh_ai_config_homework_action (strategy_id, order_index, action_type, condition_key, condition_value, text_content, material_url, oss_url, voice_duration_millis, pdf_file_name, pdf_file_size_bytes, delay_millis, enabled, created_by, updated_by, created_at, updated_at)
SELECT s.id, 1, 'VOICE', 'question', '节奏有问题', NULL, 'https://kkhc.tos-cn-beijing.volces.com/eps-juzibot/permanent/material/%36%61%33%61%37%34%36%64%61%61%61%30%64%30%66%34%65%32%35%33%31%36%66%36.silk', 'https://drh.likeduoduiyi.cn/homework/voice/4fcc8c79aaad4b3f975709a942f1e318.mp3', 27000, NULL, NULL, 27000, 1, 'yaqi_prod_sync_20260623', 'yaqi_prod_sync_20260623', NOW(6), NOW(6)
FROM (SELECT id FROM drh_ai_config_homework_strategy WHERE strategy_name = 'yaqi-piano-day1-comment1' AND enabled = 1 ORDER BY id DESC LIMIT 1) s;

INSERT INTO drh_ai_config_homework_action (strategy_id, order_index, action_type, condition_key, condition_value, text_content, material_url, oss_url, voice_duration_millis, pdf_file_name, pdf_file_size_bytes, delay_millis, enabled, created_by, updated_by, created_at, updated_at)
SELECT s.id, 2, 'VIDEO_CHANNEL', 'question', '节奏有问题', 'V24', NULL, NULL, NULL, NULL, NULL, 2000, 1, 'yaqi_prod_sync_20260623', 'yaqi_prod_sync_20260623', NOW(6), NOW(6)
FROM (SELECT id FROM drh_ai_config_homework_strategy WHERE strategy_name = 'yaqi-piano-day1-comment1' AND enabled = 1 ORDER BY id DESC LIMIT 1) s;

INSERT INTO drh_ai_config_homework_action (strategy_id, order_index, action_type, condition_key, condition_value, text_content, material_url, oss_url, voice_duration_millis, pdf_file_name, pdf_file_size_bytes, delay_millis, enabled, created_by, updated_by, created_at, updated_at)
SELECT s.id, 3, 'TEXT', 'question', '节奏有问题', '很多老师都不会在前期讲到的节奏问题，老师必须给您讲一下！在练习阶段，一定要越慢越好，不要追求速度，把节奏放下来，用嘴打节拍最好~', NULL, NULL, NULL, NULL, NULL, 2000, 1, 'yaqi_prod_sync_20260623', 'yaqi_prod_sync_20260623', NOW(6), NOW(6)
FROM (SELECT id FROM drh_ai_config_homework_strategy WHERE strategy_name = 'yaqi-piano-day1-comment1' AND enabled = 1 ORDER BY id DESC LIMIT 1) s;

INSERT INTO drh_ai_config_homework_action (strategy_id, order_index, action_type, condition_key, condition_value, text_content, material_url, oss_url, voice_duration_millis, pdf_file_name, pdf_file_size_bytes, delay_millis, enabled, created_by, updated_by, created_at, updated_at)
SELECT s.id, 4, 'VOICE', 'question', '节奏有问题', NULL, 'https://kkhc.tos-cn-beijing.volces.com/eps-juzibot/permanent/material/%36%61%33%61%37%34%36%66%61%30%36%37%63%30%66%64%37%39%62%66%61%37%37%30.silk', 'https://drh.likeduoduiyi.cn/homework/voice/f4b06e4a5c8049b08689421463ea7747.mp3', 12000, NULL, NULL, 12000, 1, 'yaqi_prod_sync_20260623', 'yaqi_prod_sync_20260623', NOW(6), NOW(6)
FROM (SELECT id FROM drh_ai_config_homework_strategy WHERE strategy_name = 'yaqi-piano-day1-comment1' AND enabled = 1 ORDER BY id DESC LIMIT 1) s;

INSERT INTO drh_ai_config_homework_action (strategy_id, order_index, action_type, condition_key, condition_value, text_content, material_url, oss_url, voice_duration_millis, pdf_file_name, pdf_file_size_bytes, delay_millis, enabled, created_by, updated_by, created_at, updated_at)
SELECT s.id, 5, 'TEXT', 'question', '节奏有问题', '另外老师看咱们指法的运用总体还是不错的', NULL, NULL, NULL, NULL, NULL, 2000, 1, 'yaqi_prod_sync_20260623', 'yaqi_prod_sync_20260623', NOW(6), NOW(6)
FROM (SELECT id FROM drh_ai_config_homework_strategy WHERE strategy_name = 'yaqi-piano-day1-comment1' AND enabled = 1 ORDER BY id DESC LIMIT 1) s;

INSERT INTO drh_ai_config_homework_action (strategy_id, order_index, action_type, condition_key, condition_value, text_content, material_url, oss_url, voice_duration_millis, pdf_file_name, pdf_file_size_bytes, delay_millis, enabled, created_by, updated_by, created_at, updated_at)
SELECT s.id, 6, 'VOICE', 'question', '节奏有问题', NULL, 'https://kkhc.tos-cn-beijing.volces.com/eps-juzibot/permanent/material/%36%61%33%61%37%34%37%30%61%61%61%30%64%30%66%34%65%32%35%33%31%37%64%39.silk', 'https://drh.likeduoduiyi.cn/homework/voice/37ccbbd055df426894f271d5119d89c2.mp3', 35000, NULL, NULL, 35000, 1, 'yaqi_prod_sync_20260623', 'yaqi_prod_sync_20260623', NOW(6), NOW(6)
FROM (SELECT id FROM drh_ai_config_homework_strategy WHERE strategy_name = 'yaqi-piano-day1-comment1' AND enabled = 1 ORDER BY id DESC LIMIT 1) s;

INSERT INTO drh_ai_config_homework_action (strategy_id, order_index, action_type, condition_key, condition_value, text_content, material_url, oss_url, voice_duration_millis, pdf_file_name, pdf_file_size_bytes, delay_millis, enabled, created_by, updated_by, created_at, updated_at)
SELECT s.id, 1, 'VOICE', '', '', NULL, 'https://kkhc.tos-cn-beijing.volces.com/eps-juzibot/permanent/material/%36%61%33%61%37%34%37%32%34%34%31%38%65%65%61%61%65%35%31%35%39%39%62%63.silk', 'https://drh.likeduoduiyi.cn/homework/voice/97292562b32748a4ab13b924c9a8f76e.mp3', 41000, NULL, NULL, 41000, 1, 'yaqi_prod_sync_20260623', 'yaqi_prod_sync_20260623', NOW(6), NOW(6)
FROM (SELECT id FROM drh_ai_config_homework_strategy WHERE strategy_name = 'yaqi-piano-day2-comment1' AND enabled = 1 ORDER BY id DESC LIMIT 1) s;

INSERT INTO drh_ai_config_homework_action (strategy_id, order_index, action_type, condition_key, condition_value, text_content, material_url, oss_url, voice_duration_millis, pdf_file_name, pdf_file_size_bytes, delay_millis, enabled, created_by, updated_by, created_at, updated_at)
SELECT s.id, 2, 'IMAGE', '', '', NULL, 'https://kkhc.tos-cn-beijing.volces.com/mh/permanent/material/5fc83141-3171-429e-9156-412880ae5786/%61%31%33%36%63%63%64%30%66%34%34%31%34%36%63%37%38%39%31%38%38%64%63%61%38%34%65%61%32%31%61%35.png', 'https://drh.likeduoduiyi.cn/homework/file/a136ccd0f44146c789188dca84ea21a5.png', NULL, NULL, NULL, 2000, 1, 'yaqi_prod_sync_20260623', 'yaqi_prod_sync_20260623', NOW(6), NOW(6)
FROM (SELECT id FROM drh_ai_config_homework_strategy WHERE strategy_name = 'yaqi-piano-day2-comment1' AND enabled = 1 ORDER BY id DESC LIMIT 1) s;

INSERT INTO drh_ai_config_homework_action (strategy_id, order_index, action_type, condition_key, condition_value, text_content, material_url, oss_url, voice_duration_millis, pdf_file_name, pdf_file_size_bytes, delay_millis, enabled, created_by, updated_by, created_at, updated_at)
SELECT s.id, 3, 'TEXT', '', '', '老师用笔给您圈出来方便看', NULL, NULL, NULL, NULL, NULL, 2000, 1, 'yaqi_prod_sync_20260623', 'yaqi_prod_sync_20260623', NOW(6), NOW(6)
FROM (SELECT id FROM drh_ai_config_homework_strategy WHERE strategy_name = 'yaqi-piano-day2-comment1' AND enabled = 1 ORDER BY id DESC LIMIT 1) s;

INSERT INTO drh_ai_config_homework_action (strategy_id, order_index, action_type, condition_key, condition_value, text_content, material_url, oss_url, voice_duration_millis, pdf_file_name, pdf_file_size_bytes, delay_millis, enabled, created_by, updated_by, created_at, updated_at)
SELECT s.id, 4, 'VOICE', '', '', NULL, 'https://kkhc.tos-cn-beijing.volces.com/eps-juzibot/permanent/material/%36%61%33%61%37%34%37%34%61%61%61%30%64%30%66%34%65%32%35%33%31%39%39%37.silk', 'https://drh.likeduoduiyi.cn/homework/voice/ea553c962bdf48cdae81892efc1723d2.mp3', 57000, NULL, NULL, 57000, 1, 'yaqi_prod_sync_20260623', 'yaqi_prod_sync_20260623', NOW(6), NOW(6)
FROM (SELECT id FROM drh_ai_config_homework_strategy WHERE strategy_name = 'yaqi-piano-day2-comment1' AND enabled = 1 ORDER BY id DESC LIMIT 1) s;

INSERT INTO drh_ai_config_homework_action (strategy_id, order_index, action_type, condition_key, condition_value, text_content, material_url, oss_url, voice_duration_millis, pdf_file_name, pdf_file_size_bytes, delay_millis, enabled, created_by, updated_by, created_at, updated_at)
SELECT s.id, 5, 'VOICE', '', '', NULL, 'https://kkhc.tos-cn-beijing.volces.com/eps-juzibot/permanent/material/%36%61%33%61%37%34%37%35%61%30%36%37%63%30%66%64%37%39%62%66%61%61%37%64.silk', 'https://drh.likeduoduiyi.cn/homework/voice/6857a673be8844509f9b60d7cfe19b19.mp3', 15000, NULL, NULL, 15000, 1, 'yaqi_prod_sync_20260623', 'yaqi_prod_sync_20260623', NOW(6), NOW(6)
FROM (SELECT id FROM drh_ai_config_homework_strategy WHERE strategy_name = 'yaqi-piano-day2-comment1' AND enabled = 1 ORDER BY id DESC LIMIT 1) s;

INSERT INTO drh_ai_config_homework_action (strategy_id, order_index, action_type, condition_key, condition_value, text_content, material_url, oss_url, voice_duration_millis, pdf_file_name, pdf_file_size_bytes, delay_millis, enabled, created_by, updated_by, created_at, updated_at)
SELECT s.id, 1, 'VOICE', '', '', NULL, 'https://kkhc.tos-cn-beijing.volces.com/eps-juzibot/permanent/material/%36%61%33%61%37%34%37%36%61%30%36%37%63%30%66%64%37%39%62%66%61%61%66%36.silk', 'https://drh.likeduoduiyi.cn/homework/voice/8e85e96dafcd4ab6aeef1e51dc3b2ca3.mp3', 19000, NULL, NULL, 19000, 1, 'yaqi_prod_sync_20260623', 'yaqi_prod_sync_20260623', NOW(6), NOW(6)
FROM (SELECT id FROM drh_ai_config_homework_strategy WHERE strategy_name = 'yaqi-piano-day3-comment1' AND enabled = 1 ORDER BY id DESC LIMIT 1) s;

INSERT INTO drh_ai_config_homework_action (strategy_id, order_index, action_type, condition_key, condition_value, text_content, material_url, oss_url, voice_duration_millis, pdf_file_name, pdf_file_size_bytes, delay_millis, enabled, created_by, updated_by, created_at, updated_at)
SELECT s.id, 2, 'IMAGE', '', '', NULL, 'https://kkhc.tos-cn-beijing.volces.com/mh/permanent/material/939d94b9-633e-4ea5-ad4d-1d512f3c85f4/%64%32%35%38%33%66%30%34%65%33%34%61%34%37%39%63%62%63%33%39%35%62%30%63%31%31%63%66%31%61%63%34.jpg', 'https://drh.likeduoduiyi.cn/homework/file/d2583f04e34a479cbc395b0c11cf1ac4.jpg', NULL, NULL, NULL, 2000, 1, 'yaqi_prod_sync_20260623', 'yaqi_prod_sync_20260623', NOW(6), NOW(6)
FROM (SELECT id FROM drh_ai_config_homework_strategy WHERE strategy_name = 'yaqi-piano-day3-comment1' AND enabled = 1 ORDER BY id DESC LIMIT 1) s;

INSERT INTO drh_ai_config_homework_action (strategy_id, order_index, action_type, condition_key, condition_value, text_content, material_url, oss_url, voice_duration_millis, pdf_file_name, pdf_file_size_bytes, delay_millis, enabled, created_by, updated_by, created_at, updated_at)
SELECT s.id, 3, 'VOICE', '', '', NULL, 'https://kkhc.tos-cn-beijing.volces.com/eps-juzibot/permanent/material/%36%61%33%61%37%34%37%38%34%34%31%38%65%65%61%61%65%35%31%35%39%63%33%33.silk', 'https://drh.likeduoduiyi.cn/homework/voice/5624acb663ad4fa6b11c55a000bb916b.mp3', 33000, NULL, NULL, 33000, 1, 'yaqi_prod_sync_20260623', 'yaqi_prod_sync_20260623', NOW(6), NOW(6)
FROM (SELECT id FROM drh_ai_config_homework_strategy WHERE strategy_name = 'yaqi-piano-day3-comment1' AND enabled = 1 ORDER BY id DESC LIMIT 1) s;

INSERT INTO drh_ai_config_homework_action (strategy_id, order_index, action_type, condition_key, condition_value, text_content, material_url, oss_url, voice_duration_millis, pdf_file_name, pdf_file_size_bytes, delay_millis, enabled, created_by, updated_by, created_at, updated_at)
SELECT s.id, 4, 'IMAGE', '', '', NULL, 'https://kkhc.tos-cn-beijing.volces.com/mh/permanent/material/dcf8deb4-759a-494f-bc59-f3114a0e17ac/%33%62%31%30%36%65%30%37%34%66%64%66%34%62%33%34%39%63%37%61%62%38%39%64%39%35%33%65%36%35%33%62.png', 'https://drh.likeduoduiyi.cn/homework/file/3b106e074fdf4b349c7ab89d953e653b.png', NULL, NULL, NULL, 2000, 1, 'yaqi_prod_sync_20260623', 'yaqi_prod_sync_20260623', NOW(6), NOW(6)
FROM (SELECT id FROM drh_ai_config_homework_strategy WHERE strategy_name = 'yaqi-piano-day3-comment1' AND enabled = 1 ORDER BY id DESC LIMIT 1) s;

INSERT INTO drh_ai_config_homework_action (strategy_id, order_index, action_type, condition_key, condition_value, text_content, material_url, oss_url, voice_duration_millis, pdf_file_name, pdf_file_size_bytes, delay_millis, enabled, created_by, updated_by, created_at, updated_at)
SELECT s.id, 5, 'VOICE', '', '', NULL, 'https://kkhc.tos-cn-beijing.volces.com/eps-juzibot/permanent/material/%36%61%33%61%37%34%37%61%61%61%61%30%64%30%66%34%65%32%35%33%31%63%36%32.silk', 'https://drh.likeduoduiyi.cn/homework/voice/4134275d46a248ea92fea9124bd9639e.mp3', 57000, NULL, NULL, 57000, 1, 'yaqi_prod_sync_20260623', 'yaqi_prod_sync_20260623', NOW(6), NOW(6)
FROM (SELECT id FROM drh_ai_config_homework_strategy WHERE strategy_name = 'yaqi-piano-day3-comment1' AND enabled = 1 ORDER BY id DESC LIMIT 1) s;

INSERT INTO drh_ai_config_homework_action (strategy_id, order_index, action_type, condition_key, condition_value, text_content, material_url, oss_url, voice_duration_millis, pdf_file_name, pdf_file_size_bytes, delay_millis, enabled, created_by, updated_by, created_at, updated_at)
SELECT s.id, 1, 'VOICE', '', '', NULL, 'https://kkhc.tos-cn-beijing.volces.com/eps-juzibot/permanent/material/%36%61%33%61%37%34%37%63%61%61%61%30%64%30%66%34%65%32%35%33%31%63%66%62.silk', 'https://drh.likeduoduiyi.cn/homework/voice/aafb1cbc20664834bc015135a1fc283c.mp3', 42000, NULL, NULL, 42000, 1, 'yaqi_prod_sync_20260623', 'yaqi_prod_sync_20260623', NOW(6), NOW(6)
FROM (SELECT id FROM drh_ai_config_homework_strategy WHERE strategy_name = 'yaqi-piano-day4-comment1' AND enabled = 1 ORDER BY id DESC LIMIT 1) s;

INSERT INTO drh_ai_config_homework_action (strategy_id, order_index, action_type, condition_key, condition_value, text_content, material_url, oss_url, voice_duration_millis, pdf_file_name, pdf_file_size_bytes, delay_millis, enabled, created_by, updated_by, created_at, updated_at)
SELECT s.id, 2, 'VOICE', '', '', NULL, 'https://kkhc.tos-cn-beijing.volces.com/eps-juzibot/permanent/material/%36%61%33%61%37%34%37%64%61%30%36%37%63%30%66%64%37%39%62%66%61%64%37%30.silk', 'https://drh.likeduoduiyi.cn/homework/voice/4922ba0c2df44e9799d22f7dada32340.mp3', 27000, NULL, NULL, 27000, 1, 'yaqi_prod_sync_20260623', 'yaqi_prod_sync_20260623', NOW(6), NOW(6)
FROM (SELECT id FROM drh_ai_config_homework_strategy WHERE strategy_name = 'yaqi-piano-day4-comment1' AND enabled = 1 ORDER BY id DESC LIMIT 1) s;

INSERT INTO drh_ai_config_homework_route (day_num, comment_index, comment_match_type, match_key, match_value, sku_id, strategy_id, enabled, created_by, updated_by, created_at, updated_at)
SELECT 1, 1, 'EQ', 'currentDay&&homeworkDayRelation&&speakerId', '1&&CURRENT&&113', '4', s.id, 1, 'yaqi_prod_sync_20260623', 'yaqi_prod_sync_20260623', NOW(6), NOW(6)
FROM (SELECT id FROM drh_ai_config_homework_strategy WHERE strategy_name = 'yaqi-piano-day1-comment1' AND enabled = 1 ORDER BY id DESC LIMIT 1) s;

INSERT INTO drh_ai_config_homework_route (day_num, comment_index, comment_match_type, match_key, match_value, sku_id, strategy_id, enabled, created_by, updated_by, created_at, updated_at)
SELECT 2, 1, 'EQ', 'currentDay&&homeworkDayRelation&&speakerId', '2&&CURRENT&&113', '4', s.id, 1, 'yaqi_prod_sync_20260623', 'yaqi_prod_sync_20260623', NOW(6), NOW(6)
FROM (SELECT id FROM drh_ai_config_homework_strategy WHERE strategy_name = 'yaqi-piano-day2-comment1' AND enabled = 1 ORDER BY id DESC LIMIT 1) s;

INSERT INTO drh_ai_config_homework_route (day_num, comment_index, comment_match_type, match_key, match_value, sku_id, strategy_id, enabled, created_by, updated_by, created_at, updated_at)
SELECT 3, 1, 'EQ', 'currentDay&&homeworkDayRelation&&speakerId', '3&&CURRENT&&113', '4', s.id, 1, 'yaqi_prod_sync_20260623', 'yaqi_prod_sync_20260623', NOW(6), NOW(6)
FROM (SELECT id FROM drh_ai_config_homework_strategy WHERE strategy_name = 'yaqi-piano-day3-comment1' AND enabled = 1 ORDER BY id DESC LIMIT 1) s;

INSERT INTO drh_ai_config_homework_route (day_num, comment_index, comment_match_type, match_key, match_value, sku_id, strategy_id, enabled, created_by, updated_by, created_at, updated_at)
SELECT 4, 1, 'EQ', 'currentDay&&homeworkDayRelation&&speakerId', '4&&CURRENT&&113', '4', s.id, 1, 'yaqi_prod_sync_20260623', 'yaqi_prod_sync_20260623', NOW(6), NOW(6)
FROM (SELECT id FROM drh_ai_config_homework_strategy WHERE strategy_name = 'yaqi-piano-day4-comment1' AND enabled = 1 ORDER BY id DESC LIMIT 1) s;

SELECT
  (SELECT COUNT(*) FROM drh_ai_config_homework_strategy WHERE strategy_name LIKE 'yaqi-piano-%' AND enabled = 1) AS yaqi_enabled_strategy,
  (SELECT COUNT(*) FROM drh_ai_config_homework_action a JOIN drh_ai_config_homework_strategy s ON s.id = a.strategy_id WHERE s.strategy_name LIKE 'yaqi-piano-%' AND a.enabled = 1) AS yaqi_enabled_action,
  (SELECT COUNT(*) FROM drh_ai_config_homework_route r JOIN drh_ai_config_homework_strategy s ON s.id = r.strategy_id WHERE s.strategy_name LIKE 'yaqi-piano-%' AND r.enabled = 1) AS yaqi_enabled_route;
