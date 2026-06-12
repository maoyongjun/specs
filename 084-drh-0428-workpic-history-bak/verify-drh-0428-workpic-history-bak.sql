-- 0428 营期《胡琴说（下）》提交后只读复核

SELECT
  d.id AS camp_id,
  d.name AS camp_name,
  c.id AS live_id,
  COUNT(DISTINCT wp.id) AS work_pic_count,
  COUNT(DISTINCT CASE WHEN wp.status = 0 THEN wp.id END) AS status0_count,
  COUNT(DISTINCT CASE WHEN wp.status <> 0 OR wp.status IS NULL THEN wp.id END) AS not_status0_count,
  COUNT(DISTINCT CASE WHEN wp.is_del = 0 THEN wp.id END) AS active_work_pic_count,
  COUNT(DISTINCT hp_original.id) AS history_original_rows,
  COUNT(DISTINCT hp_bak.id) AS history_bak_rows
FROM drh_works_pic wp
JOIN drh_live c ON wp.live_id = c.id
JOIN drh_live_camp d ON c.live_camp_id = d.id
LEFT JOIN drh_history_pic hp_original
  ON hp_original.pic_id = wp.id
 AND hp_original.union_id = wp.union_id
 AND hp_original.union_id NOT LIKE '%\\_bak' ESCAPE '\\'
 AND wp.is_del = 0
LEFT JOIN drh_history_pic hp_bak
  ON hp_bak.pic_id = wp.id
 AND hp_bak.union_id = CONCAT(wp.union_id, '_bak')
 AND wp.is_del = 0
WHERE d.name IN (
  '进阶班0428期-晨宇老师',
  '进阶班0428期-彦铭老师班',
  '进阶班0428期-康康老师班',
  '进阶班0428期-小向老师班'
)
AND c.name = '胡琴说（下）'
GROUP BY d.id, d.name, c.id
ORDER BY FIELD(
  d.name,
  '进阶班0428期-晨宇老师',
  '进阶班0428期-彦铭老师班',
  '进阶班0428期-康康老师班',
  '进阶班0428期-小向老师班'
), c.id;
