-- 0428 营期《胡琴说（下）》目标作业只读清单
-- 用途：执行前归档 workPicId、live_id、原始 status、is_del 和 union_id。

SELECT
  d.id AS camp_id,
  d.name AS camp_name,
  c.id AS live_id,
  c.name AS live_name,
  b.id AS work_pic_id,
  b.status AS current_status,
  b.is_del,
  b.union_id
FROM drh_works_pic b
JOIN drh_live c ON b.live_id = c.id
JOIN drh_live_camp d ON c.live_camp_id = d.id
WHERE d.name IN (
  '进阶班0428期-晨宇老师',
  '进阶班0428期-彦铭老师班',
  '进阶班0428期-康康老师班',
  '进阶班0428期-小向老师班'
)
AND c.name = '胡琴说（下）'
ORDER BY FIELD(
  d.name,
  '进阶班0428期-晨宇老师',
  '进阶班0428期-彦铭老师班',
  '进阶班0428期-康康老师班',
  '进阶班0428期-小向老师班'
), c.id, b.id;
