SELECT id, emp_id, external_userid, union_id, user_id, source, status, create_time
FROM drh.drh_emp_external_user
WHERE external_userid = 'wmW_OgDwAA5AMTr7TUm-2lSzna9CdDlA'
  AND union_id IS NOT NULL
  AND union_id <> ''
ORDER BY id DESC
LIMIT 10;
