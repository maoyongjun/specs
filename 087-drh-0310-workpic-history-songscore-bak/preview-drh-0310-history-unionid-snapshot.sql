-- 0310 营期《胡琴说（下）》历史点评 union_id 回滚快照
-- 用途：执行前归档将被改为 _bak 的 drh_history_pic 记录。

SELECT
  d.id AS camp_id,
  d.name AS camp_name,
  c.id AS live_id,
  c.name AS live_name,
  wp.id AS work_pic_id,
  wp.status AS current_work_pic_status,
  wp.is_del,
  hp.id AS history_id,
  hp.pic_id,
  hp.union_id AS original_union_id,
  CONCAT(hp.union_id, '_bak') AS target_union_id
FROM drh_history_pic hp
JOIN drh_works_pic wp
  ON hp.pic_id = wp.id
 AND hp.union_id = wp.union_id
JOIN drh_live c ON wp.live_id = c.id
JOIN drh_live_camp d ON c.live_camp_id = d.id
WHERE d.name IN (
  '进阶班0310期-小靳老师班',
  '进阶班0310期-董董老师班',
  '进阶班0310期-玉米老师'
)
AND c.name = '胡琴说（下）'
AND wp.is_del = 0
AND hp.union_id NOT LIKE '%\\_bak' ESCAPE '\\'
ORDER BY FIELD(
  d.name,
  '进阶班0310期-小靳老师班',
  '进阶班0310期-董董老师班',
  '进阶班0310期-玉米老师'
), c.id, wp.id, hp.id;
