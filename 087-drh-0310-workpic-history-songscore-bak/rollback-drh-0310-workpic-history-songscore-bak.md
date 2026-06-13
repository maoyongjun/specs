# 回滚说明：0310 营期作业状态、历史点评与五维分数 `_bak`

本目录用三份执行前快照作为回滚依据：

- `preview-drh-0310-workpic-targets.csv`：包含 `work_pic_id -> current_status`。
- `preview-drh-0310-history-unionid-snapshot.csv`：包含 `history_id -> original_union_id`。
- `preview-drh-0310-song-score-unionid-snapshot.csv`：包含 `song_score_id -> original_union_id`。

如需回滚，先从 CSV 构造临时表，再按主键回写：

```sql
START TRANSACTION;

-- 1. 导入 work_pic_id, original_status 到临时表 tmp_rollback_workpic_status。
-- 2. 导入 history_id, original_union_id 到临时表 tmp_rollback_history_unionid。
-- 3. 导入 song_score_id, original_union_id 到临时表 tmp_rollback_song_score_unionid。

UPDATE drh_works_pic wp
JOIN tmp_rollback_workpic_status rb ON wp.id = rb.work_pic_id
SET wp.status = rb.original_status;

UPDATE drh_history_pic hp
JOIN tmp_rollback_history_unionid rb ON hp.id = rb.history_id
SET hp.union_id = rb.original_union_id
WHERE hp.union_id = CONCAT(rb.original_union_id, '_bak');

UPDATE drh_song_score ss
JOIN tmp_rollback_song_score_unionid rb ON ss.id = rb.song_score_id
SET ss.union_id = rb.original_union_id
WHERE ss.union_id = CONCAT(rb.original_union_id, '_bak');

-- 复核数量无误后再提交。
ROLLBACK;
```

仓库内不保存数据库连接信息。真实回滚前必须重新执行只读复核，并按 `database-sql-skill` 写入门禁分析 SQL 风险。
