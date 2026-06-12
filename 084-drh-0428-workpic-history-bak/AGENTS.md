# 规格执行说明

本目录记录 0428 营期 `胡琴说（下）` 作业状态回退与历史点评 `union_id` 备份的 Spec Kit 文档、SQL、预览快照和执行记录。

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\084-drh-0428-workpic-history-bak`
- 目标项目：`C:\workspace\ju-chat`
- 相关模块：数据库运维 / `drh_works_pic` / `drh_history_pic`

## 当前目标

- 查询并归档 4 个 0428 营期在 `胡琴说（下）` 下的 workPicId。
- 将目标 `drh_works_pic.status` 统一设置为 `0`。
- 将目标 `drh_history_pic.union_id` 改为 `{union_id}_bak`。
- 保留执行前 CSV 快照、仓库内默认 `ROLLBACK` 脚本和提交后复核结果。

## 执行原则

- 必须先用 `database-sql-skill analyze` 分析 SQL，再执行。
- 只读 SQL 可直接通过 `prod-mysql` profile 执行；写 SQL 必须使用 `--allow-write --confirm`。
- 写入范围必须来自临时表固化的 `work_pic_id` 和 `history_id`，不得只用 `live_id IN (...)` 扩大范围。
- 仓库内执行 SQL 默认 `ROLLBACK`；正式提交只能使用临时 `COMMIT` 副本。
- 临时表 DDL 必须在 `START TRANSACTION` 之前，事务内只保留 DML 和复核，避免 MySQL DDL 隐式提交影响回滚。

## 强制门禁

- 关键参数必须可追溯到用户输入、正式库只读查询或 SQL 内现算。
- `drh_works_pic` 只允许修改 `status`。
- `drh_history_pic` 只允许修改 `union_id`。
- 历史点评更新必须保留 `wp.status=0`、`wp.is_del=0`、`hp.union_id NOT LIKE '%\_bak'`。
- 执行后必须复核 `work_pic_not_status0_count=0` 和 `history_not_updated_count=0`。
- 执行记录必须写明预览数量、演练结果、正式提交结果和剩余风险。

## 重点文件

- `preview-drh-0428-workpic-targets.sql`
- `preview-drh-0428-workpic-targets.csv`
- `preview-drh-0428-history-unionid-snapshot.sql`
- `preview-drh-0428-history-unionid-snapshot.csv`
- `execute-drh-0428-workpic-history-bak.sql`
- `verify-drh-0428-workpic-history-bak.sql`
- `verify-drh-0428-workpic-history-bak-after.csv`
- `rollback-drh-0428-workpic-history-bak.md`

## 文档维护

- `spec.md` 记录需求背景、范围、边界、成功标准、假设和执行记录。
- `tasks.md` 记录事实确认、风险门禁、脚本整理、执行和验证。
- `checklists\requirements.md` 记录规格质量、SQL 审阅和实施就绪度。
- 后续如需回滚或补充处理范围，必须追加 Dxxx 记录，并同步更新 `spec.md`、`tasks.md`、`AGENTS.md` 和 checklist。
