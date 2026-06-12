-- 0428 营期《胡琴说（下）》作业状态回退与历史点评 union_id 备份
-- 默认 ROLLBACK：正式执行前必须先审阅 preview CSV 和本脚本分析结果。
-- 正式提交时，只允许把最后一行 ROLLBACK 改为 COMMIT，其他筛选条件不得扩大。
-- 注意：所有临时表 DDL 必须在 START TRANSACTION 之前完成，避免 MySQL DDL 隐式提交影响回滚语义。

SET @expected_work_pic_count := 1972;
SET @expected_history_count := 855;

DROP TEMPORARY TABLE IF EXISTS tmp_drh_0428_workpic_targets;
CREATE TEMPORARY TABLE tmp_drh_0428_workpic_targets AS
SELECT
  b.id AS work_pic_id,
  b.live_id,
  d.id AS camp_id,
  d.name AS camp_name,
  c.name AS live_name,
  b.union_id,
  b.status AS original_status,
  b.is_del
FROM drh_works_pic b
JOIN drh_live c ON b.live_id = c.id
JOIN drh_live_camp d ON c.live_camp_id = d.id
WHERE d.name IN (
  '进阶班0428期-晨宇老师',
  '进阶班0428期-彦铭老师班',
  '进阶班0428期-康康老师班',
  '进阶班0428期-小向老师班'
)
AND c.name = '胡琴说（下）';

ALTER TABLE tmp_drh_0428_workpic_targets ADD PRIMARY KEY (work_pic_id);

SELECT COUNT(*) INTO @target_work_pic_count
FROM tmp_drh_0428_workpic_targets;

DROP TEMPORARY TABLE IF EXISTS tmp_drh_0428_history_targets;
CREATE TEMPORARY TABLE tmp_drh_0428_history_targets AS
SELECT
  hp.id AS history_id,
  hp.pic_id,
  wp.id AS work_pic_id,
  wp.live_id,
  t.camp_id,
  t.camp_name,
  hp.union_id AS original_union_id,
  CONCAT(hp.union_id, '_bak') AS target_union_id
FROM drh_history_pic hp
JOIN drh_works_pic wp
  ON hp.pic_id = wp.id
 AND hp.union_id = wp.union_id
JOIN tmp_drh_0428_workpic_targets t ON wp.id = t.work_pic_id
WHERE wp.is_del = 0
AND hp.union_id NOT LIKE '%\\_bak' ESCAPE '\\';

ALTER TABLE tmp_drh_0428_history_targets ADD PRIMARY KEY (history_id);

SELECT COUNT(*) INTO @target_history_count
FROM tmp_drh_0428_history_targets;

SELECT
  'before_work_pic' AS phase,
  camp_id,
  camp_name,
  live_id,
  COUNT(*) AS work_pic_count,
  SUM(CASE WHEN original_status = 0 THEN 1 ELSE 0 END) AS current_status0_count,
  SUM(CASE WHEN original_status <> 0 OR original_status IS NULL THEN 1 ELSE 0 END) AS current_not_status0_count,
  SUM(CASE WHEN is_del = 0 THEN 1 ELSE 0 END) AS active_work_pic_count
FROM tmp_drh_0428_workpic_targets
GROUP BY camp_id, camp_name, live_id
ORDER BY camp_id, live_id;

SELECT
  'before_history' AS phase,
  camp_id,
  camp_name,
  live_id,
  COUNT(*) AS history_count,
  COUNT(DISTINCT original_union_id) AS history_union_count
FROM tmp_drh_0428_history_targets
GROUP BY camp_id, camp_name, live_id
ORDER BY camp_id, live_id;

START TRANSACTION;

UPDATE drh_works_pic wp
JOIN tmp_drh_0428_workpic_targets t ON wp.id = t.work_pic_id
SET wp.status = 0
WHERE @target_work_pic_count = @expected_work_pic_count;

SET @work_pic_changed_rows := ROW_COUNT();

UPDATE drh_history_pic hp
JOIN tmp_drh_0428_history_targets t ON hp.id = t.history_id
JOIN drh_works_pic wp ON wp.id = t.work_pic_id
SET hp.union_id = t.target_union_id
WHERE @target_work_pic_count = @expected_work_pic_count
AND @target_history_count = @expected_history_count
AND wp.status = 0
AND wp.is_del = 0
AND hp.union_id = t.original_union_id;

SET @history_changed_rows := ROW_COUNT();

SELECT
  SUM(CASE WHEN wp.status = 0 THEN 1 ELSE 0 END),
  SUM(CASE WHEN wp.status <> 0 OR wp.status IS NULL THEN 1 ELSE 0 END)
INTO @work_pic_status0_count, @work_pic_not_status0_count
FROM drh_works_pic wp
JOIN tmp_drh_0428_workpic_targets t ON wp.id = t.work_pic_id;

SELECT
  SUM(CASE WHEN hp.union_id = t.target_union_id THEN 1 ELSE 0 END),
  SUM(CASE WHEN hp.union_id <> t.target_union_id OR hp.union_id IS NULL THEN 1 ELSE 0 END)
INTO @history_updated_count, @history_not_updated_count
FROM tmp_drh_0428_history_targets t
LEFT JOIN drh_history_pic hp ON hp.id = t.history_id;

SELECT
  'final_transaction_checks' AS phase,
  @target_work_pic_count AS target_work_pic_count,
  @work_pic_changed_rows AS work_pic_changed_rows,
  @work_pic_status0_count AS work_pic_status0_count,
  @work_pic_not_status0_count AS work_pic_not_status0_count,
  @target_history_count AS target_history_count,
  @history_changed_rows AS history_changed_rows,
  @history_updated_count AS history_updated_count,
  @history_not_updated_count AS history_not_updated_count;

ROLLBACK;
