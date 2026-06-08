SELECT 'drh_kk_emp' AS table_name, COUNT(*) AS row_count FROM drh_kk_emp
UNION ALL
SELECT 'drh_kk_one_emp' AS table_name, COUNT(*) AS row_count FROM drh_kk_one_emp;
