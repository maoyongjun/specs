-- 0310 营期《胡琴说（下）》提交后只读复核

SELECT
  d.id AS camp_id,
  d.name AS camp_name,
  c.id AS live_id,
  COUNT(DISTINCT wp.id) AS work_pic_count,
  COUNT(DISTINCT CASE WHEN wp.status = 0 THEN wp.id END) AS status0_count,
  COUNT(DISTINCT CASE WHEN wp.status <> 0 OR wp.status IS NULL THEN wp.id END) AS not_status0_count,
  COUNT(DISTINCT CASE WHEN wp.is_del = 0 THEN wp.id END) AS active_work_pic_count,
  COUNT(DISTINCT hp_original.id) AS history_original_rows,
  COUNT(DISTINCT hp_bak.id) AS history_bak_rows,
  COUNT(DISTINCT ss_original.id) AS song_score_original_rows,
  COUNT(DISTINCT ss_bak.id) AS song_score_bak_rows
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
LEFT JOIN drh_song_score ss_original
  ON ss_original.pic_id = wp.id
 AND ss_original.union_id = wp.union_id
 AND ss_original.class_id = wp.live_id
 AND ss_original.union_id NOT LIKE '%\\_bak' ESCAPE '\\'
 AND wp.is_del = 0
LEFT JOIN drh_song_score ss_bak
  ON ss_bak.pic_id = wp.id
 AND ss_bak.union_id = CONCAT(wp.union_id, '_bak')
 AND ss_bak.class_id = wp.live_id
 AND wp.is_del = 0
WHERE d.name IN (
  '进阶班0310期-小靳老师班',
  '进阶班0310期-董董老师班',
  '进阶班0310期-玉米老师'
)
AND c.name = '胡琴说（下）'
GROUP BY d.id, d.name, c.id
ORDER BY FIELD(
  d.name,
  '进阶班0310期-小靳老师班',
  '进阶班0310期-董董老师班',
  '进阶班0310期-玉米老师'
), c.id;
