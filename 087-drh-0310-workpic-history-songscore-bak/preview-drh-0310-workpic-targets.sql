-- 0310 营期《胡琴说（下）》目标作业只读清单
-- 用途：执行前归档 workPicId、live_id、原始 status、is_del 和 union_id。

SELECT
  d.id AS camp_id,
  d.name AS camp_name,
  c.id AS live_id,
  c.name AS live_name,
  wp.id AS work_pic_id,
  wp.status AS current_status,
  wp.is_del,
  wp.union_id
FROM drh_works_pic wp
JOIN drh_live c ON wp.live_id = c.id
JOIN drh_live_camp d ON c.live_camp_id = d.id
WHERE d.name IN (
  '进阶班0310期-小靳老师班',
  '进阶班0310期-董董老师班',
  '进阶班0310期-玉米老师'
)
AND c.name = '胡琴说（下）'
ORDER BY FIELD(
  d.name,
  '进阶班0310期-小靳老师班',
  '进阶班0310期-董董老师班',
  '进阶班0310期-玉米老师'
), c.id, wp.id;
