-- drh_history_pic union_id 备份 SQL
-- 目标：将指定 union_id 在“胡琴说（上）”课程下对应作业的人工点评记录 union_id 改为 {union_id}_bak
-- 注意：默认 ROLLBACK，不直接提交；审核确认后将最后的 ROLLBACK 改为 COMMIT。

START TRANSACTION;

DROP TEMPORARY TABLE IF EXISTS tmp_drh_history_pic_unionid_bak_target;

CREATE TEMPORARY TABLE tmp_drh_history_pic_unionid_bak_target AS
SELECT DISTINCT
    hp.id,
    hp.pic_id,
    wp.live_id AS class_id,
    hp.union_id AS source_union_id,
    CONCAT(hp.union_id, '_bak') AS target_union_id,
    l.name AS live_name
FROM drh_history_pic hp
JOIN drh_works_pic wp
    ON wp.id = hp.pic_id
   AND wp.union_id = hp.union_id
JOIN drh_live l
    ON l.id = wp.live_id
WHERE hp.union_id IN (
    'oNGxt5zmBZ2howLnojgjhd3e9ntI',
    'oNGxt54fYKaIKHAGsqEFhYLtXXbY',
    'oNGxt5y-muyKxySOWAw4u-gmzvNo',
    'oNGxt5z_XoNyC5kG_Q7f-WJRNlmA',
    'oNGxt5_XcRNYDz971WrqFeJOCYyk'
)
AND l.name = '胡琴说（上）';

-- 审核目标行
SELECT *
FROM tmp_drh_history_pic_unionid_bak_target
ORDER BY class_id, source_union_id, pic_id, id;

-- 审核每个 union_id 命中数量
SELECT class_id, source_union_id, target_union_id, COUNT(*) AS target_count
FROM tmp_drh_history_pic_unionid_bak_target
GROUP BY class_id, source_union_id, target_union_id
ORDER BY class_id, source_union_id;

-- 执行更新
UPDATE drh_history_pic hp
JOIN tmp_drh_history_pic_unionid_bak_target t
    ON t.id = hp.id
SET hp.union_id = t.target_union_id
WHERE hp.union_id = t.source_union_id;

-- 更新后复核
SELECT
    t.class_id,
    t.source_union_id,
    t.target_union_id,
    COUNT(*) AS target_count,
    SUM(CASE WHEN hp.union_id = t.target_union_id THEN 1 ELSE 0 END) AS updated_count,
    SUM(CASE WHEN hp.union_id <> t.target_union_id THEN 1 ELSE 0 END) AS not_updated_count
FROM tmp_drh_history_pic_unionid_bak_target t
JOIN drh_history_pic hp
    ON hp.id = t.id
GROUP BY t.class_id, t.source_union_id, t.target_union_id
ORDER BY t.class_id, t.source_union_id;

-- 更新后运维接口参数：POST /works/songScore
-- class_id 即 live_id；max_score/min_score/song_name 按本次运维口径固定。
SELECT JSON_OBJECT(
    'class_id', p.class_id,
    'max_score', 83,
    'min_score', 77,
    'song_name', '胡琴说'
) AS song_score_request_body
FROM (
    SELECT DISTINCT class_id
    FROM tmp_drh_history_pic_unionid_bak_target
) p
ORDER BY p.class_id;

-- 审核确认后改为 COMMIT;
ROLLBACK;
