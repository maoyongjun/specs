SELECT task_id, external_user_id, user_id, union_id, source, add_tag_list,
       remove_tag_list, status, fc_errcode, fc_errmsg, verify_count,
       next_verify_time, created_at, updated_at
FROM drh.drh_qw_external_tag_task
WHERE task_id = 'c29a78d958a24516bd2eb1a3188dea8e';
